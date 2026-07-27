const admin = require('firebase-admin');

const serviceAccount = require('./share-india-ee943-firebase-adminsdk-fbsvc-05d46fe3ee.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function getCollectionSizes() {
    console.log('🔍 Fetching collection list...');

    try {
        const collections = await db.listCollections();

        if (collections.length === 0) {
            console.log('❌ No collections found in this database.');
            return;
        }

        console.log(`📊 Found ${collections.length} root collections:\n`);

        for (const collection of collections) {
            const id = collection.id;
            // Using count() is the most cost-effective way to get document counts
            const snapshot = await db.collection(id).count().get();
            const count = snapshot.data().count;

            console.log(`📂 Collection: ${id.padEnd(25)} | 📄 Documents: ${count.toLocaleString()}`);
        }

        console.log('\n✅ Completed.');
    } catch (error) {
        console.error('❌ Error fetching collection sizes:', error.message);
    }
}

getCollectionSizes().catch(console.error);
