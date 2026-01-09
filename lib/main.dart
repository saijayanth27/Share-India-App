import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

/* ============================================================
   APP ROOT
============================================================ */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Firestore Offline First',
      theme: ThemeData(useMaterial3: true),
      home: const FamilyFormPage(),
    );
  }
}

/* ============================================================
   FAMILY FORM PAGE
============================================================ */

class FamilyFormPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;

  const FamilyFormPage({super.key, this.existingData});

  @override
  State<FamilyFormPage> createState() => _FamilyFormPageState();
}

class _FamilyFormPageState extends State<FamilyFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _familyId = TextEditingController();
  final _houseNo = TextEditingController();
  final _head = TextEditingController();

  String? ownHouse;
  String? typeofhouse;
  String? noOfRooms;
  String? separateKitchen;
  String? roofType;
  String? wallType;
  String? floorType;
  String? cookingFuel;
  List<String> cookingFuelTypes = [];
  String? cookingFuelMain;
  String? lightingSource;
  List<String> waterSources = [];
  String? waterMainSource;
  List<String> waterTreatment = [];
  List<String> waterAllPurposeSources = [];
  String? waterAllPurposeMain;
  String? toiletFacility;
  String? rationCard;
  String? religion;
  String? caste;
  List<String> householdAssets = [];
  String? hasAgricultureLand;
  String? agricultureLandArea;
  String? agricultureLandUnit;
  String? irrigatedLandArea;
  String? irrigatedLandUnit;
  bool irrigatedNone = false;
  List<String> cattleOwned = [];
  String? cattleOther;
  String? healthCarePlace;
  List<String> govtHospitalReasons = [];
  String? govtHospitalOther;

  @override
  void initState() {
    super.initState();

    if (widget.existingData != null) {
      final data = widget.existingData!;

      // ===== BASIC DETAILS =====
      _familyId.text = data['family_id'] ?? '';
      _houseNo.text = data['house_no'] ?? '';
      _head.text = data['head_of_family'] ?? '';

      // ===== HOUSE DETAILS =====
      ownHouse = data['own_house'];
      typeofhouse = data['type_of_house'];
      noOfRooms = data['no_of_rooms'];
      roofType = data['roof_type'];
      wallType = data['wall_type'];
      floorType = data['floor_type'];

      // ===== COOKING =====
      cookingFuel = data['cooking_fuel'];
      separateKitchen = data['separate_kitchen'];

      // Q6
      cookingFuelTypes = List<String>.from(data['cooking_fuel_types'] ?? []);
      cookingFuelMain = data['cooking_fuel_main'];

      // ===== LIGHTING =====
      lightingSource = data['lighting_source'];

      // ===== WATER (DRINKING) =====
      waterSources = List<String>.from(data['water_sources'] ?? []);
      waterMainSource = data['water_main_source'];

      // ===== WATER TREATMENT =====
      waterTreatment = List<String>.from(data['water_treatment'] ?? []);

      // ===== WATER (ALL PURPOSES) =====
      waterAllPurposeSources =
          List<String>.from(data['water_all_sources'] ?? []);
      waterAllPurposeMain = data['water_all_main'];

      // ===== SANITATION =====
      toiletFacility = data['toilet_facility'];

      // ===== RATION CARD =====
      rationCard = data['ration_card'];

      // ===== RELIGION / CASTE =====
      religion = data['religion'];
      caste = data['caste'];

      // ===== ASSETS =====
      householdAssets = List<String>.from(data['household_assets'] ?? []);

      // ===== AGRICULTURE LAND =====
      hasAgricultureLand = data['agriculture_land'];
      agricultureLandArea = data['agriculture_land_area'];
      agricultureLandUnit = data['agriculture_land_unit'];

      // ===== IRRIGATED LAND =====
      irrigatedLandArea = data['irrigated_land_area'];
      irrigatedLandUnit = data['irrigated_land_unit'];
      irrigatedNone = data['irrigated_none'] ?? false;

      // ===== CATTLE =====
      cattleOwned = List<String>.from(data['cattle_owned'] ?? []);
      cattleOther = data['cattle_other'];

      // ===== HEALTH CARE =====
      healthCarePlace = data['health_care_place'];

      // ===== GOVT HOSPITAL =====
      govtHospitalReasons =
          List<String>.from(data['govt_hospital_reasons'] ?? []);
      govtHospitalOther = data['govt_hospital_other'];
    }
  }

  @override
  void dispose() {
    _familyId.dispose();
    _houseNo.dispose();
    _head.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'family_id': _familyId.text,
      'house_no': _houseNo.text,
      'head_of_family': _head.text,
      'own_house': ownHouse,
      'type_of_house': typeofhouse,
      'no_of_rooms': noOfRooms,
      'separate_kitchen': separateKitchen,
      'cooking_fuel_types': cookingFuelTypes,
      'cooking_fuel_main': cookingFuelMain,
      'lighting_source': lightingSource,
      'water_sources': waterSources,
      'water_main_source': waterMainSource,
      'water_treatment': waterTreatment,
      'water_all_sources': waterAllPurposeSources,
      'water_all_main': waterAllPurposeMain,
      'toilet_facility': toiletFacility,
      'ration_card': rationCard,
      'religion': religion,
      'caste': caste,
      'household_assets': householdAssets,
      'agriculture_land': hasAgricultureLand,
      'agriculture_land_area': agricultureLandArea,
      'agriculture_land_unit': agricultureLandUnit,
      'irrigated_land_area': irrigatedLandArea,
      'irrigated_land_unit': irrigatedLandUnit,
      'irrigated_none': irrigatedNone,
      'cattle_owned': cattleOwned,
      'cattle_other': cattleOther,
      'health_care_place': healthCarePlace,
      'govt_hospital_reasons': govtHospitalReasons,
      'govt_hospital_other': govtHospitalOther,
      'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    };

    FirebaseFirestore.instance
        .collection('client')
        .doc(_familyId.text)
        .set(data, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(
          widget.existingData == null
              ? 'Saved locally (syncing automatically)'
              : 'Updated locally (syncing automatically)',
        ),
      ),
    );

    if (widget.existingData == null) {
      _familyId.clear();
      _houseNo.clear();
      _head.clear();
      ownHouse = null;
      typeofhouse = null;
      roofType = null;
      wallType = null;
      floorType = null;
      cookingFuel = null;
      setState(() {});
    }
  }

  void _openList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecordsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Form'),
        actions: [
          IconButton(icon: const Icon(Icons.list), onPressed: _openList),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Family Details',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _familyId,
              decoration: const InputDecoration(
                labelText: 'Family ID',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              enabled: widget.existingData == null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _houseNo,
              decoration: const InputDecoration(
                labelText: 'House No',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _head,
              decoration: const InputDecoration(
                labelText: 'Head of Family',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Do you own this house?',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Yes'),
                    value: 'yes',
                    groupValue: ownHouse,
                    onChanged: (v) => setState(() => ownHouse = v),
                  ),
                ),
                Expanded(
                  child: RadioListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('No'),
                    value: 'no',
                    groupValue: ownHouse,
                    onChanged: (v) => setState(() => ownHouse = v),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
// House Type
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Type of House',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'kutcha', child: Text('Kutcha')),
                DropdownMenuItem(
                    value: 'semi_pucca', child: Text('Semi Pucca')),
                DropdownMenuItem(value: 'pucca', child: Text('Pucca')),
              ],
              onChanged: (v) => setState(() => typeofhouse = v),
            ),
            const SizedBox(height: 12),

// Number of rooms
            TextFormField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of Rooms',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

// Roof Type
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Type of Roof',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'thatch', child: Text('Thatch')),
                DropdownMenuItem(value: 'tiles', child: Text('Tiles')),
                DropdownMenuItem(value: 'cement', child: Text('Cement')),
              ],
              onChanged: (v) => setState(() => roofType = v),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Type of Wall',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'mud', child: Text('Mud')),
                DropdownMenuItem(value: 'brick', child: Text('Brick')),
                DropdownMenuItem(value: 'cement', child: Text('Cement')),
              ],
              onChanged: (v) => setState(() => wallType = v),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Type of Floor',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'mud', child: Text('Mud')),
                DropdownMenuItem(value: 'cement', child: Text('Cement')),
                DropdownMenuItem(value: 'tiles', child: Text('Tiles')),
              ],
              onChanged: (v) => setState(() => floorType = v),
            ),
            const Divider(height: 32),
            Text('Cooking Details',
                style: Theme.of(context).textTheme.titleMedium),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Primary Cooking Fuel',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'firewood', child: Text('Firewood')),
                DropdownMenuItem(value: 'lpg', child: Text('LPG')),
                DropdownMenuItem(value: 'electric', child: Text('Electric')),
                DropdownMenuItem(value: 'others', child: Text('Others')),
              ],
              onChanged: (v) => setState(() => cookingFuel = v),
            ),

            const SizedBox(height: 12),

            Text('Is there a separate kitchen?',
                style: const TextStyle(fontWeight: FontWeight.w600)),

            const SizedBox(height: 6),

            Row(
              children: [
                Expanded(
                  child: RadioListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Yes'),
                    value: 'yes',
                    groupValue: separateKitchen,
                    onChanged: (v) => setState(() => separateKitchen = v),
                  ),
                ),
                Expanded(
                  child: RadioListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('No'),
                    value: 'no',
                    groupValue: separateKitchen,
                    onChanged: (v) => setState(() => separateKitchen = v),
                  ),
                ),
              ],
            ),

            const Divider(height: 32),
            Text(
              '6. Type of fuel used for cooking?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),

            const SizedBox(height: 8),

            CheckboxListTile(
              title: const Text('Electricity'),
              value: cookingFuelTypes.contains('electricity'),
              onChanged: (v) {
                setState(() {
                  v!
                      ? cookingFuelTypes.add('electricity')
                      : cookingFuelTypes.remove('electricity');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('LPG / PNG / GAS'),
              value: cookingFuelTypes.contains('lpg'),
              onChanged: (v) {
                setState(() {
                  v!
                      ? cookingFuelTypes.add('lpg')
                      : cookingFuelTypes.remove('lpg');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('Kerosene'),
              value: cookingFuelTypes.contains('kerosene'),
              onChanged: (v) {
                setState(() {
                  v!
                      ? cookingFuelTypes.add('kerosene')
                      : cookingFuelTypes.remove('kerosene');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('Wood / Coal / Crop Residue / Dung Cakes'),
              value: cookingFuelTypes.contains('solid_fuel'),
              onChanged: (v) {
                setState(() {
                  v!
                      ? cookingFuelTypes.add('solid_fuel')
                      : cookingFuelTypes.remove('solid_fuel');
                });
              },
            ),

            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Mainly used fuel',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => cookingFuelMain = v,
            ),

            const Divider(height: 32),
            Text(
              '7. Main source of lighting in household?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),

            const SizedBox(height: 6),

            RadioListTile(
              dense: true,
              title: const Text('Electricity'),
              value: 'electricity',
              groupValue: lightingSource,
              onChanged: (v) => setState(() => lightingSource = v),
            ),

            RadioListTile(
              dense: true,
              title: const Text('Kerosene'),
              value: 'kerosene',
              groupValue: lightingSource,
              onChanged: (v) => setState(() => lightingSource = v),
            ),

            RadioListTile(
              dense: true,
              title: const Text('Oil'),
              value: 'oil',
              groupValue: lightingSource,
              onChanged: (v) => setState(() => lightingSource = v),
            ),

            RadioListTile(
              dense: true,
              title: const Text('Gas'),
              value: 'gas',
              groupValue: lightingSource,
              onChanged: (v) => setState(() => lightingSource = v),
            ),
            Text(
              '8. Source of water',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),

            CheckboxListTile(
              title: const Text('Piped Water'),
              value: waterSources.contains('piped'),
              onChanged: (v) {
                setState(() {
                  v! ? waterSources.add('piped') : waterSources.remove('piped');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('Bore Well / Dug Well'),
              value: waterSources.contains('well'),
              onChanged: (v) {
                setState(() {
                  v! ? waterSources.add('well') : waterSources.remove('well');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('Surface Water / Tanker / Bottled'),
              value: waterSources.contains('other'),
              onChanged: (v) {
                setState(() {
                  v! ? waterSources.add('other') : waterSources.remove('other');
                });
              },
            ),

            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Mainly used source',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => waterMainSource = v,
            ),
            Text(
              '9. Do you treat water to make it safer for drinking?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),

            CheckboxListTile(
              title: const Text('Boil'),
              value: waterTreatment.contains('boil'),
              onChanged: (v) {
                setState(() {
                  v!
                      ? waterTreatment.add('boil')
                      : waterTreatment.remove('boil');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('Use water filter / purifier'),
              value: waterTreatment.contains('filter'),
              onChanged: (v) {
                setState(() {
                  v!
                      ? waterTreatment.add('filter')
                      : waterTreatment.remove('filter');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('Add bleach / strain / settle'),
              value: waterTreatment.contains('chemical'),
              onChanged: (v) {
                setState(() {
                  v!
                      ? waterTreatment.add('chemical')
                      : waterTreatment.remove('chemical');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('None / Don’t know'),
              value: waterTreatment.contains('none'),
              onChanged: (v) {
                setState(() {
                  v!
                      ? waterTreatment.add('none')
                      : waterTreatment.remove('none');
                });
              },
            ),
            Text(
              '10. Source of water used for all purposes',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),

            CheckboxListTile(
              title: const Text('Piped Water'),
              value: waterAllPurposeSources.contains('piped'),
              onChanged: (v) {
                setState(() {
                  v!
                      ? waterAllPurposeSources.add('piped')
                      : waterAllPurposeSources.remove('piped');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('Bore / Dug Well'),
              value: waterAllPurposeSources.contains('well'),
              onChanged: (v) {
                setState(() {
                  v!
                      ? waterAllPurposeSources.add('well')
                      : waterAllPurposeSources.remove('well');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('Surface / Tanker / Bottled'),
              value: waterAllPurposeSources.contains('other'),
              onChanged: (v) {
                setState(() {
                  v!
                      ? waterAllPurposeSources.add('other')
                      : waterAllPurposeSources.remove('other');
                });
              },
            ),

            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Mainly used source',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => waterAllPurposeMain = v,
            ),
            Text(
              '11. What kind of toilet facility HH?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),

            RadioListTile(
              title: const Text('Flush Toilet'),
              value: 'flush',
              groupValue: toiletFacility,
              onChanged: (v) => setState(() => toiletFacility = v),
            ),

            RadioListTile(
              title: const Text('Pit Toilet'),
              value: 'pit',
              groupValue: toiletFacility,
              onChanged: (v) => setState(() => toiletFacility = v),
            ),

            RadioListTile(
              title: const Text('Open Field'),
              value: 'open',
              groupValue: toiletFacility,
              onChanged: (v) => setState(() => toiletFacility = v),
            ),
            Text(
              '12. Have ration card?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),

            RadioListTile(
              title: const Text('White Card'),
              value: 'white',
              groupValue: rationCard,
              onChanged: (v) => setState(() => rationCard = v),
            ),

            RadioListTile(
              title: const Text('Pink Card'),
              value: 'pink',
              groupValue: rationCard,
              onChanged: (v) => setState(() => rationCard = v),
            ),

            RadioListTile(
              title: const Text('No Card'),
              value: 'none',
              groupValue: rationCard,
              onChanged: (v) => setState(() => rationCard = v),
            ),

            Text(
              '13. Religion',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),

            RadioListTile(
              title: const Text('Hindu'),
              value: 'hindu',
              groupValue: religion,
              onChanged: (v) => setState(() => religion = v),
            ),

            RadioListTile(
              title: const Text('Muslim'),
              value: 'muslim',
              groupValue: religion,
              onChanged: (v) => setState(() => religion = v),
            ),

            RadioListTile(
              title: const Text('Christian'),
              value: 'christian',
              groupValue: religion,
              onChanged: (v) => setState(() => religion = v),
            ),

            RadioListTile(
              title: const Text('Other'),
              value: 'other',
              groupValue: religion,
              onChanged: (v) => setState(() => religion = v),
            ),
            Text(
              '14. Caste of the head',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),

            RadioListTile(
                title: const Text('SC'),
                value: 'sc',
                groupValue: caste,
                onChanged: (v) => setState(() => caste = v)),
            RadioListTile(
                title: const Text('ST'),
                value: 'st',
                groupValue: caste,
                onChanged: (v) => setState(() => caste = v)),
            RadioListTile(
                title: const Text('BC'),
                value: 'bc',
                groupValue: caste,
                onChanged: (v) => setState(() => caste = v)),
            RadioListTile(
                title: const Text('OC'),
                value: 'oc',
                groupValue: caste,
                onChanged: (v) => setState(() => caste = v)),
            Text(
              '15. Household own any of this?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 3.5,
              children: [
                'Mattress',
                'Cot/Bed',
                'Fan',
                'TV',
                'Mobile',
                'Refrigerator',
                'Bicycle',
                'Scooter',
                'Car',
                'Computer'
              ].map((item) {
                return CheckboxListTile(
                  title: Text(item),
                  value: householdAssets.contains(item),
                  onChanged: (v) {
                    setState(() {
                      v!
                          ? householdAssets.add(item)
                          : householdAssets.remove(item);
                    });
                  },
                );
              }).toList(),
            ),
            Text(
              '16. Any agriculture land?',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),

            Row(
              children: [
                Expanded(
                  child: RadioListTile(
                    title: const Text('Yes'),
                    value: 'yes',
                    groupValue: hasAgricultureLand,
                    onChanged: (v) => setState(() => hasAgricultureLand = v),
                  ),
                ),
                Expanded(
                  child: RadioListTile(
                    title: const Text('No'),
                    value: 'no',
                    groupValue: hasAgricultureLand,
                    onChanged: (v) => setState(() => hasAgricultureLand = v),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            TextFormField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Land Area',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => agricultureLandArea = v,
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              value: agricultureLandUnit,
              decoration: const InputDecoration(
                labelText: 'Land Unit',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'acre', child: Text('Acre')),
                DropdownMenuItem(value: 'hectare', child: Text('Hectare')),
              ],
              onChanged: (v) => setState(() => agricultureLandUnit = v),
            ),
            Text(
              '17. Land is irrigated?',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),

            TextFormField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number you hold',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => irrigatedLandArea = v,
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              value: irrigatedLandUnit,
              decoration: const InputDecoration(
                labelText: 'Land Unit',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'acre', child: Text('Acre')),
                DropdownMenuItem(value: 'hectare', child: Text('Hectare')),
              ],
              onChanged: (v) => setState(() => irrigatedLandUnit = v),
            ),

            CheckboxListTile(
              title: const Text('None'),
              value: irrigatedNone,
              onChanged: (v) => setState(() => irrigatedNone = v!),
            ),
            Text(
              '18. Own any cattle?',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),

            CheckboxListTile(
              title: const Text('Cows / Buffaloes'),
              value: cattleOwned.contains('cows'),
              onChanged: (v) {
                setState(() {
                  v! ? cattleOwned.add('cows') : cattleOwned.remove('cows');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('Bulls'),
              value: cattleOwned.contains('bulls'),
              onChanged: (v) {
                setState(() {
                  v! ? cattleOwned.add('bulls') : cattleOwned.remove('bulls');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('Goats / Sheep'),
              value: cattleOwned.contains('goats'),
              onChanged: (v) {
                setState(() {
                  v! ? cattleOwned.add('goats') : cattleOwned.remove('goats');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('Poultry'),
              value: cattleOwned.contains('poultry'),
              onChanged: (v) {
                setState(() {
                  v!
                      ? cattleOwned.add('poultry')
                      : cattleOwned.remove('poultry');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('None'),
              value: cattleOwned.contains('none'),
              onChanged: (v) {
                setState(() {
                  v! ? cattleOwned.add('none') : cattleOwned.remove('none');
                });
              },
            ),

            TextFormField(
              decoration: const InputDecoration(
                labelText: 'If others, please mention',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => cattleOther = v,
            ),
            Text(
              '19. Get sick, where do they go?',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),

            RadioListTile(
              title: const Text('Govt Hospital'),
              value: 'govt',
              groupValue: healthCarePlace,
              onChanged: (v) => setState(() => healthCarePlace = v),
            ),

            RadioListTile(
              title: const Text('Private Hospital'),
              value: 'private',
              groupValue: healthCarePlace,
              onChanged: (v) => setState(() => healthCarePlace = v),
            ),

            RadioListTile(
              title: const Text('Medical Shop'),
              value: 'medical_shop',
              groupValue: healthCarePlace,
              onChanged: (v) => setState(() => healthCarePlace = v),
            ),

            RadioListTile(
              title: const Text('Home Treatment'),
              value: 'home',
              groupValue: healthCarePlace,
              onChanged: (v) => setState(() => healthCarePlace = v),
            ),
            Text(
              '20. Why they don’t go to Govt Hospital?',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),

            CheckboxListTile(
              title: const Text('No nearby health facility'),
              value: govtHospitalReasons.contains('no_nearby'),
              onChanged: (v) {
                setState(() {
                  v!
                      ? govtHospitalReasons.add('no_nearby')
                      : govtHospitalReasons.remove('no_nearby');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('Timing not convenient'),
              value: govtHospitalReasons.contains('timing'),
              onChanged: (v) {
                setState(() {
                  v!
                      ? govtHospitalReasons.add('timing')
                      : govtHospitalReasons.remove('timing');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('Health personnel often absent'),
              value: govtHospitalReasons.contains('absent'),
              onChanged: (v) {
                setState(() {
                  v!
                      ? govtHospitalReasons.add('absent')
                      : govtHospitalReasons.remove('absent');
                });
              },
            ),

            CheckboxListTile(
              title: const Text('Poor quality of care'),
              value: govtHospitalReasons.contains('quality'),
              onChanged: (v) {
                setState(() {
                  v!
                      ? govtHospitalReasons.add('quality')
                      : govtHospitalReasons.remove('quality');
                });
              },
            ),

            TextFormField(
              decoration: const InputDecoration(
                labelText: 'If others, please mention',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => govtHospitalOther = v,
            ),

            const Divider(height: 40),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                widget.existingData == null ? 'SAVE' : 'UPDATE',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   RECORDS PAGE (TABLE VIEW)
============================================================ */

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Records')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('client')
            .orderBy('clientUpdatedAt', descending: true)
            .snapshots(includeMetadataChanges: true),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: Text('Loading...'));
          }

          final docs = snapshot.data!.docs;
          final fromCache = snapshot.data!.metadata.isFromCache;
          final syncing = snapshot.data!.metadata.hasPendingWrites;

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color:
                    fromCache ? Colors.orange.shade100 : Colors.green.shade100,
                child: Text(
                  fromCache
                      ? 'Offline mode'
                      : syncing
                          ? 'Online – syncing...'
                          : 'Online – synced',
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        MaterialStateProperty.all(Colors.grey.shade200),
                    columns: const [
                      DataColumn(label: Text('Family ID')),
                      DataColumn(label: Text('House No')),
                      DataColumn(label: Text('Head')),
                      DataColumn(label: Text('Own House')),
                      DataColumn(label: Text('Type of House')),
                      DataColumn(label: Text('No.Of Rooms')),
                      DataColumn(label: Text('Separate Kitchen')),
                      DataColumn(label: Text('Cooking Fuel (Types)')),
                      DataColumn(label: Text('Cooking Fuel (Main)')),
                      DataColumn(label: Text('Lighting Source')),
                      DataColumn(label: Text('Water Sources')),
                      DataColumn(label: Text('Water Main Source')),
                      DataColumn(label: Text('Water Treatment')),
                      DataColumn(label: Text('Water (All)')),
                      DataColumn(label: Text('Toilet')),
                      DataColumn(label: Text('Ration Card')),
                      DataColumn(label: Text('Religion')),
                      DataColumn(label: Text('Caste')),
                      DataColumn(label: Text('Assets')),
                      DataColumn(label: Text('Agri Land')),
                      DataColumn(label: Text('Irrigated')),
                      DataColumn(label: Text('Cattle')),
                      DataColumn(label: Text('Health Care')),
                      DataColumn(label: Text('No Govt Hospital')),
                      DataColumn(label: Text('Edit')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final pending = doc.metadata.hasPendingWrites;
                      return DataRow(
                        cells: [
                          DataCell(Text(data['family_id'] ?? '')), // 1
                          DataCell(Text(data['house_no'] ?? '')), // 2
                          DataCell(Text(data['head_of_family'] ?? '')), // 3
                          DataCell(Text(data['own_house'] ?? '')), // 4
                          DataCell(Text(data['type_of_house'] ?? '')), // 5
                          DataCell(
                              Text(data['no_of_rooms']?.toString() ?? '')), // 6
                          DataCell(Text(data['separate_kitchen'] ?? '')), // 7

                          // Q6
                          DataCell(
                            Text(
                              (data['cooking_fuel_types'] as List?)
                                      ?.join(', ') ??
                                  '',
                            ),
                          ), // 8

                          DataCell(Text(data['cooking_fuel_main'] ?? '')), // 9

                          // Q7
                          DataCell(Text(data['lighting_source'] ?? '')), // 10

                          // Q8
                          DataCell(
                            Text(
                              (data['water_sources'] as List?)?.join(', ') ??
                                  '',
                            ),
                          ), // 11

                          DataCell(Text(data['water_main_source'] ?? '')), // 12

                          // Q9
                          DataCell(
                            Text(
                              (data['water_treatment'] as List?)?.join(', ') ??
                                  '',
                            ),
                          ),
                          DataCell(Text((data['water_all_sources'] as List?)
                                  ?.join(', ') ??
                              '')),
                          DataCell(Text(data['toilet_facility'] ?? '')),
                          DataCell(Text(data['ration_card'] ?? '')),
                          DataCell(Text(data['religion'] ?? '')),
                          DataCell(Text(data['caste'] ?? '')),
                          DataCell(Text(
                              (data['household_assets'] as List?)?.join(', ') ??
                                  '')), // 14

                          DataCell(Text(data['agriculture_land'] ?? '')),
                          DataCell(Text(data['irrigated_land_area'] ?? '')),
                          DataCell(Text(
                              (data['cattle_owned'] as List?)?.join(', ') ??
                                  '')),
                          DataCell(Text(data['health_care_place'] ?? '')),
                          DataCell(Text((data['govt_hospital_reasons'] as List?)
                                  ?.join(', ') ??
                              '')),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        FamilyFormPage(existingData: data),
                                  ),
                                );
                              },
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                Icon(
                                  pending ? Icons.cloud_off : Icons.cloud_done,
                                  color: pending ? Colors.red : Colors.green,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  pending ? 'Not Synced' : 'Synced',
                                  style: TextStyle(
                                    color: pending ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
