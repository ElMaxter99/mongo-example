# Mongo Example: Backups y Restauración de Colecciones

Pequeño entorno de Docker Compose con MongoDB 8 y dos scripts Bash para exportar e importar colecciones individuales como archivos JSON. Útil para respaldos rápidos durante el desarrollo o migraciones puntuales.

## Requisitos
- Docker y Docker Compose instalados.
- Permisos para ejecutar `docker exec` sobre el contenedor de Mongo.
- Bash (los scripts son ejecutables en macOS y Linux).

## Configuración
1. Clona el repositorio y entra en la carpeta `mongo-example`.
2. Crea un archivo `.env` en la raíz con las variables necesarias (ejemplo incluido en el repo):

   ```env
   MONGO_PORT=27017
   MONGO_INITDB_ROOT_USERNAME=admin
   MONGO_INITDB_ROOT_PASSWORD=superpassword
   MONGO_DB_NAME=miapp
   ```

3. Levanta el contenedor de MongoDB:

   ```bash
   docker compose up -d
   ```

   - Los datos persistentes se almacenan en `./mongo_data`.
   - Los respaldos JSON quedan en `./mongo_backups` dentro del host (mapeado al contenedor).

## ¿Cómo conectarte a tu base `MONGO_DB_NAME`?
Con las variables del `.env` anterior, tu cadena de conexión para acceder a la base `miapp` (o el nombre que definas en `MONGO_DB_NAME`) sería:

```bash
mongodb://admin:superpassword@localhost:27017/miapp?authSource=admin
```

- Sustituye `localhost` por la IP/host donde se esté ejecutando el contenedor si accedes desde otra máquina.
- `authSource=admin` indica que las credenciales se validan contra la base de administración creada con `MONGO_INITDB_ROOT_USERNAME` y `MONGO_INITDB_ROOT_PASSWORD`.
- La base de datos `miapp` se crea automáticamente cuando insertas datos desde tu aplicación o al restaurar una colección con los scripts siguientes.

## Uso de los scripts
Los scripts asumen que el contenedor se llama `mongo8` (coincide con `docker-compose.yml`). Ejecuta todos los comandos desde la raíz del proyecto.

### Respaldar una o varias colecciones
Exporta una o varias colecciones a archivos JSON con marca de tiempo. También puedes respaldar todas las colecciones detectadas.

```bash
./backup_collection.sh <collection1> [collection2 ...]
# o bien
./backup_collection.sh --all
```

- Cada archivo se crea en `./mongo_backups/<collection>_YYYYMMDD_HHMMSS.json`.
- Utiliza `mongoexport` con autenticación contra la base definida en `MONGO_DB_NAME`.

### Restaurar una colección
Importa uno o varios archivos JSON previamente generados. Cada colección se **sobrescribe** (`--drop`).

```bash
./restore_collection.sh ./mongo_backups/<archivo1.json> [./mongo_backups/<archivo2.json> ...]
```

- El nombre de la colección se toma del nombre del archivo sin la extensión `.json`.
- Usa `mongoimport` autenticando con las credenciales de `.env`.

## Consejos y comprobaciones rápidas
- Verifica que el contenedor esté corriendo con `docker ps | grep mongo8`.
- Lista los archivos disponibles en `./mongo_backups` antes de restaurar.
- Ajusta `MONGO_PORT` en `.env` si el puerto 27017 está ocupado en tu máquina.

## Limpieza
Para detener y eliminar el contenedor (manteniendo los respaldos y datos locales):

```bash
docker compose down
```

Si quieres eliminar también los datos persistentes y respaldos, borra las carpetas `mongo_data` y `mongo_backups` manualmente.
