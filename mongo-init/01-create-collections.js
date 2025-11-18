const dbName = process.env.MONGO_DB_NAME || 'miapp';
const collectionsEnv = process.env.MONGO_INIT_COLLECTIONS || '';
const collectionList = collectionsEnv
  .split(',')
  .map((name) => name.trim())
  .filter(Boolean);

if (collectionList.length === 0) {
  print(`No se definieron colecciones en MONGO_INIT_COLLECTIONS; nada que crear.`);
  quit();
}

const dbTarget = db.getSiblingDB(dbName);

collectionList.forEach((collectionName) => {
  const exists = dbTarget.getCollectionNames().includes(collectionName);
  if (!exists) {
    dbTarget.createCollection(collectionName);
    print(`Colección creada: ${collectionName}`);
  } else {
    print(`Colección ya existía: ${collectionName}`);
  }
});
