FROM alpine:3.24

# Use docker build --pull -t fflo/freeradius .

# Image details
LABEL maintainer="fflo" \
      net.fflo.name="docker-freeradius" \
      net.fflo.license="MIT" \
      net.fflo.description="Dockerfile for autobuilds" \
      net.fflo.url="https://github.com/fflo/docker-freeradius" \
      net.fflo.vcs-type="Git" \
      net.fflo.version="3.0.27.3" \
      net.fflo.radius.version="3.0.27-r3"

RUN apk add --no-cache freeradius freeradius-mysql freeradius-eap openssl

EXPOSE 1812/udp 1813/udp

ENV DB_HOST=localhost
ENV DB_PORT=3306
ENV DB_USER=radius
ENV DB_PASS=radpass
ENV DB_NAME=radius
ENV RADIUS_KEY=testing123
ENV RAD_CLIENTS=10.0.0.0/24
ENV RAD_DEBUG=no

# The MariaDB client library in this Alpine release verifies the TLS
# certificate of the database server by default, which fails with the
# self-signed certificate of a stock MySQL server.  Keep the previous
# default (no verification).  To verify the server, configure the
# "tls" section in etc/raddb/mods-available/sql instead.
ENV MARIADB_TLS_DISABLE_PEER_VERIFICATION=1

COPY --chown=root:radius ./etc/raddb/ /etc/raddb
RUN /etc/raddb/certs/bootstrap && \
    chown -R root:radius /etc/raddb/certs && \
    chmod 640 /etc/raddb/certs/*.pem

COPY ./scripts/start.sh /start.sh
COPY ./scripts/wait-for.sh /wait-for.sh

RUN chmod +x /start.sh /wait-for.sh

CMD ["/start.sh"]
