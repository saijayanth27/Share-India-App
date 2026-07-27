const admin = require('firebase-admin');
const XLSX = require('xlsx');

const serviceAccount = require('./share-india-d9717-firebase-adminsdk-fbsvc-ebe7273a5e.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const GENDER_MAP   = { 0: '(0) Female', 1: '(1) Male' };
const EDUC_MAP     = { 0: '(0) ILLITIRATE', 1: '(1) CAN READ ONLY', 2: '(2) CAN READ AND WRITE', 3: '(3) PRIMARY SCHOOL', 4: '(4) MIDDLE SCHOOL', 5: '(5) HIGH SCHOOL', 6: '(6) GRADUATE', 7: '(7) POST GRADUATE' };
const OCCU_MAP     = { 1: '(1) HOUSE WIFE', 2: '(2) AGRICULTURE', 3: '(3) UNEMPLOYED', 4: '(4)LABOUR', 5: '(5) SELF-EMPLOYED', 6: '(6) PRIVATE EMPLOYEE', 7: '(7) ANGANWADI TEACHER', 8: '(8) C.H.V', 9: '(9) PENSION', 10: '(10) GOVT EMPLOYEE', 99: '(99) DONT KNOW' };
const MSTATUS_MAP  = { 1: '(0) Unmarried', 2: '(1) Married', 3: '(2) Widowed', 4: '(3) Divorced' };
const REL_MAP      = { 1: 'Hindu', 2: 'Muslim', 3: 'Christian', 5: 'Others', 6: 'Others' };

function excelSerialToISO(serial) {
  if (!serial || typeof serial !== 'number' || isNaN(serial)) return null;
  const corrected = serial >= 60 ? serial - 1 : serial;
  return new Date(Date.UTC(1899, 11, 31) + corrected * 86400000).toISOString().split('T')[0];
}

function calcAge(dobSerial) {
  if (!dobSerial || typeof dobSerial !== 'number') return null;
  const corrected = dobSerial >= 60 ? dobSerial - 1 : dobSerial;
  const dob = new Date(Date.UTC(1899, 11, 31) + corrected * 86400000);
  const today = new Date();
  let age = today.getFullYear() - dob.getFullYear();
  const m = today.getMonth() - dob.getMonth();
  if (m < 0 || (m === 0 && today.getDate() < dob.getDate())) age--;
  return age > 0 && age < 120 ? age : null;
}

async function batchWrite(collectionName, docs, idFn) {
  let batch = db.batch();
  let count = 0;
  let total = 0;
  for (const doc of docs) {
    const id = idFn(doc);
    if (!id) continue;
    const ref = db.collection(collectionName).doc(id);
    batch.set(ref, doc, { merge: true });
    count++;
    total++;
    if (count === 499) {
      await batch.commit();
      process.stdout.write(`   committed ${total}...\n`);
      batch = db.batch();
      count = 0;
    }
  }
  if (count > 0) await batch.commit();
  console.log(`✅ ${collectionName}: ${total} docs written`);
}

// ─── RELATIONS → personal_details ────────────────────────────────────────────
async function importPersonalDetails() {
  console.log('\n📂 RELATIONS.xlsx → personal_details');
  const wb = XLSX.readFile('./RELATIONS.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`   ${data.length} rows`);

  const docs = data.map(row => {
    const dobISO = excelSerialToISO(row.REL_DOB);
    return {
      Family_Code:               String(row.REL_DUP_CODE || '').trim().toUpperCase() || null,
      uniq_Registration_Number:  row.REL_REG_NO !== undefined ? row.REL_REG_NO : null,
      Name:                      String(row.REL_NAME || '').trim() || null,
      Gender:                    GENDER_MAP[row.REL_SEX] ?? null,
      Date_of_Birth:             dobISO,
      Age:                       calcAge(row.REL_DOB),
      Marital_Status:            MSTATUS_MAP[row.REL_MSTATUS] ?? null,
      Education:                 EDUC_MAP[row.REL_EDUC] ?? null,
      Live_Status:               row.REL_LIVE_ST === 1 ? '(1) Alive' : '(0) Dead',
      A_v_Status:                row.REL_ACTIVE_STA === 1 ? '(1) Active' : '(0) Vacant',
      Occupation:                OCCU_MAP[row.REL_OCCU] ?? null,
      Income:                    row.REL_INCOME !== undefined ? String(row.REL_INCOME) : null,
      Parents_ID:                row.PARENTS_ID !== undefined ? String(row.PARENTS_ID) : null,
    };
  });

  await batchWrite('personal_details', docs, d =>
    d.uniq_Registration_Number ? `member_${d.uniq_Registration_Number}` : null
  );
}

// ─── FAMILY_DETAILS → Family Code Creation ───────────────────────────────────
async function importFamilyCodeCreation() {
  console.log('\n📂 FAMILY_DETAILS.xlsx → Family Code Creation');
  const wb = XLSX.readFile('./FAMILY_DETAILS.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`   ${data.length} rows`);

  const FAM_TYPE_MAP = { 1: '(1) Nuclear', 2: '(2) Joint', 3: '(3) Extended' };

  const docs = data.map(row => {
    const famId = String(row.FAM_ID_OLD || row.FAM_ID || '').trim().toUpperCase();
    return {
      family_id:   famId || null,
      Family_Code: famId || null,
      Map_No:      row.HNO ? String(row.HNO).trim() : null,
      Family_Type: FAM_TYPE_MAP[row.FAM_TYPE] ?? null,
      Religion:    REL_MAP[row.RELIGION] ?? null,
    };
  });

  await batchWrite('Family Code Creation', docs, d =>
    d.family_id ? d.family_id : null
  );
}

async function run() {
  await importPersonalDetails();
  await importFamilyCodeCreation();
  console.log('\n🎉 Done!');
}

run().catch(console.error);
