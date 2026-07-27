const admin = require('firebase-admin');
const XLSX = require('xlsx');

const serviceAccount = require('./share-india-d9717-firebase-adminsdk-fbsvc-ebe7273a5e.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const GENDER_MAP = { 0: '(0) Female', 1: '(1) Male' };

function excelSerialToISO(serial) {
  if (!serial || typeof serial !== 'number' || isNaN(serial)) return null;
  const corrected = serial >= 60 ? serial - 1 : serial;
  return new Date(Date.UTC(1899, 11, 31) + corrected * 86400000).toISOString().split('T')[0];
}

function excelSerialToDMY(serial) {
  const iso = excelSerialToISO(serial);
  if (!iso) return null;
  const [y, m, d] = iso.split('-');
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return `${d}-${months[parseInt(m) - 1]}-${y}`;
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

// ─── CC_REF → cc_refusal ─────────────────────────────────────────────────────
// REASON codes: 1=Currently Menstruating, 2=Not Available,
//               5=Currently Pregnant, 6=Uterus Removed, 7=Not Interested
async function importCcRefusal(regMap) {
  console.log('\n📂 CC_REF.xlsx → cc_refusal');
  const wb = XLSX.readFile('./CC_REF.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`   ${data.length} rows`);

  const docs = data.map(row => {
    const m = regMap[row.REGNO] || {};
    return {
      Registration_Number:    row.REGNO !== undefined ? String(row.REGNO) : null,
      Family_Code:            m.Family_Code || null,
      Name:                   m.Name || null,
      Gender:                 m.Gender || null,
      Age:                    m.Age !== undefined ? String(m.Age) : null,
      Visit_Date:             excelSerialToDMY(row.CREATED_DT),
      Interviewer_s_Name:     row.INTNAME ? String(row.INTNAME).trim() : null,
      Currently_Menstruating: row.REASON === 1,
      Not_Available:          row.REASON === 2,
      Currently_Pregnant:     row.REASON === 5,
      Uterus_Removed:         row.REASON === 6,
      Not_Interested:         row.REASON === 7,
    };
  });

  await batchWrite('cc_refusal', docs, d =>
    d.Registration_Number ? `cc_ref_${d.Registration_Number}` : null
  );
}

// ─── QST_NA → questionnaire_not_available ────────────────────────────────────
// NA codes: 1=Not Available (only value in data)
async function importQstNA(regMap) {
  console.log('\n📂 QST_NA.xlsx → questionnaire_not_available');
  const wb = XLSX.readFile('./QST_NA.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`   ${data.length} rows`);

  const docs = data.map(row => {
    const m = regMap[row.REGNO] || {};
    return {
      Registration_Number:  row.REGNO !== undefined ? String(row.REGNO) : null,
      Family_Code:          m.Family_Code || null,
      Name:                 m.Name || null,
      Visit_Date:           excelSerialToDMY(row.CREATED_DT),
      Interviewer_s_Name:   row.INTNAME ? String(row.INTNAME).trim() : null,
      Not_Available:        row.NA === 1,
      House_Locked:         row.NA === 2,
      Refused_Current_Visit: row.NA === 3,
      Other_Reason:         row.NA === 4,
    };
  });

  await batchWrite('questionnaire_not_available', docs, d =>
    d.Registration_Number ? `qst_na_${d.Registration_Number}` : null
  );
}

async function run() {
  console.log('📂 Reading RELATIONS.xlsx...');
  const relWb = XLSX.readFile('./RELATIONS.xlsx');
  const relRows = XLSX.utils.sheet_to_json(relWb.Sheets[relWb.SheetNames[0]]);
  const regMap = {};
  for (const r of relRows) {
    if (r.REL_REG_NO !== undefined) {
      regMap[r.REL_REG_NO] = {
        Name:        String(r.REL_NAME || '').trim(),
        Family_Code: String(r.REL_DUP_CODE || '').trim().toUpperCase(),
        Gender:      GENDER_MAP[r.REL_SEX] ?? null,
        Age:         calcAge(r.REL_DOB),
      };
    }
  }
  console.log(`✅ RELATIONS: ${Object.keys(regMap).length} entries`);

  await importCcRefusal(regMap);
  await importQstNA(regMap);

  console.log('\n🎉 Done!');
}

run().catch(console.error);
