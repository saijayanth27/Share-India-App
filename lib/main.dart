import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'zoho_creator_service.dart';
import 'app_drawer.dart';
import 'health_ocr_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'data_cache_service.dart';
import 'local_database_service.dart';
import 'home_page.dart';
import 'widget.dart';
import 'personal_details_page.dart';
import 'sync_service.dart';
import 'location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'admin_dashboard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Set Firestore settings for unlimited offline cache
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await dotenv.load(fileName: ".env");

  // Initialize Location Service with local cache and background refresh
  await LocationService().init();
  
  // Start the background sync service to auto-sync offline records when network is available

  SyncService().initialize();

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
      title: 'Share India',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          primary: Colors.indigo.shade700,
          secondary: Colors.blue.shade600,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 16),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
        ),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const HomePage();
          }
          return const LoginPage();
        },
      ),

    );
  }
}



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

  final _familyId = TextEditingController(text: 'TSRRMED');
  final _houseNo = TextEditingController();
  final _head = TextEditingController();
  Map<String, dynamic> locationData = {};
  bool isLoadingLocations = true;
  bool _isSaving = false;
  bool _isEditingFromSearch = false;

  // --- NEW: Sync State for FamilyFormPage ---
  bool _isSyncing = false;
  int _importedCountProgress = 0;
  int _totalRecordCount = 0;
  int _lastSyncProgress = 0;
  DocumentSnapshot? _lastSyncDoc;
  bool _isSyncResumable = false;
  bool _isActionActive = false;
  bool _familyCodesAlreadyDownloaded = false;
  String? _familyCodesDownloadedAt;
  // ------------------------------------------
  String? zohoId;
  String? ownHouse;
  String? selectedState = 'TELANGANA';
  String? selectedDistrict = 'Medchal-Malkajgiri';
  String? selectedMandal = 'Medchal';
  String? selectedVillage;
  final FocusNode _headNode = FocusNode();
  final FocusNode _familyIdNode = FocusNode();



  bool familyIdReadOnly = false;

  String? familyType;
  String? familyStatus;
  List<String> cookingLocations = [];
  final _cookingLocationOther = TextEditingController();
  final _cookingLocationMain = TextEditingController();
  String? typeofhouse;
  int? noOfRooms;
  String? roofType;
  String? wallType;
  String? floorType;
  List<String> cookingFuelTypes = [];
  final _cookingFuelOther = TextEditingController();
  final _cookingFuelMainController = TextEditingController();
  String? cookingFuelMain; // Keep for compatibility if needed elsewhere
  String? lightingSource;
  List<String> waterSources = [];
  final _waterSourceOther = TextEditingController();
  final _waterMainSourceController = TextEditingController();
  String? waterMainSource;
  List<String> waterTreatment = [];
  final _waterTreatmentOther = TextEditingController();
  List<String> waterAllPurposeSources = [];
  final _waterAllPurposeOther = TextEditingController();
  final _waterAllPurposeMainController = TextEditingController();
  String? waterAllPurposeMain;
  String? toiletFacility;
  String? rationCard;
  String? religion;
  String? caste;
  List<String> householdAssets = [];
  List<String> householdAssetsNotOwned = [];
  String? separateKitchen;
  String? hasAgricultureLand;
  final _agriLandArea = TextEditingController();
  String? agriLandUnit;
  String? isIrrigated;
  final _irrigatedLandArea = TextEditingController();
  String? irrigatedLandUnit;
  bool irrigatedNone = false;
  String? ownsCattle;
  List<String> cattleOwned = [];
  final _cattleOther = TextEditingController();
  String? healthCarePlace;
  List<String> govtHospitalReasons = [];
  final _govtHospitalOther = TextEditingController();
  final _toiletOther = TextEditingController();

  // --- New Agriculture Questions (Q15-Q17) ---
  String? leaseLand;
  String? usesPesticides;
  String? protectiveEquipment;
  List<String> protectiveEquipmentItems = [];

  // --- Pets & Rodents (Q19-Q20) ---
  String? ownsPets;
  List<String> petsOwned = [];
  final _petsOther = TextEditingController();
  String? hasRodents;
  List<String> rodentTypes = [];

  // --- Health Events (Q23-Q26) ---
  String? feverHospitalAdmission;
  final _feverHospitalStay = TextEditingController();
  String? snakeBiteHistory;
  final _snakeBiteOutcome = TextEditingController();
  String? dogBiteHistory;
  final _dogBiteOutcome = TextEditingController();
  String? surveyParticipation;
  final _surveyProject1 = TextEditingController();
  final _surveyProject2 = TextEditingController();
  final _surveyProject3 = TextEditingController();

  List<String> availableStates = ['Telangana'];

  Future<void> fetchLocations() async {
    setState(() => isLoadingLocations = true);
    
    // Get available states list
    final states = await LocationService().getAvailableStates();
    
    setState(() {
      availableStates = states;
      locationData = LocationService().locationData;
      isLoadingLocations = false;

      // Set defaults for new records
      if (widget.existingData == null && !_isEditingFromSearch) {
        if (availableStates.contains('Telangana')) {
          selectedState = 'Telangana';
        }
        final districts = locationData['districts'] as Map<String, dynamic>?;
        if (districts != null && (districts.containsKey('Medchal Malkajgiri') || districts.containsKey('Medchal-Malkajgiri'))) {
          selectedDistrict = districts.containsKey('Medchal Malkajgiri') ? 'Medchal Malkajgiri' : 'Medchal-Malkajgiri';
          final mKey = districts.containsKey('Medchal Malkajgiri') ? 'Medchal Malkajgiri' : 'Medchal-Malkajgiri';
          final mandals = districts[mKey]['mandals'] as Map<String, dynamic>?;
          if (mandals != null && mandals.containsKey('Medchal')) {
            selectedMandal = 'Medchal';
          }
        }
      }
    });

    if (widget.existingData == null && !_isEditingFromSearch) {
      _generateFamilyId();
    }

    // If a record was already loaded from SQLite (before locationData was ready),
    // decode its family ID now that locationData is available.
    if (_isEditingFromSearch && selectedState == null) {
      final fId = _familyId.text.trim();
      if (fId.isNotEmpty) _decodeAndApplyLocation(fId);
    }
  }

  // _mergeMappings logic moved to LocationService

  @override
  void initState() {
    super.initState();
    fetchLocations();
    
    // Generate initial ID based on defaults
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateFamilyId();
    });

    if (widget.existingData != null) {
      _populateForm(widget.existingData!, widget.docId ?? widget.existingData!['family_id'] ?? '');
    }
    _loadFamilyDownloadStatus();
  }

  Future<void> _loadFamilyDownloadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString('family_codes_download_timestamp');
    if (ts != null && mounted) {
      setState(() {
        _familyCodesAlreadyDownloaded = true;
        _familyCodesDownloadedAt = ts;
      });
    }
  }

  String? _matchOption(dynamic val, List<String> options) {
    if (val == null) return null;
    final s = val.toString().trim();
    if (s.isEmpty) return null;
    
    // 1. Exact match
    for (var opt in options) {
      if (opt == s) return opt;
    }
    
    // 2. Match pattern "(X) Name" where X is the value
    for (var opt in options) {
      if (opt.startsWith('($s)')) return opt;
    }
    
    // 3. Fallback: partially match if the value is contained in parentheses
    for (var opt in options) {
      if (opt.contains('($s)')) return opt;
    }
    
    return null;
  }

  void _populateForm(Map<String, dynamic> rawData, String docId) {
    debugPrint('POPULATE: Received data for $docId: ${rawData.keys.toList()}');
    final data = rawData.map((key, value) => MapEntry(key.toLowerCase(), value));
    // REACH stores binary flags as integer 1/0; app stores as string '1'/'0'.
    // isOne() handles both so old REACH imports don't silently fail.
    bool isOne(dynamic v) => v != null && v.toString().trim() == '1';

    setState(() {
      _isEditingFromSearch = true;
      
      // ===== BASIC DETAILS =====
      _familyId.text = (data['family_id'] ?? data['fam_id'] ?? data['fam_id_old'] ?? docId).toString();
      _houseNo.text = (data['house_no'] ?? data['hno'] ?? data['house no'] ?? '').toString();
      _head.text = (data['head_of_family'] ?? data['name'] ?? data['head'] ?? data['head_name'] ?? '').toString();
      familyIdReadOnly = true;

      // ===== LOCATION DETAILS =====
      selectedState = data['state']?.toString();
      selectedDistrict = data['district']?.toString();
      selectedMandal = data['mandal']?.toString();
      selectedVillage = data['village']?.toString();

      // ===== NEW FIELDS =====
      familyType = _matchOption(data['family_type'] ?? data['fam_type'], ['(1) Nuclear Family', '(0) Joint Family']);
      familyStatus = _matchOption(data['family_status'] ?? data['active_st'], ['(1) Active', '(0) Vacant']);
      
      cookingLocations = [];
      final cookLocRaw = data['cooking_location'] ?? data['kplace'];
      if (cookLocRaw is List) {
        cookingLocations = List<String>.from(cookLocRaw);
      } else if (cookLocRaw != null) {
        final matched = _matchOption(cookLocRaw, ['(1) In the House', '(2) In a seperate Building', '(3) Outdoors', '(4) Other']);
        if (matched != null) cookingLocations.add(matched);
      }
      _cookingLocationOther.text = (data['cooking_location_other'] ?? data['kplace_oth'] ?? '').toString();

      // ===== HOUSE DETAILS =====
      ownHouse = _matchOption(data['own_house'] ?? data['ownhouse'], ['(1) Yes', '(2) No']);
      typeofhouse = _matchOption(data['type_of_house'] ?? data['typhouse'], ['(3) KACHHA', '(2) SEMI PUCCA', '(1) PUCCA']);
      
      final roomsRaw = data['no_of_rooms'] ?? data['norooms'] ?? data['rooms'];
      noOfRooms = int.tryParse(roomsRaw?.toString() ?? '');
      
      roofType = _matchOption(data['roof_type'] ?? data['roof'], ['(1) PUCCA', '(2) SEMI PUCCA', '(3) KACHHA']);
      wallType = _matchOption(data['wall_type'] ?? data['wall'], ['(1) PUCCA', '(2) SEMI PUCCA', '(3) KACHHA']);
      floorType = _matchOption(data['floor_type'] ?? data['floor'], ['(1) PUCCA', '(2) SEMI PUCCA', '(3) KACHHA']);

      // ===== COOKING =====
      
      cookingFuelTypes = [];
      final cookFuelRaw = data['cooking_fuel_types'] ?? data['typcookfuel'];
      if (cookFuelRaw is List) {
        cookingFuelTypes = List<String>.from(cookFuelRaw);
      } else {
        if (isOne(data['typcookfuel_lpg'])) cookingFuelTypes.add('(2) LPG/N.GAS');
        if (isOne(data['typcookfuel_ele'])) cookingFuelTypes.add('(1) Electricity');
        if (isOne(data['typcookfuel_ker'])) cookingFuelTypes.add('(3) Kerosene');
        if (isOne(data['typcookfuel_woo'])) cookingFuelTypes.add('(4) Wood');
        if (isOne(data['typcookfuel_coa'])) cookingFuelTypes.add('(5) Coal');
        if (isOne(data['typcookfuel_crp'])) cookingFuelTypes.add('(6) Crop Residues');
        if (isOne(data['typcookfuel_dun'])) cookingFuelTypes.add('(7) Dung Cakes');
        if (isOne(data['typcookfuel_oth'])) cookingFuelTypes.add('(77) Other');
      }
      
      _cookingFuelOther.text = (data['cooking_fuel_other'] ?? data['typcookfuel_spy'] ?? '').toString();
      final fuelMainValue = _matchOption(data['cooking_fuel_main'] ?? data['typcookfuel_main'], ['(1) Electricity', '(2) LPG/N.GAS', '(3) Kerosene', '(4) Wood', '(5) Coal', '(6) Crop Residues', '(7) Dung Cakes', '(77) Other']) ?? (data['cooking_fuel_main'] ?? data['typcookfuel_main'])?.toString();
      _cookingFuelMainController.text = _extractNumericCode(fuelMainValue);
      _cookingLocationMain.text = _extractNumericCode((data['cooking_location_main'] ?? '').toString());

      // ===== LIGHTING / WATER =====
      lightingSource = _matchOption(data['lighting_source'] ?? data['source_lig'], ['(1) Electricity', '(2) Kerosene/Solar', '(3) Oil', '(4) Gas', '(77) Other'])
          ?? (data['lighting_source'] == '(2) Kerosene' || data['source_lig']?.toString() == '2' ? '(2) Kerosene/Solar' : null);
      
      waterSources = [];
      final waterOptList = ['(1) Piped water', '(2) Bore Well', '(3) Dug Well', '(4) Surface water', '(5) Tanker/truck', '(6) Bottled water', '(77) Other'];
      final waterSourceRaw = data['water_sources'];
      if (waterSourceRaw is List) {
        waterSources = List<String>.from(waterSourceRaw);
      } else {
        if (isOne(data['pipedwater']) || isOne(data['pipedwater31'])) waterSources.add('(1) Piped water');
        if (isOne(data['borewell'])) waterSources.add('(2) Bore Well');
        if (isOne(data['dugwell'])) waterSources.add('(3) Dug Well');
        if (isOne(data['surfacewater'])) waterSources.add('(4) Surface water');
        if (isOne(data['tankertruck'])) waterSources.add('(5) Tanker/truck');
        if (isOne(data['bottledwater'])) waterSources.add('(6) Bottled water');
        if (isOne(data['source_water_oth'])) waterSources.add('(77) Other');
      }
      
      _waterSourceOther.text = (data['water_source_other'] ?? data['source_water_spy'] ?? '').toString();
      final waterMainValue = _matchOption(data['water_main_source'] ?? data['mainly_use_drink'], waterOptList) ?? (data['water_main_source'] ?? data['mainly_use_drink'])?.toString();
      _waterMainSourceController.text = _extractNumericCode(waterMainValue);

      waterTreatment = [];
      final waterTreatRaw = data['water_treatment'];
      if (waterTreatRaw is List) {
        waterTreatment = List<String>.from(waterTreatRaw);
      } else {
        if (isOne(data['safer_water_boil'])) waterTreatment.add('(1) Boil');
        if (isOne(data['safer_water_bleach'])) waterTreatment.add('(2) Add bleach');
        if (isOne(data['safer_water_strain'])) waterTreatment.add('(3) strain by cloth');
        if (isOne(data['safer_water_filter'])) waterTreatment.add('(4) Use water filter');
        if (isOne(data['safer_water_purifier'])) waterTreatment.add('(5) use electronic purifier');
        if (isOne(data['safer_water_settle'])) waterTreatment.add('(6) stand and settle');
        if (isOne(data['safer_water_none'])) waterTreatment.add('(7) None');
        if (isOne(data['safer_water_dk'])) waterTreatment.add('(88) Dont Know');
      }
      _waterTreatmentOther.text = (data['water_treatment_other'] ?? data['safe_drink_spy'] ?? '').toString();

      waterAllPurposeSources = [];
      final waterAllRaw = data['water_all_sources'];
      if (waterAllRaw is List) {
        waterAllPurposeSources = List<String>.from(waterAllRaw);
      } else {
        if (isOne(data['pipedwater_all'])) waterAllPurposeSources.add('(1) Piped water');
        if (isOne(data['borewell_all'])) waterAllPurposeSources.add('(2) Bore Well');
        if (isOne(data['dugwell_all'])) waterAllPurposeSources.add('(3) Dug Well');
        if (isOne(data['surfacewater_all'])) waterAllPurposeSources.add('(4) Surface water');
        if (isOne(data['tankertruck_all'])) waterAllPurposeSources.add('(5) Tanker/truck');
        if (isOne(data['bottledwater_all'])) waterAllPurposeSources.add('(6) Bottled water');
        if (isOne(data['source_water_all_oth'])) waterAllPurposeSources.add('(77) Other');
      }
      _waterAllPurposeOther.text = data['water_all_other']?.toString() ?? '';
      final waterAllMainValue = _matchOption(data['water_all_main'] ?? data['mainly_use_all'], waterOptList) ?? (data['water_all_main'] ?? data['mainly_use_all'])?.toString();
      _waterAllPurposeMainController.text = _extractNumericCode(waterAllMainValue);

      // ===== SANITATION / RATION =====
      toiletFacility = _matchOption(data['toilet_facility'] ?? data['toilet'], ['(1) Flush Toilet', '(2) Septic Tank Toilet', '(3) Pit Toilet', '(4) No toilet facility', '(77) Other']);
      _toiletOther.text = (data['toilet_facility_other'] ?? data['toilet_spy'] ?? '').toString();
      rationCard = _matchOption(data['ration_card'] ?? data['rcard'], ['(1) White card', '(2) Pink Card', '(3) No card']);
      religion = _matchOption(data['religion'], ['(1) Hindu', '(2) Muslim', '(3) Christian', '(77) Other']);
      caste = _matchOption(data['caste'], ['(1) SC', '(2) ST', '(3) BC', '(4) FC', '(77) Other']);

      // ===== ASSETS / AGRI =====
      const allAssets = [
        'Mattress', 'Cot/bed', 'Electric Fan', 'Pressure cooker', 'sewing Machine',
        'Refrigerator', 'Mobile phone', 'Any phone', 'Bicycle', 'Scooter',
        'Animal cart', 'Chair', 'Table', 'Radio', 'Mixer', 'Colour TV', 'A/C',
        'Water pump', 'Computer', 'Tractor', 'Car', 'Thresher', 'Washing Machine', 'Geyser',
      ];
      householdAssets = [];
      householdAssetsNotOwned = [];
      final assetsRaw = data['household_assets'];
      if (assetsRaw is List) {
        householdAssets = List<String>.from(assetsRaw);
      } else {
        void addAsset(dynamic check, String name) {
          if (check?.toString() == '1' || check?.toString() == '2') {
            if (!householdAssets.contains(name)) householdAssets.add(name);
          }
        }
        addAsset(data['tv'], 'Colour TV');
        addAsset(data['bw_tv'], 'Colour TV');
        addAsset(data['refrigerator'], 'Refrigerator');
        addAsset(data['mobile'], 'Mobile phone');
        addAsset(data['any_phone'], 'Any phone');
        addAsset(data['car'], 'Car');
        addAsset(data['bicycle'], 'Bicycle');
        addAsset(data['ele_fan'], 'Electric Fan');
        addAsset(data['radio'], 'Radio');
        addAsset(data['mixer'], 'Mixer');
        addAsset(data['pressure_cooker'] ?? data['pressur_cooker'], 'Pressure cooker');
        addAsset(data['mattress'], 'Mattress');
        addAsset(data['cot'], 'Cot/bed');
        addAsset(data['sewing_mach'], 'sewing Machine');
        addAsset(data['scooter'], 'Scooter');
        addAsset(data['cart'], 'Animal cart');
        addAsset(data['chair'], 'Chair');
        addAsset(data['table1'], 'Table');
        addAsset(data['water_pump'], 'Water pump');
        addAsset(data['computer'], 'Computer');
        addAsset(data['tractor'], 'Tractor');
        addAsset(data['thresher'], 'Thresher');
        addAsset(data['ac'], 'A/C');
        addAsset(data['washing_mach'], 'Washing Machine');
        addAsset(data['geyser'], 'Geyser');
      }

      // Restore saved No list; if not present infer from assets not in Yes list
      final notOwnedRaw = data['household_assets_not_owned'];
      if (notOwnedRaw is List && notOwnedRaw.isNotEmpty) {
        householdAssetsNotOwned = List<String>.from(notOwnedRaw);
      } else {
        householdAssetsNotOwned = allAssets.where((a) => !householdAssets.contains(a)).toList();
      }

      separateKitchen = _matchOption(data['separate_kitchen'], ['(1) Yes', '(2) No']);

      final agriRaw = data['agriculture_land'] ?? data['agri_land'];
      hasAgricultureLand = _matchOption(agriRaw, ['(1) Yes', '(2) No']);
      _agriLandArea.text = data['agriculture_land_area']?.toString() ?? '';
      agriLandUnit = data['agriculture_land_unit']?.toString();
      isIrrigated = _matchOption(data['is_irrigated'], ['(1) Yes', '(2) No']);
      _irrigatedLandArea.text = data['irrigated_land_area']?.toString() ?? '';
      irrigatedLandUnit = data['irrigated_land_unit']?.toString();
      irrigatedNone = data['irrigated_none'] == true;

      ownsCattle = _matchOption(data['owns_cattle'], ['(1) Yes', '(2) No']);
      cattleOwned = [];
      final cattleRaw = data['cattle_owned'];
      if (cattleRaw is List) {
        cattleOwned = List<String>.from(cattleRaw);
      } else {
        if (isOne(data['cattle_cows'])) cattleOwned.add('(1) Cows/Buffaloes');
        if (isOne(data['cattle_bulls'])) cattleOwned.add('(2) Bulls');
        if (isOne(data['cattle_goats'])) cattleOwned.add('(3) Goats/Sheep');
        if (isOne(data['cattle_poultry'])) cattleOwned.add('(4) Poultry');
        if (isOne(data['cattle_pigs'])) cattleOwned.add('(5) Pigs');
        if (isOne(data['cattle_oth']) || isOne(data['cattle_oth_yn'])) cattleOwned.add('(77) Other');
      }
      _cattleOther.text = (data['cattle_other'] ?? data['cattle_oth_spy'] ?? '').toString();

      healthCarePlace = _matchOption(data['health_care_place'] ?? data['get_sick'], ['(1) Govt.hospital', '(2) MediCiti hospital', '(3) private hospital', '(4) Private MBBS doctor', '(5) RMP', '(6) Medical shop', '(7) Home treatment']);
      
      govtHospitalReasons = [];
      final govtReasonsRaw = data['govt_hospital_reasons'] ?? data['why_not_govt'];
      if (govtReasonsRaw is List) {
        govtHospitalReasons = List<String>.from(govtReasonsRaw);
      } else {
        if (isOne(data['why_not_govt_1'])) govtHospitalReasons.add('(1)No nearby health facility');
        if (isOne(data['why_not_govt_2'])) govtHospitalReasons.add('(2) timing not convenient');
        if (isOne(data['why_not_govt_3'])) govtHospitalReasons.add('(3) Health Personnel often absent');
        if (isOne(data['why_not_govt_4'])) govtHospitalReasons.add('(4) Waiting time too long');
        if (isOne(data['why_not_govt_5'])) govtHospitalReasons.add('(5)Poor quality of care');
        if (isOne(data['why_not_govt_oth']) || isOne(data['why_not_govt_77'])) govtHospitalReasons.add('(77) Other');
      }
      _govtHospitalOther.text = (data['govt_hospital_other'] ?? data['why_not_govt_spy'] ?? '').toString();

      zohoId = data['zoho_id']?.toString();

      // New Agriculture Questions
      leaseLand = _matchOption(data['lease_land'], ['(1) Yes', '(2) No']);
      usesPesticides = _matchOption(data['uses_pesticides'], ['(1) Yes', '(2) No']);
      protectiveEquipment = _matchOption(data['protective_equipment'], ['(1) Yes', '(2) No']);
      final protectiveRaw = data['protective_equipment_items'];
      protectiveEquipmentItems = protectiveRaw is List ? List<String>.from(protectiveRaw) : [];

      // Pets & Rodents
      ownsPets = _matchOption(data['owns_pets'], ['(1) Yes', '(2) No']);
      final petsRaw = data['pets_owned'];
      petsOwned = petsRaw is List ? List<String>.from(petsRaw) : [];
      _petsOther.text = data['pets_other']?.toString() ?? '';
      hasRodents = _matchOption(data['has_rodents'], ['(1) Yes', '(2) No']);
      final rodentsRaw = data['rodent_types'];
      rodentTypes = rodentsRaw is List ? List<String>.from(rodentsRaw) : [];

      // Health Events
      feverHospitalAdmission = _matchOption(data['fever_hospital_admission'], ['(1) Yes', '(2) No']);
      _feverHospitalStay.text = data['fever_hospital_stay']?.toString() ?? '';
      snakeBiteHistory = _matchOption(data['snake_bite_history'], ['(1) Yes', '(2) No']);
      _snakeBiteOutcome.text = data['snake_bite_outcome']?.toString() ?? '';
      dogBiteHistory = _matchOption(data['dog_bite_history'], ['(1) Yes', '(2) No']);
      _dogBiteOutcome.text = data['dog_bite_outcome']?.toString() ?? '';
      surveyParticipation = _matchOption(data['survey_participation'], ['(1) Yes', '(2) No']);
      _surveyProject1.text = data['survey_project_1']?.toString() ?? '';
      _surveyProject2.text = data['survey_project_2']?.toString() ?? '';
      _surveyProject3.text = data['survey_project_3']?.toString() ?? '';
      
      debugPrint('POPULATE: ID=${_familyId.text}, Head=${_head.text}, State=$selectedState');
    });

    // Decode location from family ID if not stored in the record
    final fId = _familyId.text.trim();
    if (fId.isNotEmpty) {
      if (locationData.isNotEmpty) {
        _decodeAndApplyLocation(fId);
      }
      // If locationData not loaded yet, fetchLocations() will call it on completion
    }
  }

  /// Decodes the family-code prefix (e.g. TSRRMEDAG) to exact district/mandal/village
  /// display names so they match the dropdown option lists.
  void _decodeAndApplyLocation(String familyId) {
    if (locationData.isEmpty) return;

    // Strip trailing digits (sequential counter)
    final prefix = familyId.replaceAll(RegExp(r'\d+$'), '').toUpperCase();
    if (prefix.isEmpty) return;

    final stateCode = (locationData['state_code'] ?? 'TS').toString().toUpperCase();
    if (!prefix.startsWith(stateCode)) return;
    final afterState = prefix.substring(stateCode.length);

    // Pick the state display name that actually exists in availableStates
    final stateName = availableStates.firstWhere(
      (s) => s.toUpperCase().contains('TELANGANA') || s.toLowerCase().contains('telangana'),
      orElse: () => availableStates.isNotEmpty ? availableStates.first : 'Telangana',
    );

    final districts = locationData['districts'] as Map<String, dynamic>?;
    if (districts == null) return;

    for (final distEntry in districts.entries) {
      final dCode = (distEntry.value['code']?.toString() ?? '').toUpperCase();
      if (dCode.isEmpty || !afterState.startsWith(dCode)) continue;
      final afterDist = afterState.substring(dCode.length);

      final mandals = distEntry.value['mandals'] as Map<String, dynamic>?;
      if (mandals == null) {
        if (mounted) setState(() { selectedState = stateName; selectedDistrict = distEntry.key; });
        return;
      }

      for (final manEntry in mandals.entries) {
        final mCode = (manEntry.value['code']?.toString() ?? '').toUpperCase();
        if (mCode.isEmpty || !afterDist.startsWith(mCode)) continue;
        final afterMan = afterDist.substring(mCode.length);

        final villages = manEntry.value['Villages'] as Map<String, dynamic>?;

        if (afterMan.isEmpty || villages == null) {
          if (mounted) setState(() { selectedState = stateName; selectedDistrict = distEntry.key; selectedMandal = manEntry.key; });
          return;
        }

        for (final vilEntry in villages.entries) {
          final vCode = (vilEntry.value['code']?.toString() ?? '').toUpperCase();
          if (vCode.isNotEmpty && afterMan == vCode) {
            if (mounted) setState(() {
              selectedState    = stateName;
              selectedDistrict = distEntry.key;
              selectedMandal   = manEntry.key;
              selectedVillage  = vilEntry.key;
            });
            debugPrint('DECODE: $familyId → $stateName / ${distEntry.key} / ${manEntry.key} / ${vilEntry.key}');
            return;
          }
        }

        // Village code not found in locationData, still set state/district/mandal
        if (mounted) setState(() { selectedState = stateName; selectedDistrict = distEntry.key; selectedMandal = manEntry.key; });
        return;
      }
    }
  }

  @override
  void dispose() {
    _familyId.dispose();
    _houseNo.dispose();
    _head.dispose();
    _cookingLocationOther.dispose();
    _cookingLocationMain.dispose();
    _cookingFuelOther.dispose();
    _waterSourceOther.dispose();
    _waterTreatmentOther.dispose();
    _waterAllPurposeOther.dispose();
    _cattleOther.dispose();
    _govtHospitalOther.dispose();
    _toiletOther.dispose();
    _cookingFuelMainController.dispose();
    _waterMainSourceController.dispose();
    _waterAllPurposeMainController.dispose();
    _headNode.dispose();
    _familyIdNode.dispose();
    _petsOther.dispose();
    _agriLandArea.dispose();
    _irrigatedLandArea.dispose();
    _feverHospitalStay.dispose();
    _snakeBiteOutcome.dispose();
    _dogBiteOutcome.dispose();
    _surveyProject1.dispose();
    _surveyProject2.dispose();
    _surveyProject3.dispose();
    super.dispose();
  }

  String _extractNumericCode(String? val) {
    if (val == null || val.isEmpty) return '';
    final match = RegExp(r'\((\d+)\)').firstMatch(val);
    if (match != null) return match.group(1)!;
    return val;
  }

  List<String> _getSelectedCodes(List<String> selections) {
    return selections.map((s) {
      final match = RegExp(r'\((\d+)\)').firstMatch(s);
      return match != null ? match.group(1)! : s;
    }).toList();
  }

  void _resetForm({bool resetAction = true}) {
    setState(() {
      if (resetAction) _isActionActive = false;
      _isEditingFromSearch = false;
      _familyId.text = 'TSRRMED';
      _houseNo.clear();
      _head.clear();

      // familyIdReadOnly = false; (now permanently true)

      // Retain existing selections or set to defaults to enable auto-generation
      if (selectedState == null || (availableStates.isNotEmpty && !availableStates.contains(selectedState))) {
        selectedState = availableStates.isNotEmpty ? availableStates.first : 'TELANGANA';
      }
      selectedDistrict ??= 'Medchal-Malkajgiri';
      selectedMandal ??= 'Medchal';
      
      // User must explicitly select the village
      selectedVillage = null;

      familyType = null;
      familyStatus = null;
      cookingLocations = [];
      _cookingLocationOther.clear();
      _cookingLocationMain.clear();
      ownHouse = null;
      typeofhouse = null;
      noOfRooms = null;
      roofType = null;
      wallType = null;
      floorType = null;
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
      householdAssetsNotOwned = [];
      separateKitchen = null;
      hasAgricultureLand = null;
      _agriLandArea.clear();
      agriLandUnit = null;
      isIrrigated = null;
      _irrigatedLandArea.clear();
      irrigatedLandUnit = null;
      irrigatedNone = false;
      ownsCattle = null;
      cattleOwned = [];
      _cattleOther.clear();
      healthCarePlace = null;
      govtHospitalReasons = [];
      _govtHospitalOther.clear();
      zohoId = null;
      leaseLand = null;
      usesPesticides = null;
      protectiveEquipment = null;
      protectiveEquipmentItems = [];
      ownsPets = null;
      petsOwned = [];
      _petsOther.clear();
      hasRodents = null;
      rodentTypes = [];
      feverHospitalAdmission = null;
      _feverHospitalStay.clear();
      snakeBiteHistory = null;
      _snakeBiteOutcome.clear();
      dogBiteHistory = null;
      _dogBiteOutcome.clear();
      surveyParticipation = null;
      _surveyProject1.clear();
      _surveyProject2.clear();
      _surveyProject3.clear();
    });
  }

  String? _validateExtraFields() {
    if (selectedVillage == null || selectedVillage!.isEmpty) return 'Village is required';
    if (familyType == null) return 'Family Type is required';
    if (familyStatus == null) return 'Family Status is required';

    // Housing
    if (ownHouse == null) return 'Q1: Own house/property answer is required';
    if (typeofhouse == null) return 'Q2: Type of House is required';
    if (roofType == null) return 'Q2: Type of Roof is required';
    if (wallType == null) return 'Q2: Type of Wall is required';
    if (floorType == null) return 'Q2: Type of Floor is required';

    // Cooking
    if (cookingLocations.isEmpty) return 'Q3: Where do you cook? — select at least one';
    if (cookingLocations.contains('(4) Other') && _cookingLocationOther.text.trim().isEmpty)
      return 'Q3: Please specify other cooking location';

    // Fuel
    if (cookingFuelTypes.isEmpty) return 'Q4: Fuel type — select at least one';
    if (cookingFuelTypes.contains('(77) Other') && _cookingFuelOther.text.trim().isEmpty)
      return 'Q4: Please specify other fuel type';

    // Lighting
    if (lightingSource == null) return 'Q5: Main source of lighting is required';

    // Drinking water
    if (waterSources.isEmpty) return 'Q6: Main source of drinking water — select at least one';
    if (waterSources.contains('(77) Other') && _waterSourceOther.text.trim().isEmpty)
      return 'Q6: Please specify other drinking water source';
    if (waterSources.length > 1 && _waterMainSourceController.text.trim().isEmpty)
      return 'Q6: Mainly used water source code is required';

    // Water treatment
    if (waterTreatment.isEmpty) return 'Q7: Water treatment — select at least one';
    if (waterTreatment.contains('(77) Other') && _waterTreatmentOther.text.trim().isEmpty)
      return 'Q7: Please specify other water treatment';

    // All-purpose water
    if (waterAllPurposeSources.isEmpty) return 'Q8: Source of water for all purposes — select at least one';
    if (waterAllPurposeSources.contains('(77) Other') && _waterAllPurposeOther.text.trim().isEmpty)
      return 'Q8: Please specify other all-purpose water source';
    if (waterAllPurposeSources.length > 1 && _waterAllPurposeMainController.text.trim().isEmpty)
      return 'Q8: Mainly used all-purpose water source code is required';

    // Toilet
    if (toiletFacility == null) return 'Q9: Toilet facility is required';
    if (toiletFacility == '(77) Other' && _toiletOther.text.trim().isEmpty)
      return 'Q9: Please specify other toilet facility';

    // Socio-economic
    if (religion == null) return 'Q10: Religion is required';
    if (caste == null) return 'Q11: Caste is required';
    if (rationCard == null) return 'Q12: Ration Card is required';

    // Agriculture
    if (hasAgricultureLand == null) return 'Q13: Own agricultural land answer is required';
    if (hasAgricultureLand == '(1) Yes') {
      if (isIrrigated == null) return 'Q14: Is land irrigated answer is required';
      if (leaseLand == null) return 'Q15: Cultivating on rental/lease land answer is required';
      if (usesPesticides == null) return 'Q16: Use agricultural pesticides answer is required';
      if (usesPesticides == '(1) Yes') {
        if (protectiveEquipment == null) return 'Q17: Protective equipment answer is required';
        if (protectiveEquipment == '(1) Yes' && protectiveEquipmentItems.isEmpty)
          return 'Q17: Please specify at least one protective equipment item';
      }
    }

    // Livestock
    if (ownsCattle == null) return 'Q18: Own cattle answer is required';
    if (ownsCattle == '(1) Yes') {
      if (cattleOwned.isEmpty) return 'Q18: Please specify at least one cattle type';
      if (cattleOwned.contains('(77) Other') && _cattleOther.text.trim().isEmpty)
        return 'Q18: Please specify other cattle type';
    }

    // Pets
    if (ownsPets == null) return 'Q19: Own pets answer is required';
    if (ownsPets == '(1) Yes') {
      if (petsOwned.isEmpty) return 'Q19: Please specify at least one pet type';
      if (petsOwned.contains('Other') && _petsOther.text.trim().isEmpty)
        return 'Q19: Please specify other pet type';
    }

    // Rodents
    if (hasRodents == null) return 'Q20: Presence of rodents answer is required';
    if (hasRodents == '(1) Yes' && rodentTypes.isEmpty)
      return 'Q20: Please specify rodent type (Rats/Bats)';

    // Health
    if (healthCarePlace == null) return 'Q21: Where do household members go when sick — required';
    if (healthCarePlace != '(1) Govt.hospital') {
      if (govtHospitalReasons.isEmpty) return 'Q22: Reason for not going to Govt. hospital — select at least one';
      if (govtHospitalReasons.contains('(77) Other') && _govtHospitalOther.text.trim().isEmpty)
        return 'Q22: Please specify other reason';
    }
    if (feverHospitalAdmission == null) return 'Q23: Fever hospitalization answer is required';
    if (feverHospitalAdmission == '(1) Yes' && _feverHospitalStay.text.trim().isEmpty)
      return 'Q23: Duration of hospital stay is required';
    if (snakeBiteHistory == null) return 'Q24: Snake bite history answer is required';
    if (snakeBiteHistory == '(1) Yes' && _snakeBiteOutcome.text.trim().isEmpty)
      return 'Q24: Snake bite outcome is required';
    if (dogBiteHistory == null) return 'Q25: Dog bite history answer is required';
    if (dogBiteHistory == '(1) Yes' && _dogBiteOutcome.text.trim().isEmpty)
      return 'Q25: Dog bite outcome is required';
    if (surveyParticipation == null) return 'Q26: Survey participation answer is required';
    if (surveyParticipation == '(1) Yes' && _surveyProject1.text.trim().isEmpty)
      return 'Q26: At least one project name is required';

    return null;
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    final extraError = _validateExtraFields();
    if (extraError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⚠️ $extraError'),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ));
      return;
    }
    if (_isSaving) return;
    setState(() => _isSaving = true);
    debugPrint('SAVE: Started save process...');

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;
      final isEditing = widget.existingData != null || _isEditingFromSearch;

      debugPrint('SAVE: isOnline=$isOnline, isEditing=$isEditing');

      String finalId = _familyId.text;
      bool isTemp = finalId.startsWith('Off-') || finalId.startsWith('Off_');
      debugPrint('SAVE: Original ID: $finalId (isTemp=$isTemp)');

      // Image uploads in background when photo is taken; by save time it's usually done.
      // If still uploading, proceed with whatever URL we have — don't block save.

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
        'cooking_location': cookingLocations,
        'cooking_location_other': _cookingLocationOther.text,
        'cooking_location_main': _cookingLocationMain.text,
        'cooking_fuel_types': cookingFuelTypes,
        'cooking_fuel_other': _cookingFuelOther.text,
        'cooking_fuel_main': _cookingFuelMainController.text,
        'lighting_source': lightingSource,
        'water_sources': waterSources,
        'water_source_other': _waterSourceOther.text,
        'water_main_source': _waterMainSourceController.text,
        'water_treatment': waterTreatment,
        'water_treatment_other': _waterTreatmentOther.text,
        'water_all_sources': waterAllPurposeSources,
        'water_all_other': _waterAllPurposeOther.text,
        'water_all_main': _waterAllPurposeMainController.text,
        'toilet_facility': toiletFacility,
        'toilet_facility_other': _toiletOther.text,
        'ration_card': rationCard,
        'religion': religion,
        'caste': caste,
        'household_assets': householdAssets,
        'household_assets_not_owned': householdAssetsNotOwned,
        'separate_kitchen': separateKitchen,
        'agriculture_land': hasAgricultureLand,
        'agriculture_land_area': _agriLandArea.text,
        'agriculture_land_unit': agriLandUnit,
        'is_irrigated': isIrrigated,
        'irrigated_land_area': _irrigatedLandArea.text,
        'irrigated_land_unit': irrigatedLandUnit,
        'irrigated_none': irrigatedNone,
        'owns_cattle': ownsCattle,
        'cattle_owned': cattleOwned,
        'cattle_other': _cattleOther.text,
        'health_care_place': healthCarePlace,
        'govt_hospital_reasons': govtHospitalReasons,
        'govt_hospital_other': _govtHospitalOther.text,
        'zoho_id': zohoId,
        'lease_land': leaseLand,
        'uses_pesticides': usesPesticides,
        'protective_equipment': protectiveEquipment,
        'protective_equipment_items': protectiveEquipmentItems,
        'owns_pets': ownsPets,
        'pets_owned': petsOwned,
        'pets_other': _petsOther.text,
        'has_rodents': hasRodents,
        'rodent_types': rodentTypes,
        'fever_hospital_admission': feverHospitalAdmission,
        'fever_hospital_stay': _feverHospitalStay.text,
        'snake_bite_history': snakeBiteHistory,
        'snake_bite_outcome': _snakeBiteOutcome.text,
        'dog_bite_history': dogBiteHistory,
        'dog_bite_outcome': _dogBiteOutcome.text,
        'survey_participation': surveyParticipation,
        'survey_project_1': _surveyProject1.text,
        'survey_project_2': _surveyProject2.text,
        'survey_project_3': _surveyProject3.text,
        'needs_zoho_sync': true,
        'is_temporary': false, // Ensure this is set for updates
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'serverUpdatedAt': FieldValue.serverTimestamp(),
      };

      bool saveHandled = false;
      bool savedToFirestore = false;

      if (isEditing) {
        debugPrint('SAVE: Editing existing record $finalId');
        final oldId = widget.docId;
        if (oldId != null && oldId != finalId) {
          debugPrint('SAVE: Family Id changed. Deleting $oldId');
          FirebaseFirestore.instance.collection('Family Code Creation').doc(oldId).delete();
        }

        data['firestoreDocId'] = finalId;
        await DataCacheService().saveOfflineSubmission('Family Code Creation', data);

        FirebaseFirestore.instance
            .collection('Family Code Creation')
            .doc(finalId)
            .set(data, SetOptions(merge: true));

        saveHandled = true;
        savedToFirestore = true;
        if (isOnline) _triggerZohoSync(finalId, data);

      } else if (isOnline) {
        debugPrint('SAVE: Online mode, attempting transaction');
        try {
          final stateCode = locationData['state_code'] ?? 'TS';
          final districtCode = (locationData['districts'] as Map?)?[selectedDistrict]?['code'] ?? '';
          final mandalCode = (locationData['districts'] as Map?)?[selectedDistrict]?['mandals']?[selectedMandal]?['code'] ?? '';
          final villageCode = (locationData['districts'] as Map?)?[selectedDistrict]?['mandals']?[selectedMandal]?['Villages']?[selectedVillage]?['code'] ?? '';

          final String prefix = '$stateCode$districtCode$mandalCode$villageCode';
          debugPrint('SAVE: prefix="$prefix" length=${prefix.length}');

          if (prefix.length >= 5) {
            final counterRef = FirebaseFirestore.instance.collection('village_counters').doc(prefix);

            int countHint = 0;
            try {
              final agg = await FirebaseFirestore.instance
                  .collection('Family Code Creation')
                  .where(FieldPath.documentId, isGreaterThanOrEqualTo: prefix)
                  .where(FieldPath.documentId, isLessThanOrEqualTo: '$prefix\uf8ff')
                  .count()
                  .get().timeout(const Duration(seconds: 4));
              countHint = agg.count ?? 0;
            } catch (e) {
              debugPrint('SAVE: Count hint failed: $e');
            }

            await FirebaseFirestore.instance.runTransaction((transaction) async {
              final counterSnap = await transaction.get(counterRef);
              int lastSuffix = counterSnap.exists ? (counterSnap.data()?['last_suffix'] ?? 0) : 0;
              if (countHint > lastSuffix) lastSuffix = countHint;

              final nextSuffix = lastSuffix + 1;
              final newId = '$prefix${nextSuffix.toString().padLeft(5, '0')}';

              final finalData = Map<String, dynamic>.from(data);
              finalData['family_id'] = newId;
              finalData['is_temporary'] = false;

              transaction.set(counterRef, {'last_suffix': nextSuffix}, SetOptions(merge: true));
              transaction.set(FirebaseFirestore.instance.collection('Family Code Creation').doc(newId), finalData);
              finalId = newId;
            }).timeout(const Duration(seconds: 10));

            saveHandled = true;
            savedToFirestore = true;
            _triggerZohoSync(finalId, data);
          } else {
            debugPrint('SAVE: Prefix too short ($prefix), falling back to offline save');
          }
        } catch (e) {
          debugPrint('SAVE: Online transaction failed: $e');
        }
      }

      if (!saveHandled) {
        debugPrint('SAVE: Fallback to offline local save');
        savedToFirestore = false;
        
        // Re-calculate prefix for offline consistency
        final stateCode = locationData['state_code'] ?? 'TS';
        final districtCode = (locationData['districts'] as Map?)?[selectedDistrict]?['code'] ?? '';
        final mandalCode = (locationData['districts'] as Map?)?[selectedDistrict]?['mandals']?[selectedMandal]?['code'] ?? '';
        final villageCode = (locationData['districts'] as Map?)?[selectedDistrict]?['mandals']?[selectedMandal]?['Villages']?[selectedVillage]?['code'] ?? '';
        final String prefix = '$stateCode$districtCode$mandalCode$villageCode';

        // Always recalculate a clean sequential ID for offline saves.
        // isTemp covers 'Off-...' style IDs; the prefix check handles IDs from other villages.
        String nextSuf;
        if (isTemp || !finalId.startsWith(prefix)) {
          int lastSuf = 0;
          final localData = await LocalDatabaseService().searchFamilyDetails(prefix, limit: 1);
          if (localData.isNotEmpty) {
            final lastId = localData.first['family_id']?.toString() ?? '';
            if (lastId.startsWith(prefix)) {
              final suffixStr = lastId.substring(prefix.length).replaceAll(RegExp(r'[^0-9]'), '');
              lastSuf = int.tryParse(suffixStr) ?? 0;
            }
          }
          nextSuf = (lastSuf + 1).toString().padLeft(5, '0');
          finalId = '$prefix$nextSuf';
        } else {
          // finalId is already a properly formatted sequential ID (e.g. TSRRMEDAK00001)
          nextSuf = finalId.substring(prefix.length).replaceAll(RegExp(r'[^0-9]'), '').padLeft(5, '0');
          finalId = '$prefix$nextSuf';
        }

        final randomSuffix = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
        final tempDocId = '$finalId-OFF-$randomSuffix';

        data['firestoreDocId'] = tempDocId;
        data['family_id'] = finalId;
        data['is_temporary'] = true;
        data['village_prefix'] = prefix;
        data['needs_final_id'] = true; // Mark for SyncService to run transaction

        // Save locally for SyncService — it will promote to the final sequential ID
        // and write to Firestore when online. Do NOT write directly here because the
        // Firebase SDK would flush the temp doc to Firestore before the sync service
        // can promote it, leaving ghost documents with placeholder IDs.
        await DataCacheService().saveOfflineSubmission('Family Code Creation', data);
        debugPrint('SAVE: Offline submission queued for promotion. Local ID: $finalId');
        saveHandled = true; // Mark as handled since we saved to SQLite
      }

      if (mounted) {
        // Proactively update local cache so it's immediately available in dropdowns & searches
        final finalData = Map<String, dynamic>.from(data);
        finalData['family_id'] = finalId;
        DataCacheService().addGeneratedCode(finalId);
        DataCacheService().addGeneratedDetail(finalData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: savedToFirestore ? Colors.green : Colors.orange,
            content: Text(savedToFirestore
                ? 'Record saved to Firebase (ID: $finalId)'
                : 'Saved locally (ID: $finalId) — will sync to Firebase automatically'),
          ),
        );
        if (!savedToFirestore) SyncService().syncPendingSubmissions();

        // NEW: show "proceed to personal details?" dialog
        // EDIT: just saved — stay on page, no popup, no navigation
        if (!isEditing) {
          _showProceedToPersonalDetailsDialog(finalId);
        }
      }
    } catch (e) {
      debugPrint('SAVE CRITICAL ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() {
        _isSaving = false;
        _isActionActive = false; // Add this
      });
    }
  }

  void _showProceedToPersonalDetailsDialog(String familyId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Proceed to Personal Details?'),
        content: Text('Family Code $familyId generated successfully. Do you want to proceed to the Personal Details form?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.existingData == null) _resetForm();
              if (Navigator.canPop(context)) Navigator.pop(context);
            },
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.existingData == null) _resetForm();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PersonalDetailsPage(initialFamilyCode: familyId),
                ),
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  // New helper method for background sync
  void _triggerZohoSync(String fId, Map<String, dynamic> fData) {
    debugPrint('ZohoMicroservice: Triggering for family_id=$fId');
    try {
      const url = 'https://www.zohoapis.in/creator/custom/shareindia/FamilyCodeCreationformFromFB?publickey=sC3sTn6SMeGRA56fBrjG7DqHg';
      // Strip non-JSON-serializable values (Timestamps, FieldValues)
      final safeData = _toJsonSafe({'family_id': fId, ...fData});
      final body = jsonEncode({'firebase_data': safeData});
      debugPrint('ZohoMicroservice: Sending ${body.length} bytes to Zoho');
      http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).then((response) {
        debugPrint('ZohoMicroservice [Family Code]: ${response.statusCode} — ${response.body}');
      }).catchError((e) {
        debugPrint('ZohoMicroservice [Family Code]: HTTP Error — $e');
      });
    } catch (e) {
      debugPrint('ZohoMicroservice: Failed to prepare/send — $e');
    }
  }

  dynamic _toJsonSafe(dynamic value) {
    if (value == null || value is bool || value is num || value is String) return value;
    if (value is List) return value.map(_toJsonSafe).toList();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _toJsonSafe(v)));
    }
    return value.toString();
  }



  Future<void> _searchAndLoadRecord([String? customId]) async {
    String? code = customId ?? _familyId.text.trim();
    
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a Family ID to search'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (mounted) setState(() => _isSaving = true);
    debugPrint('SEARCH: Starting search for ID: "$code"');
    
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;

      DocumentSnapshot<Map<String, dynamic>>? firestoreDoc;
      Map<String, dynamic>? localData;

      // 1. ALWAYS Try Local SQLite First (Instant)
      debugPrint('SEARCH: Checking local SQLite for "$code"...');
      localData = await LocalDatabaseService().getSingleFamilyDetail(code.trim());

      if (localData != null) {
        debugPrint('SEARCH: Found in SQLite!');
        _populateForm(localData, code.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Details for $code loaded INSTANTLY from local memory'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return; // Success, exit
      }

      // 2. Fallback to Firestore (Server or Cache)
      if (isOnline) {
        try {
          debugPrint('SEARCH: Not in SQLite, trying server for "$code"...');
          firestoreDoc = await FirebaseFirestore.instance
              .collection('Family Code Creation')
              .doc(code.trim())
              .get()
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint('SEARCH: Server failed ($e), checking Firestore cache...');
          firestoreDoc = await FirebaseFirestore.instance
              .collection('Family Code Creation')
              .doc(code.trim())
              .get(const GetOptions(source: Source.cache));
        }

        // If not found by document ID, query by FAM_ID or family_id field
        if (firestoreDoc == null || !firestoreDoc.exists) {
          try {
            debugPrint('SEARCH: Not found by doc ID, trying FAM_ID field...');
            var querySnap = await FirebaseFirestore.instance
                .collection('Family Code Creation')
                .where('FAM_ID', isEqualTo: code.trim())
                .limit(1)
                .get()
                .timeout(const Duration(seconds: 5));
            if (querySnap.docs.isEmpty) {
              querySnap = await FirebaseFirestore.instance
                  .collection('Family Code Creation')
                  .where('family_id', isEqualTo: code.trim())
                  .limit(1)
                  .get()
                  .timeout(const Duration(seconds: 5));
            }
            if (querySnap.docs.isNotEmpty) {
              firestoreDoc = querySnap.docs.first;
            }
          } catch (e) {
            debugPrint('SEARCH: Field query failed: $e');
          }
        }
      } else {
        debugPrint('SEARCH: Offline and not in SQLite, checking Firestore cache...');
        firestoreDoc = await FirebaseFirestore.instance
            .collection('Family Code Creation')
            .doc(code.trim())
            .get(const GetOptions(source: Source.cache));
      }

      debugPrint('SEARCH: Firestore result received. Exists: ${firestoreDoc?.exists}');
      if (firestoreDoc != null && firestoreDoc.exists && firestoreDoc.data() != null) {
        _populateForm(firestoreDoc.data()!, firestoreDoc.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Details for $code loaded from ${isOnline ? "Server" : "Firestore Cache"}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Record $code not found on this phone. Please sync when online.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('SEARCH ERROR: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Search Error: Not found in memory. Please use the Green Download button while online.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
        selectedMandal == null) {
      debugPrint(
          'Selection Incomplete: $selectedState, $selectedDistrict, $selectedMandal');
      return;
    }

    try {
      final stateCode = locationData['state_code']?.toString() ?? 'TS';
      final districts = locationData['districts'] as Map<String, dynamic>?;
      // Handle potential key variations for the district (with or without hyphen)
      final dKey = selectedDistrict != null && districts != null
          ? (districts.containsKey(selectedDistrict) 
              ? selectedDistrict 
              : (districts.containsKey('Medchal Malkajgiri') ? 'Medchal Malkajgiri' : 'Medchal-Malkajgiri'))
          : 'Medchal-Malkajgiri';
      
      final districtData = districts?[dKey];
      final districtCode = districtData?['code']?.toString() ?? 'RR';
      
      final mandals = districtData?['mandals'] as Map<String, dynamic>?;
      final mandalData = mandals?[selectedMandal];
      final mandalCode = mandalData?['code']?.toString() ?? 'MED';
      
      final basePrefix = '$stateCode$districtCode$mandalCode';

      if (selectedVillage == null) {
        if (mounted) {
          setState(() {
            _familyId.text = basePrefix;
          });
        }
        return;
      }
      
      final villages = mandalData?['Villages'] as Map<String, dynamic>?;
      final villageData = villages?[selectedVillage];
      final villageCode = villageData?['code'] ?? '';

      final prefix = '$basePrefix$villageCode';
      if (prefix.length < 5) {
        debugPrint('Prefix too short: $prefix');
        return;
      }

      // Try to find the last ID from both Local DB and Firestore Cache to get the best sequential start
      int lastLocalSuffix = 0;
      try {
        final localData = await LocalDatabaseService().searchFamilyDetails(prefix, limit: 1);
        if (localData.isNotEmpty) {
          final lastId = localData.first['family_id']?.toString() ?? '';
          if (lastId.startsWith(prefix) && !lastId.startsWith('Off-')) {
            final suffixStr = lastId.substring(prefix.length);
            lastLocalSuffix = int.tryParse(suffixStr) ?? 0;
          }
        }
      } catch (e) {
        debugPrint('ID_GEN: Local suffix lookup failed: $e');
      }

      int currentMaxSuffix = lastLocalSuffix;
      
      try {
        // 1. Check local Firestore cache for the highest document ID with this prefix
        final cacheSnapshot = await FirebaseFirestore.instance
            .collection('Family Code Creation')
            .where(FieldPath.documentId, isGreaterThanOrEqualTo: prefix)
            .where(FieldPath.documentId, isLessThanOrEqualTo: '$prefix\uf8ff')
            .orderBy(FieldPath.documentId, descending: true)
            .limit(1)
            .get(const GetOptions(source: Source.cache));
            
        if (cacheSnapshot.docs.isNotEmpty) {
          final lastId = cacheSnapshot.docs.first.id;
          final suffixStr = lastId.substring(prefix.length);
          final suffix = int.tryParse(suffixStr) ?? 0;
          if (suffix > currentMaxSuffix) currentMaxSuffix = suffix;
        }
      } catch (e) {
        debugPrint('ID_GEN: Cache lookup failed: $e');
      }

      final connectivityResult = await Connectivity().checkConnectivity();
      bool isOnline = connectivityResult != ConnectivityResult.none;

      if (!isOnline) {
        final nextSuffix = currentMaxSuffix + 1;
        final newId = '$prefix${nextSuffix.toString().padLeft(5, '0')}';
        if (mounted) setState(() => _familyId.text = newId);
        return;
      }

      // Online: Get exact next sequential ID from Firestore counter
      int nextSuffix = lastLocalSuffix + 1;
      final counterRef = FirebaseFirestore.instance.collection('village_counters').doc(prefix);
      
      // Online: Use COUNT aggregation + Counter Doc + Local Cache for triple-checking
      try {
        debugPrint('ID_GEN: Aggregating count for prefix $prefix...');
        
        // 1. Firestore Count (Actual records)
        int firestoreCount = 0;
        try {
          final aggregateQuery = await FirebaseFirestore.instance
              .collection('Family Code Creation')
              .where(FieldPath.documentId, isGreaterThanOrEqualTo: prefix)
              .where(FieldPath.documentId, isLessThanOrEqualTo: '$prefix\uf8ff')
              .count()
              .get().timeout(const Duration(seconds: 4));
          firestoreCount = aggregateQuery.count ?? 0;
          debugPrint('ID_GEN: Firestore Count found: $firestoreCount');
        } catch (e) {
          debugPrint('ID_GEN: Firestore count failed (missing index?): $e');
        }

        // 2. Counter Doc (Concurrency source)
        int counterVal = 0;
        try {
          final counterSnap = await counterRef.get().timeout(const Duration(seconds: 3));
          if (counterSnap.exists) {
            counterVal = counterSnap.data()?['last_suffix'] ?? 0;
            debugPrint('ID_GEN: Counter last_suffix: $counterVal');
          }
        } catch (e) {
          debugPrint('ID_GEN: Counter fetch failed: $e');
        }

        // 3. Local Database Count (Offline data)
        int localCount = 0;
        try {
          // Add a new method to localDb to get count by prefix
          localCount = await LocalDatabaseService().getFamilyCountByPrefix(prefix);
          debugPrint('ID_GEN: Local DB Count: $localCount');
        } catch (e) {
          debugPrint('ID_GEN: Local count failed: $e');
        }

        // Final Logic: Take the MAXIMUM of everything we found
        // This ensures if you have 780 records, we see "780" and suggest "781"
        int absoluteMax = firestoreCount;
        if (counterVal > absoluteMax) absoluteMax = counterVal;
        if (localCount > absoluteMax) absoluteMax = localCount;
        if (lastLocalSuffix > absoluteMax) absoluteMax = lastLocalSuffix;

        nextSuffix = absoluteMax + 1;
        debugPrint('ID_GEN: Final sequence start point: $absoluteMax -> Suggesting: $nextSuffix');
        
      } catch (e) {
        debugPrint('ID_GEN: Overall generation failed: $e. Using local hint: $lastLocalSuffix');
        nextSuffix = lastLocalSuffix + 1;
      }

      final newId = '$prefix${nextSuffix.toString().padLeft(5, '0')}';
      debugPrint('DEBUG: Final Generated Sequential ID: $newId');
      
      if (mounted) setState(() => _familyId.text = newId);
    } catch (e) {
      debugPrint('CRITICAL: Error in _generateFamilyId: $e');
    }
  }


  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return buildSectionCard(
      context: context,
      title: title,
      children: children,
      icon: icon,
    );
  }

  // --- NEW: Sync Methods for FamilyFormPage ---
  Future<void> _downloadAllForOffline() async {
    if (_isSyncing) return;

    final dbService = LocalDatabaseService();
    final localDetailsCount = await dbService.getRecordCount('family_details');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_familyCodesAlreadyDownloaded ? 'Re-Download Records' : 'Download All Records'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_familyCodesAlreadyDownloaded) ...[
              Text('Last downloaded: $_familyCodesDownloadedAt'),
              const SizedBox(height: 8),
              const Text('Records are already available offline. Re-download to get the latest data?'),
            ] else ...[
              Text('Current Local Records: $localDetailsCount'),
              const SizedBox(height: 12),
              const Text('This will download all 16,000+ records to this phone for offline use. This is a one-time download.'),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_familyCodesAlreadyDownloaded ? 'Re-Download' : 'Download'),
          ),
        ],
      ),
    );

    if (confirm == true) _downloadFromStorage();
  }

  Future<void> _downloadFromStorage() async {
    setState(() { _isSyncing = true; _importedCountProgress = 0; });
    try {
      debugPrint('SYNC: Getting download URL...');
      final ref = FirebaseStorage.instance.ref().child('exports/family_codes.json');
      final downloadUrl = await ref.getDownloadURL();

      debugPrint('SYNC: Downloading file...');
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);
      final totalBytes = response.contentLength ?? 0;
      final bytes = <int>[];
      int downloadedBytes = 0;

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(() => _importedCountProgress = ((downloadedBytes / totalBytes) * 500).toInt());
        }
      }
      client.close();

      debugPrint('SYNC: Download complete. Parsing JSON...');
      final jsonString = String.fromCharCodes(bytes);
      final List<dynamic> records = json.decode(jsonString);
      debugPrint('SYNC: ${records.length} records parsed. Saving to SQLite...');

      final dbService = LocalDatabaseService();
      final List<Map<String, dynamic>> batch = [];
      int saved = 0;

      for (final record in records) {
        batch.add(Map<String, dynamic>.from(record as Map));
        if (batch.length == 500) {
          await dbService.saveFamilyDetails(batch, clearFirst: saved == 0);
          saved += batch.length;
          batch.clear();
          if (mounted) setState(() => _importedCountProgress = 500 + ((saved / records.length) * 500).toInt());
        }
      }
      if (batch.isNotEmpty) {
        await dbService.saveFamilyDetails(batch, clearFirst: saved == 0);
        saved += batch.length;
      }

      // Save download completion timestamp
      final prefs = await SharedPreferences.getInstance();
      final downloadedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      await prefs.setString('family_codes_download_timestamp', downloadedAt);

      if (mounted) {
        setState(() {
          _totalRecordCount = saved;
          _importedCountProgress = 1000;
          _familyCodesAlreadyDownloaded = true;
          _familyCodesDownloadedAt = downloadedAt;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $saved records ready for offline use! All family codes downloaded.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('SYNC Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 8)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _startFirestoreSync({String? mandal, bool resume = false}) async {
    setState(() {
      _isSyncing = true;
      if (!resume) _importedCountProgress = 0;
      else _importedCountProgress = _lastSyncProgress;
    });

    final dbService = LocalDatabaseService();

    try {
      int count = _importedCountProgress;
      DocumentSnapshot? lastDoc = resume ? _lastSyncDoc : null;
      bool hasMore = true;

      final baseQuery = mandal != null 
          ? FirebaseFirestore.instance.collection('Family Code Creation').where('mandal', isEqualTo: mandal)
          : FirebaseFirestore.instance.collection('Family Code Creation');

      // Update total count visibility
      final agg = await baseQuery.count().get().timeout(const Duration(seconds: 30));
      setState(() => _totalRecordCount = agg.count ?? 0);

      while (hasMore) {
        Query query = baseQuery.limit(500);
        if (lastDoc != null) query = query.startAfterDocument(lastDoc);

        final snapshot = await query.get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 60));

        if (snapshot.docs.isEmpty) {
          hasMore = false;
          _isSyncResumable = false;
          break;
        }

        lastDoc = snapshot.docs.last;
        count += snapshot.docs.length;

        final List<Map<String, dynamic>> records = snapshot.docs.map((d) => {
          ...(d.data() as Map<String, dynamic>),
          'firestoreDocId': d.id
        }).toList();
        await dbService.saveFamilyDetails(records, clearFirst: (resume == false && count == snapshot.docs.length));

        if (mounted) {
          setState(() {
            _importedCountProgress = count;
            _lastSyncDoc = lastDoc;
            _lastSyncProgress = count;
            _isSyncResumable = true;
          });
        }

        if (snapshot.docs.length < 500) {
          hasMore = false;
          _isSyncResumable = false;
        }
      }

      debugPrint('Sync: Family Code Creation sync complete.');


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SUCCESS: $count records ready for offline use!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Firestore Sync Error: $e');
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('TimeoutException')) msg = "Signal lost. Paused at $_importedCountProgress. Tap again to RESUME.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $msg'), backgroundColor: Colors.red, duration: const Duration(seconds: 8)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }
  // ------------------------------------------

  @override
  Widget build(BuildContext context) {
    debugPrint('BUILD: FamilyFormPage rebuild. ID=${_familyId.text}, Head=${_head.text}, EditingFromSearch=$_isEditingFromSearch');
    if (isLoadingLocations) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Family Registration', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade700, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'View Records List',
            onPressed: _openList,
          ),
          IconButton(
            icon: Icon(
              Icons.sync,
              color: _familyCodesAlreadyDownloaded ? Colors.greenAccent : Colors.white,
            ),
            tooltip: _familyCodesAlreadyDownloaded
                ? 'Downloaded on $_familyCodesDownloadedAt'
                : 'Sync Records to Local Database',
            onPressed: _downloadAllForOffline,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                buildHeader(
                  context: context,
                  title: 'Family Registration',
                  subtitle: 'Register and manage family unit records',
                ),
                const SizedBox(height: 16),
            if (_isSyncing)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Syncing Data for Offline Use...', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('$_importedCountProgress / $_totalRecordCount'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _totalRecordCount > 0 ? _importedCountProgress / _totalRecordCount : null,
                      backgroundColor: Colors.blue[100],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                    ),
                  ],
              ),
            ),
            _buildSectionCard(
              title: 'Family & Location Details',
              icon: Icons.location_on_outlined,
              children: [
                TextFormField(
                  controller: _familyId,
                  focusNode: _familyIdNode,
                  readOnly: familyIdReadOnly,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Family ID',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: familyIdReadOnly ? Colors.grey.shade100 : Colors.white,
                    helperText: 'Auto-generated based on location',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, color: Colors.blue),
                      onPressed: () => _searchAndLoadRecord(_familyId.text.trim()),
                    ),
                  ),
                  onFieldSubmitted: (val) => _searchAndLoadRecord(val.trim()),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                formSearchableDropdown(
                  context,
                  'State',
                  availableStates,
                  selectedState,
                  (v) {
                    setState(() {
                      selectedState = v as String?;
                      selectedDistrict = null;
                      selectedMandal = null;
                      selectedVillage = null;
                    });
                  },
                  key: ValueKey('state_$selectedState'),
                  enabled: _isActionActive,
                  isLoading: isLoadingLocations,
                ),
                const SizedBox(height: 16),
                formSearchableDropdown(
                  context,
                  'District',
                  (selectedState == null || locationData['districts'] == null)
                      ? []
                      : (locationData['districts'] as Map<String, dynamic>)
                          .keys
                          .toList(),
                  selectedDistrict,
                  (v) {
                    setState(() {
                      selectedDistrict = v as String?;
                      selectedMandal = null;
                      selectedVillage = null;
                    });
                  },
                  key: ValueKey('district_$selectedDistrict'),
                  enabled: _isActionActive,
                ),
                const SizedBox(height: 16),
                formSearchableDropdown(
                  context,
                  'Mandal',
                  (selectedDistrict == null ||
                          locationData['districts'] == null ||
                          locationData['districts'][selectedDistrict] == null)
                      ? []
                      : (locationData['districts'][selectedDistrict]['mandals']
                              as Map<String, dynamic>)
                          .keys
                          .toList(),
                  selectedMandal,
                  (v) {
                    setState(() {
                      selectedMandal = v as String?;
                      selectedVillage = null;
                    });
                  },
                  key: ValueKey('mandal_$selectedMandal'),
                  enabled: _isActionActive,
                ),
                const SizedBox(height: 16),
                formSearchableDropdown(
                  context,
                  'Village',
                  (selectedMandal == null ||
                          locationData['districts'] == null ||
                          locationData['districts'][selectedDistrict] == null ||
                          locationData['districts'][selectedDistrict]['mandals']
                                  [selectedMandal] == null)
                      ? []
                      : (locationData['districts'][selectedDistrict]['mandals']
                                  [selectedMandal]['Villages']
                              as Map<String, dynamic>)
                          .keys
                          .toList()
                          ..sort(),
                  selectedVillage,
                  (v) {
                    setState(() {
                      selectedVillage = v as String?;
                    });
                    _generateFamilyId();
                  },
                  key: ValueKey('village_$selectedVillage'),
                  enabled: _isActionActive,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: formTextField(
                        'House No',
                        _houseNo,
                        enabled: _isActionActive,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: formTextField(
                        'Head of Family',
                        _head,
                        enabled: _isActionActive,
                        focusNode: _headNode,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Family Type', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    formRadioOption(label: '(1) Nuclear Family', value: '(1) Nuclear Family', groupValue: familyType, onChanged: !_isActionActive ? null : (v) => setState(() => familyType = v as String?)),
                    formRadioOption(label: '(0) Joint Family', value: '(0) Joint Family', groupValue: familyType, onChanged: !_isActionActive ? null : (v) => setState(() => familyType = v as String?)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Family Status', style: TextStyle(fontWeight: FontWeight.w600)),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    formRadioOption(label: '(1) Active', value: '(1) Active', groupValue: familyStatus, onChanged: !_isActionActive ? null : (v) => setState(() => familyStatus = v as String?)),
                    formRadioOption(label: '(0) Vacant', value: '(0) Vacant', groupValue: familyStatus, onChanged: !_isActionActive ? null : (v) => setState(() => familyStatus = v as String?)),
                  ],
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Housing Details',
              children: <Widget>[
                yesNoQuestion(
                  label: '1. Do you own this house or any other property?',
                  value: ownHouse,
                  yesValue: '(1) Yes',
                  noValue: '(2) No',
                  onChanged: !_isActionActive ? null : (v) => setState(() => ownHouse = v as String?),
                ),
                const SizedBox(height: 12),
                Text('2. Type of House:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: formSearchableDropdown(
                        context,
                        'Type of House',
                        ['(3) KACHHA', '(2) SEMI PUCCA', '(1) PUCCA'],
                        ['(3) KACHHA', '(2) SEMI PUCCA', '(1) PUCCA'].contains(typeofhouse) 
                            ? typeofhouse : null,
                        (v) => setState(() => typeofhouse = v as String?),
                        enabled: _isActionActive,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: formTextField(
                        'No. Rooms',
                        TextEditingController(text: noOfRooms?.toString()),
                        keyboardType: TextInputType.number,
                        enabled: _isActionActive,
                        onChanged: (v) => noOfRooms = int.tryParse(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                formSearchableDropdown(
                  context,
                  'Type of Roof',
                  ['(1) PUCCA', '(2) SEMI PUCCA', '(3) KACHHA'],
                  ['(1) PUCCA', '(2) SEMI PUCCA', '(3) KACHHA'].contains(roofType) 
                      ? roofType : null,
                  (v) => setState(() => roofType = v as String?),
                  enabled: _isActionActive,
                ),
                const SizedBox(height: 16),
                formSearchableDropdown(
                  context,
                  'Type of Wall',
                  ['(1) PUCCA', '(2) SEMI PUCCA', '(3) KACHHA'],
                  ['(1) PUCCA', '(2) SEMI PUCCA', '(3) KACHHA'].contains(wallType) 
                      ? wallType : null,
                  (v) => setState(() => wallType = v as String?),
                  enabled: _isActionActive,
                ),
                const SizedBox(height: 16),
                formSearchableDropdown(
                  context,
                  'Type of Floor',
                  ['(1) PUCCA', '(2) SEMI PUCCA', '(3) KACHHA'],
                  ['(1) PUCCA', '(2) SEMI PUCCA', '(3) KACHHA'].contains(floorType) 
                      ? floorType : null,
                  (v) => setState(() => floorType = v as String?),
                  enabled: _isActionActive,
                ),
                const SizedBox(height: 16),
                Text('3. Where do you cook?', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    '(1) In the House',
                    '(2) In a seperate Building',
                    '(3) Outdoors',
                    '(4) Other'
                  ].map<Widget>((val) {
                    return formCheckboxOption(
                      label: val,
                      value: cookingLocations.contains(val),
                      onChanged: !_isActionActive ? null : (v) {
                        setState(() {
                          if (v!) {
                            cookingLocations.add(val);
                          } else {
                            cookingLocations.remove(val);
                          }
                          if (cookingLocations.length == 1) {
                            _cookingLocationMain.text = _extractNumericCode(cookingLocations.first);
                          } else if (cookingLocations.isEmpty) {
                            _cookingLocationMain.clear();
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                if (cookingLocations.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: formTextField(
                      'mainly used?',
                      _cookingLocationMain,
                      enabled: _isActionActive,
                      isNumericOnly: true,
                      helper: 'Enter numeric code (e.g. 1) from selections above: ${_getSelectedCodes(cookingLocations).join(", ")}',
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                          final validCodes = _getSelectedCodes(cookingLocations);
                          if (!validCodes.contains(v)) return 'Enter one of: ${validCodes.join(", ")}';
                        }
                        return null;
                      },
                    ),
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
                const Divider(height: 24),
                yesNoQuestion(
                  label: '4. Separate Room for Kitchen?',
                  value: separateKitchen,
                  yesValue: '(1) Yes',
                  noValue: '(2) No',
                  onChanged: !_isActionActive ? null : (v) => setState(() => separateKitchen = v as String?),
                ),
              ],
            ),
            _buildSectionCard(
               title: 'Energy & Utilities',
              children: [
                const SizedBox(height: 16),
                Text(
                  '4. Type of fuel used for cooking:',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    '(1) Electricity',
                    '(2) LPG/N.GAS',
                    '(3) Kerosene',
                    '(4) Wood',
                    '(5) Coal',
                    '(6) Crop Residues',
                    '(7) Dung Cakes',
                    '(77) Other'
                  ].map<Widget>((val) {
                    return formCheckboxOption(
                      label: val,
                      value: cookingFuelTypes.contains(val),
                      onChanged: !_isActionActive ? null : (v) {
                        setState(() {
                          v! ? cookingFuelTypes.add(val) : cookingFuelTypes.remove(val);
                          if (cookingFuelTypes.length == 1) {
                            _cookingFuelMainController.text = _extractNumericCode(cookingFuelTypes.first);
                          } else if (cookingFuelTypes.isEmpty) {
                            _cookingFuelMainController.clear();
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
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
                if (cookingFuelTypes.length > 1)
                  formTextField(
                    'Mainly used fuel',
                    _cookingFuelMainController,
                    enabled: _isActionActive,
                    isNumericOnly: true,
                    helper: 'Valid codes: ${_getSelectedCodes(cookingFuelTypes).join(", ")}',
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        final validCodes = _getSelectedCodes(cookingFuelTypes);
                        if (!validCodes.contains(v)) return 'Enter one of: ${validCodes.join(", ")}';
                      }
                      return null;
                    },
                  ),
                const Divider(height: 24),
                Text(
                  '5. Main source of lighting:',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    '(1) Electricity',
                    '(2) Kerosene/Solar',
                    '(3) Oil',
                    '(4) Gas',
                    '(77) Other'
                  ].map<Widget>((val) {
                    return formRadioOption(
                      label: val,
                      value: val,
                      groupValue: lightingSource,
                      onChanged: !_isActionActive ? null : (v) => setState(() => lightingSource = v as String?),
                    );
                  }).toList(),
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Food & Nutrition',
              icon: Icons.restaurant_outlined,
              children: [
                Text(
                  '6. Main source of drinking water:',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Text(
                  'What is the main source of water used by your household?',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    '(1) Piped water',
                    '(2) Bore Well',
                    '(3) Dug Well',
                    '(4) Surface water',
                    '(5) Tanker/truck',
                    '(6) Bottled water',
                    '(77) Other'
                  ].map<Widget>((val) {
                    return formCheckboxOption(
                      label: val,
                      value: waterSources.contains(val),
                      onChanged: !_isActionActive ? null : (v) {
                        setState(() {
                          v! ? waterSources.add(val) : waterSources.remove(val);
                          if (waterSources.length == 1) {
                            _waterMainSourceController.text = _extractNumericCode(waterSources.first);
                          } else if (waterSources.isEmpty) {
                            _waterMainSourceController.clear();
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
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
                if (waterSources.length > 1)
                  formTextField(
                    'Mainly used source',
                    _waterMainSourceController,
                    enabled: _isActionActive,
                    isNumericOnly: true,
                    helper: 'Valid codes: ${_getSelectedCodes(waterSources).join(", ")}',
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        final validCodes = _getSelectedCodes(waterSources);
                        if (!validCodes.contains(v)) return 'Enter one of: ${validCodes.join(", ")}';
                      }
                      return null;
                    },
                  ),
                const Divider(height: 24),
                Text(
                  '7. What do you do to make water safer to drink?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    '(1) Boil',
                    '(2) Add bleach',
                    '(3) strain by cloth',
                    '(4) Use water filter',
                    '(5) use electronic purifier',
                    '(6) stand and settle',
                    '(7) None',
                    '(88) Dont Know',
                    '(77) Other'
                  ].map<Widget>((val) {
                    return formCheckboxOption(
                      label: val,
                      value: waterTreatment.contains(val),
                      onChanged: !_isActionActive ? null : (v) {
                        setState(() {
                          if (v == true) {
                            if (val == '(7) None' || val == '(88) Dont Know') {
                              waterTreatment = [val];
                            } else {
                              waterTreatment.remove('(7) None');
                              waterTreatment.remove('none');
                              waterTreatment.remove('(88) Dont Know');
                              waterTreatment.add(val);
                            }
                          } else {
                            waterTreatment.remove(val);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
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
                
                const Divider(height: 24),
                Text(
                  '8. Source of water used for all purposes:',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    '(1) Piped water',
                    '(2) Bore Well',
                    '(3) Dug Well',
                    '(4) Surface water',
                    '(5) Tanker/truck',
                    '(6) Bottled water',
                    '(77) Other'
                  ].map<Widget>((val) {
                    return formCheckboxOption(
                      label: val,
                      value: waterAllPurposeSources.contains(val),
                      onChanged: !_isActionActive ? null : (v) {
                        setState(() {
                          v!
                              ? waterAllPurposeSources.add(val)
                              : waterAllPurposeSources.remove(val);
                          if (waterAllPurposeSources.length == 1) {
                            _waterAllPurposeMainController.text = _extractNumericCode(waterAllPurposeSources.first);
                          } else if (waterAllPurposeSources.isEmpty) {
                            _waterAllPurposeMainController.clear();
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
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
                if (waterAllPurposeSources.length > 1)
                  formTextField(
                    'Mainly used source',
                    _waterAllPurposeMainController,
                    enabled: _isActionActive,
                    isNumericOnly: true,
                    helper: 'Valid codes: ${_getSelectedCodes(waterAllPurposeSources).join(", ")}',
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        final validCodes = _getSelectedCodes(waterAllPurposeSources);
                        if (!validCodes.contains(v)) return 'Enter one of: ${validCodes.join(", ")}';
                      }
                      return null;
                    },
                  ),
                const Divider(height: 24),
                Text(
                  '9. What kind of toilet facility does the household have?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    '(1) Flush Toilet',
                    '(2) Septic Tank Toilet',
                    '(3) Pit Toilet',
                    '(4) No toilet facility',
                    '(77) Other'
                  ].map<Widget>((val) {
                    return formRadioOption(
                      label: val,
                      value: val,
                      groupValue: toiletFacility,
                      onChanged: !_isActionActive ? null : (v) => setState(() => toiletFacility = v as String?),
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
              title: 'Socio - Economic Indicators',
              icon: Icons.monetization_on_outlined,
              children: [
                Text(
                  '10. Religion:',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    '(1) Hindu',
                    '(2) Muslim',
                    '(3) Christian',
                    '(77) Other'
                  ].map((val) => formRadioOption(
                    label: val,
                    value: val,
                    groupValue: religion,
                    onChanged: !_isActionActive ? null : (v) => setState(() => religion = v as String?),
                  )).toList(),
                ),
                const Divider(height: 16),
                Text(
                  '11. Caste of Head of Household:',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    '(1) SC',
                    '(2) ST',
                    '(3) BC',
                    '(4) FC',
                    '(77) Other'
                  ].map((val) => formRadioOption(
                    label: val,
                    value: val,
                    groupValue: caste,
                    onChanged: !_isActionActive ? null : (v) => setState(() => caste = v as String?),
                  )).toList(),
                ),
                const Divider(height: 16),
                Text(
                  '12. Do you have a Ration Card?',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    '(1) White card',
                    '(2) Pink Card',
                    '(3) No card'
                  ].map<Widget>((val) {
                    return formRadioOption(
                      label: val,
                      value: val,
                      groupValue: rationCard,
                      onChanged: !_isActionActive ? null : (v) => setState(() => rationCard = v as String?),
                    );
                  }).toList(),
                ),
                const Divider(height: 16),
                Text(
                  'Household Assets',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
                    'Thresher',
                    'Washing Machine',
                    'Geyser'
                  ].map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text(item, style: const TextStyle(fontSize: 13))),
                          Expanded(
                            flex: 5,
                            child: Row(
                              children: [
                                formRadioOption(
                                  label: '(1) Yes',
                                  value: true,
                                  groupValue: householdAssets.contains(item) ? true : (householdAssetsNotOwned.contains(item) ? false : null),
                                  onChanged: !_isActionActive ? null : (v) {
                                    setState(() {
                                      if (v == true) {
                                        if (!householdAssets.contains(item)) householdAssets.add(item);
                                        householdAssetsNotOwned.remove(item);
                                      } else if (v == false) {
                                        householdAssets.remove(item);
                                        if (!householdAssetsNotOwned.contains(item)) householdAssetsNotOwned.add(item);
                                      } else {
                                        householdAssets.remove(item);
                                        householdAssetsNotOwned.remove(item);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 12),
                                formRadioOption(
                                  label: '(2) No',
                                  value: false,
                                  groupValue: householdAssets.contains(item) ? true : (householdAssetsNotOwned.contains(item) ? false : null),
                                  onChanged: !_isActionActive ? null : (v) {
                                    setState(() {
                                      if (v == false) {
                                        householdAssets.remove(item);
                                        if (!householdAssetsNotOwned.contains(item)) householdAssetsNotOwned.add(item);
                                      } else if (v == true) {
                                        if (!householdAssets.contains(item)) householdAssets.add(item);
                                        householdAssetsNotOwned.remove(item);
                                      } else {
                                        householdAssets.remove(item);
                                        householdAssetsNotOwned.remove(item);
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Agriculture & Livestock',
              children: [
                yesNoQuestion(
                  label: '13. Does the household own agricultural land?',
                  value: hasAgricultureLand,
                  yesValue: '(1) Yes',
                  noValue: '(2) No',
                  onChanged: !_isActionActive ? null : (v) => setState(() => hasAgricultureLand = v as String?),
                ),
                if (hasAgricultureLand == '(1) Yes') ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: formTextField('How many Acres', _agriLandArea,
                        enabled: _isActionActive, keyboardType: TextInputType.number),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: formSearchableDropdown(
                        context, 'Land Unit',
                        ['Acres', 'Guntas', 'Acres & Guntas', 'Hectares'],
                        agriLandUnit,
                        (v) => setState(() => agriLandUnit = v?.toString()),
                        enabled: _isActionActive,
                      ),
                    ),
                  ]),
                ],
                if (hasAgricultureLand == '(1) Yes') ...[
                  const SizedBox(height: 8),
                  yesNoQuestion(
                    label: '14. Is the land irrigated?',
                    value: isIrrigated,
                    yesValue: '(1) Yes',
                    noValue: '(2) No',
                    onChanged: !_isActionActive ? null : (v) => setState(() => isIrrigated = v as String?),
                  ),
                  if (isIrrigated == '(1) Yes') ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: formTextField('How many Acres irrigated', _irrigatedLandArea,
                          enabled: _isActionActive, keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: formSearchableDropdown(
                          context, 'Land Unit',
                          ['Acres', 'Guntas', 'Acres & Guntas', 'Hectares'],
                          irrigatedLandUnit,
                          (v) => setState(() => irrigatedLandUnit = v?.toString()),
                          enabled: _isActionActive,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    formCheckboxOption(
                      label: 'None',
                      value: irrigatedNone,
                      onChanged: !_isActionActive ? null : (v) => setState(() => irrigatedNone = v ?? false),
                    ),
                  ],
                  const Divider(height: 24),
                  // Q15
                  Text('15. Are you cultivating crops on any rental or lease land?',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                  const SizedBox(height: 6),
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    '(1) Yes', '(2) No'
                  ].map((val) => formRadioOption(
                    label: val, value: val, groupValue: leaseLand,
                    onChanged: !_isActionActive ? null : (v) => setState(() => leaseLand = v as String?),
                  )).toList()),
                  const Divider(height: 24),
                  // Q16
                  Text('16. Do you use any agricultural pesticides in your farming activities?',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                  const SizedBox(height: 6),
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    '(1) Yes', '(2) No'
                  ].map((val) => formRadioOption(
                    label: val, value: val, groupValue: usesPesticides,
                    onChanged: !_isActionActive ? null : (v) => setState(() => usesPesticides = v as String?),
                  )).toList()),
                  if (usesPesticides == '(1) Yes') ...[
                    const SizedBox(height: 8),
                    // Q17
                    Text('17. Do you use protective equipment while applying pesticides?',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    const SizedBox(height: 6),
                    Wrap(spacing: 12, runSpacing: 8, children: [
                      '(1) Yes', '(2) No'
                    ].map((val) => formRadioOption(
                      label: val, value: val, groupValue: protectiveEquipment,
                      onChanged: !_isActionActive ? null : (v) => setState(() => protectiveEquipment = v as String?),
                    )).toList()),
                    if (protectiveEquipment == '(1) Yes') ...[
                      const SizedBox(height: 8),
                      Text('If yes, specify:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[500])),
                      const SizedBox(height: 4),
                      Wrap(spacing: 12, runSpacing: 8, children: [
                        'Gloves', 'Mask', 'Boots', 'Full Protective clothing'
                      ].map((item) => formCheckboxOption(
                        label: item,
                        value: protectiveEquipmentItems.contains(item),
                        onChanged: !_isActionActive ? null : (v) => setState(() {
                          v! ? protectiveEquipmentItems.add(item) : protectiveEquipmentItems.remove(item);
                        }),
                      )).toList()),
                    ],
                  ],
                ],
                const Divider(height: 24),
                // Q18
                yesNoQuestion(
                  label: '18. Does the household own cattle?',
                  value: ownsCattle,
                  yesValue: '(1) Yes',
                  noValue: '(2) No',
                  onChanged: !_isActionActive ? null : (v) => setState(() {
                    ownsCattle = v as String?;
                    if (v == '(2) No') cattleOwned = [];
                  }),
                ),
                if (ownsCattle == '(1) Yes') ...[
                  const SizedBox(height: 8),
                  Text('If yes, specify:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[500])),
                  ...[
                    '(1) Cows/Buffaloes',
                    '(2) Bulls',
                    '(3) Goats/Sheep',
                    '(4) Poultry',
                    '(5) Pigs',
                    '(77) Other'
                  ].map((val) {
                    return CheckboxListTile(
                      dense: true,
                      title: Text(val, style: const TextStyle(fontSize: 14)),
                      value: cattleOwned.contains(val),
                      onChanged: !_isActionActive ? null : (v) {
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
                const SizedBox(height: 8),
                // Q19
                Text('19. Does the household own any pets?',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  '(1) Yes', '(2) No'
                ].map((val) => formRadioOption(
                  label: val, value: val, groupValue: ownsPets,
                  onChanged: !_isActionActive ? null : (v) => setState(() => ownsPets = v as String?),
                )).toList()),
                if (ownsPets == '(1) Yes') ...[
                  const SizedBox(height: 8),
                  Text('If yes, specify:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    'Dog', 'Cat', 'Rabbit', 'Birds', 'Other'
                  ].map((item) => formCheckboxOption(
                    label: item,
                    value: petsOwned.contains(item),
                    onChanged: !_isActionActive ? null : (v) => setState(() {
                      v! ? petsOwned.add(item) : petsOwned.remove(item);
                    }),
                  )).toList()),
                  if (petsOwned.contains('Other'))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: formTextField('If others, specify', _petsOther, enabled: _isActionActive),
                    ),
                ],
                const Divider(height: 24),
                Text('20. Have you noticed the presence of rats or bats in your household?',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  '(1) Yes', '(2) No'
                ].map((val) => formRadioOption(
                  label: val, value: val, groupValue: hasRodents,
                  onChanged: !_isActionActive ? null : (v) => setState(() => hasRodents = v as String?),
                )).toList()),
                if (hasRodents == '(1) Yes') ...[
                  const SizedBox(height: 8),
                  Text('If Yes:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    'Rats', 'Bats'
                  ].map((item) => formCheckboxOption(
                    label: item,
                    value: rodentTypes.contains(item),
                    onChanged: !_isActionActive ? null : (v) => setState(() {
                      v! ? rodentTypes.add(item) : rodentTypes.remove(item);
                    }),
                  )).toList()),
                ],
              ],
            ),
            _buildSectionCard(
              title: 'Health',
              icon: Icons.health_and_safety_outlined,
              children: [
                Text(
                  '21. When household members get sick, where do they go?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    '(1) Govt.hospital',
                    '(2) MediCiti hospital',
                    '(3) private hospital',
                    '(4) Private MBBS doctor',
                    '(5) RMP',
                    '(6) Medical shop',
                    '(7) Home treatment'
                  ].map((val) => formRadioOption(
                    label: val,
                    value: val,
                    groupValue: healthCarePlace,
                    onChanged: !_isActionActive ? null : (v) => setState(() {
                      healthCarePlace = v as String?;
                      if (healthCarePlace == '(1) Govt.hospital') {
                        govtHospitalReasons = [];
                        _govtHospitalOther.clear();
                      }
                    }),
                  )).toList(),
                ),
                if (healthCarePlace != null && healthCarePlace != '(1) Govt.hospital') ...[
                  const Divider(height: 16),
                  Text(
                    '22. Why do they not go to Government Hospital?',
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
                      onChanged: !_isActionActive ? null : (v) {
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
                const Divider(height: 24),
                Text('23. In the past three (3) months, has any member of your household been admitted to a hospital due to fever?',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  '(1) Yes', '(2) No'
                ].map((val) => formRadioOption(
                  label: val, value: val, groupValue: feverHospitalAdmission,
                  onChanged: !_isActionActive ? null : (v) => setState(() => feverHospitalAdmission = v as String?),
                )).toList()),
                if (feverHospitalAdmission == '(1) Yes')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: formTextField('If Yes, Duration of hospital stay', _feverHospitalStay, enabled: _isActionActive),
                  ),
                const Divider(height: 24),
                Text('24. Has any member of your family ever experienced a snake bite in the past?',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  '(1) Yes', '(2) No'
                ].map((val) => formRadioOption(
                  label: val, value: val, groupValue: snakeBiteHistory,
                  onChanged: !_isActionActive ? null : (v) => setState(() => snakeBiteHistory = v as String?),
                )).toList()),
                if (snakeBiteHistory == '(1) Yes')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: formTextField('Outcome (Recovered/Complications/Other)', _snakeBiteOutcome, enabled: _isActionActive),
                  ),
                const Divider(height: 24),
                Text('25. Has any member of your family experienced a dog bite in the past?',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  '(1) Yes', '(2) No'
                ].map((val) => formRadioOption(
                  label: val, value: val, groupValue: dogBiteHistory,
                  onChanged: !_isActionActive ? null : (v) => setState(() => dogBiteHistory = v as String?),
                )).toList()),
                if (dogBiteHistory == '(1) Yes')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: formTextField('Outcome (Recovered/Complications/Other)', _dogBiteOutcome, enabled: _isActionActive),
                  ),
                const Divider(height: 24),
                Text('26. Have you participated in any surveys/studies/projects before?',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  '(1) Yes', '(2) No'
                ].map((val) => formRadioOption(
                  label: val, value: val, groupValue: surveyParticipation,
                  onChanged: !_isActionActive ? null : (v) => setState(() => surveyParticipation = v as String?),
                )).toList()),
                if (surveyParticipation == '(1) Yes') ...[
                  const SizedBox(height: 8),
                  Text('If yes, in which projects have you been involved?',
                      style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  formTextField('Project Name 1', _surveyProject1, enabled: _isActionActive),
                  const SizedBox(height: 8),
                  formTextField('Project Name 2', _surveyProject2, enabled: _isActionActive),
                  const SizedBox(height: 8),
                  formTextField('Project Name 3', _surveyProject3, enabled: _isActionActive),
                ],
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
          if (_isSaving) ...[
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _isSaving
          ? null
          : formActionButtons(
              context: context,
              isEditMode: _isEditingFromSearch,
              onNew: () {
                setState(() {
                  _isEditingFromSearch = false;
                  _isActionActive = true;
                  familyIdReadOnly = true; // Auto-generated — user must not edit
                  _resetForm(resetAction: false);
                  _generateFamilyId();
                  _headNode.requestFocus();
                });
              },
              onSave: _save,
              onEdit: () {
                setState(() {
                  _isEditingFromSearch = true;
                  _isActionActive = true;
                  familyIdReadOnly = false; // Allow typing to search
                  _familyIdNode.requestFocus();
                });
              },
              onCancel: () {
                setState(() {
                  _isActionActive = false;
                  _resetForm();
                });
              },
              onExit: () => Navigator.pop(context),
              isSaving: _isSaving,
              isActionActive: _isActionActive,
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

  // Final Pure Firestore Sync State
  DocumentSnapshot? _lastSyncDoc;
  int _lastSyncProgress = 0;
  bool _isSyncResumable = false;

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
    'Assets (Yes)': 'household_assets',
    'Assets (No)': 'household_assets_not_owned',
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
    'Washing Machine': 'household_assets',
    'Geyser': 'household_assets',
    // Agriculture
    'Agri Land': 'agriculture_land',
    'Agri Area': 'agriculture_land_area',
    'Agri Unit': 'agriculture_land_unit',
    'Irrigated': 'irrigated_land_area',
    'Irrigated Unit': 'irrigated_land_unit',
    'Irrigated None': 'irrigated_none',
    'Lease Land': 'lease_land',
    'Uses Pesticides': 'uses_pesticides',
    'Protective Equip': 'protective_equipment',
    'Protective Items': 'protective_equipment_items',
    // Cattle
    'Cattle': 'cattle_owned',
    'Cattle Other': 'cattle_other',
    // Pets & Rodents
    'Owns Pets': 'owns_pets',
    'Pets': 'pets_owned',
    'Pets Other': 'pets_other',
    'Has Rodents': 'has_rodents',
    'Rodent Types': 'rodent_types',
    // Health
    'Health Place': 'health_care_place',
    'Hosp Avoid Reasons': 'govt_hospital_reasons',
    'Hosp Avoid Other': 'govt_hospital_other',
    'Fever Hospital': 'fever_hospital_admission',
    'Fever Stay': 'fever_hospital_stay',
    'Snake Bite': 'snake_bite_history',
    'Snake Outcome': 'snake_bite_outcome',
    'Dog Bite': 'dog_bite_history',
    'Dog Outcome': 'dog_bite_outcome',
    'Survey Part': 'survey_participation',
    'Survey Project 1': 'survey_project_1',
    'Survey Project 2': 'survey_project_2',
    'Survey Project 3': 'survey_project_3',
  };

  Future<void> _refreshTotalCount() async {
    try {
      final agg = await FirebaseFirestore.instance.collection('Family Code Creation').count().get();
      if (mounted) {
        setState(() => _totalRecordCount = agg.count ?? 0);
      }
    } catch (e) {
      debugPrint('Error refreshing count: $e');
    }
  }

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
                  .collection('Family Code Creation')
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FamilyFormPage(
                      existingData: record,
                      docId: doc.id,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _deleteRecord(doc.id),
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

  Future<void> _downloadByLocation() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No internet connection.')));
      return;
    }

    try {
      final locData = LocationService().locationData;
      final districts = (locData['districts'] as Map<String, dynamic>?)?.keys.toList() ?? [];
      
      if (districts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No location data cached. Please connect and refresh.')));
        return;
      }

      String? selectedDist;
      String? selectedMand;

      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Sync by Area'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select a District and Mandal to sync for offline work.'),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  menuMaxHeight: 300,
                  hint: const Text('Select District'),
                  value: selectedDist,
                  isExpanded: true,
                  items: districts.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setDialogState(() { selectedDist = v; selectedMand = null; }),
                ),
                if (selectedDist != null)
                  DropdownButton<String>(
                    menuMaxHeight: 300,
                    hint: const Text('Select Mandal'),
                    value: selectedMand,
                    isExpanded: true,
                    items: (locData[selectedDist] as List).map((v) => DropdownMenuItem(value: v.toString(), child: Text(v.toString()))).toList(),
                    onChanged: (v) => setDialogState(() => selectedMand = v),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: selectedMand == null ? null : () => Navigator.pop(context, 'start'),
                child: const Text('Sync Area'),
              ),
            ],
          ),
        ),
      ).then((val) {
        if (val == 'start') _startFirestoreSync(mandal: selectedMand);
      });
    } catch (e) {
      debugPrint('Sync Error: $e');
    }
  }

  Future<void> _downloadAllForOffline() async {
    if (_isSyncing) return;

    final dbService = LocalDatabaseService();
    final localDetailsCount = await dbService.getRecordCount('family_details');

    final confirm = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: _isSyncResumable ? const Text('Resume Sync?') : const Text('Sync All Records'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Local Records: $localDetailsCount / 17,000+'),
            const SizedBox(height: 12),
            Text(_isSyncResumable 
              ? 'Resume downloading from record $_lastSyncProgress. This is faster and safer for weak signals.'
              : 'This will sync all 17,000+ records to this phone. This takes time on slow internet.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          if (_isSyncResumable)
            TextButton(onPressed: () => Navigator.pop(context, 'new'), child: const Text('Start New', style: TextStyle(color: Colors.red))),
          ElevatedButton(onPressed: () => Navigator.pop(context, 'start'), child: Text(_isSyncResumable ? 'Resume' : 'Start')),
        ],
      ),
    );

    if (confirm == 'start') {
      _startFirestoreSync(resume: _isSyncResumable);
    } else if (confirm == 'new') {
      _lastSyncDoc = null;
      _lastSyncProgress = 0;
      _startFirestoreSync(resume: false);
    }
  }

  Future<void> _startFirestoreSync({String? mandal, bool resume = false}) async {
    setState(() {
      _isSyncing = true;
      if (!resume) _importedCountProgress = 0;
      else _importedCountProgress = _lastSyncProgress;
    });

    final dbService = LocalDatabaseService();

    try {
      int count = _importedCountProgress;
      DocumentSnapshot? lastDoc = resume ? _lastSyncDoc : null;
      bool hasMore = true;

      final baseQuery = mandal != null 
          ? FirebaseFirestore.instance.collection('Family Code Creation').where('mandal', isEqualTo: mandal)
          : FirebaseFirestore.instance.collection('Family Code Creation');

      // Update total count visibility
      final agg = await baseQuery.count().get().timeout(const Duration(seconds: 30));
      setState(() => _totalRecordCount = agg.count ?? 0);

      while (hasMore) {
        Query query = baseQuery.limit(500); // Larger batches for 17,000 records
        if (lastDoc != null) query = query.startAfterDocument(lastDoc);

        final snapshot = await query.get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 60));

        if (snapshot.docs.isEmpty) {
          hasMore = false;
          _isSyncResumable = false;
          break;
        }

        lastDoc = snapshot.docs.last;
        count += snapshot.docs.length;

        // --- NEW: Save to Local SQLite ---
        final List<Map<String, dynamic>> records = snapshot.docs.map((d) => {
          ...(d.data() as Map<String, dynamic>),
          'firestoreDocId': d.id
        }).toList();
        await dbService.saveFamilyDetails(records, clearFirst: (resume == false && count == snapshot.docs.length));
        // ---------------------------------

        if (mounted) {
          setState(() {
            _importedCountProgress = count;
            _lastSyncDoc = lastDoc;
            _lastSyncProgress = count;
            _isSyncResumable = true;
          });
        }

        if (snapshot.docs.length < 500) {
          hasMore = false;
          _isSyncResumable = false;
        }
      }

      // --- PHASE 2: Sync Personal Details for the selected Mandal ---
      if (mandal != null) {
        int memberCount = 0;
        bool hasMoreMembers = true;
        DocumentSnapshot? lastMemberDoc;

        while (hasMoreMembers) {
          Query memberQuery = FirebaseFirestore.instance
              .collection('personal_details')
              .where('Mandal', isEqualTo: mandal)
              .limit(500);
          
          if (lastMemberDoc != null) memberQuery = memberQuery.startAfterDocument(lastMemberDoc);
          
          final memberSnapshot = await memberQuery.get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 60));

          if (memberSnapshot.docs.isEmpty) {
            hasMoreMembers = false;
            break;
          }

          lastMemberDoc = memberSnapshot.docs.last;
          memberCount += memberSnapshot.docs.length;

          final List<Map<String, dynamic>> memberRecords = memberSnapshot.docs.map((d) => {
            ...(d.data() as Map<String, dynamic>),
            'firestoreDocId': d.id
          }).toList();

          await dbService.saveMembers(memberRecords, clearFirst: (memberCount == memberSnapshot.docs.length));

          if (mounted) {
            debugPrint('Sync: Downloaded $memberCount members...');
          }

          if (memberSnapshot.docs.length < 500) hasMoreMembers = false;
        }
        debugPrint('Sync: Finished syncing $memberCount members for $mandal');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SUCCESS: $count records ready for offline use!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Firestore Sync Error: $e');
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('TimeoutException')) msg = "Signal lost. Paused at $_importedCountProgress. Tap again to RESUME.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $msg'), backgroundColor: Colors.red, duration: const Duration(seconds: 8)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _performFullZohoSync({bool silent = false}) async {
    return;
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
        _refreshTotalCount(); // Refresh count when back online
      }
    });

    // Disabled auto-sync timer as per Zoho code removal
    // _autoSyncTimer = Timer.periodic(const Duration(minutes: 1), (_) => _syncPendingRecords(isAuto: true));
  }

  Future<void> _runStartupTasks() async {
    _refreshTotalCount(); // Get initial count once
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
      final snapshot = await FirebaseFirestore.instance.collection('Family Code Creation').get();
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
          .collection('Family Code Creation')
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
          if ((prefix == null || prefix.isEmpty) && (oldId.startsWith('Off-') || oldId.startsWith('OFF-') || oldId.startsWith('OFF_'))) {
            final parts = oldId.split('_');
            if (parts.length >= 2) prefix = parts[1];
          }

          if (prefix == null || prefix.isEmpty) {
            debugPrint('SYNC: Skipping temp doc $oldId due to missing prefix');
            continue;
          }

            try {
              final String effectivePrefix = prefix; // Capture non-nullable string
              final counterRef = FirebaseFirestore.instance.collection('village_counters').doc(effectivePrefix);

              // 1. Get current count as a safety hint (No index required)
              int countHint = 0;
              try {
                final agg = await FirebaseFirestore.instance
                    .collection('Family Code Creation')
                    .where(FieldPath.documentId, isGreaterThanOrEqualTo: effectivePrefix)
                    .where(FieldPath.documentId, isLessThanOrEqualTo: '$effectivePrefix\uf8ff')
                    .count()
                    .get().timeout(const Duration(seconds: 4));
                countHint = agg.count ?? 0;
              } catch (e) {
                debugPrint('SYNC: Count hint failed: $e');
              }

              await FirebaseFirestore.instance.runTransaction((transaction) async {
                final counterSnap = await transaction.get(counterRef);
                int lastSuffix = counterSnap.exists ? (counterSnap.data()?['last_suffix'] ?? 0) : 0;
                
                // Use the maximum of (Counter Value, Current DB Count)
                if (countHint > lastSuffix) {
                  lastSuffix = countHint;
                }

                final nextSuffix = lastSuffix + 1;
                final finalizedId = '$effectivePrefix${nextSuffix.toString().padLeft(5, '0')}';

                transaction.set(counterRef, {'last_suffix': nextSuffix}, SetOptions(merge: true));

                final newData = Map<String, dynamic>.from(data);
                newData['family_id'] = finalizedId;
                newData['is_temporary'] = false;
                newData.remove('village_prefix');
                newData['serverUpdatedAt'] = FieldValue.serverTimestamp();

                transaction.set(FirebaseFirestore.instance.collection('Family Code Creation').doc(finalizedId), newData);
                transaction.delete(doc.reference);
              }).timeout(const Duration(seconds: 15));
              syncCount++;
            } catch (e) {
              debugPrint('SYNC TEMP ERROR for $oldId: $e');
              errorCount++;
            }
        } else {
          // --- Case 2: Permanent Record Update (Already has permanent ID/Zoho ID) ---
          try {
            /*
            final zohoId = await ZohoCreatorService().syncRecord(data);
            if (zohoId != null) {
              await doc.reference.update({
                'needs_zoho_sync': false,
                'zoho_id': zohoId.toString(),
              });
              syncCount++;
              debugPrint('SYNC UPDATE: Successfully updated Zoho for ${doc.id}');
            }
            */
            syncCount++; // Mark as processed even if Zoho is skipped
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
      _refreshTotalCount(); // Refresh count after a sync attempt
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Stream<QuerySnapshot> _buildStream() {
    Query query = FirebaseFirestore.instance.collection('Family Code Creation');

    if (_activeSearchQuery.isEmpty) {
      return query
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
        final fromCache = snapshot.data?.metadata.isFromCache ?? false;
        final syncing = snapshot.data?.metadata.hasPendingWrites ?? false;

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

        // --- OPTIMIZATION: Removed live count query from build() to save Firebase costs ---
        // Total count is now refreshed once on load and after each sync batch.

        final loadedCount = docs.length;
        final titleText = _isSyncing
            ? 'Importing $_importedCountProgress... (Total: $_totalRecordCount)'
            : 'Records ($loadedCount / $_totalRecordCount)';
        final hasTemporary = docs.any((doc) =>
            (doc.data() as Map<String, dynamic>)['is_temporary'] == true);

        return Scaffold(
          appBar: AppBar(
            title: _isSearchingActive
                ? ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
                    child: Row(
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
                                color: Colors.black87, fontSize: 16),
                            onSubmitted: (value) {
                              setState(() {
                                _activeSearchQuery = value;
                                _hasSearched = true;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                : Text(
                    _isSyncing 
                        ? 'DL: $_importedCountProgress / $_totalRecordCount' 
                        : 'Records ($_totalRecordCount)', 
                    style: TextStyle(
                      fontSize: _isSyncing ? 14 : 17, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
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
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminDashboardPage()),
                  );
                },
                tooltip: 'Admin Dashboard',
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (val) async {
                  if (val == 'refresh') {
                    setState(() {}); // Simple rebuild to trigger stream rebuild
                  } else if (val == 'delete') {
                    _deleteAllRecords();
                  } else if (val == 'sync_lookups') {
                    setState(() => _isSyncing = true);
                    try {
                      await DataCacheService().fetchFamilyCodes(forceRefresh: true);
                      await DataCacheService().fetchFamilyDetails(forceRefresh: true);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lookups refreshed successfully!'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isSyncing = false);
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'refresh', child: Text('Refresh List')),
                  const PopupMenuItem(value: 'sync_lookups', child: Text('Refresh Codes & Names')),
                  const PopupMenuItem(value: 'delete', child: Text('Clear All Local Data', style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
          drawer: const AppDrawer(),
          body: !snapshot.hasData
              ? const Center(child: Text('Loading...'))
              : Builder(builder: (context) {
                  return Column(
                    children: [
                      if (_syncErrorMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Colors.red.shade100,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Error: $_syncErrorMessage',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => setState(() => _syncErrorMessage = null),
                              ),
                            ],
                          ),
                        ),
                      // Mode banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        color: fromCache
                            ? Colors.orange.shade100
                            : Colors.green.shade100,
                        child: Text(
                          '${fromCache ? 'Offline mode' : syncing || _isSyncing ? 'Online – syncing...' : 'Online – synced'}  |  $loadedCount / $_totalRecordCount records',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
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
