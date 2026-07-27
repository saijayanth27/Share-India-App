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

const PLACE_MAP = { 0: '(0) RHC', 1: '(1) PVT', 2: '(2) GOVT' };
const PERM_USED_MAP = { 0: '(0) Tubectomy', 1: '(1) Vasectomy', 2: '(2) Hysectomy' };

function yn(val) { return val === 1 ? '(1) Yes' : '(0) No'; }

function excelSerialToISO(serial) {
  if (!serial || typeof serial !== 'number' || isNaN(serial)) return null;
  const excelBase = Date.UTC(1899, 11, 31);
  const corrected = serial >= 60 ? serial - 1 : serial;
  return new Date(excelBase + corrected * 86400000).toISOString().split('T')[0];
}

async function createAndUploadParentsExport() {
  console.log('📂 Reading RELATIONS.xlsx to build member index...');
  const relWb = XLSX.readFile('./RELATIONS.xlsx');
  const relRows = XLSX.utils.sheet_to_json(relWb.Sheets[relWb.SheetNames[0]]);
  const regMap = {};
  for (const r of relRows) {
    if (r.REL_REG_NO !== undefined) {
      regMap[r.REL_REG_NO] = {
        Name: String(r.REL_NAME || '').trim(),
        Family_Code: String(r.REL_DUP_CODE || '').trim().toUpperCase(),
      };
    }
  }
  console.log(`✅ Member index: ${Object.keys(regMap).length} entries`);

  console.log('📂 Reading PARENTS.xlsx...');
  const wb = XLSX.readFile('./PARENTS.xlsx');
  const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`✅ Found ${rows.length} parent records`);

  let matched = 0;
  const cleanedRows = rows.map(row => {
    const mother = regMap[row.MOTHER] || {};
    const father = regMap[row.FATHER] || {};
    if (mother.Name) matched++;

    const isPermanent = row.METHOD_TYPE === 1;
    const isTemporary = row.METHOD_TYPE === 0;

    const r = {
      Family_Code:           String(row.FAMILY_CODE || '').trim().toUpperCase(),
      Registration_Number:   row.MOTHER !== undefined ? String(row.MOTHER) : null,
      Name:                  mother.Name || null,
      Husband_Name:          father.Name || null,
      Select_Entry_Screen:   isPermanent ? '(1) Permanent' : (isTemporary ? '(0) Temporary' : null),

      // Permanent fields
      Used:                  isPermanent ? (PERM_USED_MAP[row.METHOD_USED] ?? null) : null,
      Date_field1:           isPermanent ? excelSerialToISO(row.FP_DATE) : null,
      Place:                 (isPermanent || isTemporary) ? (PLACE_MAP[row.FP_PLACE] ?? null) : null,
      Remarks:               row.REMARKS ? String(row.REMARKS).trim() : null,

      // Temporary fields
      Used_oral_contraceptives: isTemporary ? yn(row.CC_USE_ORAL_CON) : null,
      How_long_use_oral1:       isTemporary && row.CC_LONG_USE_ORAL_CON !== undefined ? String(row.CC_LONG_USE_ORAL_CON) : null,
      Date_field2:              isTemporary ? excelSerialToISO(row.FP_DATE) : null,
    };

    return r;
  });

  console.log(`✅ Matched ${matched} of ${rows.length} records to members`);

  const localPath = path.join(__dirname, 'family_planning_export.json');
  fs.writeFileSync(localPath, JSON.stringify(cleanedRows));
  const fileSizeMB = (fs.statSync(localPath).size / (1024 * 1024)).toFixed(2);
  console.log(`📦 JSON file created: ${fileSizeMB} MB`);

  console.log('⬆️  Uploading to Firebase Storage...');
  await bucket.upload(localPath, {
    destination: 'exports/family_planning.json',
    metadata: { contentType: 'application/json' },
  });
  await bucket.file('exports/family_planning.json').makePublic();
  console.log('✅ Upload successful! → exports/family_planning.json');

  fs.unlinkSync(localPath);
}

createAndUploadParentsExport().catch(console.error);
