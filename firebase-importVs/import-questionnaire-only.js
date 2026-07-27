const admin = require('firebase-admin');
const XLSX = require('xlsx');

const serviceAccount = require('./share-india-d9717-firebase-adminsdk-fbsvc-ebe7273a5e.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const GENDER_MAP = { 0: '(0) Female', 1: '(1) Male' };
const GEN_HEALTH_MAP = { 1: '(1) Excellent', 2: '(2) Good', 3: '(3) Fair', 4: '(4) Poor' };

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

function yn(val) {
  if (val === 1) return '(1) Yes';
  if (val === 2) return '(2) No';
  return '(2) No';
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

async function run() {
  console.log('📂 Reading RELATIONS.xlsx...');
  const relWb = XLSX.readFile('./RELATIONS.xlsx');
  const relRows = XLSX.utils.sheet_to_json(relWb.Sheets[relWb.SheetNames[0]]);
  const regMap = {};
  for (const r of relRows) {
    if (r.REL_REG_NO !== undefined) {
      regMap[r.REL_REG_NO] = {
        Name:   String(r.REL_NAME || '').trim(),
        Family_Code: String(r.REL_DUP_CODE || '').trim().toUpperCase(),
        Gender: GENDER_MAP[r.REL_SEX] ?? null,
        Age:    calcAge(r.REL_DOB),
      };
    }
  }
  console.log(`✅ RELATIONS: ${Object.keys(regMap).length} entries`);

  console.log('\n📂 QUESTIONNAIRE.xlsx → questionnaire');
  const wb = XLSX.readFile('./QUESTIONNAIRE.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`   ${data.length} rows`);

  const docs = data.map(row => {
    const m = regMap[row.Regno] || {};
    return {
      Registration_Number:  row.Regno !== undefined ? String(row.Regno) : null,
      Family_Code_Creation: m.Family_Code || null,
      Name:                 m.Name || null,
      Gender:               m.Gender || null,
      Age:                  m.Age !== undefined ? String(m.Age) : null,
      Date_of_Interview:    excelSerialToDMY(row.INTDT),
      Contact_Tel:          row.CONTACTNO ? String(row.CONTACTNO).trim() : null,
      Interviewer_s_Name:   row.INTNAME ? String(row.INTNAME).trim() : null,
      Height_CM:            row.HT !== undefined ? row.HT : null,
      Weight_Kg:            row.WT !== undefined ? row.WT : null,
      What_is_your_general_health_status: GEN_HEALTH_MAP[row.GEN_HEALTH] ?? null,

      Have_you_ever_been_diagnosed_screened_with_hypertension: yn(row.HTN),
      Have_you_ever_been_diagnosed_screened_with_Diabetes:     yn(row.DIA_YN),
      Do_you_smoke_chew_tobacco_related_products_now:          yn(row.SMK_CUR_YN),
      Have_you_ever_smoke_chew_in_the_past:                    yn(row.SMK_PAST_YN),
      Do_you_drink_consume_Alcohol:                            yn(row.ALCO_YN),

      Did_you_suffer_from_General_Health_problems:   yn(row.HEALTH_WT_YN),
      Did_you_suffer_from_Vision_problems1:          yn(row.EYE_YN),
      Did_you_suffer_from_ENT_problems2:             yn(row.ENT_YN),
      Did_you_suffer_from_Respiratory_problems:      yn(row.RESP_YN),
      Did_you_suffer_from_Gastrointestinal_problems: yn(row.DIG_YN),
      Did_you_suffer_from_Genitourinary_problems:    yn(row.URINE_YN),
      Did_you_suffer_from_Muscles_or_bones_problems: yn(row.ORTH_YN),
      Did_you_suffer_from_Skin_problems:             yn(row.SKIN_YN),
      Did_you_suffer_from_blood_related_problems:    yn(row.BLOOD_YN),
    };
  });

  await batchWrite('questionnaire', docs, d =>
    d.Registration_Number ? `q_${d.Registration_Number}` : null
  );

  console.log('\n🎉 Done!');
}

run().catch(console.error);
