const admin = require('firebase-admin');
const XLSX = require('xlsx');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('./share-india-d9717-firebase-adminsdk-fbsvc-ebe7273a5e.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'share-india-d9717.firebasestorage.app'
});

const bucket = admin.storage().bucket();

async function createAndUploadExport() {
  console.log('📂 Reading FAMILY_DETAILS.xlsx...');

  const workbook = XLSX.readFile('./FAMILY_DETAILS.xlsx');
  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];
  const rows = XLSX.utils.sheet_to_json(sheet);

  console.log(`✅ Found ${rows.length} records`);

  // Clean up rows — remove null/undefined values
  const cleanedRows = rows.map(row => {
    const clean = {};
    for (const [key, value] of Object.entries(row)) {
      if (value !== undefined && value !== null && value !== '') {
        clean[key] = value;
      }
    }
    // Ensure family_id field exists for SQLite
    if (!clean['family_id'] && clean['FAM_ID']) {
      clean['family_id'] = String(clean['FAM_ID']).trim();
    }
    return clean;
  });

  // Save as local JSON file first
  const localPath = path.join(__dirname, 'family_codes_export.json');
  fs.writeFileSync(localPath, JSON.stringify(cleanedRows));

  const fileSizeMB = (fs.statSync(localPath).size / (1024 * 1024)).toFixed(2);
  console.log(`📦 JSON file created: ${fileSizeMB} MB`);

  // Upload to Firebase Storage
  console.log('⬆️  Uploading to Firebase Storage...');

  await bucket.upload(localPath, {
    destination: 'exports/family_codes.json',
    metadata: {
      contentType: 'application/json',
    },
  });

  // Make the file publicly readable
  await bucket.file('exports/family_codes.json').makePublic();
  const publicUrl = `https://storage.googleapis.com/share-india-d9717.firebasestorage.app/exports/family_codes.json`;

  console.log(`✅ Upload successful!`);
  console.log(`🔗 Download URL: ${publicUrl}`);
  console.log(`\n👉 Now update the app with this URL and build.`);

  // Clean up local file
  fs.unlinkSync(localPath);
}

createAndUploadExport().catch(console.error);
