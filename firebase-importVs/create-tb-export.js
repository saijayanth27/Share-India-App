const admin = require('firebase-admin');
const XLSX = require('xlsx');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('./share-india-d9717-firebase-adminsdk-fbsvc-ebe7273a5e.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount), storageBucket: 'share-india-d9717.firebasestorage.app' });
const bucket = admin.storage().bucket();

const GENDER_MAP = { 0: '(0) Female', 1: '(1) Male' };

function yn(val) {
  if (val === 1) return '(1) Yes';
  if (val === 2) return '(2) No';
  return '(2) No'; // default
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

  console.log('📂 Reading TB.xlsx...');
  const wb = XLSX.readFile('./TB.xlsx');
  const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`✅ Found ${rows.length} TB records`);

  let matched = 0;
  const cleanedRows = rows.map(row => {
    const member = regMap[row.REGNO] || {};
    if (member.Name) matched++;
    return {
      Registration_Number: row.REGNO !== undefined ? String(row.REGNO) : null,
      Family_Code:         member.Family_Code || null,
      Name:                member.Name || null,
      Gender:              member.Gender || null,
      Age:                 member.Age !== undefined ? String(member.Age) : null,
      Interview_Date:      excelSerialToISO(row.INTDT),
      Interviewer_s_Name:  row.INTNAME ? String(row.INTNAME).trim() : null,

      Have_you_had_a_cough_for_more_than_2_weeks:                      yn(row.COUGH),
      Haemoptysis_coughing_up_blood:                                    yn(row.HAEMOPTYSIS),
      Have_you_had_a_fever_for_more_than_2_weeks:                      yn(row.FEVER),
      Do_you_feel_like_you_have_lost_weight:                           yn(row.LOST_WT),
      Are_you_experiencing_excessive_sweating_at_night_Night_sweats:   yn(row.NODE_SWELLING),
      Medical_History1:                  yn(row.DIAG_TB),
      Medical_History2:                  yn(row.HIST_EXP),
      Respiratory_and_General_Health1:   yn(row.CHRONIC_RESP),
      Respiratory_and_General_Health2:   yn(row.RECENT_RESPIRATORY),
      Social_and_Environmental_Factors1: yn(row.LIVE_CROWD),
      Social_and_Environmental_Factors2: yn(row.HIST_TB_HOUSE),
      Occupational_History1:             yn(row.WORK_HC),
      Occupational_History2:             yn(row.INCREASED_RISK),
      Behavioural_Risk_Factors1:         yn(row.SMOKE_HIST),
      Behavioural_Risk_Factors2:         yn(row.CONSUME_ALOC),
      Diagnostic_Tests1:                 yn(row.XRAY),
    };
  });

  console.log(`✅ Matched ${matched} of ${rows.length} records`);

  const localPath = path.join(__dirname, 'tb_export.json');
  fs.writeFileSync(localPath, JSON.stringify(cleanedRows));
  const sizeMB = (fs.statSync(localPath).size / (1024 * 1024)).toFixed(2);
  console.log(`📦 JSON: ${sizeMB} MB`);

  console.log('⬆️  Uploading...');
  await bucket.upload(localPath, { destination: 'exports/tb_records.json', metadata: { contentType: 'application/json' } });
  await bucket.file('exports/tb_records.json').makePublic();
  console.log('✅ exports/tb_records.json uploaded');
  fs.unlinkSync(localPath);
}

run().catch(console.error);
