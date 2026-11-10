#!/bin/sh
if [ "${RAD_DEBUG}" = "yes" ]
  then
    exec /wait-for.sh "${DB_HOST}:${DB_PORT}" -t 15 -- /usr/sbin/radiusd -X -f -d /etc/raddb
  else
    exec /wait-for.sh "${DB_HOST}:${DB_PORT}" -t 15 -- /usr/sbin/radiusd -f -d /etc/raddb
fi
