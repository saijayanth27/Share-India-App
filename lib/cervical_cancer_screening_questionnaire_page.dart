import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'local_database_service.dart';
import 'sync_service.dart';
import 'widget.dart';

class CervicalCancerScreeningPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const CervicalCancerScreeningPage({super.key, this.existingData, this.docId});

  @override
  State<CervicalCancerScreeningPage> createState() => _CervicalCancerScreeningPageState();
}

class _CervicalCancerScreeningPageState extends State<CervicalCancerScreeningPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;
  bool _isActionActive = false; // Add this
  final FocusNode _familyCodeNode = FocusNode();
  bool _familyIdReadOnly = true;

  bool _isDownloadingCC = false;
  bool _ccAlreadyDownloaded = false;
  String? _ccDownloadedAt;

  // --- Controllers ---
  final _nameController = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _familyIdController = TextEditingController(text: 'TSRRMED');
  final _ageController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _schoolLevelController = TextEditingController();
  final _occupationController = TextEditingController();
  final _monthlyIncomeController = TextEditingController();
  final _familyMembersCountController = TextEditingController();
  final _age1Controller = TextEditingController();
  // A10-A13
  final _marriageDurationController = TextEditingController();
  final _ageAtMarriageController = TextEditingController();
  final _ageFirstIntercourseController = TextEditingController();
  final _husbandOccupationController = TextEditingController();
  // B section
  final _papSmearHospitalController = TextEditingController();
  final _abnormalTreatmentController = TextEditingController();
  final _dischargeTreatmentController = TextEditingController();
  final _gynecSymptomsController = TextEditingController();
  final _medicationController = TextEditingController();
  // D section
  final _menarcheAgeController = TextEditingController();
  final _ageFirstPregnantController = TextEditingController();
  final _timesPregnantController = TextEditingController();
  final _liveChildrenController = TextEditingController();
  // C9/C10 other
  final _smokingRelationOtherController = TextEditingController();
  final _continuousSmokingRelationOtherController = TextEditingController();
  // Sample collection
  final _vaginalSwabReasonController = TextEditingController();
  final _urineReasonController = TextEditingController();

  // --- State ---
  String? selectedFamilyId;
  String? selectedMemberName;
  String? selectedGender;
  DateTime? examDate = DateTime.now();
  DateTime? dateOfBirth;
  String? selectedAttendedSchool;
  String? selectedReligion;
  String? selectedMaritalStatus;
  String? selectedMenopause;
  String? selectedVIA;
  String? selectedTreatment;
  // A section DK flags
  bool _incomeDontKnow = false;
  bool _marriageDurationDK = false;
  bool _ageAtMarriageDK = false;
  bool _ageFirstIntercourseDK = false;
  // B section
  String? _b1PapSmear;
  DateTime? _b2PapSmearDate;
  String? _b4InformedAbnormal;
  String? _b5TreatmentAbnormal;
  String? _b6VaginalDischarge;
  String? _b6aDischargeTreatment;
  String? _b7GynecSymptoms;
  String? _b8Medication;
  // C section
  String? _c8SmokerCohabitation;
  String? _c9SmokerRelation;
  String? _c10ContinuousSmokerRelation;
  // D section
  String? _d2StillMenstruating;
  DateTime? _d3LastMenstrualPeriod;
  DateTime? _d4StopMenstrualDate;
  String? _d5EverPregnant;
  bool _menarcheDK = false;
  bool _ageFirstPregnantDK = false;
  bool _timesPregnantDK = false;
  bool _liveChildrenDK = false;
  DateTime? _d9LastChildDate;
  // E section
  String? _e1EverBirthControl;
  String? _e2EverOralContraceptives;
  String? _e3CurrentOralContraceptives;
  String? _e4EverCondoms;
  String? _e5EverIUCD;
  String? _e6Tubectomised;
  // Sample collection
  String? _vaginalSwab;
  String? _urineSample;

  // Lookup Options
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  // Location (auto-populated from Family Code)
  String? _locationVillage;
  String? _locationMandal;
  String? _locationDistrict;
  String? _locationState;


  @override
  void initState() {
    super.initState();
    _loadCCDownloadStatus();
    if (widget.existingData != null) {
      _isEditMode = true;
      _editDocId = widget.docId;
      _loadExistingData();
      final familyCode = (widget.existingData!['Family_ID'] ?? widget.existingData!['Family_Code'] ?? widget.existingData!['Family_code'] ?? '').toString();
      if (familyCode.isNotEmpty) {
        _fetchMembersByFamily(familyCode);
        _fetchExistingRecords(familyCode);
      }
    }
  }

  @override
  void dispose() {
    _familyCodeNode.dispose();
    _nameController.dispose();
    _registrationNumber.dispose();
    _familyIdController.dispose();
    _ageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _schoolLevelController.dispose();
    _occupationController.dispose();
    _monthlyIncomeController.dispose();
    _familyMembersCountController.dispose();
    _age1Controller.dispose();
    _marriageDurationController.dispose();
    _ageAtMarriageController.dispose();
    _ageFirstIntercourseController.dispose();
    _husbandOccupationController.dispose();
    _papSmearHospitalController.dispose();
    _abnormalTreatmentController.dispose();
    _dischargeTreatmentController.dispose();
    _gynecSymptomsController.dispose();
    _medicationController.dispose();
    _menarcheAgeController.dispose();
    _ageFirstPregnantController.dispose();
    _timesPregnantController.dispose();
    _liveChildrenController.dispose();
    _smokingRelationOtherController.dispose();
    _continuousSmokingRelationOtherController.dispose();
    _vaginalSwabReasonController.dispose();
    _urineReasonController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCCDownloadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString('cc_download_timestamp');
    if (mounted) setState(() { _ccAlreadyDownloaded = ts != null; _ccDownloadedAt = ts; });
  }

  Future<void> _downloadCCFromStorage() async {
    if (_isDownloadingCC) return;
    final prefs = await SharedPreferences.getInstance();

    if (_ccAlreadyDownloaded) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Already Downloaded'),
          content: Text('Cervical screening data was downloaded on $_ccDownloadedAt.\n\nDownload again to refresh?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Re-download')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isDownloadingCC = true);
    try {
      final ref = FirebaseStorage.instance.ref('exports/cc_records.json');
      final url = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final List<dynamic> jsonList = jsonDecode(response.body);
      final records = jsonList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await LocalDatabaseService().saveCcRecords(records, clearFirst: true);
      final downloadedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      await prefs.setString('cc_download_timestamp', downloadedAt);
      if (mounted) {
        setState(() { _ccAlreadyDownloaded = true; _ccDownloadedAt = downloadedAt; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('CC data downloaded (${records.length} records)'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Download failed: $e'), backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isDownloadingCC = false);
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

        // Filter: only members aged 18 or older
        final age = int.tryParse(data['Age']?.toString() ?? '0') ?? 0;
        if (age < 18) return;

        memberMap[name] = data;
        allNames.add(name);
      }
      for (var doc in snapshot.docs) processMember(doc.data());
      for (var local in localMembers) processMember(local);
      setState(() {
        _allMembersData = memberMap;
        familyMemberNames = allNames.toList()..sort();
        selectedFamilyId = familyCode;
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
          .collection('cervical_screening')
          .where('Family_ID', isEqualTo: familyCode)
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
      _registrationNumber.text = (baseData['uniq_Registration_Number'] ?? baseData['Registration_Number'] ?? baseData['Registration_Number1'] ?? '').toString();
      selectedGender = normalizeGender(baseData['Gender']);
      _ageController.text = baseData['Age']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyIdController.text.trim();

        // Check local SQLite first
        final localRecord = await LocalDatabaseService().getCcRecordByName(fCode, name);
        if (localRecord != null) {
          final merged = {...?baseData, ...localRecord};
          if (mounted) setState(() => _populateForm(merged));
        }

        // Try Firestore with timeout
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('cervical_screening')
              .where('Family_ID', isEqualTo: fCode)
              .where('Name', isEqualTo: name)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 5));

          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            final merged = {...?baseData, ...?localRecord, ...doc.data()};
            if (mounted) setState(() { _editDocId = doc.id; _populateForm(merged); });
          } else if (localRecord == null && baseData != null) {
            _populateForm(baseData);
          }
        } catch (e) {
          debugPrint('CC: Firestore lookup failed, using local: $e');
          if (localRecord == null && baseData != null) _populateForm(baseData);
        }
      } catch (e) {
        debugPrint('Error in CC _onNameSelected: $e');
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
    _registrationNumber.text = d['Registration_Number'] ?? '';
    selectedFamilyId = d['Family_ID'] ?? d['Family_Code'] ?? d['Family_code'];
    _familyIdController.text = selectedFamilyId ?? '';
    selectedMemberName = d['Name'];
    _locationVillage  = (d['Village']  ?? d['village'])?.toString();
    _locationMandal   = (d['Mandal']   ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState    = (d['State']    ?? d['state'])?.toString();
    _nameController.text = selectedMemberName ?? '';
    selectedGender = normalizeGender(d['Gender']);
    _ageController.text = d['Age']?.toString() ?? '';
    
    final rawExamDate = d['Exam_Date'];
    if (rawExamDate != null) {
      if (rawExamDate is Timestamp) {
        examDate = rawExamDate.toDate();
      } else {
        try {
          examDate = DateFormat('dd-MMM-yyyy').parse(rawExamDate.toString());
        } catch (_) {
          try {
            examDate = DateTime.parse(rawExamDate.toString());
          } catch (_) {}
        }
      }
    }
    
    _firstNameController.text = d['Interviewer_s_Name_first_name'] ?? '';
    _lastNameController.text = d['Interviewer_s_Name_last_name'] ?? '';
    
    if (d['Date_of_Birth'] != null) {
      if (d['Date_of_Birth'] is Timestamp) {
        dateOfBirth = (d['Date_of_Birth'] as Timestamp).toDate();
      } else {
        try {
          dateOfBirth = DateFormat('dd-MMM-yyyy').parse(d['Date_of_Birth'].toString());
        } catch (_) {}
      }
    }
    
    selectedAttendedSchool = d['Have_you_attended_school'];
    _schoolLevelController.text = d['If_Yes_What_was_the_highest_level_attended'] ?? '';
    _occupationController.text = d['Occupation'] ?? '';
    _monthlyIncomeController.text = d['Monthly_Household_Income']?.toString() ?? '';
    _familyMembersCountController.text = d['Total_Number_of_household_living_at_home']?.toString() ?? '';
    _age1Controller.text = d['Age1']?.toString() ?? '';
    selectedMenopause = d['Menopause_Status'];
    selectedVIA = d['VIA_Examination_Result'];
    selectedTreatment = d['Treatment_Provided'];
    // A10-A13
    _marriageDurationController.text = d['Years_Since_Married']?.toString() ?? '';
    _marriageDurationDK = d['Years_Since_Married_DK'] == true;
    _ageAtMarriageController.text = d['Age_At_Marriage']?.toString() ?? '';
    _ageAtMarriageDK = d['Age_At_Marriage_DK'] == true;
    _ageFirstIntercourseController.text = d['Age_First_Intercourse']?.toString() ?? '';
    _ageFirstIntercourseDK = d['Age_First_Intercourse_DK'] == true;
    _husbandOccupationController.text = d['Husband_Occupation']?.toString() ?? '';
    _incomeDontKnow = d['Monthly_Income_DK'] == true;
    // B section
    _b1PapSmear = d['B1_Pap_Smear']?.toString();
    final rawB2 = d['B2_Pap_Smear_Date'];
    if (rawB2 is Timestamp) _b2PapSmearDate = rawB2.toDate();
    else if (rawB2 != null) { try { _b2PapSmearDate = DateFormat('dd-MMM-yyyy').parse(rawB2.toString()); } catch (_) { try { _b2PapSmearDate = DateTime.parse(rawB2.toString()); } catch (_) {} } }
    _papSmearHospitalController.text = d['B3_Pap_Smear_Hospital']?.toString() ?? '';
    _b4InformedAbnormal = d['B4_Informed_Abnormal']?.toString();
    _b5TreatmentAbnormal = d['B5_Treatment_Abnormal']?.toString();
    _abnormalTreatmentController.text = d['B5_Treatment_Where']?.toString() ?? '';
    _b6VaginalDischarge = d['B6_Vaginal_Discharge']?.toString();
    _b6aDischargeTreatment = d['B6a_Discharge_Treatment']?.toString();
    _dischargeTreatmentController.text = d['B6a_Discharge_Treatment_Where']?.toString() ?? '';
    _b7GynecSymptoms = d['B7_Gynec_Symptoms']?.toString();
    _gynecSymptomsController.text = d['B7_Gynec_Symptoms_Specify']?.toString() ?? '';
    _b8Medication = d['B8_Medication']?.toString();
    _medicationController.text = d['B8_Medication_Specify']?.toString() ?? '';
    // C section
    _c8SmokerCohabitation = d['C8_Smoker_Cohabitation']?.toString();
    _c9SmokerRelation = d['C9_Smoker_Relation']?.toString();
    _smokingRelationOtherController.text = d['C9_Smoker_Relation_Other']?.toString() ?? '';
    _c10ContinuousSmokerRelation = d['C10_Continuous_Smoker_Relation']?.toString();
    _continuousSmokingRelationOtherController.text = d['C10_Continuous_Smoker_Relation_Other']?.toString() ?? '';
    // D section
    _menarcheAgeController.text = d['D1_Menarche_Age']?.toString() ?? '';
    _menarcheDK = d['D1_Menarche_DK'] == true;
    _d2StillMenstruating = d['D2_Still_Menstruating']?.toString();
    final rawD3 = d['D3_Last_Menstrual_Period'];
    if (rawD3 is Timestamp) _d3LastMenstrualPeriod = rawD3.toDate();
    else if (rawD3 != null) { try { _d3LastMenstrualPeriod = DateFormat('dd-MMM-yyyy').parse(rawD3.toString()); } catch (_) { try { _d3LastMenstrualPeriod = DateTime.parse(rawD3.toString()); } catch (_) {} } }
    final rawD4 = d['D4_Stop_Menstrual_Date'];
    if (rawD4 is Timestamp) _d4StopMenstrualDate = rawD4.toDate();
    else if (rawD4 != null) { try { _d4StopMenstrualDate = DateFormat('dd-MMM-yyyy').parse(rawD4.toString()); } catch (_) { try { _d4StopMenstrualDate = DateTime.parse(rawD4.toString()); } catch (_) {} } }
    _d5EverPregnant = d['D5_Ever_Pregnant']?.toString();
    _ageFirstPregnantController.text = d['D6_Age_First_Pregnancy']?.toString() ?? '';
    _ageFirstPregnantDK = d['D6_Age_First_Pregnancy_DK'] == true;
    _timesPregnantController.text = d['D7_Times_Pregnant']?.toString() ?? '';
    _timesPregnantDK = d['D7_Times_Pregnant_DK'] == true;
    _liveChildrenController.text = d['D8_Live_Children']?.toString() ?? '';
    _liveChildrenDK = d['D8_Live_Children_DK'] == true;
    final rawD9 = d['D9_Last_Child_Date'];
    if (rawD9 is Timestamp) _d9LastChildDate = rawD9.toDate();
    else if (rawD9 != null) { try { _d9LastChildDate = DateFormat('dd-MMM-yyyy').parse(rawD9.toString()); } catch (_) { try { _d9LastChildDate = DateTime.parse(rawD9.toString()); } catch (_) {} } }
    // E section
    _e1EverBirthControl = d['E1_Ever_Birth_Control']?.toString();
    _e2EverOralContraceptives = d['E2_Ever_Oral_Contraceptives']?.toString();
    _e3CurrentOralContraceptives = d['E3_Current_Oral_Contraceptives']?.toString();
    _e4EverCondoms = d['E4_Ever_Condoms']?.toString();
    _e5EverIUCD = d['E5_Ever_IUCD']?.toString();
    _e6Tubectomised = d['E6_Tubectomised']?.toString();
    // Sample collection
    _vaginalSwab = d['Vaginal_Swab']?.toString();
    _vaginalSwabReasonController.text = d['Vaginal_Swab_Reason']?.toString() ?? '';
    _urineSample = d['Urine_Sample']?.toString();
    _urineReasonController.text = d['Urine_Sample_Reason']?.toString() ?? '';

    if (!_isEditMode && selectedFamilyId != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyId!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _isActionActive = false;
      _registrationNumber.clear();
      // _familyIdController.text = 'TSRRMED'; // Preserved
      _nameController.clear();
      // selectedFamilyId = null; // Preserved
      selectedMemberName = null;
      selectedGender = null;
      _locationVillage = null;
      _locationMandal = null;
      _locationDistrict = null;
      _locationState = null;
      _ageController.clear();
      examDate = DateTime.now();
      _firstNameController.clear();
      _lastNameController.clear();
      dateOfBirth = null;
      selectedAttendedSchool = null;
      _schoolLevelController.clear();
      _occupationController.clear();
      selectedReligion = null;
      _monthlyIncomeController.clear();
      _familyMembersCountController.clear();
      selectedMaritalStatus = null;
      _age1Controller.clear();
      selectedMenopause = null;
      selectedVIA = null;
      selectedTreatment = null;
      _marriageDurationController.clear(); _marriageDurationDK = false;
      _ageAtMarriageController.clear(); _ageAtMarriageDK = false;
      _ageFirstIntercourseController.clear(); _ageFirstIntercourseDK = false;
      _husbandOccupationController.clear();
      _incomeDontKnow = false;
      _b1PapSmear = null; _b2PapSmearDate = null;
      _papSmearHospitalController.clear();
      _b4InformedAbnormal = null; _b5TreatmentAbnormal = null;
      _abnormalTreatmentController.clear();
      _b6VaginalDischarge = null; _b6aDischargeTreatment = null;
      _dischargeTreatmentController.clear();
      _b7GynecSymptoms = null; _gynecSymptomsController.clear();
      _b8Medication = null; _medicationController.clear();
      _c8SmokerCohabitation = null; _c9SmokerRelation = null;
      _smokingRelationOtherController.clear();
      _c10ContinuousSmokerRelation = null;
      _continuousSmokingRelationOtherController.clear();
      _menarcheAgeController.clear(); _menarcheDK = false;
      _d2StillMenstruating = null;
      _d3LastMenstrualPeriod = null; _d4StopMenstrualDate = null;
      _d5EverPregnant = null;
      _ageFirstPregnantController.clear(); _ageFirstPregnantDK = false;
      _timesPregnantController.clear(); _timesPregnantDK = false;
      _liveChildrenController.clear(); _liveChildrenDK = false;
      _d9LastChildDate = null;
      _e1EverBirthControl = null; _e2EverOralContraceptives = null;
      _e3CurrentOralContraceptives = null; _e4EverCondoms = null;
      _e5EverIUCD = null; _e6Tubectomised = null;
      _vaginalSwab = null; _vaginalSwabReasonController.clear();
      _urineSample = null; _urineReasonController.clear();
      familyMemberNames = [];
      _existingRecords = [];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number': _registrationNumber.text,
        'Family_ID': selectedFamilyId ?? _familyIdController.text,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Village': _locationVillage,
        'Mandal': _locationMandal,
        'District': _locationDistrict,
        'State': _locationState,
        'Age': int.tryParse(_ageController.text),
        'Exam_Date': examDate != null ? Timestamp.fromDate(examDate!) : null,
        'Interviewer_s_Name_first_name': _firstNameController.text,
        'Interviewer_s_Name_last_name': _lastNameController.text,
        'Date_of_Birth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
        'Have_you_attended_school': selectedAttendedSchool,
        'If_Yes_What_was_the_highest_level_attended': _schoolLevelController.text,
        'Occupation': _occupationController.text,
        'Religion': selectedReligion,
        'Monthly_Household_Income': _monthlyIncomeController.text.isNotEmpty ? int.tryParse(_monthlyIncomeController.text) : null,
        'Total_Number_of_household_living_at_home': _familyMembersCountController.text.isNotEmpty ? int.tryParse(_familyMembersCountController.text) : null,
        'Marital_status': selectedMaritalStatus,
        'Age1': _age1Controller.text.isNotEmpty ? int.tryParse(_age1Controller.text) : null,
        'Menopause_Status': selectedMenopause,
        'VIA_Examination_Result': selectedVIA,
        'Treatment_Provided': selectedTreatment,
        // A10-A13
        'Years_Since_Married': _marriageDurationController.text.isNotEmpty ? int.tryParse(_marriageDurationController.text) : null,
        'Years_Since_Married_DK': _marriageDurationDK,
        'Age_At_Marriage': _ageAtMarriageController.text.isNotEmpty ? int.tryParse(_ageAtMarriageController.text) : null,
        'Age_At_Marriage_DK': _ageAtMarriageDK,
        'Age_First_Intercourse': _ageFirstIntercourseController.text.isNotEmpty ? int.tryParse(_ageFirstIntercourseController.text) : null,
        'Age_First_Intercourse_DK': _ageFirstIntercourseDK,
        'Husband_Occupation': _husbandOccupationController.text,
        'Monthly_Income_DK': _incomeDontKnow,
        // B section
        'B1_Pap_Smear': _b1PapSmear,
        'B2_Pap_Smear_Date': _b2PapSmearDate != null ? Timestamp.fromDate(_b2PapSmearDate!) : null,
        'B3_Pap_Smear_Hospital': _papSmearHospitalController.text,
        'B4_Informed_Abnormal': _b4InformedAbnormal,
        'B5_Treatment_Abnormal': _b5TreatmentAbnormal,
        'B5_Treatment_Where': _abnormalTreatmentController.text,
        'B6_Vaginal_Discharge': _b6VaginalDischarge,
        'B6a_Discharge_Treatment': _b6aDischargeTreatment,
        'B6a_Discharge_Treatment_Where': _dischargeTreatmentController.text,
        'B7_Gynec_Symptoms': _b7GynecSymptoms,
        'B7_Gynec_Symptoms_Specify': _gynecSymptomsController.text,
        'B8_Medication': _b8Medication,
        'B8_Medication_Specify': _medicationController.text,
        // C section
        'C8_Smoker_Cohabitation': _c8SmokerCohabitation,
        'C9_Smoker_Relation': _c9SmokerRelation,
        'C9_Smoker_Relation_Other': _smokingRelationOtherController.text,
        'C10_Continuous_Smoker_Relation': _c10ContinuousSmokerRelation,
        'C10_Continuous_Smoker_Relation_Other': _continuousSmokingRelationOtherController.text,
        // D section
        'D1_Menarche_Age': _menarcheAgeController.text.isNotEmpty ? int.tryParse(_menarcheAgeController.text) : null,
        'D1_Menarche_DK': _menarcheDK,
        'D2_Still_Menstruating': _d2StillMenstruating,
        'D3_Last_Menstrual_Period': _d3LastMenstrualPeriod != null ? Timestamp.fromDate(_d3LastMenstrualPeriod!) : null,
        'D4_Stop_Menstrual_Date': _d4StopMenstrualDate != null ? Timestamp.fromDate(_d4StopMenstrualDate!) : null,
        'D5_Ever_Pregnant': _d5EverPregnant,
        'D6_Age_First_Pregnancy': _ageFirstPregnantController.text.isNotEmpty ? int.tryParse(_ageFirstPregnantController.text) : null,
        'D6_Age_First_Pregnancy_DK': _ageFirstPregnantDK,
        'D7_Times_Pregnant': _timesPregnantController.text.isNotEmpty ? int.tryParse(_timesPregnantController.text) : null,
        'D7_Times_Pregnant_DK': _timesPregnantDK,
        'D8_Live_Children': _liveChildrenController.text.isNotEmpty ? int.tryParse(_liveChildrenController.text) : null,
        'D8_Live_Children_DK': _liveChildrenDK,
        'D9_Last_Child_Date': _d9LastChildDate != null ? Timestamp.fromDate(_d9LastChildDate!) : null,
        // E section
        'E1_Ever_Birth_Control': _e1EverBirthControl,
        'E2_Ever_Oral_Contraceptives': _e2EverOralContraceptives,
        'E3_Current_Oral_Contraceptives': _e3CurrentOralContraceptives,
        'E4_Ever_Condoms': _e4EverCondoms,
        'E5_Ever_IUCD': _e5EverIUCD,
        'E6_Tubectomised': _e6Tubectomised,
        // Sample collection
        'Vaginal_Swab': _vaginalSwab,
        'Vaginal_Swab_Reason': _vaginalSwabReasonController.text,
        'Urine_Sample': _urineSample,
        'Urine_Sample_Reason': _urineReasonController.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('cervical_screening', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Screening updated! Syncing...' : 'Screening saved! Syncing...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ));
        if (widget.docId != null) {
          Navigator.pop(context);
        } else if (!wasEditing) {
          _resetForm();
        }
      }

      // 2. Trigger Background Sync (Handles Firestore push)
      SyncService().syncPendingSubmissions();

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Cervical Screening',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade700, Colors.teal.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          _isDownloadingCC
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : IconButton(
                  icon: Icon(Icons.cloud_download_outlined, color: _ccAlreadyDownloaded ? Colors.greenAccent : Colors.white),
                  tooltip: _ccAlreadyDownloaded ? 'Downloaded: $_ccDownloadedAt' : 'Download for offline',
                  onPressed: _downloadCCFromStorage,
                ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildIdentitySection(),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Socio-Demographic Details',
                      icon: Icons.info_outline,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: _buildDatePicker('Date of Birth',
                                    dateOfBirth, (v) {
                              setState(() {
                                dateOfBirth = v;
                                final age = DateTime.now().year - v.year;
                                _age1Controller.text = age.toString();
                              });
                            })),
                            const SizedBox(width: 12),
                            Expanded(
                                child: formTextField('Age', _age1Controller,
                                    enabled: _isActionActive,
                                    keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Have you ever attended school?',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        Row(
                          children: [
                            Expanded(
                                child: RadioListTile<String>(
                                    title: const Text('Yes'),
                                    value: 'Yes',
                                    groupValue: selectedAttendedSchool,
                                    onChanged: !_isActionActive ? null : (v) =>
                                        setState(() => selectedAttendedSchool = v),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true)),
                            Expanded(
                                child: RadioListTile<String>(
                                    title: const Text('No'),
                                    value: 'No',
                                    groupValue: selectedAttendedSchool,
                                    onChanged: !_isActionActive ? null : (v) =>
                                        setState(() => selectedAttendedSchool = v),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        formTextField('Highest level of school completed?',
                            _schoolLevelController, enabled: _isActionActive),
                        const SizedBox(height: 16),
                        formTextField(
                            'What is your occupation?', _occupationController, enabled: _isActionActive),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: formSearchableDropdown(
                                    context,
                                    'Religion',
                                    ['Hindu', 'Muslim', 'Christian', 'Others'],
                                    selectedReligion,
                                    (v) => setState(() => selectedReligion = v),
                                    enabled: _isActionActive)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: formSearchableDropdown(
                                    context,
                                    'Marital status',
                                    ['Single', 'Married', 'Widowed', 'Divorced'],
                                    selectedMaritalStatus,
                                    (v) => setState(
                                        () => selectedMaritalStatus = v),
                                    enabled: _isActionActive)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: formTextField(
                                    'Total monthly income (Rs.)',
                                    _monthlyIncomeController,
                                    enabled: _isActionActive,
                                    keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: formTextField('Family members count',
                                    _familyMembersCountController,
                                    enabled: _isActionActive,
                                    keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // A9 Marital status already above
                        // A10
                        _buildDKRow('A10. How long since you were married? (years)', _marriageDurationController, _marriageDurationDK, (v) => setState(() => _marriageDurationDK = v)),
                        const SizedBox(height: 12),
                        // A11
                        _buildDKRow('A11. How old were you when you were married?', _ageAtMarriageController, _ageAtMarriageDK, (v) => setState(() => _ageAtMarriageDK = v)),
                        const SizedBox(height: 12),
                        // A12
                        _buildDKRow('A12. Age at first intercourse', _ageFirstIntercourseController, _ageFirstIntercourseDK, (v) => setState(() => _ageFirstIntercourseDK = v)),
                        const SizedBox(height: 12),
                        // A13
                        formTextField("A13. Husband's occupation", _husbandOccupationController, enabled: _isActionActive),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── Section B: Pap Smear ──────────────────────────────────
                    buildSectionCard(
                      context: context,
                      title: 'B. Pap Smear / Cervical Cancer History',
                      icon: Icons.medical_services_outlined,
                      children: [
                        _buildYesNoDK('B1. Have you ever had a Pap smear (cervical cancer test)?', _b1PapSmear, (v) => setState(() => _b1PapSmear = v)),
                        if (_b1PapSmear == '1') ...[
                          const SizedBox(height: 12),
                          _buildDatePicker('B2. Date of Pap smear test done?', _b2PapSmearDate, (v) => setState(() => _b2PapSmearDate = v)),
                          const SizedBox(height: 12),
                          formTextField('B3. At what hospital was the Pap smear done? (name & address)', _papSmearHospitalController, enabled: _isActionActive, maxLines: 2),
                          const SizedBox(height: 12),
                          _buildYesNoDK('B4. Were you informed if Pap smear result was abnormal?', _b4InformedAbnormal, (v) => setState(() => _b4InformedAbnormal = v)),
                          const SizedBox(height: 12),
                          _buildYesNoDK('B5. Was the treatment done for the abnormal Pap smear result?', _b5TreatmentAbnormal, (v) => setState(() => _b5TreatmentAbnormal = v)),
                          if (_b5TreatmentAbnormal == '1') ...[
                            const SizedBox(height: 8),
                            formTextField('  Where was treatment done?', _abnormalTreatmentController, enabled: _isActionActive),
                          ],
                        ],
                        const SizedBox(height: 12),
                        _buildYesNoDK('B6. Do you have any abnormal vaginal discharge?', _b6VaginalDischarge, (v) => setState(() => _b6VaginalDischarge = v)),
                        if (_b6VaginalDischarge == '1') ...[
                          const SizedBox(height: 8),
                          _buildYesNoDK('B6a. Was treatment taken for the abnormal vaginal discharge?', _b6aDischargeTreatment, (v) => setState(() => _b6aDischargeTreatment = v)),
                          if (_b6aDischargeTreatment == '1') ...[
                            const SizedBox(height: 8),
                            formTextField('  Where was treatment taken?', _dischargeTreatmentController, enabled: _isActionActive),
                          ],
                        ],
                        const SizedBox(height: 12),
                        _buildYesNo('B7. Do you have any other significant gynecologic symptoms?', _b7GynecSymptoms, (v) => setState(() => _b7GynecSymptoms = v)),
                        if (_b7GynecSymptoms == '1') ...[
                          const SizedBox(height: 8),
                          formTextField('  Specify symptoms', _gynecSymptomsController, enabled: _isActionActive),
                        ],
                        const SizedBox(height: 12),
                        _buildYesNo('B8. Are you currently using any medication?', _b8Medication, (v) => setState(() => _b8Medication = v)),
                        if (_b8Medication == '1') ...[
                          const SizedBox(height: 8),
                          formTextField('  Specify medication', _medicationController, enabled: _isActionActive, maxLines: 3),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── Section C: Smoking Exposure ───────────────────────────
                    buildSectionCard(
                      context: context,
                      title: 'C. Smoking Exposure',
                      icon: Icons.smoking_rooms_outlined,
                      children: [
                        _buildYesNo('C8. Do you stay with a person who smokes?', _c8SmokerCohabitation, (v) => setState(() => _c8SmokerCohabitation = v)),
                        if (_c8SmokerCohabitation == '1') ...[
                          const SizedBox(height: 12),
                          _buildSmokingRelation('C9. Relationship with the person who smokes?', _c9SmokerRelation, _smokingRelationOtherController, (v) => setState(() => _c9SmokerRelation = v)),
                        ],
                        const SizedBox(height: 12),
                        _buildSmokingRelation('C10. Relationship with person who smokes continuously?', _c10ContinuousSmokerRelation, _continuousSmokingRelationOtherController, (v) => setState(() => _c10ContinuousSmokerRelation = v)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── Section D: Menstrual / Pregnancy ─────────────────────
                    buildSectionCard(
                      context: context,
                      title: 'D. Menstrual & Pregnancy History',
                      icon: Icons.pregnant_woman_outlined,
                      children: [
                        _buildDKRow('D1. At what age did you first start having your menstrual period?', _menarcheAgeController, _menarcheDK, (v) => setState(() => _menarcheDK = v)),
                        const SizedBox(height: 12),
                        _buildYesNo('D2. Are you still having menstrual periods?', _d2StillMenstruating, (v) => setState(() => _d2StillMenstruating = v)),
                        const SizedBox(height: 12),
                        _buildDatePicker('D3. When was your last menstrual period?', _d3LastMenstrualPeriod, (v) => setState(() => _d3LastMenstrualPeriod = v)),
                        if (_d2StillMenstruating == '2') ...[
                          const SizedBox(height: 12),
                          _buildDatePicker('D4. When did you stop having menstrual periods?', _d4StopMenstrualDate, (v) => setState(() => _d4StopMenstrualDate = v)),
                        ],
                        const SizedBox(height: 12),
                        _buildYesNo('D5. Have you ever been pregnant?', _d5EverPregnant, (v) => setState(() => _d5EverPregnant = v)),
                        if (_d5EverPregnant == '1') ...[
                          const SizedBox(height: 12),
                          _buildDKRow('D6. How old were you when you were first pregnant?', _ageFirstPregnantController, _ageFirstPregnantDK, (v) => setState(() => _ageFirstPregnantDK = v)),
                          const SizedBox(height: 12),
                          _buildDKRow('D7. How many times have you been pregnant?', _timesPregnantController, _timesPregnantDK, (v) => setState(() => _timesPregnantDK = v)),
                          const SizedBox(height: 12),
                          _buildDKRow('D8. Number of live children?', _liveChildrenController, _liveChildrenDK, (v) => setState(() => _liveChildrenDK = v)),
                          const SizedBox(height: 12),
                          _buildDatePicker('D9. When did you have your last child?', _d9LastChildDate, (v) => setState(() => _d9LastChildDate = v)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── Section E: Birth Control ──────────────────────────────
                    buildSectionCard(
                      context: context,
                      title: 'E. Birth Control / Family Planning',
                      icon: Icons.family_restroom_outlined,
                      children: [
                        _buildYesNo('E1. Have you ever used birth control or family planning?', _e1EverBirthControl, (v) => setState(() => _e1EverBirthControl = v)),
                        const SizedBox(height: 12),
                        _buildYesNo('E2. Have you ever used oral contraceptives?', _e2EverOralContraceptives, (v) => setState(() => _e2EverOralContraceptives = v)),
                        const SizedBox(height: 12),
                        _buildYesNo('E3. Are you currently using oral contraceptives?', _e3CurrentOralContraceptives, (v) => setState(() => _e3CurrentOralContraceptives = v)),
                        const SizedBox(height: 12),
                        _buildYesNo('E4. Have you ever used condoms?', _e4EverCondoms, (v) => setState(() => _e4EverCondoms = v)),
                        const SizedBox(height: 12),
                        _buildYesNo('E5. Have you ever used an IUCD (Copper-T)?', _e5EverIUCD, (v) => setState(() => _e5EverIUCD = v)),
                        const SizedBox(height: 12),
                        _buildYesNo('E6. Are you tubectomised (permanent sterilisation)?', _e6Tubectomised, (v) => setState(() => _e6Tubectomised = v)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── Sample Collection ─────────────────────────────────────
                    buildSectionCard(
                      context: context,
                      title: 'Sample Collection',
                      icon: Icons.science_outlined,
                      children: [
                        const Text('Vaginal Swab sample collected?', style: TextStyle(fontWeight: FontWeight.w500)),
                        _buildYesNoRefused(_vaginalSwab, (v) => setState(() => _vaginalSwab = v)),
                        if (_vaginalSwab == '2' || _vaginalSwab == '3') ...[
                          const SizedBox(height: 8),
                          formTextField('Reason', _vaginalSwabReasonController, enabled: _isActionActive),
                        ],
                        const SizedBox(height: 12),
                        const Text('Urine sample collected?', style: TextStyle(fontWeight: FontWeight.w500)),
                        _buildYesNoRefused(_urineSample, (v) => setState(() => _urineSample = v)),
                        if (_urineSample == '2' || _urineSample == '3') ...[
                          const SizedBox(height: 8),
                          formTextField('Reason', _urineReasonController, enabled: _isActionActive),
                        ],
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
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
                  final code = _familyIdController.text.trim();
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
      title: 'Patient Identity',
      icon: Icons.person_outline,
      children: [
        formTextField(
          'Registration Number',
          _registrationNumber,
          enabled: _isActionActive,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        formSearchField(
          'Family Code',
          _familyIdController,
          onSearch: () {
            if (_familyIdController.text.isNotEmpty) {
              _fetchMembersByFamily(_familyIdController.text);
              _fetchExistingRecords(_familyIdController.text);
            }
          },
          isLoading: _isLoadingMembers,
          enabled: _isActionActive,
          readOnly: _familyIdReadOnly,
          focusNode: _familyCodeNode,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
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
            Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: '(1) Male', groupValue: selectedGender, onChanged: !_isActionActive ? null : (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: '(0) Female', groupValue: selectedGender, onChanged: !_isActionActive ? null : (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField(
              'Age (years)',
              _ageController,
              enabled: _isActionActive,
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Exam Date', examDate, (v) => setState(() => examDate = v))),
          ],
        ),
        const SizedBox(height: 16),
        const Text("Interviewer's Name", style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: formTextField('First Name', _firstNameController, enabled: _isActionActive)),
            const SizedBox(width: 12),
            Expanded(child: formTextField('Last Name', _lastNameController, enabled: _isActionActive)),
          ],
        ),
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
          onTap: !_isActionActive ? null : () async {
            final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              onPicked(picked);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) _scrollController.jumpTo(offset);
              });
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(selectedDate == null ? 'dd-MMM-yyyy' : DateFormat('dd-MMM-yyyy').format(selectedDate)),
          ),
        ),
      ],
    );
  }

  // Yes / No / Don't Know (77) radio row
  Widget _buildYesNoDK(String question, String? value, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: const TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '1', groupValue: value, onChanged: !_isActionActive ? null : onChanged, contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '2', groupValue: value, onChanged: !_isActionActive ? null : onChanged, contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(77) DK'), value: '77', groupValue: value, onChanged: !_isActionActive ? null : onChanged, contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
      ],
    );
  }

  // Yes / No only
  Widget _buildYesNo(String question, String? value, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: const TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '1', groupValue: value, onChanged: !_isActionActive ? null : onChanged, contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '2', groupValue: value, onChanged: !_isActionActive ? null : onChanged, contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
      ],
    );
  }

  // Yes / No / Refused (3)
  Widget _buildYesNoRefused(String? value, ValueChanged<String?> onChanged) {
    return Row(
      children: [
        Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '1', groupValue: value, onChanged: !_isActionActive ? null : onChanged, contentPadding: EdgeInsets.zero, dense: true)),
        Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '2', groupValue: value, onChanged: !_isActionActive ? null : onChanged, contentPadding: EdgeInsets.zero, dense: true)),
        Expanded(child: RadioListTile<String>(title: const Text('(3) Refused'), value: '3', groupValue: value, onChanged: !_isActionActive ? null : onChanged, contentPadding: EdgeInsets.zero, dense: true)),
      ],
    );
  }

  // Numeric field with (77) Don't Know checkbox
  Widget _buildDKRow(String label, TextEditingController ctrl, bool isDK, ValueChanged<bool> onDKChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: ctrl,
                enabled: _isActionActive && !isDK,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  fillColor: (_isActionActive && !isDK) ? Colors.white : Colors.grey.shade100,
                  filled: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: !_isActionActive ? null : () { onDKChanged(!isDK); if (!isDK) ctrl.clear(); },
              child: Row(
                children: [
                  Checkbox(value: isDK, onChanged: !_isActionActive ? null : (v) { onDKChanged(v!); if (v) ctrl.clear(); }),
                  const Text('(77) DK', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Smoking relation options
  Widget _buildSmokingRelation(String label, String? value, TextEditingController otherCtrl, ValueChanged<String?> onChanged) {
    final options = [
      MapEntry('1', '(1) Spouse'),
      MapEntry('2', '(2) Father'),
      MapEntry('3', '(3) Mother'),
      MapEntry('4', '(4) Siblings'),
      MapEntry('5', '(5) Children'),
      MapEntry('6', '(6) Others'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Wrap(
          children: options.map((e) => SizedBox(
            width: 160,
            child: RadioListTile<String>(
              title: Text(e.value, style: const TextStyle(fontSize: 13)),
              value: e.key,
              groupValue: value,
              onChanged: !_isActionActive ? null : onChanged,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          )).toList(),
        ),
        if (value == '6') ...[
          const SizedBox(height: 4),
          formTextField('Specify other', otherCtrl, enabled: _isActionActive),
        ],
      ],
    );
  }
}
