const admin = require('firebase-admin');
const XLSX = require('xlsx');

const serviceAccount = require('./share-india-d9717-firebase-adminsdk-fbsvc-ebe7273a5e.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// --- Shared helpers ---
const GENDER_MAP   = { 0: '(0) Female', 1: '(1) Male' };
const REASON_MAP   = { 1: '(1) Left the Village', 2: '(2) Died', 3: '(3) Double code', 4: '(4) Not Interested / Refused' };
const REL_MAP      = { 1: 'Hindu', 2: 'Muslim', 3: 'Christian', 5: 'Others', 6: 'Others' };
const M_STATUS_MAP = { 1: 'Single', 2: 'Married', 3: 'Widowed', 4: 'Divorced' };
const PLACE_MAP    = { 0: '(0) RHC', 1: '(1) PVT', 2: '(2) GOVT' };
const PERM_USED_MAP = { 0: '(0) Tubectomy', 1: '(1) Vasectomy', 2: '(2) Hysectomy' };

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

function parseDateField(val) {
  if (!val) return null;
  if (typeof val === 'number') return excelSerialToISO(val);
  const s = String(val).trim();
  if (s === '' || s === '0000-00-00' || s.startsWith('0000')) return null;
  return s.split(' ')[0];
}

function parseDob(val) {
  if (val === undefined || val === null) return null;
  if (typeof val === 'number') return excelSerialToDMY(val);
  const str = String(val).trim();
  if (!str || str.startsWith('0000')) return null;
  return null;
}

function yn(val) {
  if (val === 1) return '(1) Yes';
  if (val === 2) return '(2) No';
  return '(2) No';
}

function collected(val) {
  return val === 1 ? '(1) Collected' : (val !== undefined ? '(0) Not Collected' : null);
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

// Batch write: commits every 499 docs to stay under Firestore 500-op limit
async function batchWrite(collectionName, docs, getDocId) {
  let batch = db.batch();
  let batchCount = 0;
  let total = 0;
  let skipped = 0;

  for (const doc of docs) {
    const docId = getDocId(doc);
    if (!docId) { skipped++; continue; }

    const ref = db.collection(collectionName).doc(docId);
    const cleanDoc = Object.fromEntries(
      Object.entries(doc).filter(([_, v]) => v !== null && v !== undefined && v !== '')
    );
    batch.set(ref, cleanDoc);
    batchCount++;
    total++;

    if (batchCount === 499) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
      process.stdout.write(`\r  ${total} written...`);
    }
  }

  if (batchCount > 0) await batch.commit();
  console.log(`\n  ✅ ${total} docs written to '${collectionName}' (${skipped} skipped — no reg no)`);
}

// ─── BP → health_readings ────────────────────────────────────────────────────
async function importBP(regMap) {
  console.log('\n📂 BP.xlsx → health_readings');
  const wb = XLSX.readFile('./BP.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`   ${data.length} rows`);

  const docs = data.map(row => {
    const m = regMap[row.Regno] || {};
    return {
      Registration_Number: row.Regno !== undefined ? String(row.Regno) : null,
      Family_code:         m.Family_Code || null,
      Name:                m.Name || null,
      Gender:              m.Gender || null,
      Age:                 m.Age !== undefined ? String(m.Age) : null,
      Date_of_Interview:   excelSerialToISO(row.INTDT),
      Interviewer_s_Name:  row.INTNAME ? String(row.INTNAME).trim() : null,
      systolic:            row.BP1S ?? null,
      diastolic:           row.BP1D ?? null,
      pulse:               row.HR1  ?? null,
      systolic2:           row.BP2S ?? null,
      diastolic2:          row.BP2D ?? null,
      pulse2:              row.HR2  ?? null,
      systolic3:           row.BP3S ?? null,
      diastolic3:          row.BP3D ?? null,
      pulse3:              row.HR3  ?? null,
    };
  });

  // BP can have multiple visits per person → use reg_no + date as doc ID
  await batchWrite('health_readings', docs, d =>
    d.Registration_Number
      ? `bp_${d.Registration_Number}_${(d.Date_of_Interview || 'nodate').replace(/-/g, '')}`
      : null
  );
}

// ─── Refusal → refused_form ──────────────────────────────────────────────────
async function importRefusal(regMap) {
  console.log('\n📂 REFUSAL.xlsx → refused_form');
  const wb = XLSX.readFile('./REFUSAL.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`   ${data.length} rows`);

  const docs = data.map(row => {
    const m = regMap[row.REGNO] || {};
    return {
      Registration_Number:               row.REGNO !== undefined ? String(row.REGNO) : null,
      Family_code:                       m.Family_Code || null,
      Name:                              m.Name || null,
      Gender:                            m.Gender || null,
      Age:                               m.Age !== undefined ? String(m.Age) : null,
      Date_of_Interview:                 parseDateField(row.CREATED_DT),
      Interviewer_s_Name:                row.INTNAME ? String(row.INTNAME).trim() : null,
      Respondent:                        row.RESP ? String(row.RESP).trim() : null,
      Reason_for_withdrawing_from_study: REASON_MAP[row.REASON] ?? null,
      Death_Date:                        parseDateField(row.DIED_DT),
      other_reasons_specified:           row.REASON_SPY ? String(row.REASON_SPY).trim() : null,
    };
  });

  await batchWrite('refused_form', docs, d =>
    d.Registration_Number ? `refused_${d.Registration_Number}` : null
  );
}

// ─── QUESTIONNAIRE → questionnaire ──────────────────────────────────────────
async function importQuestionnaire(regMap) {
  console.log('\n📂 QUESTIONNAIRE.xlsx → questionnaire');
  const wb = XLSX.readFile('./QUESTIONNAIRE.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`   ${data.length} rows`);

  const GEN_HEALTH_MAP = { 1: '(1) Excellent', 2: '(2) Good', 3: '(3) Fair', 4: '(4) Poor' };

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
}

// ─── TB → tb_questionnaire ───────────────────────────────────────────────────
async function importTB(regMap) {
  console.log('\n📂 TB.xlsx → tb_questionnaire');
  const wb = XLSX.readFile('./TB.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`   ${data.length} rows`);

  const docs = data.map(row => {
    const m = regMap[row.REGNO] || {};
    return {
      Registration_Number: row.REGNO !== undefined ? String(row.REGNO) : null,
      Family_code:         m.Family_Code || null,
      Name:                m.Name || null,
      Gender:              m.Gender || null,
      Age:                 m.Age !== undefined ? String(m.Age) : null,
      Date_of_Interview:   excelSerialToISO(row.INTDT),
      Interviewer_s_Name:  row.INTNAME ? String(row.INTNAME).trim() : null,

      Have_you_had_a_cough_for_more_than_2_weeks:                    yn(row.COUGH),
      Haemoptysis_coughing_up_blood:                                  yn(row.HAEMOPTYSIS),
      Have_you_had_a_fever_for_more_than_2_weeks:                    yn(row.FEVER),
      Do_you_feel_like_you_have_lost_weight:                         yn(row.LOST_WT),
      Are_you_experiencing_excessive_sweating_at_night_Night_sweats: yn(row.NODE_SWELLING),
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

  await batchWrite('tb_questionnaire', docs, d =>
    d.Registration_Number ? `tb_${d.Registration_Number}` : null
  );
}

// ─── FBS → blood_sugar_fasting ───────────────────────────────────────────────
async function importFBS(regMap) {
  console.log('\n📂 FBS.xlsx → blood_sugar_fasting');
  const wb = XLSX.readFile('./FBS.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`   ${data.length} rows`);

  const docs = data.map(row => {
    const m = regMap[row.Regno] || {};
    return {
      Registration_Number: row.Regno !== undefined ? String(row.Regno) : null,
      Family_code:         m.Family_Code || null,
      Name:                m.Name || null,
      Gender:              m.Gender || null,
      Age:                 m.Age !== undefined ? String(m.Age) : null,
      Date_of_Interview:   excelSerialToISO(row.INTDT),
      Interviewer_s_Name:  row.INTNAME ? String(row.INTNAME).trim() : null,
      Date_of_Last_Meal:   excelSerialToDMY(row.FOODDT),
      Time_of_Last_Meal:   row.FOODTIME ? String(row.FOODTIME).trim() : null,
      FBS_Test_Result:     row.SUGARREAD !== undefined ? row.SUGARREAD : null,
    };
  });

  await batchWrite('blood_sugar_fasting', docs, d =>
    d.Registration_Number ? `fbs_${d.Registration_Number}` : null
  );
}

// ─── SAMP → blood_sample_status ─────────────────────────────────────────────
async function importSamp(regMap) {
  console.log('\n📂 SAMP.xlsx → blood_sample_status');
  const wb = XLSX.readFile('./SAMP.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`   ${data.length} rows`);

  const docs = data.map(row => {
    const m = regMap[row.REGNO] || {};
    return {
      Registration_Number:      row.REGNO !== undefined ? String(row.REGNO) : null,
      Family_code:              m.Family_Code || null,
      Name:                     m.Name || null,
      Gender:                   m.Gender || null,
      Age:                      m.Age !== undefined ? String(m.Age) : null,
      Date_of_Interview:        excelSerialToISO(row.INTDT),
      Interviewer_s_Name:       row.INTNAME ? String(row.INTNAME).trim() : null,
      Collect_Blood_Sample:     collected(row.CBP),
      Collect_HBA1C:            collected(row.HBA1C),
      Collect_Thyroid:          collected(row.THYROID),
      Collect_CRE:              collected(row.CRE),
      Collect_Sputum_TB:        collected(row.SPUTUM),
      Collect_Vaginal_Swab_HPV: collected(row.VS),
      Collect_Urine:            collected(row.URINE),
      Date_CBP:                 excelSerialToISO(row.DTCBP),
      Date_HBA1C:               excelSerialToISO(row.DTHBA1C),
      Date_Thyroid:             excelSerialToISO(row.DTTHYROID),
      Date_CRE:                 excelSerialToISO(row.DTCRE),
      Date_Sputum_TB:           excelSerialToISO(row.DTSPUTUM),
      Date_Vaginal_Swab_HPV:    excelSerialToISO(row.DTVS),
      Date_Urine:               excelSerialToISO(row.DTURINE),
    };
  });

  await batchWrite('blood_sample_status', docs, d =>
    d.Registration_Number ? `samp_${d.Registration_Number}` : null
  );
}

// ─── CC → cervical_screening ─────────────────────────────────────────────────
async function importCC(regMap) {
  console.log('\n📂 CC.xlsx → cervical_screening');
  const wb = XLSX.readFile('./CC.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`   ${data.length} rows`);

  const docs = data.map(row => {
    const m = regMap[row.REGNO] || {};
    const intName = row.INTNAME ? String(row.INTNAME).trim() : '';
    const intParts = intName.split(/\s+/);
    const ageVal = row.AGE !== undefined ? String(row.AGE) : null;

    return {
      Registration_Number:                        row.REGNO !== undefined ? String(row.REGNO) : null,
      Family_ID:                                  m.Family_Code || null,
      Name:                                       m.Name || null,
      Gender:                                     m.Gender || null,
      Age:                                        ageVal,
      Age1:                                       ageVal,
      Exam_Date:                                  excelSerialToISO(row.INTDT),
      Interviewer_s_Name_first_name:              intParts[0] || null,
      Interviewer_s_Name_last_name:               intParts.length > 1 ? intParts.slice(1).join(' ') : null,
      Date_of_Birth:                              parseDob(row.DOB),
      Have_you_attended_school:                   row.SCH_GO === 1 ? 'Yes' : (row.SCH_GO === 2 ? 'No' : null),
      If_Yes_What_was_the_highest_level_attended: row.EDU_LEV ? String(row.EDU_LEV).trim() : null,
      Occupation:                                 row.OCCU ? String(row.OCCU).trim() : null,
      Religion:                                   REL_MAP[row.REL] ?? null,
      Monthly_Household_Income:                   row.INCOME ?? null,
      Total_Number_of_household_living_at_home:   row.PER_H ?? null,
      Marital_status:                             M_STATUS_MAP[row.M_STATUS] ?? null,
      Menopause_Status:                           row.STILL_MENSTRUATING === 1 ? '(1) Still Menstruating' : (row.STILL_MENSTRUATING === 2 ? '(2) Menopause' : null),
      VIA_Examination_Result:                     row.VS === 1 ? '(1) VIA Positive' : (row.VS === 2 ? '(2) VIA Negative' : null),
      Treatment_Provided:                         row.TREAT_DONE === 1 ? '(1) Treatment Done' : (row.TREAT_DONE === 2 ? '(2) Not Done' : null),
    };
  });

  await batchWrite('cervical_screening', docs, d =>
    d.Registration_Number ? `cc_${d.Registration_Number}` : null
  );
}

// ─── Family Planning → family_planning ───────────────────────────────────────
async function importFamilyPlanning(regMap) {
  console.log('\n📂 PARENTS.xlsx → family_planning');
  const wb = XLSX.readFile('./PARENTS.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
  console.log(`   ${data.length} rows`);

  const docs = data.map(row => {
    const mother = regMap[row.MOTHER] || {};
    const father = regMap[row.FATHER] || {};
    const isPermanent = row.METHOD_TYPE === 1;
    const isTemporary = row.METHOD_TYPE === 0;

    return {
      Family_Code:                  String(row.FAMILY_CODE || '').trim().toUpperCase() || mother.Family_Code || null,
      Registration_Number:          row.MOTHER !== undefined ? String(row.MOTHER) : null,
      Name:                         mother.Name || null,
      Husband_Name:                 father.Name || null,
      Select_Entry_Screen:          isPermanent ? '(1) Permanent' : (isTemporary ? '(0) Temporary' : null),
      Used:                         isPermanent ? (PERM_USED_MAP[row.METHOD_USED] ?? null) : null,
      Date_field1:                  isPermanent ? excelSerialToISO(row.FP_DATE) : null,
      Place:                        (isPermanent || isTemporary) ? (PLACE_MAP[row.FP_PLACE] ?? null) : null,
      Remarks:                      row.REMARKS ? String(row.REMARKS).trim() : null,
      Used_oral_contraceptives:     isTemporary ? yn(row.CC_USE_ORAL_CON) : null,
      How_long_use_oral1:           isTemporary && row.CC_LONG_USE_ORAL_CON !== undefined ? String(row.CC_LONG_USE_ORAL_CON) : null,
      Date_field2:                  isTemporary ? excelSerialToISO(row.FP_DATE) : null,
    };
  });

  await batchWrite('family_planning', docs, d =>
    d.Registration_Number ? `fp_${d.Registration_Number}` : null
  );
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function run() {
  console.log('📂 Reading RELATIONS.xlsx...');
  const relWb = XLSX.readFile('./RELATIONS.xlsx');
  const relRows = XLSX.utils.sheet_to_json(relWb.Sheets[relWb.SheetNames[0]]);
  const regMap = {};
  for (const r of relRows) {
    if (r.REL_REG_NO !== undefined) {
      regMap[r.REL_REG_NO] = {
        Name:                String(r.REL_NAME || '').trim(),
        Family_Code:         String(r.REL_DUP_CODE || '').trim().toUpperCase(),
        Gender:              GENDER_MAP[r.REL_SEX] ?? null,
        Age:                 calcAge(r.REL_DOB),
        Registration_Number: String(r.REL_REG_NO),
      };
    }
  }
  console.log(`✅ RELATIONS loaded: ${Object.keys(regMap).length} entries`);

  await importBP(regMap);
  await importRefusal(regMap);
  await importTB(regMap);
  await importFBS(regMap);
  await importSamp(regMap);
  await importCC(regMap);
  await importFamilyPlanning(regMap);
  await importQuestionnaire(regMap);

  console.log('\n🎉 All done! All historical data is now in Firestore.');
}

run().catch(console.error);
