import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'local_database_service.dart';
import 'widget.dart';

class QuestionnairePage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const QuestionnairePage({super.key, this.existingData, this.docId});

  @override
  State<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends State<QuestionnairePage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;
  bool _isActionActive = false; // Add this
  final FocusNode _familyCodeNode = FocusNode();
  bool _familyIdReadOnly = true;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;

  // --- Identity & Registration ---
  final _registrationNumber = TextEditingController();
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  final _nameController = TextEditingController();
  final _age = TextEditingController();
  final _contactTel = TextEditingController();
  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectedGender;
  DateTime? dateOfInterview = DateTime.now();
  String? interviewersName;
  File? _image;

  // --- Lookups ---
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  // Location (auto-populated from Family Code)
  String? _locationVillage;
  String? _locationMandal;
  String? _locationDistrict;
  String? _locationState;


  // --- Measurements ---
  final _heightCm = TextEditingController();
  final _weightKg = TextEditingController();
  String? generalHealthStatus;

  // --- Hypertension ---
  String? hasHypertension; // Was (2) No
  final _hypertensionDays = TextEditingController();
  String? hypertensionDuration;
  String? hypertensionMedicine;
  final _hypertensionDosage = TextEditingController();
  final _hypertensionOtherMedicine = TextEditingController();

  // --- Diabetes ---
  String? hasDiabetes; // Was (2) No
  final _diabetesDays = TextEditingController();
  String? diabetesDuration;
  String? diabetesMedicine;
  String? diabetesStrength;
  final _diabetesOtherMedicine = TextEditingController();

  // --- Tobacco & Alcohol ---
  String? smokesNow;
  List<Map<String, dynamic>> tobaccoProductsPresent = [];
  String? smokedPast;
  List<Map<String, dynamic>> tobaccoProductsPast = [];
  String? drinksAlcohol;
  final _alcoholDuration = TextEditingController();
  String? alcoholDurationUnit;
  List<Map<String, dynamic>> alcoholProducts = [];

  // --- Systemic Review ---
  String? sufferGeneralHealth;
  String? generalHealthStatusDetail;
  final _generalHealthOther = TextEditingController();
  String? sufferVision;
  String? visionStatusDetail;
  final _visionOther = TextEditingController();
  String? sufferEnt;
  String? entStatusDetail;
  final _entOther = TextEditingController();
  String? sufferRespiratory;
  String? respiratoryStatusDetail;
  final _respiratoryOther = TextEditingController();
  String? sufferGastro;
  String? gastroStatusDetail;
  final _gastroOther = TextEditingController();
  String? sufferGenitourinary;
  String? genitourinaryStatusDetail;
  final _genitourinaryOther = TextEditingController();
  String? sufferMusclesBones;
  String? musclesBonesStatusDetail;
  final _musclesBonesOther = TextEditingController();
  String? sufferSkin;
  String? skinStatusDetail;
  final _skinOther = TextEditingController();
  String? sufferBlood;
  String? bloodStatusDetail;
  final _bloodOther = TextEditingController();

  // --- Identity & Registration (continued) ---
  final _idController = TextEditingController(); // linked to Link_Name: ID in some forms, but linking to Name ID (fam_id) usually.

  final List<String> interviewerList = [
    'KUSUMA', 'CHV', 'SHAKUNTHALA (CHV AT)', 'HEMALATHA (CHV AT)', 'LAXMI', 'BHASKAR', 'KARUNAKAR', 'KRISHNAVENI', 'MADHAVI (CHV GR)', 'ANNAPURNA', 'BALAMANI (CHV GR)', 'SALOMI', 'UDYASHREE', 'JOHN', 'SUNITHA', 'KOMARIAH', 'MADAV', 'LAVANYA M', 'LAVANYA METTU', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'PUSHPA K', 'RAMADEVI G', 'RAMADEVI Y', 'REVATHI CH', 'ASHA', 'B JYOTHI', 'BHASKAR K', 'G RAMADEVI', 'K BHASKAR', 'KIRANMAI K', 'KUSUMA G', 'LAVANYA KASPOJU'
  ];

  final List<String> hypertensionMeds = [
    'AMLODIPINE', 'ATENOLOL', 'DILTIZEM SR', 'HYDROCHLOROTHIAZIDE', 'INDAPAMIDE', 'LOSARTAN', 'METOPROLOL', 'METOPROLOL-XL', 'MINIPRESS-XL', 'NIFEDIPINE SR', 'OLMESARTAN', 'S-AMLODIPINE', 'TELMISARTAN'
  ];

  final List<String> diabetesMeds = [
    'ACARBOSE', 'GLIBENCLAMIDE', 'GLICLAZIDE', 'GLIMEPIRIDE', 'METFORMIN', 'METFORMIN SR', 'MIGITOL', 'PIOGLITAZONE', 'SITAGLIPTIN', 'VILDAGLIPTIN', 'VOGLIBOSE', 'INS-MIXTARD', 'INS-GLARGINE', 'INS-ASPART', 'INS-LISPRO'
  ];

  final List<String> diabetesStrengths = [
    '0.2', '0.3', '1', '2', '2.5', '5', '15', '25', '30', '45', '50', '80', '100', '150', '500', '1000', '250', '20', '60', '0.5'
  ];

  final List<String> tobaccoNames = [
    '(1) Cigarette', '(2) Beedi', '(3) Pan Masala', '(4) Tobacco powder', '(5) Hooka', '(6) gutka'
  ];

  final List<String> alcoholItems = [
    '(1)Beer', '(2)Wine', '(3)Toddy', '(4)Whisky', '(5)Arrack'
  ];

  final List<String> alcoholFrequencies = [
    '(1) More than once in a day', '(2) Once a day', '(3) Few days in a week', '(4) Once in a week', '(5) Few times in a month', '(6) Once in a month', '(7) Rarely'
  ];

  final List<String> alcoholUnits = [
    '(1) ml', '(2) Peg', '(3) Glass', '(4) Packet', '(5) Bottle'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _isEditMode = true;
      _editDocId = widget.docId;
      _loadExistingData();
      final familyCode = (widget.existingData!['Family_Code'] ?? widget.existingData!['Family_code'] ?? '').toString();
      if (familyCode.isNotEmpty) {
        _fetchMembersByFamily(familyCode);
        _fetchExistingRecords(familyCode);
      }
    }
  }

  @override
  void dispose() {
    _familyCodeNode.dispose();
    _registrationNumber.dispose();
    _familyCodeController.dispose();
    _nameController.dispose();
    _age.dispose();
    _contactTel.dispose();
    _heightCm.dispose();
    _weightKg.dispose();
    _hypertensionDays.dispose();
    _hypertensionDosage.dispose();
    _hypertensionOtherMedicine.dispose();
    _diabetesDays.dispose();
    _diabetesOtherMedicine.dispose();
    _alcoholDuration.dispose();
    _generalHealthOther.dispose();
    _visionOther.dispose();
    _entOther.dispose();
    _respiratoryOther.dispose();
    _gastroOther.dispose();
    _genitourinaryOther.dispose();
    _musclesBonesOther.dispose();
    _skinOther.dispose();
    _bloodOther.dispose();
    _idController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembersByFamily(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      final fCode = familyCode.trim().toUpperCase();
      if (fCode.isEmpty) {
        setState(() => _isLoadingMembers = false);
        return;
      }

      // 1. Fetch Local Members immediately (Fastest for offline)
      final localMembers = await DataCacheService().fetchMembersLocally(fCode);
      
      // 2. Try Firestore for fresh data, but with a short timeout
      List<Map<String, dynamic>> firestoreMembers = [];
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('personal_details')
            .where('Family_Code', isEqualTo: fCode)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 3));
        
        firestoreMembers = snapshot.docs.map((d) => d.data() as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint('Questionnaire: Firestore lookup failed/timeout, relying on LOCAL: $e');
      }

      final Map<String, Map<String, dynamic>> memberMap = {};
      final Set<String> allNames = {};
      
      // Process both, preferring Firestore but ensuring Local captures everything else
      final combined = [...firestoreMembers, ...localMembers];

      for (var data in combined) {
        final name = data['Name']?.toString() ?? '';
        if (name.isEmpty) continue;
        
        // Only include members aged 18 or older for the questionnaire
        final age = int.tryParse(data['Age']?.toString() ?? '0') ?? 0;
        if (age < 18) continue;

        memberMap[name] = data;
        allNames.add(name);
      }

      setState(() {
        _allMembersData = memberMap;
        familyMemberNames = allNames.toList()..sort();
        selectedFamilyCode = fCode;
      });
          _fetchFamilyLocation(familyCode);
    } catch (e) {
      debugPrint('Error fetching members: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _fetchExistingRecords(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('questionnaire')
          .where('Family_Code', isEqualTo: familyCode)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 8));
      setState(() {
        _existingRecords = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error fetching records: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  void _onNameSelected(String? name) async {
    setState(() {
      selectedMemberName = name;
      _nameController.text = name ?? '';
    });
    
    if (name == null) return;

    final baseData = _allMembersData[name];
    if (baseData != null && !_isEditMode) {
      _registrationNumber.text = baseData['Registration_Number']?.toString() ?? '';
      selectedGender = baseData['Gender']?.toString();
      _age.text = baseData['Age']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        final snapshot = await FirebaseFirestore.instance
            .collection('questionnaire')
            .where('Family_Code_Creation', isEqualTo: fCode)
            .where('Name', isEqualTo: name)
            .limit(1)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 8));

        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          setState(() {
            _editDocId = doc.id;
            final merged = {...?baseData, ...doc.data()};
            _populateForm(merged);
          });
        } else if (baseData != null) {
          _populateForm(baseData);
        }
      } catch (e) {
        debugPrint('Error fetching questionnaire record: $e');
        if (baseData != null) _populateForm(baseData);
      } finally {
        if (mounted) setState(() => _isLoadingMembers = false);
      }
    }
  }

  void _loadExistingData() {
    setState(() {
      _populateForm(widget.existingData!);
    });
  }

  void _populateForm(Map<String, dynamic> d) {
    _registrationNumber.text = d['Registration_Number']?.toString() ?? '';
    selectedFamilyCode = d['Family_Code_Creation'] ?? d['Family_Code'] ?? d['Family_code'] ?? d['Family_ID'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _locationVillage  = (d['Village']  ?? d['village'])?.toString();
    _locationMandal   = (d['Mandal']   ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState    = (d['State']    ?? d['state'])?.toString();
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    _age.text = d['Age']?.toString() ?? '';
    _contactTel.text = d['Contact_Tel'] ?? '';
    
    final rawDate = d['Date_of_Interview'] ?? d['Interview_Date'];
    if (rawDate != null) {
      if (rawDate is Timestamp) {
        dateOfInterview = rawDate.toDate();
      } else {
        try {
          dateOfInterview = DateFormat('dd-MMM-yyyy').parse(rawDate.toString());
        } catch (_) {
          try {
            dateOfInterview = DateTime.parse(rawDate.toString());
          } catch (_) {}
        }
      }
    }
    
    interviewersName = matchInterviewerName(d['Interviewer_s_Name'] ?? d['Interviewer_Name'] ?? d['INTNAME'], interviewerList);
    _heightCm.text = d['Height_CM']?.toString() ?? '';
    _weightKg.text = d['Weight_Kg']?.toString() ?? '';
    generalHealthStatus = d['What_is_your_general_health_status'];

    // Hypertension
    hasHypertension = d['Have_you_ever_been_diagnosed_screened_with_hypertension'] ?? '(2) No';
    _hypertensionDays.text = d['No_of_days1']?.toString() ?? '';
    hypertensionDuration = d['Duration2'];
    hypertensionMedicine = d['b_Are_you_currently_using_any_medicine_s_Medicine_Name1'];
    _hypertensionDosage.text = d['Dosage']?.toString() ?? '';
    _hypertensionOtherMedicine.text = d['Any_other_Medicine_name1']?.toString() ?? '';

    // Diabetes
    hasDiabetes = d['Have_you_ever_been_diagnosed_screened_with_Diabetes'] ?? '(2) No';
    _diabetesDays.text = d['No_of_days']?.toString() ?? '';
    diabetesDuration = d['Duration1'];
    diabetesMedicine = d['b_Are_you_currently_using_any_medicine_s_Medicine_Name'];
    diabetesStrength = d['Strength1'];
    _diabetesOtherMedicine.text = d['Any_other_Medicine_name']?.toString() ?? '';

    // Habits
    smokesNow = d['Do_you_smoke_chew_tobacco_related_products_now'];
    tobaccoProductsPresent = List<Map<String, dynamic>>.from(d['Products_List'] ?? []);
    smokedPast = d['Have_you_ever_smoke_chew_in_the_past'];
    tobaccoProductsPast = List<Map<String, dynamic>>.from(d['Products_List_Past'] ?? []);
    drinksAlcohol = d['Do_you_drink_consume_Alcohol'];
    _alcoholDuration.text = d['Duration']?.toString() ?? '';
    alcoholDurationUnit = d['Dropdown'];
    alcoholProducts = List<Map<String, dynamic>>.from(d['List_field'] ?? []);

    // Systemic Review
    sufferGeneralHealth = d['Did_you_suffer_from_General_Health_problems'] ?? '(2) No';
    generalHealthStatusDetail = d['If_yes7'];
    _generalHealthOther.text = d['If_Others_Please_Mention7']?.toString() ?? '';

    sufferVision = d['Did_you_suffer_from_Vision_problems1'] ?? '(2) No';
    visionStatusDetail = d['If_yes'];
    _visionOther.text = d['If_Others_Please_Mention8']?.toString() ?? '';

    sufferEnt = d['Did_you_suffer_from_ENT_problems2'] ?? '(2) No';
    entStatusDetail = d['If_yes1'];
    _entOther.text = d['If_Others_Please_Mention9']?.toString() ?? '';

    sufferRespiratory = d['Did_you_suffer_from_Respiratory_problems'] ?? '(2) No';
    respiratoryStatusDetail = d['If_yes2'];
    _respiratoryOther.text = d['If_Others_Please_Mention10']?.toString() ?? '';

    sufferGastro = d['Did_you_suffer_from_Gastrointestinal_problems'] ?? '(2) No';
    gastroStatusDetail = d['If_yes3'];
    _gastroOther.text = d['If_Others_Please_Mention11']?.toString() ?? '';

    sufferGenitourinary = d['Did_you_suffer_from_Genitourinary_problems'] ?? '(2) No';
    genitourinaryStatusDetail = d['If_yes4'];
    _genitourinaryOther.text = d['If_Others_Please_Mention12']?.toString() ?? '';

    sufferMusclesBones = d['Did_you_suffer_from_Muscles_or_bones_problems'] ?? '(2) No';
    musclesBonesStatusDetail = d['If_yes5'];
    _musclesBonesOther.text = d['If_Others_Please_Mention13']?.toString() ?? '';

    sufferSkin = d['Did_you_suffer_from_Skin_problems'] ?? '(2) No';
    skinStatusDetail = d['If_yes6'];
    _skinOther.text = d['If_Others_Please_Mention14']?.toString() ?? '';

    sufferBlood = d['Did_you_suffer_from_blood_related_problems'] ?? '(2) No';
    bloodStatusDetail = d['If_yes8'];
    _bloodOther.text = d['If_Others_Please_Mention15']?.toString() ?? '';

    if (!_isEditMode && selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _isActionActive = false;
      _registrationNumber.clear();
      _nameController.clear();
      // selectedFamilyCode = null; // Preserved
      selectedMemberName = null;
      selectedGender = null;
      _locationVillage = null;
      _locationMandal = null;
      _locationDistrict = null;
      _locationState = null;
      _age.clear();
      _contactTel.clear();
      dateOfInterview = DateTime.now();
      interviewersName = null;
      _image = null;
      _heightCm.clear();
      _weightKg.clear();
      generalHealthStatus = null;
      hasHypertension = null; // Cleaned
      _hypertensionDays.clear();
      hypertensionDuration = null;
      hypertensionMedicine = null;
      _hypertensionDosage.clear();
      _hypertensionOtherMedicine.clear();

      hasDiabetes = null; // Cleaned
      _diabetesDays.clear();
      diabetesDuration = null;
      diabetesMedicine = null;
      diabetesStrength = null;
      _diabetesOtherMedicine.clear();

      smokesNow = null; // Cleaned
      tobaccoProductsPresent = [];
      smokedPast = null; // Cleaned
      tobaccoProductsPast = [];
      drinksAlcohol = null; // Cleaned
      _alcoholDuration.clear();
      alcoholDurationUnit = null;
      alcoholProducts = [];

      sufferGeneralHealth = null;
      generalHealthStatusDetail = null;
      _generalHealthOther.clear();
      sufferVision = null;
      visionStatusDetail = null;
      _visionOther.clear();
      sufferEnt = null;
      entStatusDetail = null;
      _entOther.clear();
      sufferRespiratory = null;
      respiratoryStatusDetail = null;
      _respiratoryOther.clear();
      sufferGastro = null;
      gastroStatusDetail = null;
      _gastroOther.clear();
      sufferGenitourinary = null;
      genitourinaryStatusDetail = null;
      _genitourinaryOther.clear();
      sufferMusclesBones = null;
      musclesBonesStatusDetail = null;
      _musclesBonesOther.clear();
      sufferSkin = null;
      skinStatusDetail = null;
      _skinOther.clear();
      sufferBlood = null;
      bloodStatusDetail = null;
      _bloodOther.clear();

      familyMemberNames = [];
      _existingRecords = [];
      // _familyCodeController.text = 'TSRRMED'; // Preserved
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number': int.tryParse(_registrationNumber.text),
        'Family_Code_Creation': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Village': _locationVillage,
        'Mandal': _locationMandal,
        'District': _locationDistrict,
        'State': _locationState,
        'Age': int.tryParse(_age.text),
        'Contact_Tel': int.tryParse(_contactTel.text),
        'Date_of_Interview': dateOfInterview != null ? DateFormat('dd-MMM-yyyy').format(dateOfInterview!) : null,
        'Interviewer_s_Name': interviewersName,
        'Height_CM': int.tryParse(_heightCm.text),
        'Weight_Kg': int.tryParse(_weightKg.text),
        'What_is_your_general_health_status': generalHealthStatus,
        
        // Hypertension
        'Have_you_ever_been_diagnosed_screened_with_hypertension': hasHypertension,
        'No_of_days1': _hypertensionDays.text,
        'Duration2': hypertensionDuration,
        'b_Are_you_currently_using_any_medicine_s_Medicine_Name1': hypertensionMedicine,
        'Dosage': _hypertensionDosage.text,
        'Any_other_Medicine_name1': _hypertensionOtherMedicine.text,

        // Diabetes
        'Have_you_ever_been_diagnosed_screened_with_Diabetes': hasDiabetes,
        'No_of_days': int.tryParse(_diabetesDays.text),
        'Duration1': diabetesDuration,
        'b_Are_you_currently_using_any_medicine_s_Medicine_Name': diabetesMedicine,
        'Strength1': diabetesStrength,
        'Any_other_Medicine_name': _diabetesOtherMedicine.text,

        // Habits
        'Do_you_smoke_chew_tobacco_related_products_now': smokesNow,
        'Products_List': tobaccoProductsPresent,
        'Have_you_ever_smoke_chew_in_the_past': smokedPast,
        'Products_List_Past': tobaccoProductsPast,
        'Do_you_drink_consume_Alcohol': drinksAlcohol,
        'Duration': int.tryParse(_alcoholDuration.text),
        'Dropdown': alcoholDurationUnit,
        'List_field': alcoholProducts,

        // Systemic Review
        'Did_you_suffer_from_General_Health_problems': sufferGeneralHealth,
        'If_yes7': generalHealthStatusDetail,
        'If_Others_Please_Mention7': _generalHealthOther.text,

        'Did_you_suffer_from_Vision_problems1': sufferVision,
        'If_yes': visionStatusDetail,
        'If_Others_Please_Mention8': _visionOther.text,

        'Did_you_suffer_from_ENT_problems2': sufferEnt,
        'If_yes1': entStatusDetail,
        'If_Others_Please_Mention9': _entOther.text,

        'Did_you_suffer_from_Respiratory_problems': sufferRespiratory,
        'If_yes2': respiratoryStatusDetail,
        'If_Others_Please_Mention10': _respiratoryOther.text,

        'Did_you_suffer_from_Gastrointestinal_problems': sufferGastro,
        'If_yes3': gastroStatusDetail,
        'If_Others_Please_Mention11': _gastroOther.text,

        'Did_you_suffer_from_Genitourinary_problems': sufferGenitourinary,
        'If_yes4': genitourinaryStatusDetail,
        'If_Others_Please_Mention12': _genitourinaryOther.text,

        'Did_you_suffer_from_Muscles_or_bones_problems': sufferMusclesBones,
        'If_yes5': musclesBonesStatusDetail,
        'If_Others_Please_Mention13': _musclesBonesOther.text,

        'Did_you_suffer_from_Skin_problems': sufferSkin,
        'If_yes6': skinStatusDetail,
        'If_Others_Please_Mention14': _skinOther.text,

        'Did_you_suffer_from_blood_related_problems': sufferBlood,
        'If_yes8': bloodStatusDetail,
        'If_Others_Please_Mention15': _bloodOther.text,

        'Entry_time': DateFormat('HH:mm:ss').format(DateTime.now()),
        'modified_time1': DateFormat('HH:mm:ss').format(DateTime.now()),
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('questionnaire', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Questionnaire updated! Syncing...' : 'Questionnaire saved! Syncing...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ));
        if (widget.docId != null) {
          Navigator.pop(context);
        } else if (!wasEditing) {
          _resetForm();
        }
      }

      // 2. Background Sync (Non-blocking)
      // Note: DataCacheService already triggers background sync via SyncService if online.
    } catch (e) {
      debugPrint('Error saving questionnaire: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save questionnaire.'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() {
        _isSaving = false;
        _isActionActive = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('Main Questionnaire'), elevation: 0),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('questionnaire_scroll'),
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildIdentitySection(),
                  const SizedBox(height: 16),
                  _buildMeasurementSection(),
                  const SizedBox(height: 16),
                  _buildHypertensionSection(),
                  const SizedBox(height: 16),
                  _buildDiabetesSection(),
                  const SizedBox(height: 16),
                  _buildHabitsSection(),
                  const SizedBox(height: 16),
                  _buildSystemicReview(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: _isSaving
          ? null
          : formActionButtons(
              context: context,
              isEditMode: _isEditMode,
              onNew: () {
                setState(() {
                  _isEditMode = false;
                  _resetForm();
                  _isActionActive = true;
                  _familyIdReadOnly = false;
                  _familyCodeNode.requestFocus();
                });
              },
              onSave: _save,
              onEdit: () {
                setState(() {
                  _isEditMode = true;
                  _isActionActive = true;
                  _familyIdReadOnly = false;
                  _familyCodeNode.requestFocus();
                  final code = _familyCodeController.text.trim();
                  if (code.isNotEmpty) {
                    _fetchMembersByFamily(code);
                    _fetchExistingRecords(code);
                  }
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


  Future<void> _fetchFamilyLocation(String familyCode) async {
    try {
      var detail = await LocalDatabaseService().getSingleFamilyDetail(familyCode.trim().toUpperCase());
      detail ??= await LocalDatabaseService().getSingleFamilyDetail(familyCode.trim());

      if (detail == null) {
        final snap = await FirebaseFirestore.instance
            .collection('Family Code Creation')
            .doc(familyCode.trim().toUpperCase())
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 6));
        if (snap.exists) detail = snap.data();
      }

      if (detail != null && mounted) {
        setState(() {
          _locationVillage  = (detail!['village']  ?? detail['Village'])?.toString();
          _locationMandal   = (detail['mandal']    ?? detail['Mandal'])?.toString();
          _locationDistrict = (detail['district']  ?? detail['District'])?.toString();
          _locationState    = (detail['state']     ?? detail['State'])?.toString();
        });
      }
    } catch (e) {
      debugPrint('_fetchFamilyLocation: $e');
    }
  }

  Widget _buildLocationRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text('$label:', style: const TextStyle(fontSize: 12, color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildIdentitySection() {
    return buildSectionCard(
      context: context,
      title: 'Member Identity',
      icon: Icons.person_outline,
      children: [
        formTextField('Registration Number', _registrationNumber, enabled: _isActionActive, isNumericOnly: true),
        const SizedBox(height: 12),
        formSearchField(
          'Family Code',
          _familyCodeController,
          isUpperCase: true,
          readOnly: _familyIdReadOnly,
          focusNode: _familyCodeNode,
          onSearch: () {
            if (_familyCodeController.text.isNotEmpty) {
              _fetchMembersByFamily(_familyCodeController.text);
              _fetchExistingRecords(_familyCodeController.text);
            }
          },
          isLoading: _isLoadingMembers,
        ),
        const SizedBox(height: 12),
        if (_locationVillage != null || _locationMandal != null || _locationDistrict != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text('Location', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade700, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildLocationRow('Village', _locationVillage),
                  _buildLocationRow('Mandal', _locationMandal),
                  _buildLocationRow('District', _locationDistrict),
                  _buildLocationRow('State', _locationState),
                ],
              ),
            ),
          ),
        formSearchableDropdown(
          context,
          'Name',
          (<String>{...familyMemberNames, ..._existingRecords.map((r) => r['Name']?.toString() ?? '')}
              .where((n) => n.isNotEmpty)
              .toList()
            ..sort()),
          selectedMemberName,
          _onNameSelected,
          isLoading: _isLoadingMembers,
          enabled: _isActionActive,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(child: formRadioOption(label: '(1) Male', value: '(1) Male', groupValue: selectedGender, enabled: _isActionActive, onChanged: (v) => setState(() => selectedGender = v))),
            Expanded(child: formRadioOption(label: '(0) Female', value: '(0) Female', groupValue: selectedGender, enabled: _isActionActive, onChanged: (v) => setState(() => selectedGender = v))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField('Age', _age, enabled: _isActionActive, isNumericOnly: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Interview Date', dateOfInterview, (v) => setState(() => dateOfInterview = v), enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 12),
        formTextField('Contact Tel', _contactTel, enabled: _isActionActive, isNumericOnly: true),
        const SizedBox(height: 12),
         formSearchableDropdown(context, 'Interviewer Name', interviewerList, interviewersName, (v) => setState(() => interviewersName = v as String?), enabled: _isActionActive),
        const SizedBox(height: 16),
        _buildImagePicker(),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Profile Image', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: !_isActionActive ? null : _pickImage,
          child: Container(
            height: 150, width: double.infinity,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
            child: _image == null ? const Center(child: Icon(Icons.camera_alt, size: 50, color: Colors.grey)) : Image.file(_image!, fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementSection() {
    return buildSectionCard(
      context: context,
      title: 'Measurements',
      icon: Icons.straighten_outlined,
      children: [
        Row(
          children: [
            Expanded(child: formTextField('Height (cm)', _heightCm, enabled: _isActionActive, isNumericOnly: true)),
            const SizedBox(width: 12),
            Expanded(child: formTextField('Weight (kg)', _weightKg, enabled: _isActionActive, isNumericOnly: true)),
          ],
        ),
        const SizedBox(height: 12),
         formSearchableDropdown(context, '1. What is your general health status?', ['(1) Excellent', '(2) Good', '(3) Fair', '(4) Poor'], generalHealthStatus, (v) => setState(() => generalHealthStatus = v as String?), enabled: _isActionActive),
      ],
    );
  }

  Widget _buildHypertensionSection() {
    return buildSectionCard(
      context: context,
      title: 'Hypertension',
      icon: Icons.favorite_outline,
      children: [
        const Text('2. Have you ever been diagnosed/screened with hypertension?', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
         Row(
           children: [
             formRadioOption(label: '(1) Yes', value: '(1) Yes', groupValue: hasHypertension, enabled: _isActionActive, onChanged: (v) => setState(() => hasHypertension = v as String?)),
             const SizedBox(width: 16),
             formRadioOption(label: '(2) No', value: '(2) No', groupValue: hasHypertension, enabled: _isActionActive, onChanged: (v) => setState(() => hasHypertension = v as String?)),
           ],
         ),],
        ),
        if (hasHypertension == '(1) Yes') ...[
          const SizedBox(height: 12),
          Row(
            children: [
               Expanded(child: formTextField('(2a) If Yes, since how many had?', _hypertensionDays, enabled: _isActionActive)),
              const SizedBox(width: 8),
                Expanded(child: formSearchableDropdown(context, 'Duration', ['(1) Years', '(2) Months', '(3) Days'], hypertensionDuration, (v) => setState(() => hypertensionDuration = v as String?), enabled: _isActionActive)),
            ],
          ),
          const SizedBox(height: 12),
            formSearchableDropdown(context, '(2b) Are you currently using any medicine\'s?', hypertensionMeds, hypertensionMedicine, (v) => setState(() => hypertensionMedicine = v as String?), enabled: _isActionActive),
          const SizedBox(height: 12),
           formTextField('Dosage', _hypertensionDosage, enabled: _isActionActive),
          const SizedBox(height: 12),
           formTextField('Any other Medicine name', _hypertensionOtherMedicine, enabled: _isActionActive),
        ],
      ],
    );
  }

  Widget _buildDiabetesSection() {
    return buildSectionCard(
      context: context,
      title: 'Diabetes',
      icon: Icons.medical_services_outlined,
      children: [
        const Text('3. Have you ever been diagnosed/screened with Diabetes?', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            formRadioOption(label: '(1) Yes', value: '(1) Yes', groupValue: hasDiabetes, enabled: _isActionActive, onChanged: (v) => setState(() => hasDiabetes = v as String?)),
            const SizedBox(width: 16),
            formRadioOption(label: '(2) No', value: '(2) No', groupValue: hasDiabetes, enabled: _isActionActive, onChanged: (v) => setState(() => hasDiabetes = v as String?)),
          ],
        ),
        if (hasDiabetes == '(1) Yes') ...[
          const SizedBox(height: 12),
          Row(
            children: [
               Expanded(child: formTextField('(3a) If Yes, since how many had?', _diabetesDays, enabled: _isActionActive, keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
                Expanded(child: formSearchableDropdown(context, 'Duration', ['(1) Years', '(2) Months', '(3) Days'], diabetesDuration, (v) => setState(() => diabetesDuration = v as String?), enabled: _isActionActive)),
            ],
          ),
          const SizedBox(height: 12),
            formSearchableDropdown(context, '(3b) Are you currently using any medicine\'s?', diabetesMeds, diabetesMedicine, (v) => setState(() => diabetesMedicine = v as String?), enabled: _isActionActive),
          const SizedBox(height: 12),
            formSearchableDropdown(context, 'Strength', diabetesStrengths, diabetesStrength, (v) => setState(() => diabetesStrength = v as String?), enabled: _isActionActive),
          const SizedBox(height: 12),
           formTextField('Any other Medicine name', _diabetesOtherMedicine, enabled: _isActionActive),
        ],
      ],
    );
  }

  Widget _buildHabitsSection() {
    return buildSectionCard(
      context: context,
      title: 'Habits (Tobacco & Alcohol)',
      icon: Icons.smoke_free_outlined,
      children: [
        const Text('4. Do you smoke/chew tobacco related products now?', style: TextStyle(fontWeight: FontWeight.w500)),
         Row(
           children: [
             formRadioOption(label: '(1) Yes', value: '(1) Yes', groupValue: smokesNow, enabled: _isActionActive, onChanged: (v) => setState(() => smokesNow = v as String?)),
             const SizedBox(width: 16),
             formRadioOption(label: '(2) No', value: '(2) No', groupValue: smokesNow, enabled: _isActionActive, onChanged: (v) => setState(() => smokesNow = v as String?)),
           ],
         ),
        if (smokesNow == '(1) Yes') ...[
          const Text('Products List (Present)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          _buildTobaccoProductsList(tobaccoProductsPresent),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: !_isActionActive ? null : () => _addTobaccoProduct(tobaccoProductsPresent), icon: const Icon(Icons.add), label: const Text('Add Product')),
        ],
        const Divider(height: 32),
        const Text('5. Have you ever smoke/chew in the past?', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            formRadioOption(label: '(1) Yes', value: '(1) Yes', groupValue: smokedPast, enabled: _isActionActive, onChanged: (v) => setState(() => smokedPast = v as String?)),
            const SizedBox(width: 16),
            formRadioOption(label: '(2) No', value: '(2) No', groupValue: smokedPast, enabled: _isActionActive, onChanged: (v) => setState(() => smokedPast = v as String?)),
          ],
        ),
        if (smokedPast == '(1) Yes') ...[
          const Text('Products List (Past)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          _buildTobaccoProductsList(tobaccoProductsPast),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: !_isActionActive ? null : () => _addTobaccoProduct(tobaccoProductsPast), icon: const Icon(Icons.add), label: const Text('Add Product')),
        ],
        const Divider(height: 32),
        const Text('6. Do you drink/consume Alcohol?', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            formRadioOption(label: '(1) Yes', value: '(1) Yes', groupValue: drinksAlcohol, enabled: _isActionActive, onChanged: (v) => setState(() => drinksAlcohol = v as String?)),
            const SizedBox(width: 16),
            formRadioOption(label: '(2) No', value: '(2) No', groupValue: drinksAlcohol, enabled: _isActionActive, onChanged: (v) => setState(() => drinksAlcohol = v as String?)),
          ],
        ),
        if (drinksAlcohol == '(1) Yes') ...[
          const SizedBox(height: 12),
          Row(
            children: [
               Expanded(child: formTextField('Duration', _alcoholDuration, enabled: _isActionActive, keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
                Expanded(child: formSearchableDropdown(context, 'Unit', ['(1) Years', '(2) Months', '(3) Days'], alcoholDurationUnit, (v) => setState(() => alcoholDurationUnit = v as String?), enabled: _isActionActive)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Alcohol List', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          _buildAlcoholProductsList(),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: !_isActionActive ? null : _addAlcoholProduct, icon: const Icon(Icons.add), label: const Text('Add Item')),
        ],
      ],
    );
  }

  Widget _buildTobaccoProductsList(List<Map<String, dynamic>> products) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final item = products[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                      Expanded(child: formSearchableDropdown(context, 'Tobacco Name', tobaccoNames, item['Tobacco_Name'], (v) => setState(() => item['Tobacco_Name'] = v as String?), enabled: _isActionActive)),
                     IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: !_isActionActive ? null : () => setState(() => products.removeAt(index))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                      Expanded(child: formSearchableDropdown(context, 'Habit', ['(1) Yes', '(0) No'], item['Product_Habit'], (v) => setState(() => item['Product_Habit'] = v as String?), enabled: _isActionActive)),
                    const SizedBox(width: 8),
                     Expanded(child: formTextField('Days', TextEditingController(text: item['Days']?.toString() ?? '')..addListener(() {}), enabled: _isActionActive, onChanged: (v) => item['Days'] = int.tryParse(v), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                      Expanded(child: formSearchableDropdown(context, 'Months/Years', ['(1) Years', '(2) Months', '(3) Days'], item['Months_years'], (v) => setState(() => item['Months_years'] = v as String?), enabled: _isActionActive)),
                    const SizedBox(width: 8),
                     Expanded(child: formTextField('Qty', TextEditingController(text: item['Quantity']?.toString() ?? '')..addListener(() {}), enabled: _isActionActive, onChanged: (v) => item['Quantity'] = int.tryParse(v), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 8),
                 formSearchableDropdown(context, 'Type', ['(1) Number', '(2) Packets'], item['Type_field'], (v) => setState(() => item['Type_field'] = v as String?), enabled: _isActionActive),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlcoholProductsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: alcoholProducts.length,
      itemBuilder: (context, index) {
        final item = alcoholProducts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
              Row(
                children: [
                    Expanded(child: formSearchableDropdown(context, 'Item', alcoholItems, item['Item'], (v) => setState(() => item['Item'] = v as String?), enabled: _isActionActive)),
                   IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: !_isActionActive ? null : () => setState(() => alcoholProducts.removeAt(index))),
                ],
              ),
              const SizedBox(height: 8),
               formTextField('If Others Please Mention', TextEditingController(text: item['If_Others_Please_Mention'] ?? '')..addListener(() {}), enabled: _isActionActive, onChanged: (v) => item['If_Others_Please_Mention'] = v),
              const SizedBox(height: 8),
                formSearchableDropdown(context, 'Frequency', alcoholFrequencies, item['Frequent'], (v) => setState(() => item['Frequent'] = v as String?), enabled: _isActionActive),
              const SizedBox(height: 8),
              Row(
                children: [
                   Expanded(child: formTextField('Quantity', TextEditingController(text: item['Quantity']?.toString() ?? '')..addListener(() {}), enabled: _isActionActive, onChanged: (v) => item['Quantity'] = int.tryParse(v), keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                    Expanded(child: formSearchableDropdown(context, 'Unit', alcoholUnits, item['Units'], (v) => setState(() => item['Units'] = v as String?), enabled: _isActionActive)),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

  void _addTobaccoProduct(List<Map<String, dynamic>> products) {
    setState(() { products.add({'Tobacco_Name': null, 'Product_Habit': '(1) Yes', 'Days': null, 'Months_years': null, 'Quantity': null, 'Type_field': null}); });
  }

  void _addAlcoholProduct() {
     setState(() { alcoholProducts.add({'Item': null, 'If_Others_Please_Mention': '', 'Frequent': null, 'Quantity': null, 'Units': null}); });
  }

  Widget _buildSystemicReview() {
    return buildSectionCard(
      context: context,
      title: 'Systemic Review',
      icon: Icons.medical_services_outlined,
      children: [
        _buildReviewItem(
          '7. Did you suffer from General Health problems?',
          sufferGeneralHealth,
          (v) => setState(() => sufferGeneralHealth = v as String?),
          details: sufferGeneralHealth == '(1) Yes' ? Column(
            children: [
                formSearchableDropdown(context, 'Details', ['(1) Weight gain', '(2) Weight loss'], generalHealthStatusDetail, (v) => setState(() => generalHealthStatusDetail = v as String?), enabled: _isActionActive),
               const SizedBox(height: 8),
               formTextField('If Others Please Mention', _generalHealthOther, enabled: _isActionActive),
            ],
          ) : null,
        ),
        _buildReviewItem(
          '8. Did you suffer from vision problems?',
          sufferVision,
          (v) => setState(() => sufferVision = v as String?),
          details: sufferVision == '(1) Yes' ? Column(
            children: [
                formSearchableDropdown(context, 'Details', ['(1) Near sightedness', '(2) Far sightedness', '(3) Any Other'], visionStatusDetail, (v) => setState(() => visionStatusDetail = v as String?), enabled: _isActionActive),
               const SizedBox(height: 8),
               formTextField('If Others Please Mention', _visionOther, enabled: _isActionActive),
            ],
          ) : null,
        ),
        _buildReviewItem(
          '9. Did you suffer from Ear, Nose and Throat problems?',
          sufferEnt,
          (v) => setState(() => sufferEnt = v as String?),
          details: sufferEnt == '(1) Yes' ? Column(
            children: [
                formSearchableDropdown(context, 'Details', ['(1) Ear', '(2) Nose', '(3) Throat', '(4) Any Other'], entStatusDetail, (v) => setState(() => entStatusDetail = v as String?), enabled: _isActionActive),
               const SizedBox(height: 8),
               formTextField('If Others Please Mention', _entOther, enabled: _isActionActive),
            ],
          ) : null,
        ),
        _buildReviewItem(
          '10. Did you suffer from Respiratory problems?',
          sufferRespiratory,
          (v) => setState(() => sufferRespiratory = v as String?),
          details: sufferRespiratory == '(1) Yes' ? Column(
            children: [
                formSearchableDropdown(context, 'Details', ['(1) Aasthma', '(2) COPD', '(3) Any Other'], respiratoryStatusDetail, (v) => setState(() => respiratoryStatusDetail = v as String?), enabled: _isActionActive),
               const SizedBox(height: 8),
               formTextField('If Others Please Mention', _respiratoryOther, enabled: _isActionActive),
            ],
          ) : null,
        ),
        _buildReviewItem(
          '11. Did you suffer from Gastrointestinal problems?',
          sufferGastro,
          (v) => setState(() => sufferGastro = v as String?),
          details: sufferGastro == '(1) Yes' ? Column(
            children: [
                formSearchableDropdown(context, 'Details', ['(1) Heart burn', '(2) Abdominal Pain', '(3) Any Other'], gastroStatusDetail, (v) => setState(() => gastroStatusDetail = v as String?), enabled: _isActionActive),
               const SizedBox(height: 8),
               formTextField('If Others Please Mention', _gastroOther, enabled: _isActionActive),
            ],
          ) : null,
        ),
        _buildReviewItem(
          '12. Did you suffer from Genitourinary problems?',
          sufferGenitourinary,
          (v) => setState(() => sufferGenitourinary = v as String?),
          details: sufferGenitourinary == '(1) Yes' ? Column(
            children: [
                formSearchableDropdown(context, 'Details', ['(1) Burning in urine', '(2) Increase frequency of urine', '(3) Any Other'], genitourinaryStatusDetail, (v) => setState(() => genitourinaryStatusDetail = v as String?), enabled: _isActionActive),
               const SizedBox(height: 8),
               formTextField('If Others Please Mention', _genitourinaryOther, enabled: _isActionActive),
            ],
          ) : null,
        ),
        _buildReviewItem(
          '13. Did you suffer from Muscles or bones problems?',
          sufferMusclesBones,
          (v) => setState(() => sufferMusclesBones = v as String?),
          details: sufferMusclesBones == '(1) Yes' ? Column(
            children: [
                formSearchableDropdown(context, 'Details', ['(1) Arthritis', '(2) Spondylitis', '(3) Any Other'], musclesBonesStatusDetail, (v) => setState(() => musclesBonesStatusDetail = v as String?), enabled: _isActionActive),
               const SizedBox(height: 8),
               formTextField('If Others Please Mention', _musclesBonesOther, enabled: _isActionActive),
            ],
          ) : null,
        ),
        _buildReviewItem(
          '14. Did you suffer from Skin problems?',
          sufferSkin,
          (v) => setState(() => sufferSkin = v as String?),
          details: sufferSkin == '(1) Yes' ? Column(
            children: [
                formSearchableDropdown(context, 'Details', ['(1) Skin rash', '(2) Skin dryness', '(3) Itching', '(4) Any Other'], skinStatusDetail, (v) => setState(() => skinStatusDetail = v as String?), enabled: _isActionActive),
               const SizedBox(height: 8),
               formTextField('If Others Please Mention', _skinOther, enabled: _isActionActive),
            ],
          ) : null,
        ),
        _buildReviewItem(
          '15. Did you suffer from blood related problems?',
          sufferBlood,
          (v) => setState(() => sufferBlood = v as String?),
          details: sufferBlood == '(1) Yes' ? Column(
            children: [
                formSearchableDropdown(context, 'Details', ['(1) Anemia', '(2) Bruising or excessive bleeding', '(3) Any Other'], bloodStatusDetail, (v) => setState(() => bloodStatusDetail = v as String?), enabled: _isActionActive),
               const SizedBox(height: 8),
               formTextField('If Others Please Mention', _bloodOther, enabled: _isActionActive),
            ],
          ) : null,
        ),
      ],
    );
  }

  Widget _buildReviewItem(String title, String? val, ValueChanged<String?> onChanged, {Widget? details}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
         Row(children: [
          Expanded(child: RadioListTile<String>(value: '(1) Yes', title: const Text('Yes', style: TextStyle(fontSize: 12)), groupValue: val, onChanged: !_isActionActive ? null : (v) => onChanged(v as String?), contentPadding: EdgeInsets.zero, dense: true)),
          Expanded(child: RadioListTile<String>(value: '(2) No', title: const Text('No', style: TextStyle(fontSize: 12)), groupValue: val, onChanged: !_isActionActive ? null : (v) => onChanged(v as String?), contentPadding: EdgeInsets.zero, dense: true)),
        ]),
        if (details != null) Padding(padding: const EdgeInsets.only(left: 16, bottom: 12), child: details),
        const Divider(),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onPicked, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        InkWell(
           onTap: !enabled ? null : () async {
            final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
            final picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
            if (picked != null) {
              onPicked(picked);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) _scrollController.jumpTo(offset);
              });
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), suffixIcon: const Icon(Icons.calendar_today, size: 18)),
            child: Text(selectedDate == null ? 'dd-MMM-yyyy' : DateFormat('dd-MMM-yyyy').format(selectedDate)),
          ),
        ),
      ],
    );
  }
}
