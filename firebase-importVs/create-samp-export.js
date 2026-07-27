const admin = require('firebase-admin');
const XLSX = require('xlsx');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('./share-india-d9717-firebase-adminsdk-fbsvc-ebe7273a5e.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount), storageBucket: 'share-india-d9717.firebasestorage.app' });
const bucket = admin.storage().bucket();

const GENDER_MAP = { 0: '(0) Female', 1: '(1) Male' };

function collected(val) {
  return val === 1 ? '(1) Collected' : (val !== undefined ? '(0) Not Collected' : null);
}

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

  console.log('📂 Reading SAMP.xlsx...');
  const wb = XLSX.readFile('./SAMP.xlsx');
  const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`✅ Found ${rows.length} sample records`);

  let matched = 0;
  const cleanedRows = rows.map(row => {
    const member = regMap[row.REGNO] || {};
    if (member.Name) matched++;
    return {
      Registration_Number:    row.REGNO !== undefined ? String(row.REGNO) : null,
      Family_code:            member.Family_Code || null,
      Name:                   member.Name || null,
      Gender:                 member.Gender || null,
      Age:                    member.Age !== undefined ? String(member.Age) : null,
      Date_of_Interview:      excelSerialToISO(row.INTDT),
      Interviewer_s_Name:     row.INTNAME ? String(row.INTNAME).trim() : null,

      Collect_Blood_Sample:   collected(row.CBP),
      Collect_HBA1C:          collected(row.HBA1C),
      Collect_Thyroid:        collected(row.THYROID),
      Collect_CRE:            collected(row.CRE),
      Collect_Sputum_TB:      collected(row.SPUTUM),
      Collect_Vaginal_Swab_HPV: collected(row.VS),
      Collect_Urine:          collected(row.URINE),

      Date_CBP:               excelSerialToISO(row.DTCBP),
      Date_HBA1C:             excelSerialToISO(row.DTHBA1C),
      Date_Thyroid:           excelSerialToISO(row.DTTHYROID),
      Date_CRE:               excelSerialToISO(row.DTCRE),
      Date_Sputum_TB:         excelSerialToISO(row.DTSPUTUM),
      Date_Vaginal_Swab_HPV:  excelSerialToISO(row.DTVS),
      Date_Urine:             excelSerialToISO(row.DTURINE),
    };
  });

  console.log(`✅ Matched ${matched} of ${rows.length} records`);

  const localPath = path.join(__dirname, 'samp_export.json');
  fs.writeFileSync(localPath, JSON.stringify(cleanedRows));
  const sizeMB = (fs.statSync(localPath).size / (1024 * 1024)).toFixed(2);
  console.log(`📦 JSON: ${sizeMB} MB`);

  console.log('⬆️  Uploading...');
  await bucket.upload(localPath, { destination: 'exports/blood_sample_records.json', metadata: { contentType: 'application/json' } });
  await bucket.file('exports/blood_sample_records.json').makePublic();
  console.log('✅ exports/blood_sample_records.json uploaded');
  fs.unlinkSync(localPath);
}

run().catch(console.error);
