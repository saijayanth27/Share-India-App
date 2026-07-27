const admin = require('firebase-admin');

const serviceAccount = require('./share-india-d9717-firebase-adminsdk-fbsvc-ebe7273a5e.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function deleteCollection(collectionName) {
  console.log(`🗑️  Deleting all docs in '${collectionName}'...`);
  let deleted = 0;

  while (true) {
    const snapshot = await db.collection(collectionName).limit(500).get();
    if (snapshot.empty) break;

    const batch = db.batch();
    snapshot.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snapshot.docs.length;
    console.log(`   Deleted ${deleted} so far...`);
  }

  console.log(`✅ Done deleting '${collectionName}' — ${deleted} total deleted.\n`);
}

async function run() {
  const collections = [
    'Family Code Creation',
    'personal_details',
    'ante_natal_care',
    'ante_natal_checkup',
    'child_immunization',
  ];

  for (const col of collections) {
    await deleteCollection(col);
  }

  console.log('✅ All old data deleted. Now run: node import.js');
}

run().catch(console.error);
