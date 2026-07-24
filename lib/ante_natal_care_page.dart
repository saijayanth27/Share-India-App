import "package:flutter/material.dart";
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'local_database_service.dart';
import 'sync_service.dart';
import 'widget.dart';

class AnteNatalCarePage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const AnteNatalCarePage({super.key, this.existingData, this.docId});

  @override
  State<AnteNatalCarePage> createState() => _AnteNatalCarePageState();
}

class _AnteNatalCarePageState extends State<AnteNatalCarePage> {
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
  bool _isDownloadingAnc = false;
  bool _ancAlreadyDownloaded = false;
  String? _ancDownloadedAt;

  // --- Controllers & State Variables ---
  final _registrationNumber = TextEditingController();
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  final _nameController = TextEditingController();
  final _husbandName = TextEditingController();
  final _age = TextEditingController();

  // --- TT Dose Controllers ---
  DateTime? stDt;
  DateTime? ndDt;
  String? stGivenYN;
  String? stGivenBy;
  String? ndGivenYN;
  String? ndGivenBy;

  // --- IFA Controllers ---
  DateTime? stDt1;
  DateTime? ndDt1;
  DateTime? rdDt;
  DateTime? thDt;
  String? stGivenYN1;
  String? stGivenBy1;
  String? ndGivenYN1;
  String? ndGivenBy1;
  String? rdGivenYN;
  String? rdGivenYN1; // 3rd Given By
  String? THGivenYN;
  String? THGivenYN1; // 4th Given By

  // --- Delivery Controllers ---
  DateTime? deliveryDt;
  String? deliveryType;
  String? deliveryPlace;
  final _deliveryPlaceDetails = TextEditingController();
  String? deliveryOutcome;
  final _noOfBirths = TextEditingController();
  final _noOfBirthOfFemale = TextEditingController();
  final _totalLiveBirths = TextEditingController();

  // --- New Birth Infant Registration ---
  bool _hasMaleBirth = false;
  bool _hasFemaleBirth = false;
  List<TextEditingController> _maleWeightControllers = [];
  List<TextEditingController> _femaleWeightControllers = [];

  void _updateMaleControllers() {
    int count = int.tryParse(_noOfBirths.text) ?? 0;
    setState(() {
      while (_maleWeightControllers.length < count) {
        _maleWeightControllers.add(TextEditingController());
      }
      while (_maleWeightControllers.length > count) {
        _maleWeightControllers.removeLast().dispose();
      }
    });
  }

  void _updateFemaleControllers() {
    int count = int.tryParse(_noOfBirthOfFemale.text) ?? 0;
    setState(() {
      while (_femaleWeightControllers.length < count) {
        _femaleWeightControllers.add(TextEditingController());
      }
      while (_femaleWeightControllers.length > count) {
        _femaleWeightControllers.removeLast().dispose();
      }
    });
  }

  // --- Remarks & Screen Selection ---
  final _remarks2 = TextEditingController();
  String? selectEntryScreen;

  String? selectedFamilyCode;
  String? selectedMemberName;
  DateTime? dateOfInterview = DateTime.now();
  String? interviewersName;
  DateTime? lmpDate;
  DateTime? eddDate;

  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  // Location (auto-populated from Family Code)
  String? _locationVillage;
  String? _locationMandal;
  String? _locationDistrict;
  String? _locationState;

  String? _baseRegistrationNumber;

  final List<String> interviewerList = ['KIRANMAI K', 'REVATHI CH', 'RAMADEVI Y', 'LAVANYA KASPOJU', 'PUSHPA K', 'G RAMADEVI', 'BHASKAR K', 'ASHA', 'KUSUMA G', 'B JYOTHI', 'RAMADEVI G', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU'];
  final List<String> screenChoices = ['TT Dose', 'IFA', 'Delivery', 'Remarks'];
  final List<String> yesNoChoices = ['(1) Yes', '(0) No'];
  final List<String> givenByChoices = ['(0) RHC', '(1) PVT', '(2) GOVT'];
  final List<String> deliveryTypeChoices = ['(0) Normal', '(1) Caesarian', '(2) Abortion'];
  final List<String> deliveryPlaceChoices = ['(0) RHC', '(1) PVT', '(2) GOVT', '(3) HOME'];
  final List<String> deliveryOutcomeChoices = ['(0) Live Birth', '(1) Still Birth', '(2) Premature'];

  @override
  void initState() {
    super.initState();
    _noOfBirths.addListener(_updateMaleControllers);
    _noOfBirthOfFemale.addListener(_updateFemaleControllers);
    _loadAncDownloadStatus();
    if (widget.existingData != null) {
      _isEditMode = true;
      _editDocId = widget.docId;
      _loadExistingData();
      final familyCode = (widget.existingData!['Family_Code'] ?? widget.existingData!['Family_code'] ?? '').toString();
      if (familyCode.isNotEmpty) {
        _fetchMembersByFamily(familyCode).then((_) {
          // After members load, fill husband name from personal_details if still empty
          if (mounted && _husbandName.text.isEmpty && selectedMemberName != null) {
            final memberData = _allMembersData[selectedMemberName];
            if (memberData != null) {
              final hName = (memberData['Name2'] ?? '').toString();
              if (hName.isNotEmpty) setState(() => _husbandName.text = hName);
            }
          }
        });
        _fetchExistingRecords(familyCode);
      }
    }
  }

  @override
  void dispose() {
    _familyCodeNode.dispose();
    _noOfBirths.removeListener(_updateMaleControllers);
    _noOfBirthOfFemale.removeListener(_updateFemaleControllers);
    for (var c in _maleWeightControllers) { c.dispose(); }
    for (var c in _femaleWeightControllers) { c.dispose(); }
    _registrationNumber.dispose();
    _familyCodeController.dispose();
    _nameController.dispose();
    _husbandName.dispose();
    _age.dispose();
    _deliveryPlaceDetails.dispose();
    _noOfBirths.dispose();
    _noOfBirthOfFemale.dispose();
    _totalLiveBirths.dispose();
    _remarks2.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAncDownloadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString('anc_records_download_timestamp');
    if (ts != null && mounted) {
      setState(() { _ancAlreadyDownloaded = true; _ancDownloadedAt = ts; });
    }
  }

  Future<void> _downloadAncFromStorage() async {
    setState(() { _isDownloadingAnc = true; });
    try {
      final ref = FirebaseStorage.instance.ref().child('exports/anc_records.json');
      final downloadUrl = await ref.getDownloadURL();
      final client = http.Client();
      final response = await client.send(http.Request('GET', Uri.parse(downloadUrl)));
      final bytes = <int>[];
      await for (final chunk in response.stream) { bytes.addAll(chunk); }
      client.close();

      final List<dynamic> records = json.decode(String.fromCharCodes(bytes));
      final dbService = LocalDatabaseService();
      final List<Map<String, dynamic>> batch = [];
      int saved = 0;
      for (final r in records) {
        batch.add(Map<String, dynamic>.from(r as Map));
        if (batch.length == 500) {
          await dbService.saveAncRecords(batch, clearFirst: saved == 0);
          saved += batch.length;
          batch.clear();
        }
      }
      if (batch.isNotEmpty) {
        await dbService.saveAncRecords(batch, clearFirst: saved == 0);
        saved += batch.length;
      }

      final prefs = await SharedPreferences.getInstance();
      final ts = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      await prefs.setString('anc_records_download_timestamp', ts);

      if (mounted) {
        setState(() { _ancAlreadyDownloaded = true; _ancDownloadedAt = ts; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $saved ANC records downloaded for offline use!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Download failed: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 8),
      ));
    } finally {
      if (mounted) setState(() => _isDownloadingAnc = false);
    }
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
      Set<String> excludedNames = {};
      List<Map<String, dynamic>> firestoreMembers = [];
      
      try {
        final fpSnapshot = await FirebaseFirestore.instance
            .collection('family_planning')
            .where('Family_Code', isEqualTo: fCode)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 3));
        
        excludedNames = fpSnapshot.docs
            .map((doc) => doc.data()['Name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toSet();

        final snapshot = await FirebaseFirestore.instance
            .collection('personal_details')
            .where('Family_Code', isEqualTo: fCode)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 3));
        
        firestoreMembers = snapshot.docs.map((d) => d.data() as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint('ANC: Firestore lookup failed/timeout, relying on LOCAL: $e');
      }

      final Map<String, Map<String, dynamic>> memberMap = {};
      final Set<String> allNames = {};
      
      // Process both lists, preferring Firestore but falling back to Local
      final combined = [...firestoreMembers, ...localMembers];
      
      for (var data in combined) {
        final name = data['Name']?.toString() ?? '';
        final gender = data['Gender']?.toString() ?? '';
        final maritalStatus = data['Marital_Status']?.toString() ?? '';
        final avStatus = data['A_v_Status']?.toString() ?? '';

        if (name.isEmpty) continue;
        
        // Filter: only members aged 18 or older
        final age = int.tryParse(data['Age']?.toString() ?? '0') ?? 0;
        if (age < 18) continue;

        // Filter: (0) Female AND ((1) Married OR (3) Widow) AND (1) Active AND Not in excludedNames
        bool isEligibleFemale = gender == '(0) Female' && 
                               (maritalStatus == '(1) Married' || maritalStatus == '(3) Widow') &&
                               avStatus == '(1) Active';
        
        if (isEligibleFemale && !excludedNames.contains(name)) {
          memberMap[name] = data;
          allNames.add(name);
        }
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
      // 1. Local SQLite first (instant offline)
      final localRecords = await LocalDatabaseService().getAncRecordsByFamily(familyCode);
      if (localRecords.isNotEmpty && mounted) {
        setState(() => _existingRecords = localRecords);
      }

      // 2. Firestore for fresh data
      final snapshot = await FirebaseFirestore.instance
          .collection('ante_natal_care')
          .where('Family_Code', isEqualTo: familyCode)
          .get().timeout(const Duration(seconds: 5));
      if (mounted) {
        final firestoreRecords = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
        // Merge: Firestore records take precedence by name
        final Map<String, Map<String, dynamic>> merged = {};
        for (final r in localRecords) { merged[r['Name'] ?? r['Registration_Number'] ?? ''] = r; }
        for (final r in firestoreRecords) { merged[r['Name'] ?? r['id'] ?? ''] = r; }
        setState(() { _existingRecords = merged.values.toList(); _isLoadingMembers = false; });
      }
    } catch (e) {
      debugPrint('ANC: Firestore records fetch failed, using local: $e');
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  void _onNameSelected(String? name) async {
    setState(() {
      selectedMemberName = name;
      _nameController.text = name ?? '';
    });
    
    if (name == null) return;

    // 1. Get base data from common Personal Details (immediate)
    final baseData = _allMembersData[name];
    if (baseData != null && !_isEditMode) {
      _baseRegistrationNumber = (baseData['uniq_Registration_Number'] ?? baseData['Registration_Number'] ?? '').toString();
      final hName = (baseData['Name2'] ?? '').toString();
      if (hName.isNotEmpty) {
        _husbandName.text = hName;
      }
      _age.text = baseData['Age']?.toString() ?? '';
      _updateRegistrationNumber();
    }

    // 2. If Edit mode, fetch the latest specific record from Firestore or Local Cache
    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        Map<String, dynamic>? latestData;

        // Check local pending submissions first for immediate edits
        final offlineSubs = await DataCacheService().getOfflineSubmissions('ante_natal_care');
        try {
          latestData = offlineSubs.firstWhere((sub) => 
            (sub['Family_Code'] == fCode || sub['Family_code'] == fCode || sub['Family_ID'] == fCode) 
            && sub['Name'] == name
          );
        } catch (_) {}

        if (latestData == null) {
          final snapshot = await FirebaseFirestore.instance
              .collection('ante_natal_care')
              .where('Family_Code', isEqualTo: fCode)
              .where('Name', isEqualTo: name)
              .limit(1)
              .get(const GetOptions(source: Source.serverAndCache))
              .timeout(const Duration(seconds: 8));
              
          if (snapshot.docs.isNotEmpty) {
            latestData = snapshot.docs.first.data();
            _editDocId = snapshot.docs.first.id;
          }
        }

        if (latestData != null) {
          setState(() {
            // Merge base data with specific record (record takes precedence)
            final merged = {...?baseData, ...latestData!};
            
            if (merged['Age'] == null) merged['Age'] = baseData?['Age'];
            
            _populateForm(merged);
          });
        } else if (baseData != null) {
          // No specific record yet, but we have member details
          setState(() => _populateForm(baseData));
        }
      } catch (e) {
        debugPrint('Error fetching ANC record: $e');
        if (baseData != null) _populateForm(baseData);
      } finally {
        if (mounted) setState(() => _isLoadingMembers = false);
      }
    }
  }

  void _updateRegistrationNumber() {
    if (_baseRegistrationNumber != null && _baseRegistrationNumber!.isNotEmpty) {
      String newRegNo = _baseRegistrationNumber!;
      if (lmpDate != null) {
        newRegNo += DateFormat('ddMMyy').format(lmpDate!);
      }
      _registrationNumber.text = newRegNo;
    }
  }

  void _loadExistingData() {
    setState(() {
      _populateForm(widget.existingData!);
    });
  }

  void _populateForm(Map<String, dynamic> d) {
    // Registration: app field → REACH REG_NO fallback
    _registrationNumber.text = (d['Registration_Number'] ?? d['REG_NO'] ?? d['REGNO'] ?? '').toString();
    selectedFamilyCode = d['Family_Code'] ?? d['Family_code'] ?? d['Family_ID'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _locationVillage  = (d['Village']  ?? d['village'])?.toString();
    _locationMandal   = (d['Mandal']   ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState    = (d['State']    ?? d['state'])?.toString();
    _nameController.text = selectedMemberName ?? '';
    _husbandName.text = (d['Husband_Name']?.toString().isNotEmpty == true) ? d['Husband_Name'].toString() : (d['Name2'] ?? '').toString();
    _age.text = d['Age']?.toString() ?? '';
    selectEntryScreen = d['Select_Entry_Screen'];

    // --- Helper for Date parsing ---
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String && val.isNotEmpty) {
        try { return DateFormat('dd-MMM-yyyy').parse(val); } catch (_) {}
        try { return DateTime.parse(val); } catch (_) {}
      }
      return null;
    }

    // --- Helper to normalize REACH 0/1/2 codes to app option strings ---
    String? normYN(dynamic raw, {bool yesNo = true}) {
      if (raw == null) return null;
      final s = raw.toString().trim();
      if (yesNo) {
        if (s == '1' || s == '(1) Yes') return '(1) Yes';
        if (s == '0' || s == '(0) No') return '(0) No';
      }
      return s.isEmpty ? null : s;
    }
    String? normPlace(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString().trim();
      const placeMap = {'0': '(0) RHC', '1': '(1) PVT', '2': '(2) GOVT', '3': '(3) HOME'};
      return placeMap[s] ?? (s.isEmpty ? null : s);
    }

    dateOfInterview = parseDate(d['Date_of_Interview'] ?? d['Interview_Date'] ?? d['CHKUP_DT']) ?? DateTime.now();
    // LMP → REACH LMP_DT fallback
    lmpDate = parseDate(d['LMP_Date'] ?? d['LMP_DT']);
    eddDate = parseDate(d['EDD_Date']);
    interviewersName = matchInterviewerName(d['Interviewer_s_Name'] ?? d['Interviewer_Name'] ?? d['INTNAME'], interviewerList);

    // --- TT Dose: app fields → REACH TT1/TT2 fallbacks ---
    stGivenYN = normYN(d['st_Given_Y_N'] ?? d['TT1']);
    stGivenBy = normPlace(d['st_Given_By'] ?? d['TT_DOSE_I_GB']);
    stDt = parseDate(d['st_Dt'] ?? d['TT_DOSE_I_DT']);
    ndGivenYN = normYN(d['nd_Given_Y_N'] ?? d['TT2']);
    ndGivenBy = normPlace(d['nd_Given_By'] ?? d['TT_DOSE_II_GB']);
    ndDt = parseDate(d['nd_Dt'] ?? d['TT_DOSE_II_DT']);

    // --- IFA: app fields → REACH IFA1-4 fallbacks ---
    stGivenYN1 = normYN(d['st_Given_Y_N1'] ?? d['IFA1']);
    stGivenBy1 = normPlace(d['st_Given_By1'] ?? d['IFA_DOSE_I_GB']);
    stDt1 = parseDate(d['st_Dt1'] ?? d['IFA_DOSE_I_DT']);
    ndGivenYN1 = normYN(d['nd_Given_Y_N1'] ?? d['IFA2']);
    ndGivenBy1 = normPlace(d['nd_Given_By1'] ?? d['IFA_DOSE_II_GB']);
    ndDt1 = parseDate(d['nd_Dt1'] ?? d['IFA_DOSE_II_DT']);
    rdGivenYN = normYN(d['rd_Given_Y_N'] ?? d['IFA3']);
    rdGivenYN1 = normPlace(d['rd_Given_Y_N1'] ?? d['IFA_DOSE_III_GB']);
    rdDt = parseDate(d['rd_Dt'] ?? d['IFA_DOSE_III_DT']);
    THGivenYN = normYN(d['TH_Given_Y_N'] ?? d['IFA4']);
    THGivenYN1 = normPlace(d['TH_Given_Y_N1'] ?? d['IFA_DOSE_IV_GB']);
    thDt = parseDate(d['th_Dt'] ?? d['IFA_DOSE_IV_DT']);

    // --- Delivery: app fields → REACH fallbacks ---
    // DELTYPE: 0=Normal, 1=Caesarian, 2=Abortion
    final rawDelType = d['Delivery_Type'] ?? d['DELTYPE'];
    const delTypeMap = {'0': '(0) Normal', '1': '(1) Caesarian', '2': '(2) Abortion'};
    deliveryType = (rawDelType != null) ? (delTypeMap[rawDelType.toString()] ?? rawDelType.toString()) : null;
    deliveryDt = parseDate(d['Delivery_Dt'] ?? d['DELIVERY_DT']);
    // DEL_PLACE: 0=RHC, 1=PVT, 2=GOVT, 3=HOME
    final rawDelPlace = d['Delivery_Place'] ?? d['DEL_PLACE'];
    deliveryPlace = (rawDelPlace != null) ? (normPlace(rawDelPlace) ?? rawDelPlace.toString()) : null;
    _deliveryPlaceDetails.text = (d['Delivery_Place_Details'] ?? d['DEL_PLACE_DET'] ?? '').toString();
    // DELIVERY: 0=Live Birth, 1=Still Birth, 2=Premature
    final rawOutcome = d['Delivery'] ?? d['DELIVERY'];
    const outcomeMap = {'0': '(0) Live Birth', '1': '(1) Still Birth', '2': '(2) Premature'};
    deliveryOutcome = (rawOutcome != null) ? (outcomeMap[rawOutcome.toString()] ?? rawOutcome.toString()) : null;
    _noOfBirths.text = d['No_of_Births']?.toString() ?? '';
    _noOfBirthOfFemale.text = d['No_of_Birth_of_Female1']?.toString() ?? '';
    // LIVE_BIRTHS fallback from REACH
    _totalLiveBirths.text = (d['Total_Live_Births'] ?? d['LIVE_BIRTHS'])?.toString() ?? '';

    // --- Remarks ---
    _remarks2.text = d['Remarks2'] ?? '';

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _isActionActive = false;
      _registrationNumber.clear();
      _familyCodeController.text = 'TSRRMED';
      _nameController.clear();
      _husbandName.clear();
      selectedFamilyCode = null;
      selectedMemberName = null;
      _locationVillage = null; _locationMandal = null; _locationDistrict = null; _locationState = null;
      _age.clear();
      dateOfInterview = DateTime.now();
      lmpDate = null;
      eddDate = null;
      interviewersName = null;
      _baseRegistrationNumber = null;

      // Reset TT Dose
      stDt = ndDt = null;
      stGivenYN = stGivenBy = ndGivenYN = ndGivenBy = null;

      // Reset IFA
      stDt1 = ndDt1 = rdDt = thDt = null;
      stGivenYN1 = stGivenBy1 = ndGivenYN1 = ndGivenBy1 = rdGivenYN = rdGivenYN1 = THGivenYN = THGivenYN1 = null;

      // Reset Delivery
      deliveryDt = null;
      deliveryType = deliveryPlace = deliveryOutcome = null;
      _deliveryPlaceDetails.clear();
      _noOfBirths.clear();
      _noOfBirthOfFemale.clear();
      _totalLiveBirths.clear();
      
      _hasMaleBirth = false;
      _hasFemaleBirth = false;
      for (var c in _maleWeightControllers) { c.dispose(); }
      for (var c in _femaleWeightControllers) { c.dispose(); }
      _maleWeightControllers.clear();
      _femaleWeightControllers.clear();

      // Reset Remarks & Selection
      _remarks2.clear();
      selectEntryScreen = null;

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
        'Family_Code': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Village': _locationVillage,
        'Mandal': _locationMandal,
        'District': _locationDistrict,
        'State': _locationState,
        'Husband_Name': _husbandName.text,
        'Age': int.tryParse(_age.text),
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'LMP_Date': lmpDate != null ? Timestamp.fromDate(lmpDate!) : null,
        'EDD_Date': eddDate != null ? Timestamp.fromDate(eddDate!) : null,
        'Interviewer_s_Name': interviewersName,
        'Select_Entry_Screen': selectEntryScreen,

        // --- TT Dose ---
        'st_Given_Y_N': stGivenYN,
        'st_Given_By': stGivenBy,
        'st_Dt': stDt != null ? Timestamp.fromDate(stDt!) : null,
        'nd_Given_Y_N': ndGivenYN,
        'nd_Given_By': ndGivenBy,
        'nd_Dt': ndDt != null ? Timestamp.fromDate(ndDt!) : null,

        // --- IFA ---
        'st_Given_Y_N1': stGivenYN1,
        'st_Given_By1': stGivenBy1,
        'st_Dt1': stDt1 != null ? Timestamp.fromDate(stDt1!) : null,
        'nd_Given_Y_N1': ndGivenYN1,
        'nd_Given_By1': ndGivenBy1,
        'nd_Dt1': ndDt1 != null ? Timestamp.fromDate(ndDt1!) : null,
        'rd_Given_Y_N': rdGivenYN,
        'rd_Given_Y_N1': rdGivenYN1,
        'rd_Dt': rdDt != null ? Timestamp.fromDate(rdDt!) : null,
        'TH_Given_Y_N': THGivenYN,
        'TH_Given_Y_N1': THGivenYN1,
        'th_Dt': thDt != null ? Timestamp.fromDate(thDt!) : null,

        // --- Delivery ---
        'Delivery_Type': deliveryType,
        'Delivery_Dt': deliveryDt != null ? Timestamp.fromDate(deliveryDt!) : null,
        'Delivery_Place': deliveryPlace,
        'Delivery_Place_Details': _deliveryPlaceDetails.text,
        'Delivery': deliveryOutcome,
        'No_of_Births': int.tryParse(_noOfBirths.text),
        'No_of_Birth_of_Female1': int.tryParse(_noOfBirthOfFemale.text),
        'Total_Live_Births': _totalLiveBirths.text,

        'Remarks2': _remarks2.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;

      // 1. Save locally FIRST (Fast)
      final bool wasEditing = _isEditMode;
      await DataCacheService().saveOfflineSubmission('ante_natal_care', data);

      // --- New Infant Local Creation ---
      if (!_isEditMode && deliveryOutcome != null && deliveryOutcome!.contains('Live Birth')) {
        final Map<String, dynamic> baseChildData = {
          'Family_Code': selectedFamilyCode ?? _familyCodeController.text,
          'Age': 0,
          'Date_of_Birth': deliveryDt != null ? Timestamp.fromDate(deliveryDt!) : null,
          'Mother_Name': _isEditMode ? selectedMemberName : _nameController.text,
          'Father_Name': _husbandName.text,
          'Live_Status': '(1) Alive',
          'Marital_Status': '(0) Unmarried',
          'Relation_with_Head': '',
          'A_v_Status': '(1) Active',
          'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
          'needs_zoho_sync': true,
        };

        if (_hasMaleBirth) {
          for (var i = 0; i < _maleWeightControllers.length; i++) {
            final childPayload = Map<String, dynamic>.from(baseChildData);
            childPayload['Name'] = 'Boy ' + (i > 0 ? '${i+1}' : '').trim(); // E.g., Boy, Boy 2
            childPayload['Gender'] = '(1) Male';
            childPayload['Birth_weight'] = double.tryParse(_maleWeightControllers[i].text);
            await DataCacheService().saveOfflineSubmission('personal_details', childPayload);
          }
        }
        
        if (_hasFemaleBirth) {
          for (var i = 0; i < _femaleWeightControllers.length; i++) {
            final childPayload = Map<String, dynamic>.from(baseChildData);
            childPayload['Name'] = 'Girl ' + (i > 0 ? '${i+1}' : '').trim(); // E.g., Girl, Girl 2
            childPayload['Gender'] = '(0) Female';
            childPayload['Birth_weight'] = double.tryParse(_femaleWeightControllers[i].text);
            await DataCacheService().saveOfflineSubmission('personal_details', childPayload);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'ANC updated! Syncing...' : 'ANC saved! Syncing...'),
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
        _isActionActive = false; // Add this
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Ante Natal Care'),
        elevation: 0,
        actions: [
          IconButton(
            icon: _isDownloadingAnc
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(Icons.sync, color: _ancAlreadyDownloaded ? Colors.greenAccent : Colors.white),
            tooltip: _ancAlreadyDownloaded ? 'Downloaded on $_ancDownloadedAt' : 'Sync ANC Records',
            onPressed: _isDownloadingAnc ? null : () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(_ancAlreadyDownloaded ? 'Re-Sync ANC Records' : 'Sync ANC Records'),
                  content: Text(_ancAlreadyDownloaded
                      ? 'ANC records were last downloaded on $_ancDownloadedAt.\n\nRe-download to get latest data?'
                      : 'Download 20,000+ ANC records for offline use. One-time download.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start')),
                  ],
                ),
              );
              if (confirm == true) _downloadAncFromStorage();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('anc_scroll'),
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
                      title: 'Maternity Details',
                      icon: Icons.pregnant_woman_outlined,
                      children: [
                        _buildDatePicker('LMP Date', lmpDate, (v) {
                          setState(() {
                            lmpDate = v;
                            eddDate = v.add(const Duration(days: 280));
                            _updateRegistrationNumber();
                          });
                        }),
                        const SizedBox(height: 16),
                        _buildDatePicker('EDD Date', eddDate, (v) => setState(() => eddDate = v)),
                        const SizedBox(height: 16),
                        formSearchableDropdown(context, 'Select Entry Screen', screenChoices, selectEntryScreen, (v) => setState(() => selectEntryScreen = v as String?), enabled: _isActionActive),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (selectEntryScreen == 'TT Dose') _buildTTDoseSection(),
                    if (selectEntryScreen == 'IFA') _buildIFASection(),
                    if (selectEntryScreen == 'Delivery') _buildDeliverySection(),
                    if (selectEntryScreen == 'Remarks') _buildRemarksSection(),
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
        formTextField('Registration Number', _registrationNumber, enabled: _isActionActive),
        const SizedBox(height: 12),
        formSearchField('Family Code', _familyCodeController, onSearch: () {
          if (_familyCodeController.text.isNotEmpty) {
            _fetchMembersByFamily(_familyCodeController.text);
            _fetchExistingRecords(_familyCodeController.text);
          }
        }, isLoading: _isLoadingMembers,
          readOnly: _familyIdReadOnly,
          focusNode: _familyCodeNode,
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
          (v) => _onNameSelected(v as String?),
          isLoading: _isLoadingMembers,
          enabled: _isActionActive,
        ),
        const SizedBox(height: 12),
        formTextField('Husband Name', _husbandName, enabled: _isActionActive),
        const SizedBox(height: 12),
        formTextField('Age', _age, enabled: _isActionActive, keyboardType: TextInputType.number),
      ],
    );
  }

  Widget _buildTTDoseSection() {
    return buildSectionCard(
      context: context,
      title: 'TT Dose',
      icon: Icons.vaccines_outlined,
      children: [
        const Text('1st TT Dose', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, '1st Given Y/N', yesNoChoices, stGivenYN, (v) => setState(() => stGivenYN = v as String?), enabled: _isActionActive)),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, '1st Given By', givenByChoices, stGivenBy, (v) => setState(() => stGivenBy = v as String?), enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 12),
        _buildDatePicker('1st TT Dt.', stDt, (v) => setState(() => stDt = v), enabled: _isActionActive),
        const Divider(height: 32),
        const Text('2nd TT Dose', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, '2nd Given Y/N', yesNoChoices, ndGivenYN, (v) => setState(() => ndGivenYN = v as String?), enabled: _isActionActive)),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, '2nd Given By', givenByChoices, ndGivenBy, (v) => setState(() => ndGivenBy = v as String?), enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 12),
        _buildDatePicker('2nd TT Dt.', ndDt, (v) => setState(() => ndDt = v), enabled: _isActionActive),
      ],
    );
  }

  Widget _buildIFASection() {
    return buildSectionCard(
      context: context,
      title: 'IFA',
      icon: Icons.medication_outlined,
      children: [
        const Text('1st IFA', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, '1st Given Y/N', yesNoChoices, stGivenYN1, (v) => setState(() => stGivenYN1 = v as String?), enabled: _isActionActive)),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, '1st Given By', givenByChoices, stGivenBy1, (v) => setState(() => stGivenBy1 = v as String?), enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 12),
        _buildDatePicker('1st IFA Dt.', stDt1, (v) => setState(() => stDt1 = v), enabled: _isActionActive),
        const Divider(height: 32),
        const Text('2nd IFA', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, '2nd Given Y/N', yesNoChoices, ndGivenYN1, (v) => setState(() => ndGivenYN1 = v as String?), enabled: _isActionActive)),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, '2nd Given By', givenByChoices, ndGivenBy1, (v) => setState(() => ndGivenBy1 = v as String?), enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 12),
        _buildDatePicker('2nd IFA Dt.', ndDt1, (v) => setState(() => ndDt1 = v), enabled: _isActionActive),
        const Divider(height: 32),
        const Text('3rd IFA', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, '3rd Given Y/N', yesNoChoices, rdGivenYN, (v) => setState(() => rdGivenYN = v as String?), enabled: _isActionActive)),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, '3rd Given By', givenByChoices, rdGivenYN1, (v) => setState(() => rdGivenYN1 = v as String?), enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 12),
        _buildDatePicker('3rd IFA Dt.', rdDt, (v) => setState(() => rdDt = v), enabled: _isActionActive),
        const Divider(height: 32),
        const Text('4th IFA', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, '4TH Given Y/N', yesNoChoices, THGivenYN, (v) => setState(() => THGivenYN = v as String?), enabled: _isActionActive)),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, '4th Given By', givenByChoices, THGivenYN1, (v) => setState(() => THGivenYN1 = v as String?), enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 12),
        _buildDatePicker('4th IFA Dt.', thDt, (v) => setState(() => thDt = v), enabled: _isActionActive),
      ],
    );
  }

  Widget _buildDeliverySection() {
    return buildSectionCard(
      context: context,
      title: 'Delivery',
      icon: Icons.child_friendly_outlined,
      children: [
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, 'Delivery Type', deliveryTypeChoices, deliveryType, (v) => setState(() => deliveryType = v as String?), enabled: _isActionActive)),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Delivery Dt.', deliveryDt, (v) => setState(() => deliveryDt = v), enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, 'Delivery Place', deliveryPlaceChoices, deliveryPlace, (v) => setState(() => deliveryPlace = v as String?), enabled: _isActionActive)),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, 'Delivery Outcome', deliveryOutcomeChoices, deliveryOutcome, (v) => setState(() => deliveryOutcome = v as String?), enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 12),
        formTextField('Delivery Place Details', _deliveryPlaceDetails, enabled: _isActionActive),
        const SizedBox(height: 12),
        if (deliveryOutcome != null && deliveryOutcome!.contains('Live Birth')) ...[
          const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
          Row(
            children: [
              Expanded(child: CheckboxListTile(title: const Text('(1) Male'), value: _hasMaleBirth, onChanged: !_isActionActive ? null : (v) => setState(() { _hasMaleBirth = v ?? false; if (!_hasMaleBirth) { _noOfBirths.clear(); _updateMaleControllers(); } }), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero)),
              Expanded(child: CheckboxListTile(title: const Text('(0) Female'), value: _hasFemaleBirth, onChanged: !_isActionActive ? null : (v) => setState(() { _hasFemaleBirth = v ?? false; if (!_hasFemaleBirth) { _noOfBirthOfFemale.clear(); _updateFemaleControllers(); } }), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero)),
            ],
          ),
          if (_hasMaleBirth) ...[
            const SizedBox(height: 12),
            formTextField('No.of Birth of Male', _noOfBirths, enabled: _isActionActive, keyboardType: TextInputType.number),
            ...List.generate(_maleWeightControllers.length, (index) => Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 16.0),
              child: formTextField('Male Infant ${index + 1} Birth Weight', _maleWeightControllers[index], enabled: _isActionActive, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            )),
          ],
          if (_hasFemaleBirth) ...[
            const SizedBox(height: 12),
            formTextField('No.of Birth of Female', _noOfBirthOfFemale, enabled: _isActionActive, keyboardType: TextInputType.number),
            ...List.generate(_femaleWeightControllers.length, (index) => Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 16.0),
              child: formTextField('Female Infant ${index + 1} Birth Weight', _femaleWeightControllers[index], enabled: _isActionActive, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            )),
          ],
          const SizedBox(height: 12),
          formTextField('Total Live Births', _totalLiveBirths, enabled: _isActionActive, keyboardType: TextInputType.number),
        ] else ...[
          Row(
            children: [
              Expanded(child: formTextField('No.of Birth of Male', _noOfBirths, enabled: _isActionActive, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: formTextField('No.of Birth of Female', _noOfBirthOfFemale, enabled: _isActionActive, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          formTextField('Total Live Births', _totalLiveBirths, enabled: _isActionActive, keyboardType: TextInputType.number),
        ],
      ],
    );
  }

  Widget _buildRemarksSection() {
    return buildSectionCard(
      context: context,
      title: 'Remarks',
      icon: Icons.note_alt_outlined,
      children: [
        formTextField('Remarks', _remarks2, enabled: _isActionActive, maxLines: 5),
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
            final picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now().add(const Duration(days: 365)));
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