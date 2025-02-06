#!/bin/bash
# Simple postgres cloning script

if [[ $# -ne 3 ]]; then
	echo "Error: Script requires exactly 3 parameters:"
	echo "\$1: new docker container name"
	echo "\$2: local port to access new db" echo "\$3: OLD url to clone locally"
	exit 1
fi

if [[ $(docker ps -a | grep -c "$1") -ne 0 ]]; then
	read -p "Found an existing docker container with the same name, overwrite it? (y/n)" -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		docker stop "$1"
		docker rm "$1"
	else
		echo "Canceling request"
		exit 1
	fi
fi

if [[ $(lsof -ti :"$2" | wc -l) -ne 0 ]]; then
	lsof -i :"$2"
	echo "Port $2 is busy, please try a different one"
	exit 1
fi

if pg_isready -d "$3"; then
	echo "Cloning DB"
else
	echo "Bad url, cannot connect to DB"
	exit 1
fi

POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 14)
POSTGRES_USER="oedev"

docker run -d --name "$1" \
-p "$2":5432 \
-e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
-e POSTGRES_USER="$POSTGRES_USER" \
postgres:15.9 && \
sleep 3 && \
docker run --rm --network host postgres:15.9 pg_dump --no-owner --no-acl "$3" | \
docker exec -i "$1" psql -U "$POSTGRES_USER"
echo "Your new postgres url is:"
echo "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:$2/postgres"
