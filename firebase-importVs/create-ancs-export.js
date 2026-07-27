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

// --- Field mappings ---
const YES_NO_MAP = { 1: '(1) Yes', 0: '(0) No' };
const GIVEN_BY_MAP = { 0: '(0) RHC', 1: '(1) PVT', 2: '(2) GOVT' };
const DELIVERY_TYPE_MAP = { 0: '(0) Normal', 1: '(1) Caesarian', 2: '(2) Abortion', 3: '(3) Other' };
const DELIVERY_OUTCOME_MAP = { 0: '(0) Live Birth', 1: '(1) Still Birth', 2: '(2) Premature' };
const DELIVERY_PLACE_MAP = { 0: '(0) RHC', 1: '(1) PVT', 2: '(2) GOVT', 3: '(3) HOME' };

function excelSerialToISO(serial) {
  if (!serial || typeof serial !== 'number' || isNaN(serial)) return null;
  const excelBase = Date.UTC(1899, 11, 31);
  const corrected = serial >= 60 ? serial - 1 : serial;
  return new Date(excelBase + corrected * 86400000).toISOString().split('T')[0];
}

async function createAndUploadAncsExport() {
  console.log('📂 Reading RELATIONS.xlsx to build member index...');
  const relWb = XLSX.readFile('./RELATIONS.xlsx');
  const relRows = XLSX.utils.sheet_to_json(relWb.Sheets[relWb.SheetNames[0]]);

  // Build map: REL_REG_NO → { Name, Family_Code }
  const regMap = {};
  for (const r of relRows) {
    if (r.REL_REG_NO !== undefined) {
      regMap[r.REL_REG_NO] = {
        Name: String(r.REL_NAME || '').trim(),
        Family_Code: String(r.REL_DUP_CODE || '').trim().toUpperCase(),
      };
    }
  }
  console.log(`✅ Member index built: ${Object.keys(regMap).length} entries`);

  console.log('📂 Reading ANCS_LIST.xlsx...');
  const ancsWb = XLSX.readFile('./ANCS_LIST.xlsx');
  const ancsRows = XLSX.utils.sheet_to_json(ancsWb.Sheets[ancsWb.SheetNames[0]]);
  console.log(`✅ Found ${ancsRows.length} ANC records`);

  let matched = 0;
  const cleanedRows = ancsRows.map(row => {
    const member = regMap[row.REG_NO] || {};
    if (member.Name) matched++;

    return {
      // Identity — from RELATIONS join
      Registration_Number: row.REG_NO !== undefined ? String(row.REG_NO) : null,
      Name: member.Name || null,
      Family_Code: member.Family_Code || null,

      // ANC dates
      LMP_Date: excelSerialToISO(row.LMP_DT),

      // TT Dose
      st_Given_Y_N:  YES_NO_MAP[row.TT1]            ?? null,
      st_Dt:         excelSerialToISO(row.TT_DOSE_I_DT),
      st_Given_By:   GIVEN_BY_MAP[row.TT_DOSE_I_GB] ?? null,
      nd_Given_Y_N:  YES_NO_MAP[row.TT2]            ?? null,
      nd_Dt:         excelSerialToISO(row.TT_DOSE_II_DT),
      nd_Given_By:   GIVEN_BY_MAP[row.TT_DOSE_II_GB] ?? null,

      // IFA
      st_Given_Y_N1: YES_NO_MAP[row.IFA1]              ?? null,
      st_Dt1:        excelSerialToISO(row.IFA_DOSE_I_DT),
      st_Given_By1:  GIVEN_BY_MAP[row.IFA_DOSE_I_GB]   ?? null,
      nd_Given_Y_N1: YES_NO_MAP[row.IFA2]              ?? null,
      nd_Dt1:        excelSerialToISO(row.IFA_DOSE_II_DT),
      nd_Given_By1:  GIVEN_BY_MAP[row.IFA_DOSE_II_GB]  ?? null,
      rd_Given_Y_N1: YES_NO_MAP[row.IFA3]              ?? null,
      rd_Dt:         excelSerialToISO(row.IFA_DOSE_III_DT),
      rd_Given_By:   GIVEN_BY_MAP[row.IFA_DOSE_III_GB] ?? null,
      TH_Given_Y_N1: YES_NO_MAP[row.IFA4]              ?? null,
      th_Dt:         excelSerialToISO(row.IFA_DOSE_IV_DT),
      th_Given_By:   GIVEN_BY_MAP[row.IFA_DOSE_IV_GB]  ?? null,

      // Delivery
      Delivery_Type:         DELIVERY_TYPE_MAP[row.DELTYPE]  ?? null,
      Delivery:              DELIVERY_OUTCOME_MAP[row.DELIVERY] ?? null,
      Delivery_Dt:           excelSerialToISO(row.DELIVERY_DT),
      Delivery_Place:        DELIVERY_PLACE_MAP[row.DEL_PLACE] ?? null,
      Delivery_Place_Details: row.DEL_PLACE_DET !== undefined ? String(row.DEL_PLACE_DET) : null,
      Total_Live_Births:     row.LIVE_BIRTHS !== undefined ? String(row.LIVE_BIRTHS) : null,

      // Remarks
      Remarks2: row.REMARKS ? String(row.REMARKS).trim() : null,
    };
  });

  console.log(`✅ Matched ${matched} of ${ancsRows.length} records to members`);

  const localPath = path.join(__dirname, 'anc_records_export.json');
  fs.writeFileSync(localPath, JSON.stringify(cleanedRows));
  const fileSizeMB = (fs.statSync(localPath).size / (1024 * 1024)).toFixed(2);
  console.log(`📦 JSON file created: ${fileSizeMB} MB`);

  console.log('⬆️  Uploading to Firebase Storage...');
  await bucket.upload(localPath, {
    destination: 'exports/anc_records.json',
    metadata: { contentType: 'application/json' },
  });
  await bucket.file('exports/anc_records.json').makePublic();
  console.log('✅ Upload successful! → exports/anc_records.json');

  fs.unlinkSync(localPath);
}

createAndUploadAncsExport().catch(console.error);
