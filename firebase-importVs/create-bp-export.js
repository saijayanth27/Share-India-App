const admin = require('firebase-admin');
const XLSX = require('xlsx');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('./share-india-d9717-firebase-adminsdk-fbsvc-ebe7273a5e.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount), storageBucket: 'share-india-d9717.firebasestorage.app' });
const bucket = admin.storage().bucket();

const GENDER_MAP = { 0: '(0) Female', 1: '(1) Male' };

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
  return age > 0 && age < 130 ? age : null;
}

async function run() {
  console.log('📂 Reading RELATIONS.xlsx...');
  const relWb = XLSX.readFile('./RELATIONS.xlsx');
  const relRows = XLSX.utils.sheet_to_json(relWb.Sheets[relWb.SheetNames[0]]);
  const regMap = {};
  for (const r of relRows) {
    if (r.REL_REG_NO !== undefined) {
      regMap[r.REL_REG_NO] = {
        Name: String(r.REL_NAME || '').trim(),
        Family_Code: String(r.REL_DUP_CODE || '').trim().toUpperCase(),
        Gender: GENDER_MAP[r.REL_SEX] ?? null,
        Age: calcAge(r.REL_DOB),
        Registration_Number: String(r.REL_REG_NO),
      };
    }
  }
  console.log(`✅ Member index: ${Object.keys(regMap).length} entries`);

  console.log('📂 Reading BP.xlsx...');
  const wb = XLSX.readFile('./BP.xlsx');
  const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`✅ Found ${rows.length} BP records`);

  let matched = 0;
  const cleanedRows = rows.map(row => {
    const member = regMap[row.Regno] || {};
    if (member.Name) matched++;
    return {
      Registration_Number: row.Regno !== undefined ? String(row.Regno) : null,
      Family_Code:         member.Family_Code || null,
      Name:                member.Name || null,
      Gender:              member.Gender || null,
      Age:                 member.Age !== undefined ? String(member.Age) : null,
      Date_of_Interview:   excelSerialToISO(row.INTDT),
      Interviewer_s_Name:  row.INTNAME ? String(row.INTNAME).trim() : null,
      systolic:            row.BP1S !== undefined ? row.BP1S : null,
      diastolic:           row.BP1D !== undefined ? row.BP1D : null,
      pulse:               row.HR1  !== undefined ? row.HR1  : null,
      systolic2:           row.BP2S !== undefined ? row.BP2S : null,
      diastolic2:          row.BP2D !== undefined ? row.BP2D : null,
      pulse2:              row.HR2  !== undefined ? row.HR2  : null,
      systolic3:           row.BP3S !== undefined ? row.BP3S : null,
      diastolic3:          row.BP3D !== undefined ? row.BP3D : null,
      pulse3:              row.HR3  !== undefined ? row.HR3  : null,
    };
  });

  console.log(`✅ Matched ${matched} of ${rows.length} records`);

  const localPath = path.join(__dirname, 'bp_export.json');
  fs.writeFileSync(localPath, JSON.stringify(cleanedRows));
  const sizeMB = (fs.statSync(localPath).size / (1024 * 1024)).toFixed(2);
  console.log(`📦 JSON: ${sizeMB} MB`);

  console.log('⬆️  Uploading...');
  await bucket.upload(localPath, { destination: 'exports/bp_readings.json', metadata: { contentType: 'application/json' } });
  await bucket.file('exports/bp_readings.json').makePublic();
  console.log('✅ exports/bp_readings.json uploaded');
  fs.unlinkSync(localPath);
}

run().catch(console.error);
