#!/bin/bash

FILE=$1

if [ -z "$FILE" ]; then
    echo "Uso: ./restore_collection.sh <archivo.json>"
    exit 1
fi

source .env

docker exec -i mongo8 sh -c "mongoimport \
  --username $MONGO_INITDB_ROOT_USERNAME \
  --password $MONGO_INITDB_ROOT_PASSWORD \
  --authenticationDatabase admin \
  --db $MONGO_DB_NAME \
  --collection $(basename $FILE .json) \
  --drop \
--file /backups/$(basename $FILE)"
