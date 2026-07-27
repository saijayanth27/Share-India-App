/**
 * Exports all 'Family Code Creation' documents from Firestore
 * and uploads to Firebase Storage as exports/family_codes.json
 *
 * The app's download button (main.dart:1597) will pick this file up.
 *
 * Run: node create-family-codes-export.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('./share-india-d9717-firebase-adminsdk-fbsvc-ebe7273a5e.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'share-india-d9717.firebasestorage.app',
});

const db = admin.firestore();
const bucket = admin.storage().bucket();
const COLLECTION = 'Family Code Creation';
const STORAGE_PATH = 'exports/family_codes.json';
const LOCAL_PATH = path.join(__dirname, 'family_codes_export.json');

async function exportFromFirestore() {
  console.log(`📂 Reading all documents from '${COLLECTION}'...`);

  const records = [];
  let lastDoc = null;
  const PAGE_SIZE = 1000;

  while (true) {
    let query = db.collection(COLLECTION).orderBy('family_id').limit(PAGE_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      const data = doc.data();
      // Convert any Firestore Timestamps to ISO strings
      const cleaned = {};
      for (const [k, v] of Object.entries(data)) {
        if (v && typeof v === 'object' && v.toDate) {
          cleaned[k] = v.toDate().toISOString();
        } else {
          cleaned[k] = v;
        }
      }
      records.push(cleaned);
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    console.log(`   Fetched ${records.length} records so far...`);

    if (snap.docs.length < PAGE_SIZE) break;
  }

  console.log(`✅ Total records fetched: ${records.length}`);
  return records;
}

async function run() {
  console.log('====================================================');
  console.log(' Family Codes — Export Firestore → Firebase Storage');
  console.log('====================================================\n');

  const records = await exportFromFirestore();

  // Save locally
  fs.writeFileSync(LOCAL_PATH, JSON.stringify(records));
  const sizeMB = (fs.statSync(LOCAL_PATH).size / (1024 * 1024)).toFixed(2);
  console.log(`\n📦 JSON file size: ${sizeMB} MB`);

  // Upload to Firebase Storage
  console.log(`⬆️  Uploading to Storage: ${STORAGE_PATH} ...`);
  await bucket.upload(LOCAL_PATH, {
    destination: STORAGE_PATH,
    metadata: { contentType: 'application/json' },
  });

  // Make publicly accessible
  await bucket.file(STORAGE_PATH).makePublic();
  console.log(`✅ Upload complete!`);
  console.log(`\n👉 Now tap the Download button in the app — it will pull all ${records.length} records into SQLite.\n`);

  // Clean up local file
  fs.unlinkSync(LOCAL_PATH);
}

run().catch(err => {
  console.error('❌ Fatal error:', err);
  process.exit(1);
});
