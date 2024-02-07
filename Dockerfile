FROM alpine:3.18

MAINTAINER fflo

# Use docker build --pull -t fflo/freeradius .

# Image details
LABEL net.fflo.name="docker-freeradius" \
      net.fflo.license="MIT" \
      net.fflo.description="Dockerfile for autobuilds" \
      net.fflo.url="https://github.com/fflo/docker-freeradius" \
      net.fflo.vcs-type="Git" \
      net.fflo.version="3.0.26.2" \
      net.fflo.radius.version="3.0.26-r2"

RUN apk --update add freeradius freeradius-mysql freeradius-eap openssl

EXPOSE 1812/udp 1813/udp

ENV DB_HOST=localhost
ENV DB_PORT=3306
ENV DB_USER=radius
ENV DB_PASS=radpass
ENV DB_NAME=radius
ENV RADIUS_KEY=testing123
ENV RAD_CLIENTS=10.0.0.0/24
ENV RAD_DEBUG=no

ADD --chown=root:radius ./etc/raddb/ /etc/raddb
RUN /etc/raddb/certs/bootstrap && \
    chown -R root:radius /etc/raddb/certs && \
    chmod 640 /etc/raddb/certs/*.pem


ADD ./scripts/start.sh /start.sh
ADD ./scripts/wait-for.sh /wait-for.sh

RUN chmod +x /start.sh wait-for.sh

CMD ["/start.sh"]
