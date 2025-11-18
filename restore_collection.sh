#!/bin/bash

set -euo pipefail

usage() {
  echo "Uso: $0 <ruta_carpeta_o_fichero> [nuevo_nombre_coleccion]" >&2
  echo " - Soporta carpetas o archivos .tar.gz, .tgz, .tar, .gz o .zip." >&2
  echo " - Si no se indica un nombre, se usará el del directorio/archivo de entrada." >&2
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

INPUT_PATH="$1"
COLLECTION_OVERRIDE="${2:-}"

source .env

cleanup_dir=""
working_dir=""
base_name=$(basename "$INPUT_PATH")
CONTAINER_BACKUP_ROOT="./backups"

case "$base_name" in
  *.tar.gz|*.tgz)
    DATASET_NAME="${base_name%.*}"
    DATASET_NAME="${DATASET_NAME%.*}"
    ;;
  *.json.gz)
    DATASET_NAME="${base_name%.json.gz}"
    ;;
  *.tar|*.gz|*.zip)
    DATASET_NAME="${base_name%.*}"
    ;;
  *)
    DATASET_NAME="$base_name"
    ;;
esac

if [[ -d "$INPUT_PATH" ]]; then
  working_dir="$INPUT_PATH"
elif [[ -f "$INPUT_PATH" ]]; then
  cleanup_dir=$(mktemp -d)
  case "$base_name" in
    *.tar.gz|*.tgz)
      tar -xzf "$INPUT_PATH" -C "$cleanup_dir"
      ;;
    *.json.gz|*.gz)
      cp "$INPUT_PATH" "${cleanup_dir}/${base_name}"
      ;;
    *.tar)
      tar -xf "$INPUT_PATH" -C "$cleanup_dir"
      ;;
    *.zip)
      unzip -q "$INPUT_PATH" -d "$cleanup_dir"
      ;;
    *)
      echo "Formato de archivo no soportado. Usa carpeta, .tar.gz, .tgz, .tar, .gz o .zip" >&2
      exit 1
      ;;
  esac
  working_dir="$cleanup_dir"
else
  echo "Ruta no encontrada: ${INPUT_PATH}" >&2
  exit 1
fi

mapfile -t DATA_FILES < <(find "$working_dir" -type f \( -name '*.json' -o -name '*.json.gz' -o -name '*.gz' \) -print | sort)

if [[ ${#DATA_FILES[@]} -eq 0 ]]; then
  echo "No se encontraron archivos .json o .json.gz en ${INPUT_PATH}" >&2
  [[ -n "$cleanup_dir" ]] && rm -rf "$cleanup_dir"
  exit 1
fi

if [[ -n "$COLLECTION_OVERRIDE" ]]; then
  TARGET_COLLECTION="$COLLECTION_OVERRIDE"
  DROP_ONCE=true
elif [[ ${#DATA_FILES[@]} -eq 1 ]]; then
  TARGET_COLLECTION="$DATASET_NAME"
  DROP_ONCE=true
else
  TARGET_COLLECTION=""
  DROP_ONCE=false
fi

docker exec mongo8 sh -c "mkdir -p \"${CONTAINER_BACKUP_ROOT}/restore\""

FIRST_IMPORT=true
for DATA_FILE in "${DATA_FILES[@]}"; do
  DEST_FILE="${CONTAINER_BACKUP_ROOT}/restore/$(basename "$DATA_FILE")"
  docker cp "$DATA_FILE" "mongo8:${DEST_FILE}" >/dev/null

  if [[ -n "$TARGET_COLLECTION" ]]; then
    COLLECTION_NAME="$TARGET_COLLECTION"
    DROP_FLAG=""
    if $DROP_ONCE && $FIRST_IMPORT; then
      DROP_FLAG="--drop"
    fi
  else
    case "$DATA_FILE" in
      *.json.gz)
        COLLECTION_NAME=$(basename "$DATA_FILE" .json.gz)
        ;;
      *.gz)
        COLLECTION_NAME=$(basename "$DATA_FILE" .gz)
        ;;
      *)
        COLLECTION_NAME=$(basename "$DATA_FILE" .json)
        ;;
    esac
    DROP_FLAG="--drop"
  fi

  IMPORT_GZIP_FLAG=""
  case "$DATA_FILE" in
    *.gz)
      IMPORT_GZIP_FLAG="--gzip"
      ;;
  esac

  echo "Restaurando colección '${COLLECTION_NAME}' desde '$(basename "$DATA_FILE")'..."
  docker exec mongo8 sh -c "mongoimport \
    --username \"$MONGO_INITDB_ROOT_USERNAME\" \
    --password \"$MONGO_INITDB_ROOT_PASSWORD\" \
    --authenticationDatabase admin \
    --db \"$MONGO_DB_NAME\" \
    --collection \"${COLLECTION_NAME}\" \
    ${DROP_FLAG} \
    ${IMPORT_GZIP_FLAG} \
    --file \"${DEST_FILE}\""

  FIRST_IMPORT=false
done

docker exec mongo8 sh -c "rm -rf \"${CONTAINER_BACKUP_ROOT}/restore\""
[[ -n "$cleanup_dir" ]] && rm -rf "$cleanup_dir"

echo "Restauración finalizada."
