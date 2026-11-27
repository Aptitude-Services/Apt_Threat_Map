#!/bin/sh
# Mise a jour du mur apres une modification : recupere le code, reconstruit le paquet
# dans Docker et recree le conteneur Splunk pour reinstaller l'appli.
set -e
cd "$(dirname "$0")"
git pull
docker compose run --rm builder
docker compose up -d --force-recreate splunk
