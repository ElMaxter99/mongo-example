#!/bin/bash

set -euo pipefail

usage() {
  echo "Uso: ./backup_collection.sh <collection1> [collection2 ...]" >&2
  echo "       ./backup_collection.sh --all" >&2
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

source .env

mkdir -p ./mongo_backups

if [ "$1" = "--all" ]; then
  echo "Recuperando listado de colecciones en '$MONGO_DB_NAME'..."
  COLLECTIONS=$(docker exec mongo8 sh -c "mongosh --quiet --username $MONGO_INITDB_ROOT_USERNAME --password $MONGO_INITDB_ROOT_PASSWORD --authenticationDatabase admin --eval 'db.getSiblingDB(\"$MONGO_DB_NAME\").getCollectionNames().join(\" \")'")
  if [ -z "$COLLECTIONS" ]; then
    echo "No se encontraron colecciones para respaldar" >&2
    exit 1
  fi
else
  COLLECTIONS="$@"
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

for COLLECTION in $COLLECTIONS; do
  echo "Realizando backup de la colección '$COLLECTION'..."
  docker exec mongo8 sh -c "mongoexport \
    --username $MONGO_INITDB_ROOT_USERNAME \
    --password $MONGO_INITDB_ROOT_PASSWORD \
    --authenticationDatabase admin \
    --db $MONGO_DB_NAME \
    --collection $COLLECTION \
    --out /backups/${COLLECTION}_${TIMESTAMP}.json"
  echo "Backup creado en: mongo_backups/${COLLECTION}_${TIMESTAMP}.json"
done
