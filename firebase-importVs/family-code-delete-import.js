/**
 * Deletes all documents in 'Family Code Creation' and re-imports from Excel
 * with standard keys that match what the Flutter app saves.
 *
 * Keys used are the EXACT same keys the app saves at main.dart:927.
 * Column indices are used (not column names) because the Excel has duplicate headers.
 *
 * Run: node family-code-delete-import.js
 */

const admin = require('firebase-admin');
const XLSX = require('xlsx');

const serviceAccount = require('./share-india-d9717-firebase-adminsdk-fbsvc-ebe7273a5e.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const EXCEL_FILE = '/Users/jayanthrachamadugu/Downloads/All Family Code Creation (4).xlsx';
const COLLECTION = 'Family Code Creation';
const BATCH_SIZE = 400;

// ── Excel column index → asset name ─────────────────────────────────────────
// Columns 33-54 are individual asset Yes/No columns
const ASSET_COLS = {
  33: 'Mattress',
  34: 'Cot/bed',
  35: 'Electric Fan',
  36: 'Pressure cooker',
  37: 'sewing Machine',
  38: 'Refrigerator',
  39: 'Mobile phone',
  40: 'Any phone',
  41: 'Bicycle',
  42: 'Scooter',
  43: 'Animal cart',
  44: 'Chair',
  45: 'Table',
  46: 'Radio',
  47: 'Mixer',
  48: 'Colour TV',
  49: 'A/C',
  50: 'Water pump',
  51: 'Computer',
  52: 'Tractor',
  53: 'Car',
  54: 'Thresher',
};

// ── Helpers ──────────────────────────────────────────────────────────────────

function isYes(val) {
  if (val === null || val === undefined || val === '') return false;
  const s = String(val).trim().toLowerCase();
  return s === '1' || s === '(1) yes' || s === 'yes';
}

/** Split comma-separated multi-value cells into an array of trimmed strings. */
function splitMulti(val) {
  if (!val || String(val).trim() === '') return [];
  return String(val).split(',').map(s => s.trim()).filter(Boolean);
}

/** Return trimmed string or null for empty values. */
function str(val) {
  if (val === null || val === undefined) return null;
  const s = String(val).trim();
  return s === '' ? null : s;
}

// ── Row → Firestore document ─────────────────────────────────────────────────
// row is a 0-indexed array of cell values (header: 1 mode from XLSX)
function rowToDoc(row) {
  const famId = str(row[0]);
  if (!famId) return null;

  // Build household_assets and household_assets_not_owned from individual columns
  const householdAssets = [];
  const householdAssetsNotOwned = [];
  for (const [colIdxStr, assetName] of Object.entries(ASSET_COLS)) {
    const val = row[parseInt(colIdxStr)];
    if (isYes(val)) {
      householdAssets.push(assetName);
    } else if (val !== null && val !== undefined && val !== '') {
      householdAssetsNotOwned.push(assetName);
    }
  }

  // Derive owns_cattle from whether cattle list is present
  const cattleOwned = splitMulti(row[61]);
  const ownsCattle = cattleOwned.length > 0 ? '(1) Yes' : str(row[61]) === '' ? null : '(2) No';

  // Build the document with EXACT keys matching main.dart:927 save block
  const doc = {
    family_id:                famId,
    state:                    str(row[1]),
    district:                 str(row[2]),
    mandal:                   str(row[3]),
    village:                  str(row[4]),
    head_of_family:           str(row[5]),
    house_no:                 str(row[6]),
    family_type:              str(row[7]),
    family_status:            str(row[8]),
    own_house:                str(row[9]),
    no_of_rooms:              str(row[10]),
    type_of_house:            str(row[11]),
    roof_type:                str(row[12]),
    wall_type:                str(row[13]),
    floor_type:               str(row[14]),
    cooking_location:         splitMulti(row[15]),   // multi-value
    cooking_location_other:   str(row[16]),
    separate_kitchen:         str(row[17]),
    cooking_fuel_types:       splitMulti(row[18]),   // multi-value
    cooking_fuel_main:        str(row[19]),           // numeric code e.g. '2' — _matchOption handles it
    cooking_fuel_other:       str(row[20]),
    lighting_source:          str(row[21]),
    water_sources:            splitMulti(row[22]),   // multi-value
    water_main_source:        str(row[23]),           // numeric code
    water_source_other:       str(row[24]),
    water_treatment:          splitMulti(row[25]),   // multi-value
    water_treatment_other:    str(row[26]),
    water_all_sources:        splitMulti(row[27]),   // multi-value
    water_all_other:          str(row[28]),
    toilet_facility:          str(row[29]),
    ration_card:              str(row[30]),
    religion:                 str(row[31]),
    caste:                    str(row[32]),
    household_assets:         householdAssets,
    household_assets_not_owned: householdAssetsNotOwned,
    agriculture_land:         str(row[55]),
    agriculture_land_area:    str(row[56]),
    agriculture_land_unit:    str(row[57]),
    is_irrigated:             str(row[58]),           // '1' → _matchOption gives '(1) Yes'
    irrigated_land_unit:      str(row[59]),
    irrigated_none:           str(row[60]),
    owns_cattle:              ownsCattle,
    cattle_owned:             cattleOwned,           // multi-value array
    cattle_other:             str(row[62]),
    health_care_place:        str(row[63]),
    govt_hospital_reasons:    splitMulti(row[64]),   // multi-value
    // Sync metadata
    firestoreDocId:           famId,
    needs_zoho_sync:          false,
    is_temporary:             false,
  };

  // Remove null fields to keep Firestore documents clean
  for (const key of Object.keys(doc)) {
    if (doc[key] === null) delete doc[key];
  }

  return doc;
}

// ── Delete entire collection ─────────────────────────────────────────────────
async function deleteCollection() {
  console.log(`\n🗑️  Deleting all docs in '${COLLECTION}'...`);
  let total = 0;
  while (true) {
    const snap = await db.collection(COLLECTION).limit(500).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();
    total += snap.docs.length;
    console.log(`   Deleted ${total} so far...`);
  }
  console.log(`✅ Deleted ${total} documents.\n`);
}

// ── Import from Excel ─────────────────────────────────────────────────────────
async function importFromExcel() {
  console.log(`📂 Reading Excel: ${EXCEL_FILE}`);
  const workbook = XLSX.readFile(EXCEL_FILE);
  const sheet = workbook.Sheets[workbook.SheetNames[0]];

  // header: 1 → each row is an array; first row is the header row
  const allRows = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: null });
  const dataRows = allRows.slice(1); // skip header row

  console.log(`📋 Total rows in Excel: ${dataRows.length}`);

  const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
  let batch = db.batch();
  let batchCount = 0;
  let totalUploaded = 0;
  let skipped = 0;

  for (const row of dataRows) {
    const doc = rowToDoc(row);
    if (!doc) {
      skipped++;
      continue;
    }

    doc.serverUpdatedAt = serverTimestamp;

    const docRef = db.collection(COLLECTION).doc(doc.family_id);
    batch.set(docRef, doc);
    batchCount++;

    if (batchCount === BATCH_SIZE) {
      await batch.commit();
      totalUploaded += batchCount;
      console.log(`⬆️  Uploaded ${totalUploaded} records...`);
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
    totalUploaded += batchCount;
  }

  console.log(`\n🎉 Import complete!`);
  console.log(`   ✅ Uploaded: ${totalUploaded}`);
  console.log(`   ⏭️  Skipped (no FAM_ID): ${skipped}`);
}

// ── Main ─────────────────────────────────────────────────────────────────────
async function run() {
  console.log('====================================================');
  console.log(' Family Code Creation — Delete & Re-import');
  console.log('====================================================');

  await deleteCollection();
  await importFromExcel();

  console.log('\n✅ Done! Documents use FAM_ID as Firestore document ID.');
  console.log('   All keys match the Flutter app standard format.');
  console.log('   Open the app with internet — data will sync to SQLite automatically.\n');
}

run().catch(err => {
  console.error('❌ Fatal error:', err);
  process.exit(1);
});
