#!/bin/bash
set -e

docker compose up -d

# radtest client, built from the same Alpine release as the server image
docker build -q -t radtest - <<'DOCKERFILE'
FROM alpine:3.24
RUN apk add --no-cache freeradius-utils
DOCKERFILE

network=$(docker inspect -f '{{range $name, $_ := .NetworkSettings.Networks}}{{$name}}{{end}}' \
  "$(docker compose ps -q freeradius)")

# MySQL needs a while to bootstrap on first start. FreeRADIUS restarts
# until the database is reachable, so retry for up to two minutes.
for attempt in $(seq 1 12); do
  if output=$(docker run --rm --network "$network" radtest \
       radtest testing password freeradius 2 testing123 2>&1) &&
     echo "$output" | grep -q 'Received Access-Accept'; then
    echo "$output"
    exit 0
  fi
  echo "Attempt $attempt: no Access-Accept yet, retrying in 10s"
  sleep 10
done

echo "$output"
docker compose ps
docker compose logs --tail=100
exit 1
