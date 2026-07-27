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

// --- Field value mappings ---
const GENDER_MAP = { 1: '(1) Male', 0: '(0) Female' };

const LIVE_STATUS_MAP = { 1: '(1) Alive', 0: '(0) Dead' };

const ACTIVE_STATUS_MAP = { 1: '(1) Active', 0: '(0) Vacant' };

const MARITAL_STATUS_MAP = {
  1: '(0) Unmarried',
  2: '(1) Married',
  3: '(2) Widowed',
  4: '(3) Divorced',
};

const EDUCATION_MAP = {
  0: '(0) ILLITIRATE',
  1: '(1) CAN READ ONLY',
  2: '(2) CAN READ AND WRITE',
  3: '(3) PRIMARY SCHOOL',
  4: '(4) MIDDLE SCHOOL',
  5: '(5) HIGH SCHOOL',
  6: '(6) GRADUATE',
  7: '(7) POST GRADUATE',
};

const OCCUPATION_MAP = {
  1: '(1) HOUSE WIFE',
  2: '(2) AGRICULTURE',
  3: '(3) UNEMPLOYED',
  4: '(4)LABOUR',
  5: '(5) SELF-EMPLOYED',
  6: '(6) PRIVATE EMPLOYEE',
  7: '(7) ANGANWADI TEACHER',
  8: '(8) C.H.V',
  9: '(9) PENSION',
  10: '(10) GOVT EMPLOYEE',
  99: '(99) DONT KNOW',
};

const RELATION_TYPE_MAP = {
  'HP': 'HEAD OF THE FAMILY',
  'H':  'HEAD OF THE FAMILY',
  'HU': 'HUSBAND',
  'W':  'WIFE',
  'S':  'SON',
  'D':  'DAUGHTER',
  'DH': 'SON-IN-LAW',
  'SW': 'DAUGHTER-IN-LAW',
  'SS': 'GRAND-SON(S)',
  'SD': 'GRAND-DAUGHTER(S)',
  'DS': 'GRAND-SON (D)',
  'DD': 'GRAND-DAUGHTER (D)',
  'B':  'BROTHER',
  'BS': 'BROTHER SON',
  'FI': 'FATHER-IN-LAW',
  'MI': 'MOTHERS-IN-LAW',
  'I':  'FATHER-IN-LAW',
  'IH': 'MOTHERS-IN-LAW',
  'GHP': 'GRAND PARENT',
  'WP': 'WIFE PARENT',
};

// Convert Excel serial date to ISO string (YYYY-MM-DD)
function excelSerialToISO(serial) {
  if (!serial || typeof serial !== 'number' || isNaN(serial)) return null;
  const msPerDay = 86400000;
  // Excel base: Dec 31, 1899. Serial 1 = Jan 1, 1900.
  const excelBase = Date.UTC(1899, 11, 31);
  // Excel leap year bug: treats 1900 as leap, so serials >= 60 are off by 1
  const corrected = serial >= 60 ? serial - 1 : serial;
  const date = new Date(excelBase + corrected * msPerDay);
  return date.toISOString().split('T')[0];
}

// Calculate age from ISO date string
function calcAge(isoDate) {
  if (!isoDate) return null;
  const today = new Date();
  const birth = new Date(isoDate);
  let age = today.getFullYear() - birth.getFullYear();
  const m = today.getMonth() - birth.getMonth();
  if (m < 0 || (m === 0 && today.getDate() < birth.getDate())) age--;
  return age >= 0 ? age : null;
}

async function createAndUploadMembersExport() {
  console.log('📂 Reading RELATIONS.xlsx...');

  const workbook = XLSX.readFile('./RELATIONS.xlsx');
  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];
  // defval: null ensures ALL columns appear even when a cell is empty
  const rows = XLSX.utils.sheet_to_json(sheet, { defval: null });

  console.log(`✅ Found ${rows.length} records`);

  // Build reg_no → name lookup so we can resolve Father_Name / Mother_Name
  const regNoToName = {};
  for (const row of rows) {
    if (row.REL_REG_NO !== null && row.REL_REG_NO !== undefined) {
      regNoToName[row.REL_REG_NO] = String(row.REL_NAME || '').trim();
    }
  }
  console.log(`   Name lookup: ${Object.keys(regNoToName).length} entries`);

  const cleanedRows = rows.map(row => {
    const dobISO = excelSerialToISO(row.REL_DOB);

    return {
      // Identity
      Family_Code:              row.REL_DUP_CODE ? String(row.REL_DUP_CODE).trim().toUpperCase() : null,
      uniq_Registration_Number: row.REL_REG_NO ?? null,
      Name:                     row.REL_NAME ? String(row.REL_NAME).trim() : null,
      Telugu_Name:              row.REL_TNAME ? String(row.REL_TNAME).trim() : null,
      Gender:                   GENDER_MAP[row.REL_SEX] ?? null,
      SI_No:                    row.REL_SNO ?? null,
      Map_No:                   row.MAPNO ?? null,
      Aadhar_No1:               row.AADHAR ? String(row.AADHAR).trim() : null,

      // Personal
      Date_of_Birth:            dobISO,
      Age:                      dobISO ? String(calcAge(dobISO)) : null,
      Marital_Status:           MARITAL_STATUS_MAP[row.REL_MSTATUS] ?? null,
      Education:                EDUCATION_MAP[row.REL_EDUC] ?? null,
      Live_Status:              LIVE_STATUS_MAP[row.REL_LIVE_ST] ?? null,
      A_v_Status:               ACTIVE_STATUS_MAP[row.REL_ACTIVE_STA] ?? null,
      Occupation:               OCCUPATION_MAP[row.REL_OCCU] ?? null,
      Income:                   row.REL_INCOME !== null ? String(row.REL_INCOME) : null,

      // Relations — resolve IDs to actual names
      Relation_with_Head:       RELATION_TYPE_MAP[String(row.REL_TYPE || '').trim()] ?? (row.REL_TYPE ? String(row.REL_TYPE).trim() : null),
      Father_Name:              (row.FATHER_ID && row.FATHER_ID !== 0) ? (regNoToName[row.FATHER_ID] || null) : null,
      Mother_Name:              (row.MOTHER_ID && row.MOTHER_ID !== 0) ? (regNoToName[row.MOTHER_ID] || null) : null,
      Father_Registration_Number: (row.FATHER_ID && row.FATHER_ID !== 0) ? row.FATHER_ID : null,
      Parents_ID:               (row.PARENTS_ID && row.PARENTS_ID !== 0) ? String(row.PARENTS_ID) : null,

      // Registration numbers
      Registration_Number1:     row.REL_SNO ?? null,
    };
  });

  const localPath = path.join(__dirname, 'personal_details_export.json');
  fs.writeFileSync(localPath, JSON.stringify(cleanedRows));

  const fileSizeMB = (fs.statSync(localPath).size / (1024 * 1024)).toFixed(2);
  console.log(`📦 JSON file created: ${fileSizeMB} MB`);

  console.log('⬆️  Uploading to Firebase Storage...');

  await bucket.upload(localPath, {
    destination: 'exports/personal_details.json',
    metadata: { contentType: 'application/json' },
  });

  await bucket.file('exports/personal_details.json').makePublic();

  console.log(`✅ Upload successful!`);
  console.log(`🔗 File: exports/personal_details.json`);

  fs.unlinkSync(localPath);
}

createAndUploadMembersExport().catch(console.error);
