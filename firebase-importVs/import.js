const admin = require('firebase-admin');
const XLSX = require('xlsx');
const path = require('path');

const serviceAccount = require('./share-india-d9717-firebase-adminsdk-fbsvc-ebe7273a5e.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Excel file → Firestore collection mapping
const IMPORT_CONFIG = [
  {
    file: 'FAMILY_DETAILS.xlsx',
    collection: 'Family Code Creation',
    docIdField: 'FAM_ID',      // This Excel column becomes the Firestore document ID
  },
  {
    file: 'RELATIONS.xlsx',
    collection: 'personal_details',
    docIdField: null,          // Auto-generated document ID (multiple members per family)
  },
  {
    file: 'ANCS_LIST.xlsx',
    collection: 'ante_natal_care',
    docIdField: null,
  },
  {
    file: 'ANCS_CHKUP.xlsx',
    collection: 'ante_natal_checkup',
    docIdField: null,
  },
  {
    file: 'CHILD_HEALTH.xlsx',
    collection: 'child_immunization',
    docIdField: null,
  },
];

function findFamilyIdColumn(row) {
  const candidates = ['family_id', 'Family_id', 'Family_ID', 'Family Code', 'family_code', 'Family_Code', 'FAMILY_ID', 'FAMILY_CODE'];
  for (const key of candidates) {
    if (row[key] !== undefined && row[key] !== null && row[key] !== '') {
      return key;
    }
  }
  return null;
}

async function importFile(config) {
  const filePath = path.join(__dirname, config.file);
  console.log(`\n📂 Reading ${config.file}...`);

  let workbook;
  try {
    workbook = XLSX.readFile(filePath);
  } catch (e) {
    console.log(`⚠️  File not found: ${config.file} — skipping.`);
    return;
  }

  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];
  const rows = XLSX.utils.sheet_to_json(sheet);

  if (rows.length === 0) {
    console.log(`⚠️  No rows found in ${config.file} — skipping.`);
    return;
  }

  console.log(`✅ Found ${rows.length} rows`);

  // Detect family_id column from first row
  let resolvedDocIdField = config.docIdField;
  if (resolvedDocIdField && !rows[0][resolvedDocIdField]) {
    const detected = findFamilyIdColumn(rows[0]);
    if (detected) {
      console.log(`ℹ️  Column '${config.docIdField}' not found, using '${detected}' as document ID`);
      resolvedDocIdField = detected;
    } else {
      console.log(`⚠️  Could not find family_id column. Will use auto-generated document IDs.`);
      resolvedDocIdField = null;
    }
  }

  // Print detected columns
  console.log(`📋 Columns: ${Object.keys(rows[0]).join(', ')}`);

  const serverTimestamp = admin.firestore.Timestamp.now();
  let batch = db.batch();
  let count = 0;
  let totalUploaded = 0;
  let skipped = 0;

  for (const row of rows) {
    // Clean up undefined/null values
    const cleanRow = {};
    for (const [key, value] of Object.entries(row)) {
      if (value !== undefined && value !== null && value !== '') {
        cleanRow[key] = value;
      }
    }

    // Add serverUpdatedAt so delta sync can pull this record
    cleanRow['serverUpdatedAt'] = serverTimestamp;
    cleanRow['needs_zoho_sync'] = false;

    let docRef;
    if (resolvedDocIdField && cleanRow[resolvedDocIdField]) {
      const docId = String(cleanRow[resolvedDocIdField]).trim();
      if (!docId) {
        skipped++;
        continue;
      }
      docRef = db.collection(config.collection).doc(docId);
      cleanRow['firestoreDocId'] = docId;
    } else {
      docRef = db.collection(config.collection).doc();
      cleanRow['firestoreDocId'] = docRef.id;
    }

    batch.set(docRef, cleanRow, { merge: true });
    count++;

    if (count === 500) {
      await batch.commit();
      totalUploaded += count;
      console.log(`⬆️  Uploaded ${totalUploaded} rows...`);
      batch = db.batch();
      count = 0;
    }
  }

  if (count > 0) {
    await batch.commit();
    totalUploaded += count;
  }

  console.log(`🎉 ${config.file} done! ${totalUploaded} uploaded${skipped > 0 ? `, ${skipped} skipped (no ID)` : ''}`);
}

async function importAll() {
  console.log('🚀 Starting import to Firebase...\n');

  for (const config of IMPORT_CONFIG) {
    await importFile(config);
  }

  console.log('\n✅ All imports complete!');
  console.log('👉 Open the app with internet — data will sync to local SQLite automatically.');
}

importAll().catch(console.error);
