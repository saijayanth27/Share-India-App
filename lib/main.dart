import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'zoho_creator_service.dart';

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

final Map<String, Map<String, List<String>>> locationData = {
  'telangana': {
    'Hyderabad': ['Ameerpet', 'Begumpet'],
    'Ranga Reddy': ['Shamshabad', 'Ibrahimpatnam'],
  }
};

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
  Map<String, dynamic> locationData = {};
  bool isLoadingLocations = true;
  bool _isSaving = false;

  String? ownHouse;
  String? selectedState;
  String? selectedDistrict;
  String? selectedMandal;
  String? selectedVillage;

  bool familyIdReadOnly = false;

  String? familyType;
  String? familyStatus;
  String? cookingLocation;
  final _cookingLocationOther = TextEditingController();
  String? typeofhouse;
  int? noOfRooms;
  String? separateKitchen;
  String? roofType;
  String? wallType;
  String? floorType;
  String? cookingFuel;
  List<String> cookingFuelTypes = [];
  final _cookingFuelOther = TextEditingController();
  String? cookingFuelMain;
  String? lightingSource;
  List<String> waterSources = [];
  final _waterSourceOther = TextEditingController();
  String? waterMainSource;
  List<String> waterTreatment = [];
  final _waterTreatmentOther = TextEditingController();
  List<String> waterAllPurposeSources = [];
  final _waterAllPurposeOther = TextEditingController();
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
  final _cattleOther = TextEditingController();
  String? healthCarePlace;
  List<String> govtHospitalReasons = [];
  final _govtHospitalOther = TextEditingController();
  final _toiletOther = TextEditingController();
  Future<void> fetchLocations() async {
    final doc = await FirebaseFirestore.instance
        .collection('locations')
        .doc('telangana')
        .get();

    if (doc.exists) {
      setState(() {
        locationData = doc.data()!;
        isLoadingLocations = false;
      });

      // DEBUG PRINTS
      print('STATE CODE: ${locationData['state_code']}');

      final districts = locationData['districts'] as Map<String, dynamic>;
      districts.forEach((dName, dData) {
        print('DISTRICT: $dName  CODE: ${dData['code']}');

        final mandals = dData['mandals'] as Map<String, dynamic>;
        mandals.forEach((mName, mData) {
          print('  MANDAL: $mName  CODE: ${mData['code']}');

          final villages = mData['Villages'] as Map<String, dynamic>;
          villages.forEach((vName, vData) {
            print('    VILLAGE: $vName  CODE: ${vData['code']}');
          });
        });
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchLocations();

    if (widget.existingData != null) {
      final data = widget.existingData!;

      // ===== BASIC DETAILS =====
      _familyId.text = data['family_id'] ?? '';
      _houseNo.text = data['house_no'] ?? '';
      _head.text = data['head_of_family'] ?? '';
      familyIdReadOnly = true;

      // ===== LOCATION DETAILS =====
      selectedState = data['state'];
      selectedDistrict = data['district'];
      selectedMandal = data['mandal'];
      selectedVillage = data['village'];

      // ===== NEW FIELDS =====
      familyType = data['family_type'];
      familyStatus = data['family_status'];
      cookingLocation = data['cooking_location'];
      _cookingLocationOther.text = data['cooking_location_other'] ?? '';

      // ===== HOUSE DETAILS =====
      ownHouse = data['own_house'];
      typeofhouse = data['type_of_house'];
      final roomsRaw = data['no_of_rooms'];
      if (roomsRaw is int) {
        noOfRooms = roomsRaw;
      } else {
        noOfRooms = int.tryParse(roomsRaw?.toString() ?? '');
      }
      roofType = data['roof_type'];
      wallType = data['wall_type'];
      floorType = data['floor_type'];

      // ===== COOKING =====
      cookingFuel = data['cooking_fuel'];
      separateKitchen = data['separate_kitchen'];

      // Q6
      cookingFuelTypes = List<String>.from(data['cooking_fuel_types'] ?? []);
      _cookingFuelOther.text = data['cooking_fuel_other'] ?? '';
      cookingFuelMain = data['cooking_fuel_main'];

      // ===== LIGHTING =====
      lightingSource = data['lighting_source'];

      // ===== WATER (DRINKING) =====
      waterSources = List<String>.from(data['water_sources'] ?? []);
      _waterSourceOther.text = data['water_source_other'] ?? '';
      waterMainSource = data['water_main_source'];

      // ===== WATER TREATMENT =====
      waterTreatment = List<String>.from(data['water_treatment'] ?? []);
      _waterTreatmentOther.text = data['water_treatment_other'] ?? '';

      // ===== WATER (ALL PURPOSES) =====
      waterAllPurposeSources =
          List<String>.from(data['water_all_sources'] ?? []);
      _waterAllPurposeOther.text = data['water_all_other'] ?? '';
      waterAllPurposeMain = data['water_all_main'];

      // ===== SANITATION =====
      toiletFacility = data['toilet_facility'];
      _toiletOther.text = data['toilet_facility_other'] ?? '';

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
      _cattleOther.text = data['cattle_other'] ?? '';

      // ===== HEALTH CARE =====
      healthCarePlace = data['health_care_place'];

      // ===== GOVT HOSPITAL =====
      govtHospitalReasons =
          List<String>.from(data['govt_hospital_reasons'] ?? []);
      _govtHospitalOther.text = data['govt_hospital_other'] ?? '';
    }
  }

  @override
  void dispose() {
    _familyId.dispose();
    _houseNo.dispose();
    _head.dispose();
    _cookingLocationOther.dispose();
    _cookingFuelOther.dispose();
    _waterSourceOther.dispose();
    _waterTreatmentOther.dispose();
    _waterAllPurposeOther.dispose();
    _cattleOther.dispose();
    _govtHospitalOther.dispose();
    _toiletOther.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _familyId.clear();
      _houseNo.clear();
      _head.clear();

      familyIdReadOnly = false;

      selectedState = null;
      selectedDistrict = null;
      selectedMandal = null;
      selectedVillage = null;

      familyType = null;
      familyStatus = null;
      cookingLocation = null;
      _cookingLocationOther.clear();
      ownHouse = null;
      typeofhouse = null;
      noOfRooms = null;
      separateKitchen = null;
      roofType = null;
      wallType = null;
      floorType = null;
      cookingFuel = null;
      cookingFuelTypes = [];
      _cookingFuelOther.clear();
      cookingFuelMain = null;
      lightingSource = null;
      waterSources = [];
      _waterSourceOther.clear();
      waterMainSource = null;
      waterTreatment = [];
      _waterTreatmentOther.clear();
      waterAllPurposeSources = [];
      _waterAllPurposeOther.clear();
      waterAllPurposeMain = null;
      toiletFacility = null;
      rationCard = null;
      religion = null;
      caste = null;
      householdAssets = [];
      hasAgricultureLand = null;
      agricultureLandArea = null;
      agricultureLandUnit = null;
      irrigatedLandArea = null;
      irrigatedLandUnit = null;
      irrigatedNone = false;
      cattleOwned = [];
      _cattleOther.clear();
      healthCarePlace = null;
      govtHospitalReasons = [];
      _govtHospitalOther.clear();
    });
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);
    debugPrint('SAVE: Started save process...');

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;
      final isEditing = widget.existingData != null;

      debugPrint('SAVE: isOnline=$isOnline, isEditing=$isEditing');

      String finalId = _familyId.text;
      bool isTemp = finalId.startsWith('OFF_');
      debugPrint('SAVE: Original ID: $finalId (isTemp=$isTemp)');

      final data = {
        'state': selectedState,
        'district': selectedDistrict,
        'mandal': selectedMandal,
        'village': selectedVillage,
        'house_no': _houseNo.text,
        'head_of_family': _head.text,
        'family_type': familyType,
        'family_status': familyStatus,
        'own_house': ownHouse,
        'type_of_house': typeofhouse,
        'wall_type': wallType,
        'roof_type': roofType,
        'floor_type': floorType,
        'no_of_rooms': noOfRooms,
        'separate_kitchen': separateKitchen,
        'cooking_location': cookingLocation,
        'cooking_location_other': _cookingLocationOther.text,
        'cooking_fuel_types': cookingFuelTypes,
        'cooking_fuel_other': _cookingFuelOther.text,
        'cooking_fuel_main': cookingFuelMain,
        'lighting_source': lightingSource,
        'water_sources': waterSources,
        'water_source_other': _waterSourceOther.text,
        'water_main_source': waterMainSource,
        'water_treatment': waterTreatment,
        'water_treatment_other': _waterTreatmentOther.text,
        'water_all_sources': waterAllPurposeSources,
        'water_all_other': _waterAllPurposeOther.text,
        'water_all_main': waterAllPurposeMain,
        'toilet_facility': toiletFacility,
        'toilet_facility_other': _toiletOther.text,
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
        'cattle_other': _cattleOther.text,
        'health_care_place': healthCarePlace,
        'govt_hospital_reasons': govtHospitalReasons,
        'govt_hospital_other': _govtHospitalOther.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'serverUpdatedAt': FieldValue.serverTimestamp(),
      };

      bool saveHandled = false;

      if (isEditing) {
        debugPrint('SAVE: Editing existing record $finalId');
        await FirebaseFirestore.instance
            .collection('client')
            .doc(finalId)
            .set(data, SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));
        saveHandled = true;
        // Sync to Zoho Creator
        await ZohoCreatorService().syncRecord({'family_id': finalId, ...data});
      } else if (isOnline) {
        debugPrint('SAVE: Online mode, attempting atomic save with 10s timeout');
        try {
          // Determine prefix
          String prefix = '';
          if (isTemp) {
            final parts = finalId.split('_');
            if (parts.length >= 2) prefix = parts[1];
          } else if (finalId.length >= 3) {
            prefix = finalId.substring(0, finalId.length - 3);
          }

          if (prefix.isEmpty) throw 'Cannot determine village prefix';

          final counterRef = FirebaseFirestore.instance.collection('village_counters').doc(prefix);
          
          // Pre-fetch legacy ID if needed (OUTSIDE transaction)
          int legacySuffix = 0;
          try {
            final counterSnap = await counterRef.get();
            if (!counterSnap.exists) {
              final query = await FirebaseFirestore.instance
                  .collection('client')
                  .where(FieldPath.documentId, isGreaterThanOrEqualTo: prefix)
                  .where(FieldPath.documentId, isLessThan: prefix + 'z')
                  .limitToLast(1)
                  .get();
              if (query.docs.isNotEmpty) {
                final lastId = query.docs.first.id;
                if (!lastId.startsWith('OFF_')) {
                  legacySuffix = int.tryParse(lastId.substring(prefix.length)) ?? 0;
                }
              }
            }
          } catch (e) {
            debugPrint('SAVE: Legacy prefix lookup error: $e');
          }

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final counterSnap = await transaction.get(counterRef);
            int lastSuffix = legacySuffix;
            if (counterSnap.exists) {
              lastSuffix = counterSnap.data()?['last_suffix'] ?? 0;
            }

            final nextSuffix = lastSuffix + 1;
            final newId = '$prefix${nextSuffix.toString().padLeft(3, '0')}';
            
            final finalData = Map<String, dynamic>.from(data);
            finalData['family_id'] = newId;
            finalData['is_temporary'] = false;

            transaction.set(counterRef, {'last_suffix': nextSuffix}, SetOptions(merge: true));
            transaction.set(FirebaseFirestore.instance.collection('client').doc(newId), finalData);
            finalId = newId;
          }).timeout(const Duration(seconds: 10));
          
          saveHandled = true;
          debugPrint('SAVE: Online transaction successful');
          // Sync to Zoho Creator
          await ZohoCreatorService().syncRecord({'family_id': finalId, ...data});
        } catch (e) {
          debugPrint('SAVE: Online attempt failed: $e. Falling back to offline save.');
          final errStr = e.toString().toLowerCase();
          if (mounted && (errStr.contains('unknown') || errStr.contains('developer') || errStr.contains('permission'))) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Colors.orange,
                content: Text('Note: Counter service unavailable. Saving with temporary ID.'),
              ),
            );
          }
          // Fall through to offline save logic below
        }
      }

      if (!saveHandled) {
        debugPrint('SAVE: Performing offline/fallback save');
        String? villagePrefix;
        final parts = finalId.split('_');
        if (parts.length >= 2) {
          villagePrefix = parts[1];
        } else if (finalId.length >= 3 && !finalId.startsWith('OFF_')) {
          villagePrefix = finalId.substring(0, finalId.length - 3);
          finalId = 'OFF_${villagePrefix}_${DateTime.now().millisecondsSinceEpoch}';
        }

        final finalData = Map<String, dynamic>.from(data);
        finalData['family_id'] = finalId;
        finalData['is_temporary'] = true;
        finalData['village_prefix'] = villagePrefix;

        try {
          // Perform save and proceed immediately (it will queue in cache)
          FirebaseFirestore.instance
              .collection('client')
              .doc(finalId)
              .set(finalData);
          debugPrint('SAVE: Fallback save queued with ID $finalId');
        } catch (e) {
          debugPrint('SAVE: Fallback save error: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('Record saved (ID: $finalId)'),
          ),
        );
        if (widget.existingData == null) {
          _resetForm();
        }
      }
    } catch (e) {
      debugPrint('SAVE CRITICAL ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Critical save error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        debugPrint('SAVE: Process finished');
      }
    }
  }

  void _openList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecordsPage()),
    );
    // Reset form when returning from list ONLY if we are in "New" mode.
    // If we are Editing, we don't want to wipe the form.
    if (mounted && widget.existingData == null) {
      _resetForm();
    }
  }

  Future<void> _generateFamilyId() async {
    debugPrint('Generating Family ID...');
    if (selectedState == null ||
        selectedDistrict == null ||
        selectedMandal == null ||
        selectedVillage == null) {
      debugPrint(
          'Selection Incomplete: $selectedState, $selectedDistrict, $selectedMandal, $selectedVillage');
      return;
    }

    try {
      final stateCode = locationData['state_code'] ?? '';
      final districts = locationData['districts'] as Map<String, dynamic>?;
      final districtData = districts?[selectedDistrict];
      final districtCode = districtData?['code'] ?? '';
      final mandals = districtData?['mandals'] as Map<String, dynamic>?;
      final mandalData = mandals?[selectedMandal];
      final mandalCode = mandalData?['code'] ?? '';
      final villages = mandalData?['Villages'] as Map<String, dynamic>?;
      final villageData = villages?[selectedVillage];
      final villageCode = villageData?['code'] ?? '';

      final prefix = '$stateCode$districtCode$mandalCode$villageCode';
      if (prefix.isEmpty) return;

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        if (mounted) setState(() => _familyId.text = 'OFF_${prefix}_$timestamp');
        return;
      }

      // Online: Get next sequential ID (using Counter Document pattern)
      int nextSuffix = 1;
      final counterRef = FirebaseFirestore.instance.collection('village_counters').doc(prefix);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final counterSnap = await transaction.get(counterRef);
        if (counterSnap.exists) {
          nextSuffix = (counterSnap.data()?['last_suffix'] ?? 0) + 1;
        } else {
          // If counter doesn't exist, we must find the last ID legacy way ONCE
          final query = await FirebaseFirestore.instance
              .collection('client')
              .where(FieldPath.documentId, isGreaterThanOrEqualTo: prefix)
              .where(FieldPath.documentId, isLessThan: prefix + 'z')
              .get();
          final realDocs = query.docs.where((d) => !d.id.startsWith('OFF_')).toList();
          if (realDocs.isNotEmpty) {
            final lastId = realDocs.last.id;
            final suffixStr = lastId.substring(prefix.length);
            nextSuffix = (int.tryParse(suffixStr) ?? 0) + 1;
          }
        }
        // Note: We don't increment here, because if the user doesn't SAVE, we've burned an ID.
        // Actually, for sequential IDs, it's better to increment ON SAVE.
        // But for UI preview, we just show the "expected" next ID.
      });

      final newId = '$prefix${nextSuffix.toString().padLeft(3, '0')}';
      if (mounted) setState(() => _familyId.text = newId);
    } catch (e) {
      debugPrint('Error generating ID: $e');
    }
  }

  Widget fixedDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final result = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return _SearchableListSheet(
                  items: items,
                  title: label,
                  scrollController: scrollController,
                );
              },
            );
          },
        );
        if (result != null) {
          onChanged(result);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          value ?? 'Select $label',
          style: TextStyle(
            color: value == null ? Colors.grey.shade600 : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingLocations) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
            _buildSectionCard(
              title: 'Family & Location Details',
              children: [
                TextFormField(
                  controller: _familyId,
                  readOnly: familyIdReadOnly,
                  decoration: const InputDecoration(
                    labelText: 'Family ID',
                    border: OutlineInputBorder(),
                    helperText: 'Auto-generated based on location',
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                fixedDropdown(
                  label: 'State',
                  value: selectedState,
                  items: isLoadingLocations ? [] : ['Telangana'],
                  onChanged: (v) {
                    setState(() {
                      selectedState = v;
                      selectedDistrict = null;
                      selectedMandal = null;
                      selectedVillage = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                fixedDropdown(
                  label: 'District',
                  value: selectedDistrict,
                  items: selectedState == null
                      ? []
                      : (locationData['districts'] as Map<String, dynamic>)
                          .keys
                          .toList(),
                  onChanged: (v) {
                    setState(() {
                      selectedDistrict = v;
                      selectedMandal = null;
                      selectedVillage = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                fixedDropdown(
                  label: 'Mandal',
                  value: selectedMandal,
                  items: selectedDistrict == null
                      ? []
                      : (locationData['districts'][selectedDistrict]['mandals']
                              as Map<String, dynamic>)
                          .keys
                          .toList(),
                  onChanged: (v) {
                    setState(() {
                      selectedMandal = v;
                      selectedVillage = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                fixedDropdown(
                  label: 'Village',
                  value: selectedVillage,
                  items: selectedMandal == null
                      ? []
                      : (locationData['districts'][selectedDistrict]['mandals']
                                  [selectedMandal]['Villages']
                              as Map<String, dynamic>)
                          .keys
                          .toList(),
                  onChanged: (v) {
                    setState(() {
                      selectedVillage = v;
                    });
                    _generateFamilyId();
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _houseNo,
                        decoration: const InputDecoration(
                          labelText: 'House No',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _head,
                        decoration: const InputDecoration(
                          labelText: 'Head of Family',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Family Type', style: TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('(1) Nuclear Family'),
                        value: '(1) Nuclear Family',
                        groupValue: familyType,
                        onChanged: (v) => setState(() => familyType = v),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('(0) Joint Family'),
                        value: '(0) Joint Family',
                        groupValue: familyType,
                        onChanged: (v) => setState(() => familyType = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Family Status', style: TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('(1) Active'),
                        value: '(1) Active',
                        groupValue: familyStatus,
                        onChanged: (v) => setState(() => familyStatus = v),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('(0) Vacant'),
                        value: '(0) Vacant',
                        groupValue: familyStatus,
                        onChanged: (v) => setState(() => familyStatus = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Housing Details',
              children: [
                Text('Do you own this house?',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Yes'),
                        value: '(1) Yes',
                        groupValue: ownHouse,
                        onChanged: (v) => setState(() => ownHouse = v),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('No'),
                        value: '(2) No',
                        groupValue: ownHouse,
                        onChanged: (v) => setState(() => ownHouse = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Type of House',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        value: typeofhouse,
                        items: const [
                          DropdownMenuItem(
                              value: '(3) KACHHA', child: Text('(3) KACHHA')),
                          DropdownMenuItem(
                              value: '(2) SEMI PUCCA', child: Text('(2) SEMI PUCCA')),
                          DropdownMenuItem(
                              value: '(1) PUCCA', child: Text('(1) PUCCA')),
                        ],
                        onChanged: (v) => setState(() => typeofhouse = v),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: noOfRooms?.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'No. Rooms',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        onChanged: (v) => noOfRooms = int.tryParse(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Type of Roof',
                    border: OutlineInputBorder(),
                  ),
                  value: roofType,
                  items: const [
                    DropdownMenuItem(value: '(1) PUCCA', child: Text('(1) PUCCA')),
                    DropdownMenuItem(value: '(2) SEMI PUCCA', child: Text('(2) SEMI PUCCA')),
                    DropdownMenuItem(value: '(3) KACHHA', child: Text('(3) KACHHA')),
                  ],
                  onChanged: (v) => setState(() => roofType = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Type of Wall',
                    border: OutlineInputBorder(),
                  ),
                  value: wallType,
                  items: const [
                    DropdownMenuItem(value: '(1) PUCCA', child: Text('(1) PUCCA')),
                    DropdownMenuItem(value: '(2) SEMI PUCCA', child: Text('(2) SEMI PUCCA')),
                    DropdownMenuItem(value: '(3) KACHHA', child: Text('(3) KACHHA')),
                  ],
                  onChanged: (v) => setState(() => wallType = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Type of Floor',
                    border: OutlineInputBorder(),
                  ),
                  value: floorType,
                  items: const [
                    DropdownMenuItem(value: '(1) PUCCA', child: Text('(1) PUCCA')),
                    DropdownMenuItem(value: '(2) SEMI PUCCA', child: Text('(2) SEMI PUCCA')),
                    DropdownMenuItem(value: '(3) KACHHA', child: Text('(3) KACHHA')),
                  ],
                  onChanged: (v) => setState(() => floorType = v),
                ),
                const SizedBox(height: 16),
                Text('Where do you cook?', style: TextStyle(fontWeight: FontWeight.w600)),
                Wrap(
                  spacing: 8,
                  children: [
                    '(1) In the House',
                    '(2) In a seperate Building',
                    '(3) Outdoors',
                    '(4) Other'
                  ].map((val) {
                    return SizedBox(
                      width: 170,
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(val),
                        value: val,
                        groupValue: cookingLocation,
                        onChanged: (v) => setState(() => cookingLocation = v),
                      ),
                    );
                  }).toList(),
                ),
                if (cookingLocation == '(4) Other')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextFormField(
                      controller: _cookingLocationOther,
                      decoration: const InputDecoration(
                        labelText: 'If others, please mention',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
            _buildSectionCard(
              title: 'Energy & Utilities',
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Primary Cooking Fuel',
                    border: OutlineInputBorder(),
                  ),
                  value: cookingFuel,
                  items: const [
                    DropdownMenuItem(
                        value: 'firewood', child: Text('Firewood')),
                    DropdownMenuItem(value: 'lpg', child: Text('LPG')),
                    DropdownMenuItem(
                        value: 'electric', child: Text('Electric')),
                    DropdownMenuItem(value: 'others', child: Text('Others')),
                  ],
                  onChanged: (v) => setState(() => cookingFuel = v),
                ),
                const SizedBox(height: 16),
                Text('Is there a separate kitchen?',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('(1) Yes'),
                        value: '(1) Yes',
                        groupValue: separateKitchen,
                        onChanged: (v) => setState(() => separateKitchen = v),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('(2) No'),
                        value: '(2) No',
                        groupValue: separateKitchen,
                        onChanged: (v) => setState(() => separateKitchen = v),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  '6. Type of fuel used for cooking?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                ...[
                  '(1) Electricity',
                  '(2) LPG/N.GAS',
                  '(3) Kerosene',
                  '(4) Wood',
                  '(5) Coal',
                  '(6) Crop Residues',
                  '(7) Dung Cakes',
                  '(77) Other'
                ].map((val) {
                  return CheckboxListTile(
                    title: Text(val),
                    value: cookingFuelTypes.contains(val),
                    onChanged: (v) {
                      setState(() {
                        v! ? cookingFuelTypes.add(val) : cookingFuelTypes.remove(val);
                      });
                    },
                  );
                }).toList(),
                if (cookingFuelTypes.contains('(77) Other'))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextFormField(
                      controller: _cookingFuelOther,
                      decoration: const InputDecoration(
                        labelText: 'If others, please mention',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                TextFormField(
                  initialValue: cookingFuelMain,
                  decoration: const InputDecoration(
                    labelText: 'Mainly used fuel',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      cookingFuelMain = v, // Note: standard var, not state
                ),
                const Divider(height: 24),
                Text(
                  '7. Main source of lighting in household?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    '(1) Electricity',
                    '(2) Kerosene',
                    '(3) Oil',
                    '(4) Gas'
                  ].map((val) {
                    return SizedBox(
                      width: 150,
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(val),
                        value: val,
                        groupValue: lightingSource,
                        onChanged: (v) => setState(() => lightingSource = v),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Water & Sanitation',
              children: [
                Text(
                  '8. Source of water (Select all that apply)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                ...[
                  '(1) Piped water',
                  '(2) Bore Well',
                  '(3) Dug Well',
                  '(4) Surface water',
                  '(5) Tanker/truck',
                  '(6) Bottled water',
                  '(77) Other'
                ].map((val) {
                  return CheckboxListTile(
                    title: Text(val),
                    value: waterSources.contains(val),
                    onChanged: (v) {
                      setState(() {
                        v! ? waterSources.add(val) : waterSources.remove(val);
                      });
                    },
                  );
                }).toList(),
                if (waterSources.contains('(77) Other'))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextFormField(
                      controller: _waterSourceOther,
                      decoration: const InputDecoration(
                        labelText: 'If others, please mention',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                TextFormField(
                  initialValue: waterMainSource,
                  decoration: const InputDecoration(
                    labelText: 'Mainly used source',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => waterMainSource = v,
                ),
                const Divider(height: 24),
                Text(
                  '9. Do to the water to make it safer to drink',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                ...[
                  '(1) Boil',
                  '(2) Add bleach',
                  '(3) strain by cloth',
                  '(4) Use water filter',
                  '(5) use electronic purifier',
                  '(6) stand and settle',
                  '(7) None',
                  '(88) Dont Know',
                  '(77) Other'
                ].map((val) {
                  return CheckboxListTile(
                    title: Text(val),
                    value: waterTreatment.contains(val),
                    onChanged: (v) {
                      setState(() {
                        v! ? waterTreatment.add(val) : waterTreatment.remove(val);
                      });
                    },
                  );
                }).toList(),
                if (waterTreatment.contains('(77) Other'))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextFormField(
                      controller: _waterTreatmentOther,
                      decoration: const InputDecoration(
                        labelText: 'If others, please mention',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                CheckboxListTile(
                  title: const Text('Filter / Purifier'),
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
                  title: const Text('Bleach / Strain'),
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
                const Divider(height: 24),
                Text(
                  '10. Source water used for all purposes',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                ...[
                  '(1) Piped water',
                  '(2) Bore Well',
                  '(3) Dug Well',
                  '(4) Surface water',
                  '(5) Tanker/truck',
                  '(6) Bottled water',
                  '(77) Other'
                ].map((val) {
                  return CheckboxListTile(
                    title: Text(val),
                    value: waterAllPurposeSources.contains(val),
                    onChanged: (v) {
                      setState(() {
                        v!
                            ? waterAllPurposeSources.add(val)
                            : waterAllPurposeSources.remove(val);
                      });
                    },
                  );
                }).toList(),
                if (waterAllPurposeSources.contains('(77) Other'))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextFormField(
                      controller: _waterAllPurposeOther,
                      decoration: const InputDecoration(
                        labelText: 'If others, please mention',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                TextFormField(
                  initialValue: waterAllPurposeMain,
                  decoration: const InputDecoration(
                    labelText: 'Mainly used source',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => waterAllPurposeMain = v,
                ),
                const Divider(height: 24),
                Text(
                  '11. What kind of toilet facility HH',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    '(1) Flush Toilet',
                    '(2) Toilet ST',
                    '(3) Pit toilet',
                    '(4) Open Field',
                    '(77) Other'
                  ].map((val) {
                    return SizedBox(
                      width: 150,
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(val),
                        value: val,
                        groupValue: toiletFacility,
                        onChanged: (v) => setState(() => toiletFacility = v),
                      ),
                    );
                  }).toList(),
                ),
                if (toiletFacility == '(77) Other')
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextFormField(
                      controller: _toiletOther,
                      decoration: const InputDecoration(
                        labelText: 'If others, please mention',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
            _buildSectionCard(
              title: 'Socio-Economic Details',
              children: [
                Text(
                  '12. Have ration card?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    '(1) White card',
                    '(2) Pink Card',
                    '(3) No card'
                  ].map((val) {
                    return SizedBox(
                      width: 140,
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(val),
                        value: val,
                        groupValue: rationCard,
                        onChanged: (v) => setState(() => rationCard = v),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 16),
                Text(
                  '13. Religion',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    '(1) Hindu',
                    '(2) Muslim',
                    '(3) Christian'
                  ].map((val) {
                    return SizedBox(
                      width: 130,
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(val),
                        value: val,
                        groupValue: religion,
                        onChanged: (v) => setState(() => religion = v),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 16),
                Text(
                  '14. Cast of the head',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    '(1) SC',
                    '(2) ST',
                    '(3) BC',
                    '(4) FC'
                  ].map((val) {
                    return SizedBox(
                      width: 100,
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(val),
                        value: val,
                        groupValue: caste,
                        onChanged: (v) => setState(() => caste = v),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 16),
                Text(
                  'Household Assets',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 3.5,
                  mainAxisSpacing: 0,
                  children: [
                    'Mattress',
                    'Cot/bed',
                    'Electric Fan',
                    'Pressure cooker',
                    'sewing Machine',
                    'Refrigerator',
                    'Mobile phone',
                    'Any phone',
                    'Bicycle',
                    'Scooter',
                    'Animal cart',
                    'Chair',
                    'Table',
                    'Radio',
                    'Mixer',
                    'Colour TV',
                    'A/C',
                    'Water pump',
                    'Computer',
                    'Tractor',
                    'Car',
                    'Thresher'
                  ].map((item) {
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
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
              ],
            ),
            _buildSectionCard(
              title: 'Agriculture & Livestock',
              children: [
                Text(
                  '16. Any agriculture land?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('(1) Yes'),
                        value: '(1) Yes',
                        groupValue: hasAgricultureLand,
                        onChanged: (v) =>
                            setState(() => hasAgricultureLand = v),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('(2) No'),
                        value: '(2) No',
                        groupValue: hasAgricultureLand,
                        onChanged: (v) =>
                            setState(() => hasAgricultureLand = v),
                      ),
                    ),
                  ],
                ),
                if (hasAgricultureLand == 'yes') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: agricultureLandArea,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Land Area',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          onChanged: (v) => agricultureLandArea = v,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: agricultureLandUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'acre', child: Text('Acre')),
                            DropdownMenuItem(
                                value: 'hectare', child: Text('Hectare')),
                          ],
                          onChanged: (v) =>
                              setState(() => agricultureLandUnit = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '17. Land is irrigated?',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: irrigatedLandArea,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Irrigated Area',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          onChanged: (v) => irrigatedLandArea = v,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: irrigatedLandUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'acre', child: Text('Acre')),
                            DropdownMenuItem(
                                value: 'hectare', child: Text('Hectare')),
                          ],
                          onChanged: (v) =>
                              setState(() => irrigatedLandUnit = v),
                        ),
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    title: const Text('None Irrigated'),
                    value: irrigatedNone,
                    onChanged: (v) => setState(() => irrigatedNone = v!),
                  ),
                ],
                const Divider(height: 24),
                Text(
                  '18. Own any cattle',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                ...[
                  '(1) Cows/Buffaloes',
                  '(2) Bulls',
                  '(3) Goats/Sheep',
                  '(4) Poultry',
                  '(5) None',
                  '(77) Other'
                ].map((val) {
                  return CheckboxListTile(
                    title: Text(val),
                    value: cattleOwned.contains(val),
                    onChanged: (v) {
                      setState(() {
                        v! ? cattleOwned.add(val) : cattleOwned.remove(val);
                      });
                    },
                  );
                }).toList(),
                if (cattleOwned.contains('(77) Other'))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextFormField(
                      controller: _cattleOther,
                      decoration: const InputDecoration(
                        labelText: 'If others, please mention',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
            _buildSectionCard(
              title: 'Health',
              children: [
                Text(
                  '19. get sick, where do they go?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    '(1) Govt.hospital',
                    '(2) MediCiti hospital',
                    '(3) private hospital',
                    '(4) Private MBBS doctor',
                    '(5) RMP',
                    '(6) Medical shop',
                    '(7) Home treatment'
                  ].map((val) {
                    return SizedBox(
                      width: 170,
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(val),
                        value: val,
                        groupValue: healthCarePlace,
                        onChanged: (v) => setState(() => healthCarePlace = v),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 16),
                Text(
                  '20. Why they dont go to Govt. Hospital',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                ...[
                  '(1)No nearby health facility',
                  '(2) timing not convenient',
                  '(3) Health Personnel often absent',
                  '(4) Waiting time too long',
                  '(5)Poor quality of care',
                  '(77) Other'
                ].map((val) {
                  return CheckboxListTile(
                    title: Text(val),
                    value: govtHospitalReasons.contains(val),
                    onChanged: (v) {
                      setState(() {
                        v!
                            ? govtHospitalReasons.add(val)
                            : govtHospitalReasons.remove(val);
                      });
                    },
                  );
                }).toList(),
                if (govtHospitalReasons.contains('(77) Other'))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextFormField(
                      controller: _govtHospitalOther,
                      decoration: const InputDecoration(
                        labelText: 'If others, please mention',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSaving
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  widget.existingData == null ? 'Save Family' : 'Update Family',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}

/* ============================================================
   RECORDS PAGE (TABLE VIEW)
============================================================ */

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  bool _isSyncing = false;
  String? _syncErrorMessage;
  DateTime? _lastSyncTime;
  StreamSubscription? _connectivitySubscription;
  Timer? _autoSyncTimer;

  Future<void> _importFromZoho() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection. Cannot import.')),
        );
      }
      return;
    }

    setState(() => _isSyncing = true);
    int imported = 0;
    int errors = 0;

    try {
      final records = await ZohoCreatorService().fetchRecords();
      if (records.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No records found in Zoho to import.')),
          );
        }
      } else {
        for (final data in records) {
          final familyId = data['family_id'];
          if (familyId == null || familyId.isEmpty) continue;

          try {
            await FirebaseFirestore.instance
                .collection('client')
                .doc(familyId)
                .set(data, SetOptions(merge: true));
            imported++;
          } catch (e) {
            debugPrint('IMPORT ERROR for $familyId: $e');
            errors++;
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported $imported records ($errors errors).'),
              backgroundColor: errors == 0 ? Colors.green : Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('GLOBAL IMPORT ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // 1. Initial sync on load
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPendingRecords(isAuto: true));

    // 2. Sync on connectivity change
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
      if (result != ConnectivityResult.none) {
        _syncPendingRecords(isAuto: true);
      }
    });

    // 3. Periodic sync check (every 1 minute)
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 1), (_) => _syncPendingRecords(isAuto: true));
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _deleteAllRecords() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Records?'),
        content: const Text('This will permanently remove all records from Firebase. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSyncing = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('client').get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All records deleted successfully.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('DELETE ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _syncPendingRecords({bool isAuto = false}) async {
    if (_isSyncing) {
      debugPrint('SYNC: Sync already in progress, skipping ${isAuto ? "auto-sync" : "manual sync"}');
      return;
    }

    // Check connectivity first
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (!isAuto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection. Cannot sync.')),
        );
      }
      return;
    }

    setState(() {
      _isSyncing = true;
      _syncErrorMessage = null;
      _lastSyncTime = DateTime.now();
    });
    int syncCount = 0;
    int errorCount = 0;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('client')
          .where('is_temporary', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 10));

      if (snapshot.docs.isEmpty) {
        if (!isAuto && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No temporary records to sync.')),
          );
        }
        setState(() => _isSyncing = false);
        return;
      }

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final oldId = doc.id;
        String? prefix = data['village_prefix'] as String?;
        
        // Fallback: Recover prefix from ID if missing in data
        if ((prefix == null || prefix.isEmpty) && oldId.startsWith('OFF_')) {
          final parts = oldId.split('_');
          if (parts.length >= 2) {
            prefix = parts[1];
            debugPrint('SYNC: Recovered prefix $prefix from ID $oldId');
          }
        }

        debugPrint('SYNC: Processing $oldId (prefix=$prefix)');

        if (prefix == null || prefix.isEmpty) {
          debugPrint('SYNC ERROR: Missing village_prefix for doc $oldId');
          errorCount++;
          continue;
        }

        try {
          final counterRef = FirebaseFirestore.instance.collection('village_counters').doc(prefix);
          
          // Pre-fetch legacy ID if needed (OUTSIDE transaction)
          int legacySuffix = 0;
          try {
            final counterSnap = await counterRef.get();
            if (!counterSnap.exists) {
              final query = await FirebaseFirestore.instance
                  .collection('client')
                  .where(FieldPath.documentId, isGreaterThanOrEqualTo: prefix)
                  .where(FieldPath.documentId, isLessThan: prefix + 'z')
                  .limitToLast(1)
                  .get();
              if (query.docs.isNotEmpty) {
                final lastId = query.docs.first.id;
                if (!lastId.startsWith('OFF_')) {
                  legacySuffix = int.tryParse(lastId.substring(prefix.length)) ?? 0;
                }
              }
            }
          } catch (e) {
            debugPrint('SYNC: Legacy lookup failed: $e');
          }

          String? finalizedId;
          
          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final counterSnap = await transaction.get(counterRef);
            int lastSuffix = legacySuffix;
            
            if (counterSnap.exists) {
              lastSuffix = counterSnap.data()?['last_suffix'] ?? 0;
            }

            final nextSuffix = lastSuffix + 1;
            finalizedId = '$prefix${nextSuffix.toString().padLeft(3, '0')}';

            debugPrint('SYNC: Transaction block for $oldId: Assigning $finalizedId');

            transaction.set(counterRef, {'last_suffix': nextSuffix}, SetOptions(merge: true));

            final newData = Map<String, dynamic>.from(data);
            newData['family_id'] = finalizedId;
            newData['is_temporary'] = false;
            newData.remove('village_prefix');
            newData['serverUpdatedAt'] = FieldValue.serverTimestamp();

            transaction.set(
              FirebaseFirestore.instance.collection('client').doc(finalizedId!),
              newData,
            );
            transaction.delete(doc.reference);
            debugPrint('SYNC: Transaction block for $oldId: Set/Delete operations queued');
            // Sync to Zoho Creator
            await ZohoCreatorService().syncRecord(newData);
          }).timeout(const Duration(seconds: 10));
          
          syncCount++;
          debugPrint('SYNC: Successfully finalized $oldId as $finalizedId');
        } catch (e) {
          debugPrint('SYNC FAILED for $oldId: $e');
          errorCount++;
          
          final errStr = e.toString().toLowerCase();
          // Stop batch only for clear network/connectivity issues
          bool isHardNetworkError = errStr.contains('timeout') || 
                                   errStr.contains('resolve') || 
                                   errStr.contains('unavailable') ||
                                   errStr.contains('network') ||
                                   errStr.contains('no internet');

          if (isHardNetworkError) {
            debugPrint('SYNC: Connectivity issue detected, stopping batch');
            break;
          } else {
            // Log other errors but keep trying next records
            debugPrint('SYNC: Non-network error for $oldId ($e). Continuing...');
          }
        }
      }

      if (mounted) {
        if (syncCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto-synced $syncCount record(s).'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Global sync error: $e');
      if (mounted) {
        setState(() {
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('unknown') || errStr.contains('developer_error')) {
            _syncErrorMessage = 'Configuration Error (check Firebase SHA-1)';
          } else {
            _syncErrorMessage = e.toString();
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('client')
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        final rawDocs = snapshot.data?.docs ?? [];
        
        // Sort in Dart: Latest first, records without timestamp at the end
        final docs = List<QueryDocumentSnapshot>.from(rawDocs);
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aVal = aData['clientUpdatedAt'] ?? 0;
          final bVal = bData['clientUpdatedAt'] ?? 0;
          return bVal.compareTo(aVal);
        });

        final count = docs.length;
        final hasTemporary = docs.any((doc) =>
            (doc.data() as Map<String, dynamic>)['is_temporary'] == true);

        return Scaffold(
          appBar: AppBar(
            title: Text('All Records ($count)'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                tooltip: 'Delete All Local Records',
                onPressed: _deleteAllRecords,
              ),
              IconButton(
                icon: const Icon(Icons.cloud_download),
                tooltip: 'Import from Zoho',
                onPressed: _importFromZoho,
              ),
            ],
          ),
          body: !snapshot.hasData
              ? const Center(child: Text('Loading...'))
              : Builder(builder: (context) {
                  final fromCache = snapshot.data!.metadata.isFromCache;
                  final syncing = snapshot.data!.metadata.hasPendingWrites;

                  return Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        color: fromCache
                            ? Colors.orange.shade100
                            : Colors.green.shade100,
                        child: Text(
                          _syncErrorMessage != null
                              ? 'Sync error: $_syncErrorMessage'
                              : fromCache
                                  ? 'Offline mode'
                                  : syncing || _isSyncing
                                      ? 'Online – syncing...'
                                      : 'Online – synced',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _syncErrorMessage != null ? Colors.red.shade900 : null,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      // Manual Sync Banner Removed
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(
                                  Colors.grey.shade200),
                              columns: const [
                                DataColumn(label: Text('Family ID')),
                                DataColumn(label: Text('Sync')),
                                DataColumn(label: Text('State')),
                                DataColumn(label: Text('District')),
                                DataColumn(label: Text('Mandal')),
                                DataColumn(label: Text('Village')),
                                DataColumn(label: Text('House No')),
                                DataColumn(label: Text('Head')),
                                DataColumn(label: Text('Fam Type')),
                                DataColumn(label: Text('Fam Status')),
                                DataColumn(label: Text('Own House')),
                                DataColumn(label: Text('Rooms')),
                                DataColumn(label: Text('House Type')),
                                DataColumn(label: Text('Wall')),
                                DataColumn(label: Text('Roof')),
                                DataColumn(label: Text('Floor')),
                                DataColumn(label: Text('Sep Kitchen')),
                                DataColumn(label: Text('Cook Loc')),
                                DataColumn(label: Text('Cook Loc Other')),
                                DataColumn(label: Text('Fuel Types')),
                                DataColumn(label: Text('Fuel Other')),
                                DataColumn(label: Text('Fuel Main')),
                                DataColumn(label: Text('Lighting')),
                                DataColumn(label: Text('Water Sources')),
                                DataColumn(label: Text('Water Src Other')),
                                DataColumn(label: Text('Water Main')),
                                DataColumn(label: Text('Treatment')),
                                DataColumn(label: Text('Treat Other')),
                                DataColumn(label: Text('All Purpose Src')),
                                DataColumn(label: Text('All Purpose Other')),
                                DataColumn(label: Text('Toilet')),
                                 DataColumn(label: Text('Toilet Other')),
                                DataColumn(label: Text('Ration Card')),
                                DataColumn(label: Text('Religion')),
                                DataColumn(label: Text('Caste')),
                                // Assets Start (22 columns)
                                DataColumn(label: Text('Mattress')),
                                DataColumn(label: Text('Cot/bed')),
                                DataColumn(label: Text('Electric Fan')),
                                DataColumn(label: Text('Pressure cooker')),
                                DataColumn(label: Text('sewing Machine')),
                                DataColumn(label: Text('Refrigerator')),
                                DataColumn(label: Text('Mobile phone')),
                                DataColumn(label: Text('Any phone')),
                                DataColumn(label: Text('Bicycle')),
                                DataColumn(label: Text('Scooter')),
                                DataColumn(label: Text('Animal cart')),
                                DataColumn(label: Text('Chair')),
                                DataColumn(label: Text('Table')),
                                DataColumn(label: Text('Radio')),
                                DataColumn(label: Text('Mixer')),
                                DataColumn(label: Text('Colour TV')),
                                DataColumn(label: Text('A/C')),
                                DataColumn(label: Text('Water pump')),
                                DataColumn(label: Text('Computer')),
                                DataColumn(label: Text('Tractor')),
                                DataColumn(label: Text('Car')),
                                DataColumn(label: Text('Thresher')),
                                // Assets End
                                DataColumn(label: Text('Agri Land')),
                                DataColumn(label: Text('Irrigated')),
                                DataColumn(label: Text('Cattle')),
                                DataColumn(label: Text('Cattle Other')),
                                DataColumn(label: Text('Health Place')),
                                DataColumn(label: Text('Hosp Avoid Reasons')),
                                DataColumn(label: Text('Hosp Avoid Other')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: docs.map((doc) {
                                final record = doc.data() as Map<String, dynamic>;
                                final isTemp = record['is_temporary'] == true;

                                return DataRow(
                                  color: isTemp
                                      ? MaterialStateProperty.all(
                                          Colors.orange.shade50)
                                      : null,
                                  cells: [
                                    DataCell(Text(record['family_id'] ?? '')),
                                    DataCell(
                                      isTemp
                                          ? const Icon(Icons.timer, color: Colors.orange, size: 18)
                                          : const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                    ),
                                    DataCell(Text(record['state'] ?? '')),
                                    DataCell(Text(record['district'] ?? '')),
                                    DataCell(Text(record['mandal'] ?? '')),
                                    DataCell(Text(record['village'] ?? '')),
                                    DataCell(Text(record['house_no'] ?? '')),
                                    DataCell(Text(record['head_of_family'] ?? '')),
                                    DataCell(Text(record['family_type'] ?? '')),
                                    DataCell(Text(record['family_status'] ?? '')),
                                    DataCell(Text(record['own_house'] ?? '')),
                                    DataCell(Text(record['no_of_rooms']?.toString() ?? '')),
                                    DataCell(Text(record['type_of_house'] ?? '')),
                                    DataCell(Text(record['wall_type'] ?? '')),
                                    DataCell(Text(record['roof_type'] ?? '')),
                                    DataCell(Text(record['floor_type'] ?? '')),
                                    DataCell(Text(record['separate_kitchen'] ?? '')),
                                    DataCell(Text(record['cooking_location'] ?? '')),
                                    DataCell(Text(record['cooking_location_other'] ?? '')),
                                    DataCell(Text((record['cooking_fuel_types'] as List?)?.join(", ") ?? '')),
                                    DataCell(Text(record['cooking_fuel_other'] ?? '')),
                                    DataCell(Text(record['cooking_fuel_main'] ?? '')),
                                    DataCell(Text(record['lighting_source'] ?? '')),
                                    DataCell(Text((record['water_sources'] as List?)?.join(", ") ?? '')),
                                    DataCell(Text(record['water_source_other'] ?? '')),
                                    DataCell(Text(record['water_main_source'] ?? '')),
                                    DataCell(Text((record['water_treatment'] as List?)?.join(", ") ?? '')),
                                    DataCell(Text(record['water_treatment_other'] ?? '')),
                                    DataCell(Text((record['water_all_sources'] as List?)?.join(", ") ?? '')),
                                    DataCell(Text(record['water_all_other'] ?? '')),
                                    DataCell(Text(record['toilet_facility'] ?? '')),
                                     DataCell(Text(record['toilet_facility_other'] ?? '')),
                                    DataCell(Text(record['ration_card'] ?? '')),
                                    DataCell(Text(record['religion'] ?? '')),
                                    DataCell(Text(record['caste'] ?? '')),
                                    // Asset Cells (22)
                                    ...[
                                      'Mattress', 'Cot/bed', 'Electric Fan', 'Pressure cooker',
                                      'sewing Machine', 'Refrigerator', 'Mobile phone', 'Any phone',
                                      'Bicycle', 'Scooter', 'Animal cart', 'Chair', 'Table',
                                      'Radio', 'Mixer', 'Colour TV', 'A/C', 'Water pump',
                                      'Computer', 'Tractor', 'Car', 'Thresher'
                                    ].map((a) {
                                      final assetList = record['household_assets'] as List? ?? [];
                                      return DataCell(Text(assetList.contains(a) ? '(1) Yes' : '(2) No'));
                                    }),
                                    DataCell(Text('${record['agriculture_land'] ?? ''}\n(${record['agriculture_land_area'] ?? ''} ${record['agriculture_land_unit'] ?? ''})')),
                                    DataCell(Text('${record['irrigated_land_area'] ?? ''} ${record['irrigated_land_unit'] ?? ''}')),
                                    DataCell(Text((record['cattle_owned'] as List?)?.join(", ") ?? '')),
                                    DataCell(Text(record['cattle_other'] ?? '')),
                                    DataCell(Text(record['health_care_place'] ?? '')),
                                    DataCell(Text((record['govt_hospital_reasons'] as List?)?.join(", ") ?? '')),
                                    DataCell(Text(record['govt_hospital_other'] ?? '')),
                                    DataCell(Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => FamilyFormPage(existingData: record),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () {
                                            FirebaseFirestore.instance
                                                .collection('client')
                                                .doc(doc.id)
                                                .delete();
                                          },
                                        ),
                                      ],
                                    )),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
        );
      },
    );
  }
}

class _SearchableListSheet extends StatefulWidget {
  final List<String> items;
  final String title;
  final ScrollController scrollController;

  const _SearchableListSheet({
    required this.items,
    required this.title,
    required this.scrollController,
  });

  @override
  State<_SearchableListSheet> createState() => _SearchableListSheetState();
}

class _SearchableListSheetState extends State<_SearchableListSheet> {
  String _searchQuery = '';
  List<String> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items
            .where((item) => item.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle bar
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search ${widget.title}...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: _filter,
          ),
        ),
        const SizedBox(height: 12),
        // List
        Expanded(
          child: _filteredItems.isEmpty
              ? Center(
                  child: Text(
                    'No results found',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item),
                      onTap: () {
                        Navigator.pop(context, item);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
