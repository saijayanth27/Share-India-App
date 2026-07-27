const admin = require('firebase-admin');
const XLSX = require('xlsx');

const serviceAccount = require('./share-india-d9717-firebase-adminsdk-fbsvc-ebe7273a5e.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// ─── Value maps ──────────────────────────────────────────────────────────────
const GENDER_MAP  = { 0: '(0) Female', 1: '(1) Male' };
const EDUC_MAP    = { 0: '(0) ILLITIRATE', 1: '(1) CAN READ ONLY', 2: '(2) CAN READ AND WRITE', 3: '(3) PRIMARY SCHOOL', 4: '(4) MIDDLE SCHOOL', 5: '(5) HIGH SCHOOL', 6: '(6) GRADUATE', 7: '(7) POST GRADUATE' };
const OCCU_MAP    = { 1: '(1) HOUSE WIFE', 2: '(2) AGRICULTURE', 3: '(3) UNEMPLOYED', 4: '(4) LABOUR', 5: '(5) SELF-EMPLOYED', 6: '(6) PRIVATE EMPLOYEE', 7: '(7) ANGANWADI TEACHER', 8: '(8) C.H.V', 9: '(9) PENSION', 10: '(10) GOVT EMPLOYEE', 99: '(99) DONT KNOW' };
const MSTATUS_MAP = { 1: '(0) Unmarried', 2: '(1) Married', 3: '(2) Widowed', 4: '(3) Divorced' };
const RELIGION_MAP = { 1: 'Hindu', 2: 'Muslim', 3: 'Christian', 5: 'Others', 6: 'Others' };
const FAM_TYPE_MAP = { 1: '(1) Nuclear', 2: '(2) Joint', 3: '(3) Extended' };
const DEATH_PLACE_MAP = { 0: '(0) RHC', 1: '(1) PVT', 2: '(2) GOVT', 3: '(3) HOME' };

// Yes/No: 1 → "(1) Yes", 2 → "(2) No", null → null
function yn(val) {
  if (val === 1) return '(1) Yes';
  if (val === 2) return '(2) No';
  return null;
}

// ─── Full REL_TYPE → Relation_with_Head mapping ───────────────────────────────
const REL_TYPE_MAP = {
  // Head
  'H':    'HEAD OF THE FAMILY',
  'HP':   'HEAD OF THE FAMILY',
  'H ':   'HEAD OF THE FAMILY',
  // Wife / Husband
  'W':    'WIFE',
  'SP':   'WIFE',
  'HH':   'HUSBAND',
  // Direct children
  'S':    'SON',
  'S ':   'SON',
  'D':    'DAUGHTER',
  // Son's spouse / Daughter's spouse
  'SW':   'DAUGHTER-IN-LAW',   // Son's Wife
  'DH':   'SON-IN-LAW',        // Daughter's Husband
  // Grandchildren via son
  'SS':   'GRAND-SON(S)',
  'SD':   'GRAND-DAUGHTER(S)',
  'SSW':  'GRAND-DAUGHTER-IN-LAW',
  'SDH':  'GRAND DAUGHTER HUSBAND(S)',
  'SSS':  'BROTHERS SONS SON',
  'SSD':  'GREAT GRAND DAUGHTER (SS)',
  'SDS':  'GRAND-SON (D)',
  'SDD':  'GRAND-DAUGHTER (D)',
  // Grandchildren via daughter
  'DS':   'GRAND-SON (D)',
  'DD':   'GRAND-DAUGHTER (D)',
  'DSW':  'GRAND-DAUGHTER-IN-LAW (S)',
  'DDH':  'GRAND DAUGHTER HUSBAND(D)',
  // Great-grandchildren
  'DSS':  'GREAT-GRAND-SON(DS)',
  'DSD':  'GREAT-GRAND-DAUGTHER(DS)',
  'DDS':  'GREAT GRAND SON (DD)',
  'DDD':  'GREAT GRAND DAUGHTER (DD)',
  'DDA':  'GREAT GRAND DAUGHTER (DD)',
  // Brother's family
  'B':    'BROTHER',
  'BW':   'SISTER-IN-LAW(BW)',  // Brother's Wife
  'BS':   'BROTHER SON',
  'BD':   'BROTHER DAUGHTER',
  'BSW':  'BROTHERS SON WIFE',
  'BDH':  'BROTHERS DAUGHTER HUSBAND',
  'BSS':  'BROTHERS SONS SON',
  'BSD':  'BROTHERS SONS DAUGHTER',
  'BDD':  'BROTHER-DAUGHTER-DAUGHTER(DD)',
  'BDS':  'BROTHER-DAUGHTER-SON(DS)',
  'BH':   'BROTHER-IN-LAW',
  // Sister's family
  'SI':   'SISTER',
  'HS':   'SISTER',
  'HSH':  'BROTHER-IN-LAW',       // Sister's Husband
  'HSW':  'SISTER-IN-LAW (U)',    // Sister's co-wife / relative
  // Wife's family
  'WB':   'WIFE BROTHER',
  'WBW':  'WIFE BROTHERS WIFE',
  'WBS':  'WIFE BROTHERS SON',
  'WBD':  'WIFE BROTHERS DAUGHTER',
  'WP':   'WIFE PARENT',
  'WR':   'WIFE RELATIONS',
  'WRD':  'WIFE RELATIONS',
  // In-laws
  'FI':   'FATHER-IN-LAW',
  'MI':   'MOTHERS-IN-LAW',
  'I':    'OTHERS',
  'IH':   'OTHERS',
  'IS':   'OTHERS',
  'ID':   'OTHERS',
  'ISS':  'OTHERS',
  'ISD':  'OTHERS',
  'IDH':  'OTHERS',
  'ISW':  'OTHERS',
  // Head's relatives
  'HB':   'BROTHER',
  'HU':   'UNCLE',
  'HBP':  'PARENT',
  'HGBP': 'GREAT GRAND PARENT',
  'GHP':  'GRAND PARENT',
  // Parents
  'FP':   'PARENT',
  'MP':   'MOTHER RELATIONS',
  'MR':   'MOTHER RELATIONS',
  // Adopted
  'SA':   'ADOPTED SON',
  'DA':   'ADOPTED DAUGHTER',
  'GDA':  'ADOPTED GRAND DAUGHTER',
  'AGS':  'ADOPTED GRAND SON',
  'AGGD': 'ADOPTED GREAT GRAND DAUGHTER',
  'ASD':  'GREAT GRAND DAUGHTER (ASD)',
  // Misc
  'UN':   'UNCLE',
  'AN':   'AUNTY',
  'O':    'OTHERS',
  'R':    'OTHERS',
  'r':    'OTHERS',
};

// ─── Village code → village name ──────────────────────────────────────────────
const VILLAGE_MAP = {
  YP: 'Yellampet',       YA: 'Yadaram',          SZ: 'Shazadiguda',
  SR: 'Srirangavaram',   SM: 'Somaram',           SG: 'Suthariguda',
  RV: 'Ravalkole',       RT: 'Ravalkole Thanda',  RP: 'Railapur',
  RB: 'Rajbollaram',     RA: 'Rajbollaram Thanda',PU: 'Pudur',
  NU: 'Nuthankol',       MU: 'Muneerabad',        MR: 'Maisereddypally',
  MP: 'Muraharipally',   MG: 'Maisamma Gudam',    MD: 'MediCiti',
  LT: 'Lethamamidi Thanda', LP: 'Lingapur',       KT: 'Kasimbai Thanda',
  KP: 'Konahipally',     KK: 'Kandla Koyya',      KI: 'Kistapur',
  GY: 'Gyanapur',        GT: 'Gubbari Thanda',    GS: 'Gosaiguda',
  GR: 'Girmapur',        GP: 'Gundla Pochampally',GN: 'Ghanpur',
  GG: 'Ghanpur Thanda',  GD: 'Gowdavelly',        GA: 'Guddamgadda Thanda',
  DP: 'Dabilpur',        DG: 'Dongalgutta Thanda', BS: 'Basaragadi',
  BM: 'Bandamadaram',    BG: 'Barmajigudam',      AK: 'Akberjapet',
  AG: 'Arkalaguda',      AT: 'Athvelly',
};

function decodeLocation(familyCode) {
  if (!familyCode || familyCode.length < 9) return { state: null, district: null, mandal: null, village: null };
  const upper = familyCode.toUpperCase();
  if (!upper.startsWith('TSRRMED')) return { state: null, district: null, mandal: null, village: null };
  const villageCode = upper.slice(7, 9);
  return {
    state:    'Telangana',
    district: 'Medchal-Malkajgiri',
    mandal:   'Medchal',
    village:  VILLAGE_MAP[villageCode] || null,
  };
}

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

async function deleteCollection(collectionName) {
  console.log(`🗑️  Deleting '${collectionName}'...`);
  let deleted = 0;
  while (true) {
    const snapshot = await db.collection(collectionName).limit(500).get();
    if (snapshot.empty) break;
    const batch = db.batch();
    snapshot.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snapshot.docs.length;
    process.stdout.write(`   deleted ${deleted}...\r`);
  }
  console.log(`✅ Deleted '${collectionName}' — ${deleted} docs\n`);
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

// ─── RELATIONS → personal_details ────────────────────────────────────────────
async function importPersonalDetails() {
  console.log('\n📂 RELATIONS.xlsx → personal_details');
  // defval: null ensures ALL columns appear in every row object
  const wb = XLSX.readFile('./RELATIONS.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { defval: null });
  console.log(`   ${data.length} rows`);

  // Build reg_no → name lookup for Father_Name / Mother_Name resolution
  const regNoToName = {};
  for (const row of data) {
    if (row.REL_REG_NO !== null && row.REL_REG_NO !== undefined) {
      regNoToName[row.REL_REG_NO] = String(row.REL_NAME || '').trim();
    }
  }
  console.log(`   Name lookup: ${Object.keys(regNoToName).length} entries`);

  const docs = data.map(row => {
    const famCode = String(row.REL_DUP_CODE || '').trim().toUpperCase();
    const relTypeRaw = row.REL_TYPE !== null ? String(row.REL_TYPE).trim() : '';
    const fatherName = (row.FATHER_ID && row.FATHER_ID !== 0) ? (regNoToName[row.FATHER_ID] || null) : null;
    const motherName = (row.MOTHER_ID && row.MOTHER_ID !== 0) ? (regNoToName[row.MOTHER_ID] || null) : null;

    return {
      // ── Identity ──
      Family_Code:              famCode || null,
      uniq_Registration_Number: row.REL_REG_NO,
      Name:                     String(row.REL_NAME || '').trim() || null,
      Telugu_Name:              row.REL_TNAME ? String(row.REL_TNAME).trim() : null,
      Gender:                   GENDER_MAP[row.REL_SEX] ?? null,
      SI_No:                    row.REL_SNO,
      Map_No:                   row.MAPNO !== null ? row.MAPNO : null,
      Aadhar_No1:               row.AADHAR ? String(row.AADHAR).trim() : null,

      // ── Personal Info ──
      Date_of_Birth:            excelSerialToISO(row.REL_DOB),
      Age:                      calcAge(row.REL_DOB),
      Marital_Status:           MSTATUS_MAP[row.REL_MSTATUS] ?? null,
      Education:                EDUC_MAP[row.REL_EDUC] ?? null,
      Live_Status:              row.REL_LIVE_ST === 1 ? '(1) Alive' : (row.REL_LIVE_ST === 0 ? '(0) Dead' : null),
      A_v_Status:               row.REL_ACTIVE_STA === 1 ? '(1) Active' : (row.REL_ACTIVE_STA === 0 ? '(0) Vacant' : null),
      Occupation:               OCCU_MAP[row.REL_OCCU] ?? null,
      Income:                   row.REL_INCOME !== null ? String(row.REL_INCOME) : null,

      // ── Death Details ──
      Death_Date:               excelSerialToDMY(row.EXPR_DT),
      Death_Place:              DEATH_PLACE_MAP[row.EXPR_AT] ?? null,
      Death_Cause:              row.DEATH_CAUSE ? String(row.DEATH_CAUSE).trim() : null,

      // ── Relations ──
      Relation_with_Head:       REL_TYPE_MAP[relTypeRaw] || (relTypeRaw || null),
      Father_Name:              fatherName,
      Mother_Name:              motherName,
      Father_Registration_Number: (row.FATHER_ID && row.FATHER_ID !== 0) ? row.FATHER_ID : null,
      Parents_ID:               (row.PARENTS_ID && row.PARENTS_ID !== 0) ? String(row.PARENTS_ID) : null,

      // ── Health Status (1 = Yes, 2 = No) ──
      Asthma:                   yn(row.ASTHMA),
      Diabetes:                 yn(row.DIABETES),
      Hypertensive:             yn(row.HTN),
      Thyroid:                  yn(row.THYROID),
      Malaria_last_6m:          yn(row.MALARIA),
      jaundice_last_6m:         yn(row.JAUNDICE),
      Panmasala_currently:      yn(row.PANMASALA),
      Drink_alcohol_currently:  yn(row.ALCOHOL),
      Smoke_currently:          yn(row.SMOKE),
      Diabetes_Duration:        row.DIA_LONG ? String(row.DIA_LONG).trim() : null,
      HTN_Duration:             row.HTN_LONG ? String(row.HTN_LONG).trim() : null,

      // ── Flags ──
      CC_Flag:                  row.CC_FLAG ? String(row.CC_FLAG).trim() : null,
      Flag2:                    row.FLAG2 ? String(row.FLAG2).trim() : null,
    };
  });

  await batchWrite('personal_details', docs, d =>
    d.uniq_Registration_Number !== null ? `member_${d.uniq_Registration_Number}` : null
  );
}

// ─── Value maps for Family Code Creation ─────────────────────────────────────
const HOUSE_TYPE_MAP  = { 1: '(1) PUCCA', 2: '(2) SEMI PUCCA', 3: '(3) KACHHA' };
const LIGHTING_MAP    = { 1: '(1) Electricity', 2: '(2) Kerosene/Solar', 3: '(3) Oil', 4: '(4) Gas' };
const TOILET_MAP      = { 1: '(1) Flush Toilet', 2: '(2) Toilet ST', 3: '(3) Pit toilet', 4: '(4) Open Field', 77: '(77) Other' };
const RCARD_MAP       = { 1: '(1) White card', 2: '(2) Pink Card', 3: '(3) No card' };
const CASTE_MAP       = { 1: '(1) SC', 2: '(2) ST', 3: '(3) BC', 4: '(4) FC', 77: '(77) Other' };
const RELIGION2_MAP   = { 1: '(1) Hindu', 2: '(2) Muslim', 3: '(3) Christian', 5: '(77) Other', 6: '(77) Other' };
const COOK_LOC_MAP    = { 1: '(1) Inside (separate room)', 2: '(2) Inside (same room)', 3: '(3) Outside covered', 4: '(4) Outside open', 77: '(77) Other' };
const FUEL_MAIN_MAP   = { 1: '(1) Electricity', 2: '(2) LPG/N.GAS', 3: '(3) Kerosene', 4: '(4) Wood', 5: '(5) Coal', 6: '(6) Crop Residues', 7: '(7) Dung Cakes', 77: '(77) Other' };
const WATER_MAIN_MAP  = { 1: '(1) Piped water', 2: '(2) Bore Well', 3: '(3) Dug Well', 4: '(4) Surface water', 5: '(5) Tanker/truck', 6: '(6) Bottled water', 7: '(77) Other' };
const HEALTH_PLACE_MAP = { 1: '(1) PHC/CHC', 2: '(2) Govt Hospital', 3: '(3) Private Clinic', 4: '(4) Private Hospital', 5: '(5) None', 77: '(77) Other' };
const FAMILY_STATUS_MAP = { 1: '(1) Active', 0: '(0) Vacant' };

function flag(val) { return val === 1 ? '1' : null; }

// ─── FAMILY_DETAILS → Family Code Creation ───────────────────────────────────
async function importFamilyCodeCreation() {
  console.log('\n📂 FAMILY_DETAILS.xlsx → Family Code Creation');
  const wb = XLSX.readFile('./FAMILY_DETAILS.xlsx');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { defval: null });
  console.log(`   ${data.length} rows`);

  const docs = data.map(row => {
    const famId = String(row.FAM_ID_OLD || '').trim().toUpperCase() || String(row.FAM_ID || '').trim().toUpperCase();
    const loc = decodeLocation(famId);

    // ── Cooking fuel types (multi-select array) ──
    const cookingFuelTypes = [];
    if (row.TYPCOOKFUEL_ELEC === 1)   cookingFuelTypes.push('(1) Electricity');
    if (row.TYPCOOKFUEL_LPG === 1)    cookingFuelTypes.push('(2) LPG/N.GAS');
    if (row.TYPCOOKFUEL_KER === 1)    cookingFuelTypes.push('(3) Kerosene');
    if (row.TYPCOOKFUEL_WOOD === 1)   cookingFuelTypes.push('(4) Wood');
    if (row.TYPCOOKFUEL_COAL === 1)   cookingFuelTypes.push('(5) Coal');
    if (row.TYPCOOKFUEL_CROP === 1)   cookingFuelTypes.push('(6) Crop Residues');
    if (row.TYPCOOKFUEL_DCAKES === 1) cookingFuelTypes.push('(7) Dung Cakes');
    if (row.TYPCOOKFUEL_OTH === 1)    cookingFuelTypes.push('(77) Other');

    // ── Drinking water sources ──
    const waterSources = [];
    if (row.PIPEDWATER === 1)       waterSources.push('(1) Piped water');
    if (row.BOREWELL === 1)         waterSources.push('(2) Bore Well');
    if (row.DUGWELL === 1)          waterSources.push('(3) Dug Well');
    if (row.SURFACEWATER === 1)     waterSources.push('(4) Surface water');
    if (row.TANKER === 1)           waterSources.push('(5) Tanker/truck');
    if (row.BOTTLEDWATER === 1)     waterSources.push('(6) Bottled water');
    if (row.SOURCE_WATER_OTH === 1) waterSources.push('(77) Other');

    // ── All-purpose water sources ──
    const waterAllSources = [];
    if (row.PIPEDWATER31 === 1)       waterAllSources.push('(1) Piped water');
    if (row.BOREWELL31 === 1)         waterAllSources.push('(2) Bore Well');
    if (row.DUGWELL31 === 1)          waterAllSources.push('(3) Dug Well');
    if (row.SURFACEWATER31 === 1)     waterAllSources.push('(4) Surface water');
    if (row.TANKER31 === 1)           waterAllSources.push('(5) Tanker/truck');
    if (row.BOTTLEDWATER31 === 1)     waterAllSources.push('(6) Bottled water');
    if (row.SOURCE_WATER_OTH31 === 1) waterAllSources.push('(77) Other');

    // ── Water treatment ──
    const waterTreatment = [];
    if (row.SAFER_BOIL === 1)          waterTreatment.push('(1) Boil');
    if (row.SAFER_BLEACH === 1)        waterTreatment.push('(2) Add bleach');
    if (row.SAFER_CLOTH === 1)         waterTreatment.push('(3) strain by cloth');
    if (row.SAFER_WATER_FILTER === 1)  waterTreatment.push('(4) Use water filter');
    if (row.SAFER_ELE_PURIFIER === 1)  waterTreatment.push('(5) use electronic purifier');
    if (row.SAFER_SETTLE === 1)        waterTreatment.push('(6) stand and settle');
    if (row.SAFER_NONE_DK === 1)       waterTreatment.push('(7) None');

    // ── Household assets ──
    const householdAssets = [];
    if (row.TV === 1)             householdAssets.push('Colour TV');
    if (row.REFRIGERATOR === 1)   householdAssets.push('Refrigerator');
    if (row.MOBILE === 1)         householdAssets.push('Mobile phone');
    if (row.ANY_PHONE === 1)      householdAssets.push('Any phone');
    if (row.CAR === 1)            householdAssets.push('Car');
    if (row.BICYCLE === 1)        householdAssets.push('Bicycle');
    if (row.SCOOTER === 1)        householdAssets.push('Scooter');
    if (row.ELE_FAN === 1)        householdAssets.push('Electric Fan');
    if (row.RADIO === 1)          householdAssets.push('Radio');
    if (row.MIXER === 1)          householdAssets.push('Mixer');
    if (row.PRESSUR_COOKER === 1) householdAssets.push('Pressure cooker');
    if (row.MATTRESS === 1)       householdAssets.push('Mattress');
    if (row.COT === 1)            householdAssets.push('Cot/bed');
    if (row.SEWING_MACH === 1)    householdAssets.push('Sewing machine');
    if (row.WATER_PUMP === 1)     householdAssets.push('Water pump');
    if (row.COMPUTER === 1)       householdAssets.push('Computer');
    if (row.TRACTOR === 1)        householdAssets.push('Tractor');
    if (row.THRESHER === 1)       householdAssets.push('Thresher');
    if (row.CART === 1)           householdAssets.push('Cart');
    if (row.CHAIR === 1)          householdAssets.push('Chair');
    if (row.TABLE1 === 1)         householdAssets.push('Table');

    // ── Cattle owned ──
    const cattleOwned = [];
    if (row.CATTLE_COWS)    cattleOwned.push(`Cows: ${row.CATTLE_COWS}`);
    if (row.CATTLE_BULLS)   cattleOwned.push(`Bulls: ${row.CATTLE_BULLS}`);
    if (row.CATTLE_GOATS)   cattleOwned.push(`Goats: ${row.CATTLE_GOATS}`);
    if (row.CATTLE_POULTRY) cattleOwned.push(`Poultry: ${row.CATTLE_POULTRY}`);
    if (row.CATTLE_OTH === 1 && row.CATTLE_OTH_SPY) cattleOwned.push(`Other: ${row.CATTLE_OTH_SPY}`);

    // ── Govt hospital reasons ──
    const govtHospitalReasons = [];
    if (row.WHY_NOT_GOVT_1 === 1) govtHospitalReasons.push('(1) Far away');
    if (row.WHY_NOT_GOVT_2 === 1) govtHospitalReasons.push('(2) Cost');
    if (row.WHY_NOT_GOVT_3 === 1) govtHospitalReasons.push('(3) Poor quality');
    if (row.WHY_NOT_GOVT_4 === 1) govtHospitalReasons.push('(4) Long wait');
    if (row.WHY_NOT_GOVT_5 === 1) govtHospitalReasons.push('(5) Not available');

    return {
      // ── Identity & Location ──
      family_id:          famId || null,
      Family_Code:        famId || null,
      house_no:           row.HNO !== null ? String(row.HNO).trim() : null,
      state:              loc.state,
      district:           loc.district,
      mandal:             loc.mandal,
      village:            loc.village,

      // ── Family Info ──
      family_type:        FAM_TYPE_MAP[row.FAM_TYPE] ?? null,
      family_status:      FAMILY_STATUS_MAP[row.ACTIVE_ST] ?? null,
      religion:           RELIGION2_MAP[row.RELIGION] ?? null,
      religion_other:     row.OTH_RELIGION ? String(row.OTH_RELIGION).trim() : null,
      caste:              CASTE_MAP[row.CASTE] ?? null,
      caste_other:        row.OTH_CASTE ? String(row.OTH_CASTE).trim() : null,
      ration_card:        RCARD_MAP[row.RCARD] ?? null,

      // ── House ──
      own_house:          row.OWNHOUSE === 1 ? '(1) Yes' : (row.OWNHOUSE === 2 ? '(2) No' : null),
      no_of_rooms:        row.NOROOMS !== null ? row.NOROOMS : null,
      type_of_house:      HOUSE_TYPE_MAP[row.TYPHOUSE] ?? null,
      roof_type:          HOUSE_TYPE_MAP[row.ROOF] ?? null,
      wall_type:          HOUSE_TYPE_MAP[row.WALL] ?? null,
      floor_type:         HOUSE_TYPE_MAP[row.FLOOR] ?? null,

      // ── Cooking ──
      cooking_location:       COOK_LOC_MAP[row.KPLACE] ?? null,
      cooking_location_other: row.KPLACE_OTH ? String(row.KPLACE_OTH).trim() : null,
      separate_kitchen:       row.SEPROOMK === 1 ? '(1) Yes' : (row.SEPROOMK === 2 ? '(2) No' : null),
      cooking_fuel_types:     cookingFuelTypes.length > 0 ? cookingFuelTypes : null,
      cooking_fuel_other:     row.TYPCOOKFUEL_SPY ? String(row.TYPCOOKFUEL_SPY).trim() : null,
      cooking_fuel_main:      FUEL_MAIN_MAP[row.TYPCOOKFUEL_MAIN] ?? null,

      // ── Lighting ──
      lighting_source:        LIGHTING_MAP[row.SOURCE_LIG] ?? null,
      lighting_source_other:  row.SOURCE_LIG_SPY ? String(row.SOURCE_LIG_SPY).trim() : null,

      // ── Water ──
      water_sources:          waterSources.length > 0 ? waterSources : null,
      water_source_other:     row.SOURCE_WATER_SPY ? String(row.SOURCE_WATER_SPY).trim() : null,
      water_main_source:      WATER_MAIN_MAP[row.MAINLY_USE_DRINK] ?? null,
      water_treatment:        waterTreatment.length > 0 ? waterTreatment : null,
      water_treatment_other:  row.SAFE_DRINK_SPY ? String(row.SAFE_DRINK_SPY).trim() : null,
      water_all_sources:      waterAllSources.length > 0 ? waterAllSources : null,
      water_all_other:        row.SOURCE_WATER_SPY31 ? String(row.SOURCE_WATER_SPY31).trim() : null,
      water_all_main:         WATER_MAIN_MAP[row.MAINLY_USE_ALL] ?? null,

      // ── Sanitation ──
      toilet_facility:        TOILET_MAP[row.TOILET] ?? null,
      toilet_facility_other:  row.TOILET_SPY ? String(row.TOILET_SPY).trim() : null,

      // ── Assets ──
      household_assets:       householdAssets.length > 0 ? householdAssets : null,

      // ── Agriculture ──
      agriculture_land:       row.AGRI_LAND === 1 ? '(1) Yes' : (row.AGRI_LAND === 2 ? '(2) No' : null),
      agri_land_area:         row.AGRI_LAND_SPY ? String(row.AGRI_LAND_SPY).trim() : null,
      agri_land_unit:         row.AGRI_LAND_SPY_AG ? String(row.AGRI_LAND_SPY_AG).trim() : null,
      agri_land_irrigated:    row.AGRI_LAND_IRR_SPY ? String(row.AGRI_LAND_IRR_SPY).trim() : null,

      // ── Cattle ──
      owns_cattle:            row.CATTLE_NONE === 1 ? '(2) No' : (cattleOwned.length > 0 ? '(1) Yes' : null),
      cattle_owned:           cattleOwned.length > 0 ? cattleOwned : null,

      // ── Health Care ──
      health_care_place:      HEALTH_PLACE_MAP[row.GET_SICK] ?? null,
      health_care_other:      row.GET_SICK_OTH ? String(row.GET_SICK_OTH).trim() : null,
      govt_hospital_reasons:  govtHospitalReasons.length > 0 ? govtHospitalReasons : null,
      govt_hospital_other:    row.WHY_NOT_GOVT_SPY ? String(row.WHY_NOT_GOVT_SPY).trim() : null,
    };
  });

  await batchWrite('Family Code Creation', docs, d =>
    d.family_id ? d.family_id : null
  );
}

async function run() {
  // No deletion — merge: true patches existing docs without extra cost
  await importPersonalDetails();
  await importFamilyCodeCreation();

  console.log('\n🎉 Done!');
}

run().catch(console.error);
