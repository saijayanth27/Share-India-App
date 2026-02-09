import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'zoho_creator_service.dart';
import 'bpgluco.dart';
import 'app_drawer.dart';
import 'health_ocr_service.dart';

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
  final String? docId;

  const FamilyFormPage({super.key, this.existingData, this.docId});

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
  String? zohoId;

  String? ownHouse;
  String? selectedState;
  String? selectedDistrict;
  String? selectedMandal;
  String? selectedVillage;

  bool familyIdReadOnly = true;

  String? familyType;
  String? familyStatus;
  List<String> cookingLocations = [];
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
    try {
      final doc = await FirebaseFirestore.instance
          .collection('locations')
          .doc('telangana')
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists) {
        setState(() {
          locationData = doc.data()!;
          isLoadingLocations = false;
        });

        // Debug prints omitted for brevity or kept if needed
      } else {
        setState(() {
          isLoadingLocations = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching locations: $e');
      setState(() {
        isLoadingLocations = false;
        // Optionally set a fallback or error state if needed
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
      _familyId.text = data['family_id'] ?? widget.docId ?? '';
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
      cookingLocations = List<String>.from(data['cooking_location'] ?? []);
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
      final agriRaw = data['agriculture_land'];
      if (agriRaw == 'yes' || agriRaw == '(1) Yes') {
        hasAgricultureLand = '(1) Yes';
      } else if (agriRaw == 'no' || agriRaw == '(2) No') {
        hasAgricultureLand = '(2) No';
      } else {
        hasAgricultureLand = agriRaw;
      }
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

      // ===== ZOHO ID =====
      zohoId = data['zoho_id'];
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

      // familyIdReadOnly = false; (now permanently true)

      selectedState = null;
      selectedDistrict = null;
      selectedMandal = null;
      selectedVillage = null;

      familyType = null;
      familyStatus = null;
      cookingLocations = [];
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
      zohoId = null;
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
        'family_id': finalId,
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
        'cooking_location': cookingLocations,
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
        'zoho_id': zohoId,
        'needs_zoho_sync': true,
        'is_temporary': false, // Ensure this is set for updates
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'serverUpdatedAt': FieldValue.serverTimestamp(),
      };

      bool saveHandled = false;

      if (isEditing) {
        debugPrint('SAVE: Editing existing record $finalId');
        final oldId = widget.docId;
        if (oldId != null && oldId != finalId) {
          debugPrint('SAVE: Family Id changed. Deleting $oldId');
          // No await here to avoid blocking UI if offline
          FirebaseFirestore.instance.collection('client').doc(oldId).delete();
        }

        // Fire and forget local write for immediate feedback
        FirebaseFirestore.instance
            .collection('client')
            .doc(finalId)
            .set(data, SetOptions(merge: true));
        
        saveHandled = true;
        
        // Sync to Zoho in the background if we think we are online
        if (isOnline) {
          _triggerZohoSync(finalId, data);
        }
      } else if (isOnline) {
        debugPrint('SAVE: Online mode, attempting transaction with 5s timeout');
        try {
          // Determine prefix
          String prefix = '';
          if (isTemp) {
            final parts = finalId.split('_');
            if (parts.length >= 2) prefix = parts[1];
          } else if (finalId.length >= 3) {
            prefix = finalId.substring(0, finalId.length - 3);
          }

          if (prefix.isNotEmpty) {
            final counterRef = FirebaseFirestore.instance.collection('village_counters').doc(prefix);
            
            // Pre-fetch legacy ID (quick check)
            int legacySuffix = 0;
            try {
              final counterSnap = await counterRef.get().timeout(const Duration(seconds: 2));
              if (!counterSnap.exists) {
                final query = await FirebaseFirestore.instance
                    .collection('client')
                    .where(FieldPath.documentId, isGreaterThanOrEqualTo: prefix)
                    .where(FieldPath.documentId, isLessThan: prefix + 'z')
                    .limitToLast(1)
                    .get().timeout(const Duration(seconds: 2));
                if (query.docs.isNotEmpty) {
                  final lastId = query.docs.first.id;
                  if (!lastId.startsWith('OFF_')) {
                    legacySuffix = int.tryParse(lastId.substring(prefix.length)) ?? 0;
                  }
                }
              }
            } catch (_) {}

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
            }).timeout(const Duration(seconds: 5));
            
            saveHandled = true;
            _triggerZohoSync(finalId, data);
          }
        } catch (e) {
          debugPrint('SAVE: Online transaction failed/timed out: $e');
        }
      }

      if (!saveHandled) {
        debugPrint('SAVE: Fallback to offline local save');
        String villagePrefix = '';
        if (isTemp) {
          final parts = finalId.split('_');
          if (parts.length >= 2) villagePrefix = parts[1];
        } else if (finalId.length >= 3) {
          villagePrefix = finalId.substring(0, finalId.length - 3);
        }

        // Generate OFF ID if not already one
        if (!finalId.startsWith('OFF_')) {
          finalId = 'OFF_${villagePrefix}_${DateTime.now().millisecondsSinceEpoch}';
        }

        final finalData = Map<String, dynamic>.from(data);
        finalData['family_id'] = finalId;
        finalData['is_temporary'] = true;
        finalData['village_prefix'] = villagePrefix;

        FirebaseFirestore.instance
            .collection('client')
            .doc(finalId)
            .set(finalData);
        debugPrint('SAVE: Local save queued for ID $finalId');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isOnline ? Colors.green : Colors.orange,
            content: Text(isOnline ? 'Record saved (ID: $finalId)' : 'Saved offline (ID: $finalId) - will sync automatically'),
          ),
        );
        if (widget.existingData == null) _resetForm();
        if (Navigator.canPop(context)) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('SAVE CRITICAL ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // New helper method for background sync
  void _triggerZohoSync(String fId, Map<String, dynamic> fData) {
    ZohoCreatorService().syncRecord({'family_id': fId, ...fData}).then((returnedZohoId) {
      if (returnedZohoId != null) {
        FirebaseFirestore.instance
            .collection('client')
            .doc(fId)
            .update({
              'zoho_id': returnedZohoId.toString(),
              'needs_zoho_sync': false,
            });
        debugPrint('SAVE: Background Zoho sync successful for $fId');
      }
    }).catchError((e) {
      debugPrint('SAVE: Background Zoho sync failed for $fId: $e');
    });
  }

  void _openList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecordsPage()),
    );
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
      drawer: const AppDrawer(),
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
                  items: selectedState == null || locationData['districts'] == null
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
                  items: selectedDistrict == null ||
                          locationData['districts'] == null ||
                          locationData['districts'][selectedDistrict] == null
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
                  items: selectedMandal == null ||
                          locationData['districts'] == null ||
                          locationData['districts'][selectedDistrict] == null ||
                          locationData['districts'][selectedDistrict]['mandals']
                                  [selectedMandal] == null
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
                        title: const Text('(1) Yes'),
                        value: '(1) Yes',
                        groupValue: ownHouse,
                        onChanged: (v) => setState(() => ownHouse = v),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('(2) No'),
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
                        value: ['(3) KACHHA', '(2) SEMI PUCCA', '(1) PUCCA'].contains(typeofhouse) 
                            ? typeofhouse : null,
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
                  value: ['(1) PUCCA', '(2) SEMI PUCCA', '(3) KACHHA'].contains(roofType) 
                      ? roofType : null,
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
                  value: ['(1) PUCCA', '(2) SEMI PUCCA', '(3) KACHHA'].contains(wallType) 
                      ? wallType : null,
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
                  value: ['(1) PUCCA', '(2) SEMI PUCCA', '(3) KACHHA'].contains(floorType) 
                      ? floorType : null,
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
                      child: CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(val),
                        value: cookingLocations.contains(val),
                        onChanged: (v) {
                          setState(() {
                            if (v!) {
                              cookingLocations.add(val);
                            } else {
                              cookingLocations.remove(val);
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
                if (cookingLocations.contains('(4) Other'))
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
                  value: ['firewood', 'lpg', 'electric', 'others'].contains(cookingFuel) 
                      ? cookingFuel : null,
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
                        if (v == true) {
                          if (val == '(7) None') {
                            waterTreatment = ['(7) None'];
                          } else {
                            waterTreatment.remove('(7) None');
                            waterTreatment.remove('none');
                            waterTreatment.add(val);
                          }
                        } else {
                          waterTreatment.remove(val);
                        }
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
                      if (v!) {
                        waterTreatment.add('filter');
                        waterTreatment.remove('(7) None');
                        waterTreatment.remove('none');
                      } else {
                        waterTreatment.remove('filter');
                      }
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Bleach / Strain'),
                  value: waterTreatment.contains('chemical'),
                  onChanged: (v) {
                    setState(() {
                      if (v!) {
                        waterTreatment.add('chemical');
                        waterTreatment.remove('(7) None');
                        waterTreatment.remove('none');
                      } else {
                        waterTreatment.remove('chemical');
                      }
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('None / Don’t know'),
                  value: waterTreatment.contains('none'),
                  onChanged: (v) {
                    setState(() {
                      if (v!) {
                        waterTreatment = ['none'];
                      } else {
                        waterTreatment.remove('none');
                      }
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
                    '(4) Open Field'
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
                            setState(() {
                              hasAgricultureLand = v;
                              if (v == '(2) No') {
                                agricultureLandArea = null;
                                agricultureLandUnit = null;
                              }
                            }),
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
                            setState(() {
                              hasAgricultureLand = v;
                              if (v == '(2) No') {
                                agricultureLandArea = null;
                                agricultureLandUnit = null;
                              }
                            }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        key: ValueKey('agriArea_${hasAgricultureLand}_$agricultureLandArea'),
                        initialValue: agricultureLandArea,
                        enabled: hasAgricultureLand == '(1) Yes',
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Number (Area)',
                          border: const OutlineInputBorder(),
                          filled: hasAgricultureLand != '(1) Yes',
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        onChanged: (v) => agricultureLandArea = v,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: (agricultureLandUnit == 'Acres' || agricultureLandUnit == 'Guntas') 
                            ? agricultureLandUnit : null,
                        decoration: InputDecoration(
                          labelText: 'Land Unit',
                          border: const OutlineInputBorder(),
                          filled: hasAgricultureLand != '(1) Yes',
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        items: hasAgricultureLand == '(1) Yes' ? const [
                          DropdownMenuItem(value: 'Acres', child: Text('Acres')),
                          DropdownMenuItem(value: 'Guntas', child: Text('Guntas'))
                        ] : [],
                        onChanged: hasAgricultureLand == '(1) Yes' ? (v) =>
                            setState(() => agricultureLandUnit = v) : null,
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        key: ValueKey('irrArea_${irrigatedNone}_$irrigatedLandArea'),
                        initialValue: irrigatedLandArea,
                        enabled: !irrigatedNone,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Number (Irrigated)',
                          helperText: 'Number you Hold',
                          border: const OutlineInputBorder(),
                          filled: irrigatedNone,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        onChanged: (v) => irrigatedLandArea = v,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: (irrigatedLandUnit == 'Acres' || irrigatedLandUnit == 'Guntas') 
                            ? irrigatedLandUnit : null,
                        decoration: InputDecoration(
                          labelText: 'Land Unit',
                          border: const OutlineInputBorder(),
                          filled: irrigatedNone,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        items: !irrigatedNone ? const [
                          DropdownMenuItem(value: 'Acres', child: Text('Acres')),
                          DropdownMenuItem(value: 'Guntas', child: Text('Guntas')),
                        ] : [],
                        onChanged: !irrigatedNone ? (v) =>
                            setState(() => irrigatedLandUnit = v) : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          const Text('None', style: TextStyle(fontSize: 12)),
                          Checkbox(
                            value: irrigatedNone,
                            onChanged: (v) => setState(() {
                              irrigatedNone = v!;
                              if (irrigatedNone) {
                                irrigatedLandArea = null;
                                irrigatedLandUnit = null;
                              }
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                        if (v == true) {
                          if (val == '(5) None') {
                            cattleOwned = ['(5) None'];
                          } else {
                            cattleOwned.remove('(5) None');
                            cattleOwned.add(val);
                          }
                        } else {
                          cattleOwned.remove(val);
                        }
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

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _activeSearchQuery = '';
  bool _isSearchingActive = false;
  bool _hasSearched = false;
  String _searchField = 'All';
  int _importedCountProgress = 0;
  int _totalRecordCount = 0;
  int _currentLimit = 300;
  bool _isLoadingMore = false;

  // Mapping of UI Label to Firestore/Zoho Data Key
  final Map<String, String> _fieldMapping = {
    'State': 'state',
    'District': 'district',
    'Mandal': 'mandal',
    'Village': 'village',
    'House No': 'house_no',
    'Head': 'head_of_family',
    'Fam Type': 'family_type',
    'Fam Status': 'family_status',
    'Own House': 'own_house',
    'Rooms': 'no_of_rooms',
    'House Type': 'type_of_house',
    'Wall': 'wall_type',
    'Roof': 'roof_type',
    'Floor': 'floor_type',
    'Sep Kitchen': 'separate_kitchen',
    'Cook Loc': 'cooking_location',
    'Cook Loc Other': 'cooking_location_other',
    'Fuel Types': 'cooking_fuel_types',
    'Fuel Other': 'cooking_fuel_other',
    'Fuel Main': 'cooking_fuel_main',
    'Lighting': 'lighting_source',
    'Water Sources': 'water_sources',
    'Water Src Other': 'water_source_other',
    'Water Main': 'water_main_source',
    'Treatment': 'water_treatment',
    'Treat Other': 'water_treatment_other',
    'All Purpose Src': 'water_all_sources',
    'All Purpose Other': 'water_all_other',
    'All Purpose Main': 'water_all_main',
    'Toilet': 'toilet_facility',
    'Toilet Other': 'toilet_facility_other',
    'Ration Card': 'ration_card',
    'Religion': 'religion',
    'Caste': 'caste',
    'Assets': 'household_assets',
    // Individual Assets
    'Mattress': 'household_assets',
    'Cot/bed': 'household_assets',
    'Electric Fan': 'household_assets',
    'Pressure cooker': 'household_assets',
    'sewing Machine': 'household_assets',
    'Refrigerator': 'household_assets',
    'Mobile phone': 'household_assets',
    'Any phone': 'household_assets',
    'Bicycle': 'household_assets',
    'Scooter': 'household_assets',
    'Animal cart': 'household_assets',
    'Chair': 'household_assets',
    'Table': 'household_assets',
    'Radio': 'household_assets',
    'Mixer': 'household_assets',
    'Colour TV': 'household_assets',
    'A/C': 'household_assets',
    'Water pump': 'household_assets',
    'Computer': 'household_assets',
    'Tractor': 'household_assets',
    'Car': 'household_assets',
    'Thresher': 'household_assets',
    // Agriculture
    'Agri Land': 'agriculture_land',
    'Agri Area': 'agriculture_land_area',
    'Agri Unit': 'agriculture_land_unit',
    'Irrigated': 'irrigated_land_area',
    'Irrigated Unit': 'irrigated_land_unit',
    'Irrigated None': 'irrigated_none',
    // Cattle
    'Cattle': 'cattle_owned',
    'Cattle Other': 'cattle_other',
    // Health
    'Health Place': 'health_care_place',
    'Hosp Avoid Reasons': 'govt_hospital_reasons',
    'Hosp Avoid Other': 'govt_hospital_other',
  };

  void _deleteRecord(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('client')
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  DataCell _buildDataCell(String label, Map<String, dynamic> record, QueryDocumentSnapshot doc) {
    if (label == 'Family ID') return DataCell(Text(record['family_id'] ?? doc.id));
    if (label == 'Sync') {
      final isTemp = record['is_temporary'] == true;
      final needsSync = record['needs_zoho_sync'] == true;
      return DataCell(
        (isTemp || needsSync)
            ? const Icon(Icons.timer, color: Colors.orange, size: 18)
            : const Icon(Icons.check_circle, color: Colors.green, size: 18),
      );
    }
    if (label == 'Actions') {
      return DataCell(
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FamilyFormPage(
                    existingData: record,
                    docId: doc.id,
                  ),
                ),
              );
            } else if (value == 'delete') {
              _deleteRecord(doc.id);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit, color: Colors.blue),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      );
    }

    final key = _fieldMapping[label];
    if (key == null) return const DataCell(Text(''));

    final value = record[key];

    // Handle Individual Assets
    const assets = [
      'Mattress', 'Cot/bed', 'Electric Fan', 'Pressure cooker',
      'sewing Machine', 'Refrigerator', 'Mobile phone', 'Any phone',
      'Bicycle', 'Scooter', 'Animal cart', 'Chair', 'Table',
      'Radio', 'Mixer', 'Colour TV', 'A/C', 'Water pump',
      'Computer', 'Tractor', 'Car', 'Thresher'
    ];
    if (assets.contains(label)) {
      final assetList = record['household_assets'] as List? ?? [];
      return DataCell(Text(assetList.contains(label) ? '(1) Yes' : '(2) No'));
    }

    if (value is List) {
      return DataCell(Text(value.join(", ")));
    }

    return DataCell(Text(value?.toString() ?? ''));
  }

  DataColumn _buildSearchColumn(String label) {
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (label != 'Sync' && label != 'Actions')
            IconButton(
              icon: const Icon(Icons.search, size: 16),
              onPressed: () => setState(() {
                _searchField = label;
                _isSearchingActive = true;
              }),
            ),
        ],
      ),
    );
  }

  Future<void> _performFullZohoSync({bool silent = false}) async {
    if (_isSyncing) {
      debugPrint('IMPORT: Already syncing, ignoring request.');
      return;
    }
    
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection. Cannot sync with Zoho.')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSyncing = true;
        _importedCountProgress = 0;
      });
    }
    
    int imported = 0;
    int errors = 0;
    final Set<String> fetchedZohoIds = {};

    try {
      debugPrint('IMPORT: Starting full Zoho fetch...');
      await ZohoCreatorService().fetchRecords(
        onBatch: (batch) async {
          final writeBatch = FirebaseFirestore.instance.batch();
          int batchSaved = 0;

          for (final data in batch) {
            final zidRaw = data['zoho_id']?.toString();
            if (zidRaw == null || zidRaw.isEmpty) continue;

            final zohoId = zidRaw.trim();
            fetchedZohoIds.add(zohoId);

            try {
              final docRef = FirebaseFirestore.instance.collection('client').doc(zohoId);
              writeBatch.set(docRef, data, SetOptions(merge: true));
              batchSaved++;
              imported++;
            } catch (e) {
              debugPrint('IMPORT ERROR for Zoho ID $zohoId: $e');
              errors++;
            }
          }

          if (batchSaved > 0) {
            await writeBatch.commit();
          }
          
          if (mounted) {
            setState(() {
              _importedCountProgress = imported;
              if (imported % 1000 == 0) _totalRecordCount = imported;
            });
          }
        },
      );

      debugPrint('IMPORT: Zoho fetch complete. Found ${fetchedZohoIds.length} records. Starting cleanup...');

      // --- DELETE STALE RECORDS ---
      if (fetchedZohoIds.isNotEmpty) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification: Deleting stale records...'), duration: Duration(seconds: 3)),
          );
        }

        // Force server fetch to ensure we see the latest state and don't rely on cache
        final snapshot = await FirebaseFirestore.instance
            .collection('client')
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(minutes: 5));
        
        debugPrint('IMPORT: Firebase snapshot fetched (${snapshot.docs.length} docs).');
        
        int deletedCount = 0;
        final deleteBatch = FirebaseFirestore.instance.batch();
        int batchSize = 0;

        for (var doc in snapshot.docs) {
          final docId = doc.id.trim();
          final data = doc.data() as Map<String, dynamic>;
          final zid = data['zoho_id']?.toString().trim();
          
          bool isLocalTemp = docId.startsWith('OFF_');
          // If it's not a temp record, and it's NOT in our list from Zoho, it should be deleted
          // We check if the docId is a Zoho ID OR if there's a zoho_id field
          bool isZohoRecord = RegExp(r'^\d{15,}$').hasMatch(docId) || (zid != null && zid.isNotEmpty);

          if (!isLocalTemp && isZohoRecord) {
            final idToCheck = (zid != null && zid.isNotEmpty) ? zid : docId;
            if (!fetchedZohoIds.contains(idToCheck)) {
              debugPrint('IMPORT: Deleting record missing from Zoho: $idToCheck');
              deleteBatch.delete(doc.reference);
              deletedCount++;
              batchSize++;
              
              if (batchSize >= 400) {
                await deleteBatch.commit();
                batchSize = 0;
              }
            }
          }
        }
        
        if (batchSize > 0) {
          await deleteBatch.commit();
        }
        debugPrint('IMPORT: Cleanup complete. Deleted $deletedCount records.');
      }
      
      if (mounted) {
        setState(() => _totalRecordCount = imported);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync successful! Updated $imported records.'),
              backgroundColor: errors == 0 ? Colors.green : Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('GLOBAL SYNC ERROR: $e');
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Start startup tasks concurrently but wrapped to ensure one failure doesn't stop others
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupTasks();
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((dynamic result) async {
      ConnectivityResult finalResult;
      if (result is List) {
        finalResult = result.isNotEmpty ? result.first : ConnectivityResult.none;
      } else {
        finalResult = result;
      }
      if (finalResult != ConnectivityResult.none) {
        _syncPendingRecords(isAuto: true);
      }
    });

    _autoSyncTimer = Timer.periodic(const Duration(minutes: 1), (_) => _syncPendingRecords(isAuto: true));
  }

  Future<void> _runStartupTasks() async {
    // 1. First sync any data created while offline TO Zoho
    try {
      await _syncPendingRecords(isAuto: true);
    } catch (e) {
      debugPrint('Startup: Pending sync failed: $e');
    }

    // 2. Then pull everything FROM Zoho and clean up deletions
    try {
      await _performFullZohoSync(silent: true);
    } catch (e) {
      debugPrint('Startup: Full sync failed: $e');
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _autoSyncTimer?.cancel();
    _searchController.dispose();
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
          .where('needs_zoho_sync', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 15));

      if (snapshot.docs.isEmpty) {
        if (!isAuto && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No records to sync.')),
          );
        }
        setState(() => _isSyncing = false);
        return;
      }

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final oldId = doc.id;
        final isTemp = data['is_temporary'] == true;

        if (isTemp) {
          // --- Case 1: Temporary Record (Needs Permanent ID + Sync) ---
          String? prefix = data['village_prefix'] as String?;
          if ((prefix == null || prefix.isEmpty) && oldId.startsWith('OFF_')) {
            final parts = oldId.split('_');
            if (parts.length >= 2) prefix = parts[1];
          }

          if (prefix == null || prefix.isEmpty) {
            debugPrint('SYNC: Skipping temp doc $oldId due to missing prefix');
            continue;
          }

          try {
            final counterRef = FirebaseFirestore.instance.collection('village_counters').doc(prefix);
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
            } catch (_) {}

            await FirebaseFirestore.instance.runTransaction((transaction) async {
              final counterSnap = await transaction.get(counterRef);
              int lastSuffix = counterSnap.exists ? (counterSnap.data()?['last_suffix'] ?? 0) : legacySuffix;
              final nextSuffix = lastSuffix + 1;
              final finalizedId = '$prefix${nextSuffix.toString().padLeft(3, '0')}';

              transaction.set(counterRef, {'last_suffix': nextSuffix}, SetOptions(merge: true));

              final newData = Map<String, dynamic>.from(data);
              newData['family_id'] = finalizedId;
              newData['is_temporary'] = false;
              newData.remove('village_prefix');
              newData['serverUpdatedAt'] = FieldValue.serverTimestamp();

              transaction.set(FirebaseFirestore.instance.collection('client').doc(finalizedId), newData);
              transaction.delete(doc.reference);

              final zohoId = await ZohoCreatorService().syncRecord(newData);
              if (zohoId != null) {
                final finalZohoId = zohoId.toString();
                newData['zoho_id'] = finalZohoId;
                newData['needs_zoho_sync'] = false;
                transaction.set(FirebaseFirestore.instance.collection('client').doc(finalZohoId), newData);
                transaction.delete(FirebaseFirestore.instance.collection('client').doc(finalizedId));
              }
            }).timeout(const Duration(seconds: 15));
            syncCount++;
          } catch (e) {
            debugPrint('SYNC TEMP ERROR for $oldId: $e');
            errorCount++;
          }
        } else {
          // --- Case 2: Permanent Record Update (Already has permanent ID/Zoho ID) ---
          try {
            final zohoId = await ZohoCreatorService().syncRecord(data);
            if (zohoId != null) {
              await doc.reference.update({
                'needs_zoho_sync': false,
                'zoho_id': zohoId.toString(),
              });
              syncCount++;
              debugPrint('SYNC UPDATE: Successfully updated Zoho for ${doc.id}');
            }
          } catch (e) {
            debugPrint('SYNC UPDATE ERROR for ${doc.id}: $e');
            errorCount++;
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

      // TRIGGER BACKGROUND HEALTH OCR
      HealthOCRService.processPendingReadings();
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

  Stream<QuerySnapshot> _buildStream() {
    Query query = FirebaseFirestore.instance.collection('client');

    if (_activeSearchQuery.isEmpty) {
      return query
          .orderBy('clientUpdatedAt', descending: true)
          .limit(_currentLimit)
          .snapshots(includeMetadataChanges: true);
    }

    // Search Mode
    if (_searchField == 'Family ID') {
      return query
          .where('family_id', isGreaterThanOrEqualTo: _activeSearchQuery)
          .where('family_id',
              isLessThanOrEqualTo: '$_activeSearchQuery\uf8ff')
          .limit(_currentLimit)
          .snapshots(includeMetadataChanges: true);
    } else if (_fieldMapping.containsKey(_searchField)) {
      final key = _fieldMapping[_searchField]!;
      return query
          .where(key, isGreaterThanOrEqualTo: _activeSearchQuery)
          .where(key, isLessThanOrEqualTo: '$_activeSearchQuery\uf8ff')
          .limit(_currentLimit)
          .snapshots(includeMetadataChanges: true);
    } else {
      // 'All' search: We fetch a larger batch for local filtering
      // as Firestore doesn't support 'search all fields'.
      return query
          .limit(_currentLimit > 1000 ? _currentLimit : 1000)
          .snapshots(includeMetadataChanges: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildStream(),
      builder: (context, snapshot) {
        final rawDocs = snapshot.data?.docs ?? [];
        
        // Filter by search query
            var docs = List<QueryDocumentSnapshot>.from(rawDocs);
            if (_activeSearchQuery.isNotEmpty) {
              final query = _activeSearchQuery.toLowerCase();
              docs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;

                if (_searchField == 'Family ID') {
                  final famId = data['family_id']?.toString() ?? '';
                  return famId.toLowerCase().contains(query);
                } else if (_fieldMapping.containsKey(_searchField)) {
                  final key = _fieldMapping[_searchField]!;
                  final value = data[key];
                  if (value == null) return false;
                  if (value is List) {
                    return value.any((item) =>
                        item.toString().toLowerCase().contains(query));
                  }
                  return value.toString().toLowerCase().contains(query);
                } else {
                  // 'All' search: Check all values in the record data
                  bool matchFound = data.values.any((value) {
                    if (value == null) return false;
                    if (value is List) {
                      return value.any((item) =>
                          item.toString().toLowerCase().contains(query));
                    }
                    return value.toString().toLowerCase().contains(query);
                  });
                  // Also check the doc ID (Family ID) in 'All' search
                  if (matchFound) return true;
                  return doc.id.toLowerCase().contains(query);
                }
              }).toList();
            }

            if (docs.isEmpty && _hasSearched) {
              return Scaffold(
                appBar: AppBar(
                    title: Text('All Records (${rawDocs.length})'),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => setState(() {
                          _activeSearchQuery = '';
                          _hasSearched = false;
                          _searchController.clear();
                          _isSearchingActive = false;
                        }),
                      )
                    ]),
                body: const Center(
                  child: Text(
                    'No records found matching your search.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              );
            }

        // Sort in Dart: Latest first, records without timestamp at the end
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aVal = aData['clientUpdatedAt'] ?? 0;
          final bVal = bData['clientUpdatedAt'] ?? 0;
          return bVal.compareTo(aVal);
        });

        final count = snapshot.data?.size ?? 0;
        
        // Update Total Count via Aggregate Query (Fast)
        if (snapshot.hasData) {
          // Update total count live from the database
          FirebaseFirestore.instance.collection('client').count().get().then((agg) {
            if (mounted && _totalRecordCount != agg.count) {
              setState(() => _totalRecordCount = agg.count ?? 0);
            }
          });
        }

        final loadedCount = docs.length;
        final titleText = _isSyncing 
            ? 'Importing $_importedCountProgress... (Total: $_totalRecordCount)' 
            : 'Records ($loadedCount / $_totalRecordCount)';
        final hasTemporary = docs.any((doc) =>
            (doc.data() as Map<String, dynamic>)['is_temporary'] == true);

        return Scaffold(
          appBar: AppBar(
            title: _isSearchingActive
                ? Row(
                    children: [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.filter_list),
                        initialValue: _searchField,
                        onSelected: (val) => setState(() => _searchField = val),
                        itemBuilder: (context) {
                          final items = <String>['All', 'Family ID'];
                          items.addAll(_fieldMapping.keys);
                          return items
                              .map((f) =>
                                  PopupMenuItem(value: f, child: Text(f)))
                              .toList();
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search $_searchField...',
                            border: InputBorder.none,
                            hintStyle: const TextStyle(color: Colors.black54),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search, color: Colors.blue),
                              onPressed: () {
                                setState(() {
                                  _activeSearchQuery = _searchController.text;
                                  _hasSearched = true;
                                });
                              },
                            ),
                          ),
                          style: const TextStyle(
                              color: Colors.black87, fontSize: 18),
                          onSubmitted: (value) {
                            setState(() {
                              _activeSearchQuery = value;
                              _hasSearched = true;
                            });
                          },
                        ),
                      ),
                    ],
                  )
                : const Text('Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            actions: [
              if (_isSearchingActive)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _isSearchingActive = false;
                      _activeSearchQuery = '';
                      _hasSearched = false;
                      _searchField = 'All';
                      _searchController.clear();
                    });
                  },

                )
              else
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _isSearchingActive = true;
                    });
                  },
                ),
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                tooltip: 'Delete All Local Records',
                onPressed: _deleteAllRecords,
              ),
              IconButton(
                icon: const Icon(Icons.cloud_download),
                tooltip: 'Import from Zoho',
                onPressed: () => _performFullZohoSync(silent: false),
              ),
            ],
          ),
          drawer: const AppDrawer(),
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
                              : '${fromCache ? 'Offline mode' : syncing || _isSyncing ? 'Online – syncing...' : 'Online – synced'}  |  $loadedCount / $_totalRecordCount records',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _syncErrorMessage != null ? Colors.red.shade900 : null,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Manual Sync Banner Removed
                      Expanded(
                        child: ListView(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(
                                    Colors.grey.shade200),
                                  columns: [
                                    const DataColumn(label: Text('Actions')),
                                    _buildSearchColumn('Family ID'),
                                    const DataColumn(label: Text('Sync')),
                                    ..._fieldMapping.keys
                                        .map((label) => _buildSearchColumn(label))
                                        .toList(),
                                  ],
                                rows: docs.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final doc = entry.value;
                                  final record = doc.data() as Map<String, dynamic>;
                                  final isTemp = record['is_temporary'] == true;

                                  return DataRow(
                                    color: isTemp
                                        ? MaterialStateProperty.all(
                                            Colors.orange.shade50)
                                        : null,
                                    cells: [
                                      _buildDataCell('Actions', record, doc),
                                      _buildDataCell('Family ID', record, doc),
                                      _buildDataCell('Sync', record, doc),
                                      ..._fieldMapping.keys
                                          .map((label) =>
                                              _buildDataCell(label, record, doc))
                                          .toList(),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                            if (loadedCount < _totalRecordCount)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        'Showing $loadedCount of $_totalRecordCount records',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton.icon(
                                        onPressed: _isLoadingMore ? null : () async {
                                          setState(() => _isLoadingMore = true);
                                          // Small delay to show loading state if it's too fast
                                          await Future.delayed(const Duration(milliseconds: 300));
                                          if (mounted) {
                                            setState(() {
                                              _currentLimit += 500;
                                              _isLoadingMore = false;
                                            });
                                          }
                                        },
                                        icon: _isLoadingMore 
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Icon(Icons.add),
                                        label: Text(_isLoadingMore ? 'Loading...' : 'Load 500 More'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else if (_totalRecordCount > 0)
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Center(
                                  child: Text(
                                    'All $_totalRecordCount records loaded',
                                    style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ),
                          ],
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
