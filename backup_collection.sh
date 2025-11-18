#!/bin/bash

set -euo pipefail

DEFAULT_OUTPUT_DIR="./backup-host"
CONTAINER_BACKUP_ROOT="/backups"

usage() {
  echo "Uso: $0 <base_de_datos> [--output <ruta>] [coleccion1 coleccion2 ... | --all]" >&2
  echo " - <base_de_datos>: nombre de la base a respaldar." >&2
  echo " - --output/-o: ruta en el host donde dejar el backup (por defecto ${DEFAULT_OUTPUT_DIR})." >&2
  echo " - colecciones: listado de colecciones a exportar." >&2
  echo " - --all: fuerza a respaldar todas las colecciones (excepto las internas de MongoDB)." >&2
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

DB_NAME="$1"
shift
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
BACKUP_ALL=false
declare -a COLLECTIONS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output|-o)
      if [[ $# -lt 2 ]]; then
        echo "Falta la ruta para --output" >&2
        exit 1
      fi
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --all)
      BACKUP_ALL=true
      shift
      ;;
    *)
      COLLECTIONS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#COLLECTIONS[@]} -eq 0 ]]; then
  BACKUP_ALL=true
fi

source .env

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DATASET_NAME="${DB_NAME}_${TIMESTAMP}"
CONTAINER_OUTPUT_DIR="${CONTAINER_BACKUP_ROOT}/${DATASET_NAME}"
HOST_OUTPUT_DIR="${OUTPUT_DIR}/${DATASET_NAME}"

mkdir -p "$OUTPUT_DIR"
docker exec mongo8 sh -c "mkdir -p \"${CONTAINER_OUTPUT_DIR}\""

if $BACKUP_ALL; then
  echo "Recuperando listado de colecciones en '${DB_NAME}'..."
  COLLECTIONS_RAW=$(docker exec mongo8 sh -c "mongosh --quiet --username \"$MONGO_INITDB_ROOT_USERNAME\" --password \"$MONGO_INITDB_ROOT_PASSWORD\" --authenticationDatabase admin --eval 'db.getSiblingDB(\"${DB_NAME}\").getCollectionNames().filter(c => ![\"admin\",\"config\",\"local\"].includes(c) && !c.startsWith(\"system.\")).join(\" \")'")
  if [[ -z "$COLLECTIONS_RAW" ]]; then
    echo "No se encontraron colecciones para respaldar" >&2
    exit 1
  fi
  read -r -a COLLECTIONS <<<"$COLLECTIONS_RAW"
fi

echo "Respaldando en '${HOST_OUTPUT_DIR}'..."
for COLLECTION in "${COLLECTIONS[@]}"; do
  echo "  - Exportando colección '${COLLECTION}'"
  docker exec mongo8 sh -c "mongoexport \
    --username \"$MONGO_INITDB_ROOT_USERNAME\" \
    --password \"$MONGO_INITDB_ROOT_PASSWORD\" \
    --authenticationDatabase admin \
    --db \"${DB_NAME}\" \
    --collection \"${COLLECTION}\" \
    --out \"${CONTAINER_OUTPUT_DIR}/${COLLECTION}.json\""
done

docker cp "mongo8:${CONTAINER_OUTPUT_DIR}" "${HOST_OUTPUT_DIR}" >/dev/null

docker exec mongo8 sh -c "rm -rf \"${CONTAINER_OUTPUT_DIR}\""

echo "Backup creado en: ${HOST_OUTPUT_DIR}"
