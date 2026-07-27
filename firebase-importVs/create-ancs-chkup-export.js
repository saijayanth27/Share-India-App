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
const CHECKUP_PLACE_MAP = { 0: 'Subcentre', 1: 'PHC', 2: 'CHC' };
const POS_NEG_MAP = { 1: 'Pos', 0: 'Neg' };
const HB_MAP = { 1: 'Normal', 0: 'Anemic' };

function excelSerialToISO(serial) {
  if (!serial || typeof serial !== 'number' || isNaN(serial)) return null;
  const excelBase = Date.UTC(1899, 11, 31);
  const corrected = serial >= 60 ? serial - 1 : serial;
  return new Date(excelBase + corrected * 86400000).toISOString().split('T')[0];
}

async function createAndUploadAncsChkupExport() {
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

  // Build LMP date lookup from ANCS_LIST (REG_NO → LMP_Date)
  console.log('📂 Reading ANCS_LIST.xlsx for LMP dates...');
  const ancsWb = XLSX.readFile('./ANCS_LIST.xlsx');
  const ancsRows = XLSX.utils.sheet_to_json(ancsWb.Sheets[ancsWb.SheetNames[0]]);
  const lmpMap = {};
  for (const r of ancsRows) {
    if (r.REG_NO !== undefined && r.LMP_DT) {
      lmpMap[r.REG_NO] = excelSerialToISO(r.LMP_DT);
    }
  }
  console.log(`✅ LMP date index: ${Object.keys(lmpMap).length} entries`);

  console.log('📂 Reading ANCS_CHKUP.xlsx...');
  const chkWb = XLSX.readFile('./ANCS_CHKUP.xlsx');
  const chkRows = XLSX.utils.sheet_to_json(chkWb.Sheets[chkWb.SheetNames[0]]);
  console.log(`✅ Found ${chkRows.length} checkup records`);

  let matched = 0;
  const cleanedRows = chkRows.map(row => {
    const member = regMap[row.REG_NO] || {};
    if (member.Name) matched++;

    return {
      // Identity — from joins
      Registration_Number: row.REG_NO !== undefined ? String(row.REG_NO) : null,
      Visit_No: row.VISIT_NO !== undefined ? String(row.VISIT_NO) : null,
      Name: member.Name || null,
      Family_Code: member.Family_Code || null,
      LMP_Date: lmpMap[row.REG_NO] || null,

      // Checkup details
      Checkup_Date:  excelSerialToISO(row.CHKUP_DT),
      Checkup_Place: CHECKUP_PLACE_MAP[row.CHKUP_PLACE] ?? null,

      // Medical tests
      HBsAg:  row.HBSAG !== undefined ? (POS_NEG_MAP[row.HBSAG] ?? null) : null,
      HIV:    row.HIV   !== undefined ? (POS_NEG_MAP[row.HIV]   ?? null) : null,
      VDRL:   row.VDRL  !== undefined ? (POS_NEG_MAP[row.VDRL]  ?? null) : null,
      Hb:     row.HB    !== undefined ? (HB_MAP[row.HB]         ?? null) : null,

      // Vitals (actual numeric values)
      Weight:    row.WTVAL    !== undefined ? row.WTVAL    : null,
      Systolic:  row.BPS      !== undefined ? row.BPS      : null,
      Diastolic: row.BPD      !== undefined ? row.BPD      : null,

      // Remarks
      Remarks: row.CHKUP_REMARKS ? String(row.CHKUP_REMARKS).trim() : null,
    };
  });

  console.log(`✅ Matched ${matched} of ${chkRows.length} records to members`);

  const localPath = path.join(__dirname, 'anc_checkups_export.json');
  fs.writeFileSync(localPath, JSON.stringify(cleanedRows));
  const fileSizeMB = (fs.statSync(localPath).size / (1024 * 1024)).toFixed(2);
  console.log(`📦 JSON file created: ${fileSizeMB} MB`);

  console.log('⬆️  Uploading to Firebase Storage...');
  await bucket.upload(localPath, {
    destination: 'exports/anc_checkups.json',
    metadata: { contentType: 'application/json' },
  });
  await bucket.file('exports/anc_checkups.json').makePublic();
  console.log('✅ Upload successful! → exports/anc_checkups.json');

  fs.unlinkSync(localPath);
}

createAndUploadAncsChkupExport().catch(console.error);
