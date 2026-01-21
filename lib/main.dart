import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

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

  String? typeofhouse;
  int? noOfRooms;
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

      ownHouse = null;
      typeofhouse = null;
      noOfRooms = null;
      roofType = null;
      wallType = null;
      floorType = null;

      cookingFuel = null;
      separateKitchen = null;
      cookingFuelTypes = [];
      cookingFuelMain = null;

      lightingSource = null;

      waterSources = [];
      waterMainSource = null;
      waterTreatment = [];
      waterAllPurposeSources = [];
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
      cattleOther = null;

      healthCarePlace = null;
      govtHospitalReasons = [];
      govtHospitalOther = null;
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

      bool saveHandled = false;

      if (isEditing) {
        debugPrint('SAVE: Editing existing record $finalId');
        await FirebaseFirestore.instance
            .collection('client')
            .doc(finalId)
            .set(data, SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));
        saveHandled = true;
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
                        value: 'yes',
                        groupValue: ownHouse,
                        onChanged: (v) => setState(() => ownHouse = v),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('No'),
                        value: 'no',
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
                        decoration: const InputDecoration(
                          labelText: 'Type of House',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        value: typeofhouse,
                        items: const [
                          DropdownMenuItem(
                              value: 'kutcha', child: Text('Kutcha')),
                          DropdownMenuItem(
                              value: 'semi_pucca', child: Text('Semi Pucca')),
                          DropdownMenuItem(
                              value: 'pucca', child: Text('Pucca')),
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
                  decoration: const InputDecoration(
                    labelText: 'Type of Roof',
                    border: OutlineInputBorder(),
                  ),
                  value: roofType,
                  items: const [
                    DropdownMenuItem(value: 'thatch', child: Text('Thatch')),
                    DropdownMenuItem(value: 'tiles', child: Text('Tiles')),
                    DropdownMenuItem(value: 'cement', child: Text('Cement')),
                  ],
                  onChanged: (v) => setState(() => roofType = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Type of Wall',
                    border: OutlineInputBorder(),
                  ),
                  value: wallType,
                  items: const [
                    DropdownMenuItem(value: 'mud', child: Text('Mud')),
                    DropdownMenuItem(value: 'brick', child: Text('Brick')),
                    DropdownMenuItem(value: 'cement', child: Text('Cement')),
                  ],
                  onChanged: (v) => setState(() => wallType = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Type of Floor',
                    border: OutlineInputBorder(),
                  ),
                  value: floorType,
                  items: const [
                    DropdownMenuItem(value: 'mud', child: Text('Mud')),
                    DropdownMenuItem(value: 'cement', child: Text('Cement')),
                    DropdownMenuItem(value: 'tiles', child: Text('Tiles')),
                  ],
                  onChanged: (v) => setState(() => floorType = v),
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Energy & Utilities',
              children: [
                DropdownButtonFormField<String>(
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
                        title: const Text('Yes'),
                        value: 'yes',
                        groupValue: separateKitchen,
                        onChanged: (v) => setState(() => separateKitchen = v),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('No'),
                        value: 'no',
                        groupValue: separateKitchen,
                        onChanged: (v) => setState(() => separateKitchen = v),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  'Type of fuel used for cooking?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
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
                  title: const Text('Wood / Coal / Crop Residue'),
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
                  'Main source of lighting?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 8,
                  children:
                      ['electricity', 'kerosene', 'oil', 'gas'].map((val) {
                    return SizedBox(
                      width: 150, // width constraint to fit 2 per row approx
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(val[0].toUpperCase() + val.substring(1)),
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
                  'Source of water (Select all that apply)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                CheckboxListTile(
                  title: const Text('Piped Water'),
                  value: waterSources.contains('piped'),
                  onChanged: (v) {
                    setState(() {
                      v!
                          ? waterSources.add('piped')
                          : waterSources.remove('piped');
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Bore Well / Dug Well'),
                  value: waterSources.contains('well'),
                  onChanged: (v) {
                    setState(() {
                      v!
                          ? waterSources.add('well')
                          : waterSources.remove('well');
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Surface / Tanker / Bottled'),
                  value: waterSources.contains('other'),
                  onChanged: (v) {
                    setState(() {
                      v!
                          ? waterSources.add('other')
                          : waterSources.remove('other');
                    });
                  },
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
                  'Do you treat water?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
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
                  'Source of water for all purposes',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
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
                  initialValue: waterAllPurposeMain,
                  decoration: const InputDecoration(
                    labelText: 'Mainly used source',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => waterAllPurposeMain = v,
                ),
                const Divider(height: 24),
                Text(
                  'Toilet Facility',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Flush'),
                        value: 'flush',
                        groupValue: toiletFacility,
                        onChanged: (v) => setState(() => toiletFacility = v),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Pit'),
                        value: 'pit',
                        groupValue: toiletFacility,
                        onChanged: (v) => setState(() => toiletFacility = v),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Open'),
                        value: 'open',
                        groupValue: toiletFacility,
                        onChanged: (v) => setState(() => toiletFacility = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Socio-Economic Details',
              children: [
                Text(
                  'Have Ration Card?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 4,
                  children: ['White', 'Pink', 'No Card'].map((val) {
                    final key = val == 'No Card' ? 'none' : val.toLowerCase();
                    return SizedBox(
                      width: 100,
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(val),
                        value: key,
                        groupValue: rationCard,
                        onChanged: (v) => setState(() => rationCard = v),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 16),
                Text(
                  'Religion',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 4,
                  children:
                      ['Hindu', 'Muslim', 'Christian', 'Other'].map((val) {
                    final key = val.toLowerCase();
                    return SizedBox(
                      width: 100,
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(val),
                        value: key,
                        groupValue: religion,
                        onChanged: (v) => setState(() => religion = v),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 16),
                Text(
                  'Caste of the Head',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 4,
                  children: ['SC', 'ST', 'BC', 'OC'].map((val) {
                    final key = val.toLowerCase();
                    return SizedBox(
                      width: 80,
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(val),
                        value: key,
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
                        title: const Text('Yes'),
                        value: 'yes',
                        groupValue: hasAgricultureLand,
                        onChanged: (v) =>
                            setState(() => hasAgricultureLand = v),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('No'),
                        value: 'no',
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
                  '18. Own any cattle?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
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
                      v!
                          ? cattleOwned.add('bulls')
                          : cattleOwned.remove('bulls');
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Goats / Sheep'),
                  value: cattleOwned.contains('goats'),
                  onChanged: (v) {
                    setState(() {
                      v!
                          ? cattleOwned.add('goats')
                          : cattleOwned.remove('goats');
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
                  initialValue: cattleOther,
                  decoration: const InputDecoration(
                    labelText: 'If others, please mention',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => cattleOther = v,
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Health',
              children: [
                Text(
                  '19. Where do they go if sick?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 4,
                  children:
                      ['Govt', 'Private', 'Medical Shop', 'Home'].map((val) {
                    final key = {
                      'Govt': 'govt',
                      'Private': 'private',
                      'Medical Shop': 'medical_shop',
                      'Home': 'home'
                    }[val];
                    return SizedBox(
                      width: 140, // width constraint
                      child: RadioListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: EdgeInsets.zero,
                        title: Text(val),
                        value: key,
                        groupValue: healthCarePlace,
                        onChanged: (v) => setState(() => healthCarePlace = v),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 16),
                Text(
                  '20. Why not Govt Hospital?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                CheckboxListTile(
                  title: const Text('No nearby facility'),
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
                  title: const Text('Timing inconvenient'),
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
                  title: const Text('Personnel absent'),
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
                  title: const Text('Poor quality'),
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
                  initialValue: govtHospitalOther,
                  decoration: const InputDecoration(
                    labelText: 'If others, please mention',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => govtHospitalOther = v,
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
          .orderBy('clientUpdatedAt', descending: true)
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        final docs = snapshot.data?.docs ?? [];
        final hasTemporary = docs.any((doc) =>
            (doc.data() as Map<String, dynamic>)['is_temporary'] == true);

        return Scaffold(
          appBar: AppBar(
            title: Text('All Records ($count)'),
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
                                DataColumn(label: Text('Family ID')), // 1
                                DataColumn(label: Text('Status')), // NEW
                                DataColumn(label: Text('State')),
                                DataColumn(label: Text('District')),
                                DataColumn(label: Text('Mandal')),
                                DataColumn(label: Text('Village')),
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
                                final isTemp = data['is_temporary'] == true;

                                return DataRow(
                                  color: isTemp
                                      ? MaterialStateProperty.all(
                                          Colors.orange.shade50)
                                      : null,
                                  cells: [
                                    DataCell(
                                      Text(data['family_id'] ?? '',
                                          style: TextStyle(
                                            fontWeight: isTemp
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isTemp
                                                ? Colors.orange.shade900
                                                : Colors.black,
                                          )),
                                    ),
                                    DataCell(
                                      isTemp
                                          ? const Tooltip(
                                              message: 'Temporary Record',
                                              child: Icon(Icons.timer,
                                                  color: Colors.orange,
                                                  size: 18),
                                            )
                                          : const Icon(Icons.check_circle,
                                              color: Colors.green, size: 18),
                                    ),
                                    DataCell(Text(data['state'] ?? '')),
                                    DataCell(Text(data['district'] ?? '')),
                                    DataCell(Text(data['mandal'] ?? '')),
                                    DataCell(Text(data['village'] ?? '')),
                                    DataCell(Text(data['house_no'] ?? '')),
                                    DataCell(Text(
                                        data['head_of_family'] ?? '')),
                                    DataCell(
                                        Text(data['own_house'] ?? '')),
                                    DataCell(
                                        Text(data['type_of_house'] ?? '')),
                                    DataCell(Text(
                                        data['no_of_rooms']?.toString() ??
                                            '')),
                                    DataCell(Text(
                                        data['separate_kitchen'] ?? '')),
                                    DataCell(
                                      Text(
                                        (data['cooking_fuel_types'] as List?)
                                                ?.join(', ') ??
                                            '',
                                      ),
                                    ),
                                    DataCell(Text(
                                        data['cooking_fuel_main'] ?? '')),
                                    DataCell(Text(
                                        data['lighting_source'] ?? '')),
                                    DataCell(
                                      Text(
                                        (data['water_sources'] as List?)
                                                ?.join(', ') ??
                                            '',
                                      ),
                                    ),
                                    DataCell(Text(
                                        data['water_main_source'] ?? '')),
                                    DataCell(
                                      Text(
                                        (data['water_treatment'] as List?)
                                                ?.join(', ') ??
                                            '',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        (data['water_all_sources'] as List?)
                                                ?.join(', ') ??
                                            '',
                                      ),
                                    ),
                                    DataCell(
                                        Text(data['toilet_facility'] ?? '')),
                                    DataCell(
                                        Text(data['ration_card'] ?? '')),
                                    DataCell(Text(data['religion'] ?? '')),
                                    DataCell(Text(data['caste'] ?? '')),
                                    DataCell(
                                      Text(
                                        (data['household_assets'] as List?)
                                                ?.join(', ') ??
                                            '',
                                      ),
                                    ),
                                    DataCell(
                                        Text(data['agriculture_land'] ?? '')),
                                    DataCell(Text(
                                        data['irrigated_land_area'] ?? '')),
                                    DataCell(
                                      Text(
                                        (data['cattle_owned'] as List?)
                                                ?.join(', ') ??
                                            '',
                                      ),
                                    ),
                                    DataCell(
                                        Text(data['health_care_place'] ?? '')),
                                    DataCell(
                                      Text(
                                        (data['govt_hospital_reasons'] as List?)
                                                ?.join(', ') ??
                                            '',
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blue),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => FamilyFormPage(
                                                  existingData: data),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () {
                                          FirebaseFirestore.instance
                                              .collection('client')
                                              .doc(doc.id)
                                              .delete();
                                        },
                                      ),
                                    ),
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
