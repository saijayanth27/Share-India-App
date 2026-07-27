const admin = require('firebase-admin');
const XLSX = require('xlsx');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('./share-india-d9717-firebase-adminsdk-fbsvc-ebe7273a5e.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount), storageBucket: 'share-india-d9717.firebasestorage.app' });
const bucket = admin.storage().bucket();

const GENDER_MAP = { 0: '(0) Female', 1: '(1) Male' };
const REL_MAP = { 1: 'Hindu', 2: 'Muslim', 3: 'Christian', 5: 'Others', 6: 'Others' };
const M_STATUS_MAP = { 1: 'Single', 2: 'Married', 3: 'Widowed', 4: 'Divorced' };

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

function parseDob(val) {
  if (val === undefined || val === null) return null;
  if (typeof val === 'number') return excelSerialToDMY(val);
  const str = String(val).trim();
  if (!str || str.startsWith('0000')) return null;
  return null;
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
        Family_ID: String(r.REL_DUP_CODE || '').trim().toUpperCase(),
        Gender: GENDER_MAP[r.REL_SEX] ?? null,
        Registration_Number: String(r.REL_REG_NO),
      };
    }
  }
  console.log(`✅ Member index: ${Object.keys(regMap).length} entries`);

  console.log('📂 Reading CC.xlsx...');
  const wb = XLSX.readFile('./CC.xlsx');
  const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`✅ Found ${rows.length} CC records`);

  let matched = 0;
  const cleanedRows = rows.map(row => {
    const member = regMap[row.REGNO] || {};
    if (member.Name) matched++;

    const intName = row.INTNAME ? String(row.INTNAME).trim() : '';
    const intParts = intName.split(/\s+/);
    const intFirst = intParts[0] || null;
    const intLast = intParts.length > 1 ? intParts.slice(1).join(' ') : null;

    const ageVal = row.AGE !== undefined ? String(row.AGE) : null;

    return {
      Registration_Number:                        row.REGNO !== undefined ? String(row.REGNO) : null,
      Family_ID:                                  member.Family_ID || null,
      Name:                                       member.Name || null,
      Gender:                                     member.Gender || null,
      Age:                                        ageVal,
      Age1:                                       ageVal,
      Exam_Date:                                  excelSerialToISO(row.INTDT),
      Interviewer_s_Name_first_name:              intFirst,
      Interviewer_s_Name_last_name:               intLast,
      Date_of_Birth:                              parseDob(row.DOB),
      Have_you_attended_school:                   row.SCH_GO === 1 ? 'Yes' : (row.SCH_GO === 2 ? 'No' : null),
      If_Yes_What_was_the_highest_level_attended: row.EDU_LEV ? String(row.EDU_LEV).trim() : null,
      Occupation:                                 row.OCCU ? String(row.OCCU).trim() : null,
      Religion:                                   REL_MAP[row.REL] ?? null,
      Monthly_Household_Income:                   row.INCOME !== undefined ? row.INCOME : null,
      Total_Number_of_household_living_at_home:   row.PER_H !== undefined ? row.PER_H : null,
      Marital_status:                             M_STATUS_MAP[row.M_STATUS] ?? null,
      Menopause_Status:                           row.STILL_MENSTRUATING === 1 ? '(1) Still Menstruating' : (row.STILL_MENSTRUATING === 2 ? '(2) Menopause' : null),
      VIA_Examination_Result:                     row.VS === 1 ? '(1) VIA Positive' : (row.VS === 2 ? '(2) VIA Negative' : null),
      Treatment_Provided:                         row.TREAT_DONE === 1 ? '(1) Treatment Done' : (row.TREAT_DONE === 2 ? '(2) Not Done' : null),
    };
  });

  console.log(`✅ Matched ${matched} of ${rows.length} records`);

  const localPath = path.join(__dirname, 'cc_export.json');
  fs.writeFileSync(localPath, JSON.stringify(cleanedRows));
  const sizeMB = (fs.statSync(localPath).size / (1024 * 1024)).toFixed(2);
  console.log(`📦 JSON: ${sizeMB} MB`);

  console.log('⬆️  Uploading...');
  await bucket.upload(localPath, { destination: 'exports/cc_records.json', metadata: { contentType: 'application/json' } });
  await bucket.file('exports/cc_records.json').makePublic();
  console.log('✅ exports/cc_records.json uploaded');
  fs.unlinkSync(localPath);
}

run().catch(console.error);
