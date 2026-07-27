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
const PLACE_MAP = { 0: '(0) RHC', 1: '(1) PVT', 2: '(2) GOVT' };

function yn(val) { return val === 1 ? '(1) Yes' : '(0) No'; }
function pl(val) { return PLACE_MAP[val] ?? null; }

function excelSerialToISO(serial) {
  if (!serial || typeof serial !== 'number' || isNaN(serial)) return null;
  const excelBase = Date.UTC(1899, 11, 31);
  const corrected = serial >= 60 ? serial - 1 : serial;
  return new Date(excelBase + corrected * 86400000).toISOString().split('T')[0];
}

async function createAndUploadChildHealthExport() {
  console.log('📂 Reading RELATIONS.xlsx to build member index...');
  const relWb = XLSX.readFile('./RELATIONS.xlsx');
  const relRows = XLSX.utils.sheet_to_json(relWb.Sheets[relWb.SheetNames[0]]);
  const regMap = {};
  for (const r of relRows) {
    if (r.REL_REG_NO !== undefined) {
      regMap[r.REL_REG_NO] = {
        Name: String(r.REL_NAME || '').trim(),
        Family_Code: String(r.REL_DUP_CODE || '').trim().toUpperCase(),
        Registration_Number: String(r.REL_REG_NO),
      };
    }
  }
  console.log(`✅ Member index: ${Object.keys(regMap).length} entries`);

  console.log('📂 Reading CHILD_HEALTH.xlsx...');
  const wb = XLSX.readFile('./CHILD_HEALTH.xlsx');
  const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`✅ Found ${rows.length} child health records`);

  let matched = 0;
  const cleanedRows = rows.map(row => {
    const member = regMap[row.REG_NO] || {};
    if (member.Name) matched++;

    const r = {
      // Identity (from RELATIONS join)
      Registration_Number: row.REG_NO !== undefined ? String(row.REG_NO) : null,
      Name: member.Name || null,
      Family_Code: member.Family_Code || null,

      // Weight & Remarks
      Birth_Weight: row.WEIGHT !== undefined ? row.WEIGHT : null,
      Remarks1: row.REMARKS ? String(row.REMARKS).trim() : null,

      // --- BCG ---
      BCG_Given_Y_N: yn(row.BCG),
      BCG_Dt:        excelSerialToISO(row.BCG_DT),
      BCG_Given_By:  pl(row.BCG_PL),

      // --- OPV0 (Polio 0) ---
      OPVO_Given_Y_N: yn(row.POLIO0),
      OPV0_Dt:        excelSerialToISO(row.POLIO_0_DT),
      OPVO_Given_By:  pl(row.POLIO_0_PL),

      // --- HepB0 (Hep B 1st dose) ---
      HepB0_Given_Y_N: yn(row.HEP_I),
      HepB0_Dt:        excelSerialToISO(row.HEP_I_DT),
      HepB0_Given_By:  pl(row.HEP_I_PL),

      // --- OPV1 (Polio 1) ---
      OPVO_Given_By1: yn(row.POLIO1),   // form uses this as YN field for OPV1
      OPV_1_Dt:       excelSerialToISO(row.POLIO_1_DT),
      OPV1_Given_By:  pl(row.POLIO_1_PL),

      // --- Penta1 / DPT1 ---
      DPT1_Given_Y_N:  yn(row.DPT1),
      DPT1_Dt3:        excelSerialToISO(row.DPT_1_DT),
      DPT1_Given_Y_N1: pl(row.DPT_1_PL),

      // --- OPV2 (Polio 2) ---
      OPV2_Given_yes_no:  yn(row.POLIO2),
      OPV2_Dt:            excelSerialToISO(row.POLIO_2_DT),
      Drop_OPV2_Given_By: pl(row.POLIO_2_PL),

      // --- Penta2 / DPT2 ---
      DPT2_Given_Y_N2: yn(row.DPT2),
      DPT2_Dt:         excelSerialToISO(row.DPT_2_DT),
      DPT2_Given_By:   pl(row.DPT_2_PL),

      // --- OPV3 (Polio 3) ---
      OPV3_Given_by_Y_N: yn(row.POLIO3),
      OPV3_Dt:           excelSerialToISO(row.POLIO_3_DT),
      OPV2_Given_By2:    pl(row.POLIO_3_PL),

      // --- Penta3 / DPT3 ---
      DPT3_Given_Y_N3: yn(row.DPT3),
      DPT3_Dt:         excelSerialToISO(row.DPT_3_DT),
      DPT3_Given_By:   pl(row.DPT_3_PL),

      // --- MR1 / Measles ---
      Measles1:         yn(row.MEASLES),
      Measles_Dt:       excelSerialToISO(row.MEASLES_DT),
      Measles_Given_Y_N: pl(row.MEASLES_PL),

      // --- VitA1 ---
      VitA1_Given_Y_N: yn(row.VIT_A_1),
      VitA1_Dt:        excelSerialToISO(row.VIT_A_1_DT),
      VitA1_Given_By:  pl(row.VIT_A_1_PL),

      // --- DPTB1 (DPT Booster 1) ---
      DPTB_Given_Y_N:  yn(row.DPT_B),
      DPT_B_Dt:        excelSerialToISO(row.DPT_B_DT),
      DPTB_Given_Y_N1: pl(row.DPT_B_PL),

      // --- OPVB (OPV Booster) ---
      OPV_B_Given_Y_N: yn(row.POLIO_B),
      OPV_B_Dt:        excelSerialToISO(row.POLIO_B_DT),
      OPV2_Given_By1:  pl(row.POLIO_B_PL),

      // --- VitA2 ---
      VitA2_Given_Y_N: yn(row.VIT_A_2),
      VitA2_Dt:        excelSerialToISO(row.VIT_A_2_DT),
      VitA2_Given_By:  pl(row.VIT_A_2_PL),

      // --- VitA3 (Booster) ---
      VitA3_Given_Y_N1: yn(row.VIT_A_B),
      VitA3_Dt:         excelSerialToISO(row.VIT_A_B_DT),
      V:                pl(row.VIT_A_B_PL),

      // --- VitA4 ---
      Vita4_Given_Y_N: yn(row.VIT_A_3),
      VitA4_Dt:        excelSerialToISO(row.VIT_A_3_DT),
      VitA4_Given_By:  pl(row.VIT_A_3_PL),

      // --- VitA5 ---
      VitA5_Given_Y_N: yn(row.VIT_A_4),
      VitA5_Dt:        excelSerialToISO(row.VIT_A_4_DT),
      VitA5_Given_By:  pl(row.VIT_A_4_PL),

      // --- DT / Td1 ---
      DT_Given_Y_N: yn(row.DT),
      DT_Dt:        excelSerialToISO(row.DT_DT),
      DT_Given_By:  pl(row.DT_PL),
    };

    return r;
  });

  console.log(`✅ Matched ${matched} of ${rows.length} records to members`);

  const localPath = path.join(__dirname, 'child_health_export.json');
  fs.writeFileSync(localPath, JSON.stringify(cleanedRows));
  const fileSizeMB = (fs.statSync(localPath).size / (1024 * 1024)).toFixed(2);
  console.log(`📦 JSON file created: ${fileSizeMB} MB`);

  console.log('⬆️  Uploading to Firebase Storage...');
  await bucket.upload(localPath, {
    destination: 'exports/child_health.json',
    metadata: { contentType: 'application/json' },
  });
  await bucket.file('exports/child_health.json').makePublic();
  console.log('✅ Upload successful! → exports/child_health.json');

  fs.unlinkSync(localPath);
}

createAndUploadChildHealthExport().catch(console.error);
