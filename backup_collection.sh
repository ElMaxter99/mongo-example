#!/bin/bash

# Nombre de la colección a respaldar (primer argumento)
COLLECTION=$1

if [ -z "$COLLECTION" ]; then
    echo "Uso: ./backup_collection.sh <collection>"
    exit 1
fi

# Carga variables .env
source .env

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_PATH="./mongo_backups/${COLLECTION}_${TIMESTAMP}.json"

echo "Realizando backup de la colección '$COLLECTION'..."

docker exec mongo8 sh -c "mongoexport \
  --username $MONGO_INITDB_ROOT_USERNAME \
  --password $MONGO_INITDB_ROOT_PASSWORD \
  --authenticationDatabase admin \
  --db $MONGO_DB_NAME \
  --collection $COLLECTION \
--out /backups/${COLLECTION}_${TIMESTAMP}.json"

echo "Backup creado en: mongo_backups/${COLLECTION}_${TIMESTAMP}.json"
