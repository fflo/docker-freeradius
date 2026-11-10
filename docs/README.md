# FreeRADIUS Docker Container

This repository builds a FreeRADIUS Docker container using Alpine Linux.  It requires a MySQL database and can be configured with environment variables.

[![CI](https://github.com/fflo/docker-freeradius/actions/workflows/ci.yml/badge.svg)](https://github.com/fflo/docker-freeradius/actions/workflows/ci.yml)
[![Docker Stars](https://img.shields.io/docker/stars/fflo/freeradius.svg?style=popout-square)](https://hub.docker.com/r/fflo/freeradius)
[![Docker Pulls](https://img.shields.io/docker/pulls/fflo/freeradius.svg?style=popout-square)](https://hub.docker.com/r/fflo/freeradius)

## Supported tags
| Tag | Alpine Version | FreeRADIUS Version | Release Date | Changes |
| --- | :---: | :---: | :---: | :---: |
| [3.0.27.3, latest](https://github.com/fflo/docker-freeradius/blob/master/Dockerfile) | 3.24 | 3.0.27-r3 | 2026-11-10 | [Changelog](https://github.com/fflo/docker-freeradius/compare/3.0.26.2...master) |

# Running the container
-   With MySQL
```bash
$ docker run -d -t --name freeradius -p 1812:1812/udp -p 1813:1813/udp -e DB_HOST=<mysql.server> fflo/freeradius
```

# Environment Variables

-   DB_HOST=localhost
-   DB_PORT=3306
-   DB_USER=radius
-   DB_PASS=radpass
-   DB_NAME=radius
-   RADIUS_KEY=testing123
-   RAD_CLIENTS=10.0.0.0/24
-   RAD_DEBUG=no
-   MARIADB_TLS_DISABLE_PEER_VERIFICATION=1 (see "Database connection and TLS" below)

# Database connection and TLS

By default the connection to the database is not encrypted and the certificate of the database server is not verified, as in earlier versions of this image.  The MariaDB client library used by FreeRADIUS would otherwise verify the server certificate by default and refuse the self-signed certificate of a stock MySQL server (`TLS/SSL error: self-signed certificate in certificate chain`); the image sets `MARIADB_TLS_DISABLE_PEER_VERIFICATION=1` to keep the previous behaviour.

To encrypt the connection and verify the database server, un-comment the `tls` section in `etc/raddb/mods-available/sql`, set `tls_required = yes` and point `ca_file` to the CA of your database server.

# Docker Compose Example

You can use the included docker-compose.yml file to test Freeradius and MySQL integration:

```yaml
services:
  freeradius:
    image: "fflo/freeradius"
    ports:
      - "1812:1812/udp"
      - "1813:1813/udp"
    #volumes:
      #- "./configs/radius/users:/etc/raddb/users"
      #- "./configs/radius/clients.conf:/etc/raddb/clients.conf"
    environment:
      #- DB_NAME=radius
      - DB_HOST=mysql
      #- DB_USER=radius
      #- DB_PASS=radpass
      #- DB_PORT=3306
      #- RADIUS_KEY=testing123
      #- RAD_CLIENTS=10.0.0.0/24
      - RAD_DEBUG=yes
    depends_on:
      - mysql
    restart: always
    networks:
      - backend

  mysql:
    image: "mysql:8.4"
    # Only needed for data directories whose accounts were created with
    # mysql_native_password (the default of older versions of this file).
    command: --mysql-native-password=ON
    ports:
      - "3306:3306"
    volumes:
      - "./configs/mysql/master/data:/var/lib/mysql"
      #- "./configs/mysql/master/conf.d:/etc/mysql/conf.d"
      - "./configs/mysql/radius.sql:/docker-entrypoint-initdb.d/radius.sql"
    environment:
      - MYSQL_ROOT_PASSWORD=radius
      - MYSQL_USER=radius
      - MYSQL_PASSWORD=radpass
      - MYSQL_DATABASE=radius
    restart: always
    networks:
      - backend

networks:
  backend:
    ipam:
      config:
        - subnet: 10.0.0.0/24
```

This compose file can be used from within this code repository by executing;
```bash
$ docker compose up -d
```

Note: The example above binds freeradius with a mysql database.  The mysql docker image, associated schema, volumes and configs are not a part of the fflo/freeradius image that can be pulled from docker hub.  See .dockerignore file for the parts of this repository that are excluded from the image.

# Testing Authentication
The freeradius container can be tested against the mysql backend created in the above compose file using a separate container running the radtest client.

```bash
$ docker run -it --rm --network docker-freeradius_backend alpine:3.24 \
    sh -c 'apk add --no-cache -q freeradius-utils && radtest testing password freeradius 0 testing123'

Sent Access-Request Id 42 from 0.0.0.0:48898 to 10.0.0.3:1812 length 77
        User-Name = "testing"
        User-Password = "password"
        NAS-IP-Address = 10.0.0.4
        NAS-Port = 0
        Message-Authenticator = 0x00
        Cleartext-Password = "password"
Received Access-Accept Id 42 from 10.0.0.3:1812 to 0.0.0.0:0 length 20
```

Note: The username and password used in the radtest example above are pre-loaded in the mysql database by the radius.sql schema included in this repository.  The preconfigured mysql database is for validating freeradius functionality only and not intended for production use.

A default SQL schema for FreeRadius on MySQL can be found [here](https://github.com/FreeRADIUS/freeradius-server/blob/v3.0.x/raddb/mods-config/sql/main/mysql/schema.sql).

# Upgrading from 3.0.26.x

The configuration in `etc/raddb` now matches the FreeRADIUS 3.0.27 defaults (it was based on 3.0.17 before), with the same customizations as before: database and client settings from environment variables, logging to stdout, SQL enabled in the default virtual server and proxying disabled.  If you bind mount your own copies of files from `etc/raddb`, compare them with the new versions.

-   **BlastRADIUS (CVE-2024-3596):** the server now adds `Message-Authenticator` to its replies and uses `require_message_authenticator = auto` and `limit_proxy_state = auto`.  Once all of your NAS devices send `Message-Authenticator`, set `require_message_authenticator = yes` for them in `clients.conf`.  See the [FreeRADIUS security notice](https://www.freeradius.org/security/).
-   **EAP/TLS:** the defaults now only allow TLS 1.2 (`tls_min_version` / `tls_max_version` in `mods-available/eap`), and LEAP is no longer available.
-   **Accounting schema:** the accounting queries write the columns `framedipv6address`, `framedipv6prefix`, `framedinterfaceid` and `delegatedipv6prefix` of `radacct`.  Databases created from the `radius.sql` of this repository already have them.  If your `radacct` table does not, add them:
```sql
ALTER TABLE radacct
  ADD COLUMN framedipv6address varchar(45) NOT NULL default '' AFTER framedipaddress,
  ADD COLUMN framedipv6prefix varchar(45) NOT NULL default '' AFTER framedipv6address,
  ADD COLUMN framedinterfaceid varchar(44) NOT NULL default '' AFTER framedipv6prefix,
  ADD COLUMN delegatedipv6prefix varchar(45) NOT NULL default '' AFTER framedinterfaceid;
```
-   **MySQL:** the compose example uses MySQL 8.4.  The `--default-authentication-plugin` option no longer exists there; new accounts use `caching_sha2_password`.

# Build the container
If you would like to make modifications or customizations, clone this repository, make your changes and then run the following from the root of the repository.

```bash
$ docker build --pull -t <docker_hub_account>/freeradius .
```

Note: Some users have reported broken symlinks when building the container.  Check that you have the default servers enabled via symlinks in the repository's `./etc/raddb/sites-enabled` directory.  If there are no symlinks in this directory you can create them with;

```bash
cd docker-freeradius/etc/raddb/sites-enabled
ln -s ../sites-available/default default
ln -s ../sites-available/inner-tunnel inner-tunnel
``` 

See [this thread](https://github.com/fflo/docker-freeradius/issues/3) for additional information.

# Certificates
The container has a set of test certificates that are generated each time the container is built using the included Dockerfile.  These certificates are configured with the default settings from the Freeradius package and are set to expire after sixty days.
These certificates are not meant to be used in production and should be recreated/replaced as needed.  Follow the steps below to generate new certificates.  It is important that you read and understand the instructions in '/etc/raddb/certs/README'
  
#### Generate new certs
From your docker host machine

  - Clone the git repository
```bash
$ git clone https://github.com/fflo/docker-freeradius.git
```
  - Make changes to the .cnf files in /etc/raddb/certs as needed. (Optional)
  - Run the container
```bash
$ docker run -it --rm -v $PWD/etc/raddb:/etc/raddb fflo/freeradius:latest sh
```

From inside the container
```bash
/ # cd /etc/raddb/certs/
/ # rm -f *.pem *.der *.csr *.crt *.key *.p12 serial* index.txt*
/ # ./bootstrap
/ # chown -R root:radius /etc/raddb/certs
/ # chmod 640 /etc/raddb/certs/*.pem
/ # exit
```

You can bind mount these certificates back in to the container or rebuild the container as mentioned above.
You'll have to change the permissions to your local user before rebuilding the container.
```bash
$ sudo chown -R $USER:$USER etc/raddb/certs
```
