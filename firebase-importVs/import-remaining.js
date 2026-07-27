const admin = require('firebase-admin');
const XLSX = require('xlsx');

const serviceAccount = require('./share-india-d9717-firebase-adminsdk-fbsvc-ebe7273a5e.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const GENDER_MAP    = { 0: '(0) Female', 1: '(1) Male' };
const DEL_TYPE_MAP  = { 0: '(0) Normal', 1: '(1) Caesarian', 2: '(2) Abortion' };
const DEL_OUT_MAP   = { 0: '(0) Live Birth', 1: '(1) Still Birth', 2: '(2) Premature' };
const DEL_PLACE_MAP = { 0: '(0) RHC', 1: '(1) PVT', 2: '(2) GOVT', 3: '(3) HOME' };

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

function givenYN(val) {
  if (val === 1) return '(1) Yes';
  if (val === 0) return '(2) No';
  return null;
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

// ─── ANCS_LIST → ante_natal_care ─────────────────────────────────────────────
async function importANC(regMap) {
  console.log('\n📂 ANCS_LIST.xlsx → ante_natal_care');
  const wb = XLSX.readFile('./ANCS_LIST.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`   ${data.length} rows`);

  const docs = data.map(row => {
    const m = regMap[row.REG_NO] || {};
    const lmpISO = excelSerialToISO(row.LMP_DT);
    return {
      Registration_Number: row.REG_NO !== undefined ? String(row.REG_NO) : null,
      Family_Code:         m.Family_Code || null,
      Name:                m.Name || null,
      Gender:              m.Gender || null,
      Age:                 m.Age !== undefined ? String(m.Age) : null,
      LMP_Date:            excelSerialToDMY(row.LMP_DT),
      Delivery_Type:       DEL_TYPE_MAP[row.DELTYPE] ?? null,
      Delivery:            DEL_OUT_MAP[row.DELIVERY] ?? null,
      Delivery_Dt:         excelSerialToDMY(row.DELIVERY_DT),
      Delivery_Place:      DEL_PLACE_MAP[row.DEL_PLACE] ?? null,
      Total_Live_Births:   row.LIVE_BIRTHS !== undefined ? String(row.LIVE_BIRTHS) : null,
      _lmpISO:             lmpISO,
    };
  });

  await batchWrite('ante_natal_care', docs, d => {
    if (!d.Registration_Number) return null;
    const suffix = d._lmpISO ? `_${d._lmpISO.replace(/-/g, '')}` : '';
    return `anc_${d.Registration_Number}${suffix}`;
  });
}

// ─── ANCS_CHKUP → ante_natal_checkup ─────────────────────────────────────────
async function importANCCheckup(regMap) {
  console.log('\n📂 ANCS_CHKUP.xlsx → ante_natal_checkup');
  const wb = XLSX.readFile('./ANCS_CHKUP.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`   ${data.length} rows`);

  const docs = data.map(row => {
    const m = regMap[row.REG_NO] || {};
    const chkupISO = excelSerialToISO(row.CHKUP_DT);
    return {
      Registration_Number: row.REG_NO !== undefined ? String(row.REG_NO) : null,
      Family_ID:           m.Family_Code || null,
      Family_Code:         m.Family_Code || null,
      Name:                m.Name || null,
      Gender:              m.Gender || null,
      Age:                 m.Age !== undefined ? String(m.Age) : null,
      Visit_No:            row.VISIT_NO !== undefined ? String(row.VISIT_NO) : null,
      Checkup_Date:        excelSerialToDMY(row.CHKUP_DT),
      _chkupISO:           chkupISO,
    };
  });

  await batchWrite('ante_natal_checkup', docs, d => {
    if (!d.Registration_Number) return null;
    const visitPart = d.Visit_No ? `_v${d.Visit_No}` : '';
    const datePart  = d._chkupISO ? `_${d._chkupISO.replace(/-/g, '')}` : '';
    return `anc_checkup_${d.Registration_Number}${visitPart}${datePart}`;
  });
}

// ─── CHILD_HEALTH → child_immunization ───────────────────────────────────────
async function importChildImmunization(regMap) {
  console.log('\n📂 CHILD_HEALTH.xlsx → child_immunization');
  const wb = XLSX.readFile('./CHILD_HEALTH.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`   ${data.length} rows`);

  const docs = data.map(row => {
    const m = regMap[row.REG_NO] || {};
    return {
      Registration_Number: row.REG_NO !== undefined ? String(row.REG_NO) : null,
      Family_Code:         m.Family_Code || null,
      Name:                m.Name || null,
      Gender:              m.Gender || null,
      Age:                 m.Age !== undefined ? String(m.Age) : null,

      // BCG
      BCG_Given_Y_N:  givenYN(row.BCG),
      BCG_Dt:         excelSerialToDMY(row.BCG_DT),

      // OPV0 (Polio 0)
      OPVO_Given_Y_N: givenYN(row.POLIO0),
      OPV0_Dt:        excelSerialToDMY(row.POLIO_0_DT),

      // OPV1 (Polio 1)
      OPVO_Given_By1: givenYN(row.POLIO1),
      OPV_1_Dt:       excelSerialToDMY(row.POLIO_1_DT),

      // OPV2 (Polio 2)
      OPV2_Given_yes_no: givenYN(row.POLIO2),
      OPV2_Dt:           excelSerialToDMY(row.POLIO_2_DT),

      // OPV3 (Polio 3)
      OPV3_Given_by_Y_N: givenYN(row.POLIO3),
      OPV3_Dt:           excelSerialToDMY(row.POLIO_3_DT),

      // OPV Booster
      OPV_B_Given_Y_N: givenYN(row.POLIO_B),
      OPV_B_Dt:        excelSerialToDMY(row.POLIO_B_DT),

      // DPT1 → Penta1
      DPT1_Given_Y_N: givenYN(row.DPT1),
      DPT1_Dt3:       excelSerialToDMY(row.DPT_1_DT),

      // DPT2 → Penta2
      DPT2_Given_Y_N2: givenYN(row.DPT2),
      DPT2_Dt:         excelSerialToDMY(row.DPT_2_DT),

      // DPT3 → Penta3
      DPT3_Given_Y_N3: givenYN(row.DPT3),
      DPT3_Dt:         excelSerialToDMY(row.DPT_3_DT),

      // DPT Booster → DPTB1
      DPTB_Given_Y_N: givenYN(row.DPT_B),
      DPT_B_Dt:       excelSerialToDMY(row.DPT_B_DT),

      // Measles → MR1
      Measles1:   givenYN(row.MEASLES),
      Measles_Dt: excelSerialToDMY(row.MEASLES_DT),

      // HepB0 (Hepatitis I)
      HepB0_Given_Y_N: givenYN(row.HEP_I),
      HepB0_Dt:        excelSerialToDMY(row.HEP_I_DT),

      // VitA1
      VitA1_Given_Y_N: givenYN(row.VIT_A_1),
      VitA1_Dt:        excelSerialToDMY(row.VIT_A_1_DT),

      // VitA2
      VitA2_Given_Y_N: givenYN(row.VIT_A_2),
      VitA2_Dt:        excelSerialToDMY(row.VIT_A_2_DT),
    };
  });

  await batchWrite('child_immunization', docs, d =>
    d.Registration_Number ? `child_${d.Registration_Number}` : null
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

  await importANC(regMap);
  await importANCCheckup(regMap);
  await importChildImmunization(regMap);

  console.log('\n🎉 Done!');
}

run().catch(console.error);
