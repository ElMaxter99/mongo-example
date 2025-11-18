#!/bin/bash

set -euo pipefail

usage() {
  echo "Uso: ./restore_collection.sh <archivo1.json> [archivo2.json ...]" >&2
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

source .env

for FILE in "$@"; do
  if [ ! -f "$FILE" ]; then
    echo "Archivo no encontrado: $FILE" >&2
    exit 1
  fi

  COLLECTION_NAME=$(basename "$FILE" .json)
  echo "Restaurando colección '$COLLECTION_NAME' desde '$FILE'..."

  docker exec -i mongo8 sh -c "mongoimport \
    --username $MONGO_INITDB_ROOT_USERNAME \
    --password $MONGO_INITDB_ROOT_PASSWORD \
    --authenticationDatabase admin \
    --db $MONGO_DB_NAME \
    --collection $COLLECTION_NAME \
    --drop \
    --file /backups/$(basename "$FILE")"
done
