import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'app_drawer.dart';
import 'data_cache_service.dart';
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
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;

  // --- Identity & Registration ---
  final _registrationNumber = TextEditingController();
  final _familyCodeController = TextEditingController();
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

  // --- Measurements ---
  final _heightCm = TextEditingController();
  final _weightKg = TextEditingController();
  String? generalHealthStatus;

  // --- Hypertension ---
  String? hasHypertension = '(2) No';
  final _hypertensionDays = TextEditingController();
  String? hypertensionDuration;
  String? hypertensionMedicine;
  final _hypertensionDosage = TextEditingController();
  final _hypertensionOtherMedicine = TextEditingController();

  // --- Diabetes ---
  String? hasDiabetes = '(2) No';
  final _diabetesDays = TextEditingController();
  String? diabetesDuration;
  String? diabetesMedicine;
  String? diabetesStrength;
  final _diabetesOtherMedicine = TextEditingController();

  // --- Tobacco & Alcohol ---
  String? smokesNow = '(2) No';
  List<Map<String, dynamic>> tobaccoProductsPresent = [];
  String? smokedPast = '(2) No';
  List<Map<String, dynamic>> tobaccoProductsPast = [];
  String? drinksAlcohol = '(2) No';
  final _alcoholDuration = TextEditingController();
  String? alcoholDurationUnit;
  List<Map<String, dynamic>> alcoholProducts = [];

  // --- Systemic Review ---
  String? sufferGeneralHealth = '(2) No';
  String? generalHealthStatusDetail;
  final _generalHealthOther = TextEditingController();
  String? sufferVision = '(2) No';
  String? visionStatusDetail;
  final _visionOther = TextEditingController();
  String? sufferEnt = '(2) No';
  String? entStatusDetail;
  final _entOther = TextEditingController();
  String? sufferRespiratory = '(2) No';
  String? respiratoryStatusDetail;
  final _respiratoryOther = TextEditingController();
  String? sufferGastro = '(2) No';
  String? gastroStatusDetail;
  final _gastroOther = TextEditingController();
  String? sufferGenitourinary = '(2) No';
  String? genitourinaryStatusDetail;
  final _genitourinaryOther = TextEditingController();
  String? sufferMusclesBones = '(2) No';
  String? musclesBonesStatusDetail;
  final _musclesBonesOther = TextEditingController();
  String? sufferSkin = '(2) No';
  String? skinStatusDetail;
  final _skinOther = TextEditingController();
  String? sufferBlood = '(2) No';
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
      _loadExistingData();
    }
  }

  Future<void> _fetchMembersByFamily(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyCode)
          .get(const GetOptions(source: Source.serverAndCache));
      final localMembers = await DataCacheService().fetchMembersLocally(familyCode);
      final Map<String, Map<String, dynamic>> memberMap = {};
      final Set<String> allNames = {};
      void processMember(Map<String, dynamic> data) {
        final name = data['Name']?.toString() ?? '';
        if (name.isEmpty) return;
        memberMap[name] = data;
        allNames.add(name);
      }
      for (var doc in snapshot.docs) processMember(doc.data());
      for (var local in localMembers) processMember(local);
      setState(() {
        _allMembersData = memberMap;
        familyMemberNames = allNames.toList()..sort();
        selectedFamilyCode = familyCode;
      });
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
          .get();
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
            .get();

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
    
    interviewersName = d['Interviewer_s_Name'];
    _heightCm.text = d['Height_cm']?.toString() ?? '';
    _weightKg.text = d['Weight_Kg']?.toString() ?? '';
    generalHealthStatus = d['General_Health_Status'];

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

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _registrationNumber.clear();
      _familyCodeController.clear();
      _nameController.clear();
      selectedFamilyCode = null;
      selectedMemberName = null;
      selectedGender = null;
      _age.clear();
      _contactTel.clear();
      dateOfInterview = DateTime.now();
      interviewersName = null;
      _image = null;
      _heightCm.clear();
      _weightKg.clear();
      generalHealthStatus = null;
      hasHypertension = '(2) No';
      _hypertensionDays.clear();
      hypertensionDuration = null;
      hypertensionMedicine = null;
      _hypertensionDosage.clear();
      _hypertensionOtherMedicine.clear();

      hasDiabetes = '(2) No';
      _diabetesDays.clear();
      diabetesDuration = null;
      diabetesMedicine = null;
      diabetesStrength = null;
      _diabetesOtherMedicine.clear();

      smokesNow = '(2) No';
      tobaccoProductsPresent = [];
      smokedPast = '(2) No';
      tobaccoProductsPast = [];
      drinksAlcohol = '(2) No';
      _alcoholDuration.clear();
      alcoholDurationUnit = null;
      alcoholProducts = [];

      sufferGeneralHealth = '(2) No';
      generalHealthStatusDetail = null;
      _generalHealthOther.clear();
      sufferVision = '(2) No';
      visionStatusDetail = null;
      _visionOther.clear();
      sufferEnt = '(2) No';
      entStatusDetail = null;
      _entOther.clear();
      sufferRespiratory = '(2) No';
      respiratoryStatusDetail = null;
      _respiratoryOther.clear();
      sufferGastro = '(2) No';
      gastroStatusDetail = null;
      _gastroOther.clear();
      sufferGenitourinary = '(2) No';
      genitourinaryStatusDetail = null;
      _genitourinaryOther.clear();
      sufferMusclesBones = '(2) No';
      musclesBonesStatusDetail = null;
      _musclesBonesOther.clear();
      sufferSkin = '(2) No';
      skinStatusDetail = null;
      _skinOther.clear();
      sufferBlood = '(2) No';
      bloodStatusDetail = null;
      _bloodOther.clear();

      familyMemberNames = [];
      _existingRecords = [];
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
      if (mounted) setState(() => _isSaving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Main Questionnaire'), elevation: 0),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('questionnaire_scroll'),
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  formActionButtons(
                      context: context,
                      isEditMode: _isEditMode,
                      onNew: () { setState(() { _isEditMode = false; _resetForm(); }); },
                      onSave: _save,
                      onEdit: () {
                        setState(() {
                          _isEditMode = true;
                          final code = _familyCodeController.text.trim();
                          if (code.isNotEmpty) {
                            _fetchMembersByFamily(code);
                            _fetchExistingRecords(code);
                          }
                        });
                      },
                      onCancel: _resetForm,
                      onExit: () => Navigator.pop(context),
                      isSaving: _isSaving,
                    ),
                    const SizedBox(height: 16),
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
    );
  }

  Widget _buildIdentitySection() {
    return buildSectionCard(
      context: context,
      title: 'Member Identity',
      icon: Icons.person_outline,
      children: [
        formTextField('Registration Number', _registrationNumber),
        const SizedBox(height: 12),
        formSearchField(
          'Family Code',
          _familyCodeController,
          onSearch: () {
            if (_familyCodeController.text.isNotEmpty) {
              _fetchMembersByFamily(_familyCodeController.text);
              _fetchExistingRecords(_familyCodeController.text);
            }
          },
          isLoading: _isLoadingMembers,
        ),
        const SizedBox(height: 12),
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
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: '(1) Male', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: '(0) Female', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField('Age', _age, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Interview Date', dateOfInterview, (v) => setState(() => dateOfInterview = v))),
          ],
        ),
        const SizedBox(height: 12),
        formTextField('Contact Tel', _contactTel, keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        formSearchableDropdown(context, 'Interviewer Name', interviewerList, interviewersName, (v) => setState(() => interviewersName = v)),
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
          onTap: _pickImage,
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
            Expanded(child: formTextField('Height (cm)', _heightCm, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: formTextField('Weight (kg)', _weightKg, keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(context, '1. What is your general health status?', ['(1) Excellent', '(2) Good', '(3) Fair', '(4) Poor'], generalHealthStatus, (v) => setState(() => generalHealthStatus = v)),
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
            Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '(1) Yes', groupValue: hasHypertension, onChanged: (v) => setState(() => hasHypertension = v), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '(2) No', groupValue: hasHypertension, onChanged: (v) => setState(() => hasHypertension = v), contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
        if (hasHypertension == '(1) Yes') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: formTextField('(2a) If Yes, since how many had?', _hypertensionDays)),
              const SizedBox(width: 8),
              Expanded(child: formSearchableDropdown(context, 'Duration', ['(1) Years', '(2) Months', '(3) Days'], hypertensionDuration, (v) => setState(() => hypertensionDuration = v))),
            ],
          ),
          const SizedBox(height: 12),
          formSearchableDropdown(context, '(2b) Are you currently using any medicine\'s?', hypertensionMeds, hypertensionMedicine, (v) => setState(() => hypertensionMedicine = v)),
          const SizedBox(height: 12),
          formTextField('Dosage', _hypertensionDosage),
          const SizedBox(height: 12),
          formTextField('Any other Medicine name', _hypertensionOtherMedicine),
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
            Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '(1) Yes', groupValue: hasDiabetes, onChanged: (v) => setState(() => hasDiabetes = v), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '(2) No', groupValue: hasDiabetes, onChanged: (v) => setState(() => hasDiabetes = v), contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
        if (hasDiabetes == '(1) Yes') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: formTextField('(3a) If Yes, since how many had?', _diabetesDays, keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: formSearchableDropdown(context, 'Duration', ['(1) Years', '(2) Months', '(3) Days'], diabetesDuration, (v) => setState(() => diabetesDuration = v))),
            ],
          ),
          const SizedBox(height: 12),
          formSearchableDropdown(context, '(3b) Are you currently using any medicine\'s?', diabetesMeds, diabetesMedicine, (v) => setState(() => diabetesMedicine = v)),
          const SizedBox(height: 12),
          formSearchableDropdown(context, 'Strength', diabetesStrengths, diabetesStrength, (v) => setState(() => diabetesStrength = v)),
          const SizedBox(height: 12),
          formTextField('Any other Medicine name', _diabetesOtherMedicine),
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
            Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '(1) Yes', groupValue: smokesNow, onChanged: (v) => setState(() => smokesNow = v), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '(2) No', groupValue: smokesNow, onChanged: (v) => setState(() => smokesNow = v), contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
        if (smokesNow == '(1) Yes') ...[
          const Text('Products List (Present)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          _buildTobaccoProductsList(tobaccoProductsPresent),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: () => _addTobaccoProduct(tobaccoProductsPresent), icon: const Icon(Icons.add), label: const Text('Add Product')),
        ],
        const Divider(height: 32),
        const Text('5. Have you ever smoke/chew in the past?', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '(1) Yes', groupValue: smokedPast, onChanged: (v) => setState(() => smokedPast = v), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '(2) No', groupValue: smokedPast, onChanged: (v) => setState(() => smokedPast = v), contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
        if (smokedPast == '(1) Yes') ...[
          const Text('Products List (Past)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          _buildTobaccoProductsList(tobaccoProductsPast),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: () => _addTobaccoProduct(tobaccoProductsPast), icon: const Icon(Icons.add), label: const Text('Add Product')),
        ],
        const Divider(height: 32),
        const Text('6. Do you drink/consume Alcohol?', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '(1) Yes', groupValue: drinksAlcohol, onChanged: (v) => setState(() => drinksAlcohol = v), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '(2) No', groupValue: drinksAlcohol, onChanged: (v) => setState(() => drinksAlcohol = v), contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
        if (drinksAlcohol == '(1) Yes') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: formTextField('Duration', _alcoholDuration, keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: formSearchableDropdown(context, 'Unit', ['(1) Years', '(2) Months', '(3) Days'], alcoholDurationUnit, (v) => setState(() => alcoholDurationUnit = v))),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Alcohol List', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          _buildAlcoholProductsList(),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: _addAlcoholProduct, icon: const Icon(Icons.add), label: const Text('Add Item')),
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
                    Expanded(child: formSearchableDropdown(context, 'Tobacco Name', tobaccoNames, item['Tobacco_Name'], (v) => setState(() => item['Tobacco_Name'] = v))),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => products.removeAt(index))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: formSearchableDropdown(context, 'Habit', ['(1) Yes', '(0) No'], item['Product_Habit'], (v) => setState(() => item['Product_Habit'] = v))),
                    const SizedBox(width: 8),
                    Expanded(child: formTextField('Days', TextEditingController(text: item['Days']?.toString() ?? '')..addListener(() {}), onChanged: (v) => item['Days'] = int.tryParse(v), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: formSearchableDropdown(context, 'Months/Years', ['(1) Years', '(2) Months', '(3) Days'], item['Months_years'], (v) => setState(() => item['Months_years'] = v))),
                    const SizedBox(width: 8),
                    Expanded(child: formTextField('Qty', TextEditingController(text: item['Quantity']?.toString() ?? '')..addListener(() {}), onChanged: (v) => item['Quantity'] = int.tryParse(v), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 8),
                formSearchableDropdown(context, 'Type', ['(1) Number', '(2) Packets'], item['Type_field'], (v) => setState(() => item['Type_field'] = v)),
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
                    Expanded(child: formSearchableDropdown(context, 'Item', alcoholItems, item['Item'], (v) => setState(() => item['Item'] = v))),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => alcoholProducts.removeAt(index))),
                  ],
                ),
                const SizedBox(height: 8),
                formTextField('If Others Please Mention', TextEditingController(text: item['If_Others_Please_Mention'] ?? '')..addListener(() {}), onChanged: (v) => item['If_Others_Please_Mention'] = v),
                const SizedBox(height: 8),
                formSearchableDropdown(context, 'Frequency', alcoholFrequencies, item['Frequent'], (v) => setState(() => item['Frequent'] = v)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: formTextField('Quantity', TextEditingController(text: item['Quantity']?.toString() ?? '')..addListener(() {}), onChanged: (v) => item['Quantity'] = int.tryParse(v), keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: formSearchableDropdown(context, 'Unit', alcoholUnits, item['Units'], (v) => setState(() => item['Units'] = v))),
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
          (v) => setState(() => sufferGeneralHealth = v),
          details: sufferGeneralHealth == '(1) Yes' ? Column(
            children: [
              formSearchableDropdown(context, 'Details', ['(1) Weight gain', '(2) Weight loss'], generalHealthStatusDetail, (v) => setState(() => generalHealthStatusDetail = v)),
              const SizedBox(height: 8),
              formTextField('If Others Please Mention', _generalHealthOther),
            ],
          ) : null,
        ),
        _buildReviewItem(
          '8. Did you suffer from vision problems?',
          sufferVision,
          (v) => setState(() => sufferVision = v),
          details: sufferVision == '(1) Yes' ? Column(
            children: [
              formSearchableDropdown(context, 'Details', ['(1) Near sightedness', '(2) Far sightedness', '(3) Any Other'], visionStatusDetail, (v) => setState(() => visionStatusDetail = v)),
              const SizedBox(height: 8),
              formTextField('If Others Please Mention', _visionOther),
            ],
          ) : null,
        ),
        _buildReviewItem(
          '9. Did you suffer from Ear, Nose and Throat problems?',
          sufferEnt,
          (v) => setState(() => sufferEnt = v),
          details: sufferEnt == '(1) Yes' ? Column(
            children: [
              formSearchableDropdown(context, 'Details', ['(1) Ear', '(2) Nose', '(3) Throat', '(4) Any Other'], entStatusDetail, (v) => setState(() => entStatusDetail = v)),
              const SizedBox(height: 8),
              formTextField('If Others Please Mention', _entOther),
            ],
          ) : null,
        ),
        _buildReviewItem(
          '10. Did you suffer from Respiratory problems?',
          sufferRespiratory,
          (v) => setState(() => sufferRespiratory = v),
          details: sufferRespiratory == '(1) Yes' ? Column(
            children: [
              formSearchableDropdown(context, 'Details', ['(1) Aasthma', '(2) COPD', '(3) Any Other'], respiratoryStatusDetail, (v) => setState(() => respiratoryStatusDetail = v)),
              const SizedBox(height: 8),
              formTextField('If Others Please Mention', _respiratoryOther),
            ],
          ) : null,
        ),
        _buildReviewItem(
          '11. Did you suffer from Gastrointestinal problems?',
          sufferGastro,
          (v) => setState(() => sufferGastro = v),
          details: sufferGastro == '(1) Yes' ? Column(
            children: [
              formSearchableDropdown(context, 'Details', ['(1) Heart burn', '(2) Abdominal Pain', '(3) Any Other'], gastroStatusDetail, (v) => setState(() => gastroStatusDetail = v)),
              const SizedBox(height: 8),
              formTextField('If Others Please Mention', _gastroOther),
            ],
          ) : null,
        ),
        _buildReviewItem(
          '12. Did you suffer from Genitourinary problems?',
          sufferGenitourinary,
          (v) => setState(() => sufferGenitourinary = v),
          details: sufferGenitourinary == '(1) Yes' ? Column(
            children: [
              formSearchableDropdown(context, 'Details', ['(1) Burning in urine', '(2) Increase frequency of urine', '(3) Any Other'], genitourinaryStatusDetail, (v) => setState(() => genitourinaryStatusDetail = v)),
              const SizedBox(height: 8),
              formTextField('If Others Please Mention', _genitourinaryOther),
            ],
          ) : null,
        ),
        _buildReviewItem(
          '13. Did you suffer from Muscles or bones problems?',
          sufferMusclesBones,
          (v) => setState(() => sufferMusclesBones = v),
          details: sufferMusclesBones == '(1) Yes' ? Column(
            children: [
              formSearchableDropdown(context, 'Details', ['(1) Arthritis', '(2) Spondylitis', '(3) Any Other'], musclesBonesStatusDetail, (v) => setState(() => musclesBonesStatusDetail = v)),
              const SizedBox(height: 8),
              formTextField('If Others Please Mention', _musclesBonesOther),
            ],
          ) : null,
        ),
        _buildReviewItem(
          '14. Did you suffer from Skin problems?',
          sufferSkin,
          (v) => setState(() => sufferSkin = v),
          details: sufferSkin == '(1) Yes' ? Column(
            children: [
              formSearchableDropdown(context, 'Details', ['(1) Skin rash', '(2) Skin dryness', '(3) Itching', '(4) Any Other'], skinStatusDetail, (v) => setState(() => skinStatusDetail = v)),
              const SizedBox(height: 8),
              formTextField('If Others Please Mention', _skinOther),
            ],
          ) : null,
        ),
        _buildReviewItem(
          '15. Did you suffer from blood related problems?',
          sufferBlood,
          (v) => setState(() => sufferBlood = v),
          details: sufferBlood == '(1) Yes' ? Column(
            children: [
              formSearchableDropdown(context, 'Details', ['(1) Anemia', '(2) Bruising or excessive bleeding', '(3) Any Other'], bloodStatusDetail, (v) => setState(() => bloodStatusDetail = v)),
              const SizedBox(height: 8),
              formTextField('If Others Please Mention', _bloodOther),
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
          Expanded(child: RadioListTile<String>(value: '(1) Yes', title: const Text('Yes', style: TextStyle(fontSize: 12)), groupValue: val, onChanged: onChanged, contentPadding: EdgeInsets.zero, dense: true)),
          Expanded(child: RadioListTile<String>(value: '(2) No', title: const Text('No', style: TextStyle(fontSize: 12)), groupValue: val, onChanged: onChanged, contentPadding: EdgeInsets.zero, dense: true)),
        ]),
        if (details != null) Padding(padding: const EdgeInsets.only(left: 16, bottom: 12), child: details),
        const Divider(),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
            if (picked != null) onPicked(picked);
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
