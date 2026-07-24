import "package:flutter/material.dart";
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data_cache_service.dart';
import 'local_database_service.dart';
import 'sync_service.dart';
import 'widget.dart';

class ChildImmunizationPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const ChildImmunizationPage({super.key, this.existingData, this.docId});

  @override
  State<ChildImmunizationPage> createState() => _ChildImmunizationPageState();
}

class _ChildImmunizationPageState extends State<ChildImmunizationPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;
  bool _isDownloadingCI = false;
  bool _ciAlreadyDownloaded = false;
  String? _ciDownloadedAt;
  bool _isEditMode = false;
  String? _editDocId;
  bool _isLoadingMembers = false;
  bool _isActionActive = false; // Add this
  final FocusNode _familyCodeNode = FocusNode();
  bool _familyIdReadOnly = true;

  // --- Controllers & State Variables ---
  final _registrationNumber = TextEditingController();
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  final _nameController = TextEditingController();
  final _motherName = TextEditingController();
  final _age = TextEditingController();
  final _remarksController = TextEditingController();
  final _birthWeight = TextEditingController();
  final _birthHeight = TextEditingController();
  
  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectEntryScreen;
  DateTime? dob;
  DateTime? dateOfInterview = DateTime.now();
  String? interviewersName;
  String? hasDiarrhea;
  String? isBreastfeeding;

  // Vaccine Data Map covering all doses from the chart
  Map<String, Map<String, dynamic>> vaccines = {
    // Birth
    'BCG': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'OPV0': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'HepB0': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    // 6 Weeks
    'OPV1': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'RV1': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'IPV1': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'Penta1': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'PCV1': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    // 10 Weeks
    'OPV2': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'RV2': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'Penta2': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    // 14 Weeks
    'OPV3': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'RV3': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'IPV2': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'Penta3': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'PCV2': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    // 9-12 Months
    'MR1': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'JE1': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'VitA1': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'PCVB': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    // 16-24 Months
    'MR2': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'JE2': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'OPVB': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'DPTB1': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    // 5-6 Years
    'DPTB2': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    // 10 Years
    'Td1': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    // 16 Years
    'Td2': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    // Vitamin A (Every 6 months)
    'VitA2': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'VitA3': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'VitA4': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'VitA5': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'VitA6': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'VitA7': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'VitA8': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'VitA9': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
  };

  // State for Missed Doses Table (5 rows for simplicity)
  List<Map<String, String>> missedDoses = List.generate(5, (_) => {
    'name': '', 'date': '', 'reason': '', 'nextDate': '', 'worker': ''
  });

  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  // Location (auto-populated from Family Code)
  String? _locationVillage;
  String? _locationMandal;
  String? _locationDistrict;
  String? _locationState;


  final List<String> interviewerList = ['KIRANMAI K', 'REVATHI CH', 'RAMADEVI Y', 'LAVANYA KASPOJU', 'PUSHPA K', 'G RAMADEVI', 'BHASKAR K', 'ASHA', 'KUSUMA G', 'B JYOTHI', 'RAMADEVI G', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU'];

  @override
  void initState() {
    super.initState();
    _loadCIDownloadStatus();
    if (widget.existingData != null) {
      _isEditMode = true;
      _editDocId = widget.docId;
      _loadExistingData();
      // Fetch family members so name/mother/father dropdowns populate in edit mode
      final familyCode = (widget.existingData!['Family_Code'] ?? widget.existingData!['Family_code'] ?? '').toString();
      if (familyCode.isNotEmpty) {
        _fetchMembersByFamily(familyCode);
      }
    }
  }

  @override
  void dispose() {
    _familyCodeNode.dispose();
    _registrationNumber.dispose();
    _familyCodeController.dispose();
    _nameController.dispose();
    _motherName.dispose();
    _age.dispose();
    _remarksController.dispose();
    _birthWeight.dispose();
    _birthHeight.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCIDownloadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString('child_immunization_download_timestamp');
    if (ts != null && mounted) {
      setState(() { _ciAlreadyDownloaded = true; _ciDownloadedAt = ts; });
    }
  }

  Future<void> _downloadCIFromStorage() async {
    setState(() { _isDownloadingCI = true; });
    try {
      final ref = FirebaseStorage.instance.ref().child('exports/child_health.json');
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
          await dbService.saveChildImmunization(batch, clearFirst: saved == 0);
          saved += batch.length;
          batch.clear();
        }
      }
      if (batch.isNotEmpty) {
        await dbService.saveChildImmunization(batch, clearFirst: saved == 0);
        saved += batch.length;
      }

      final prefs = await SharedPreferences.getInstance();
      final ts = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      await prefs.setString('child_immunization_download_timestamp', ts);

      if (mounted) {
        setState(() { _ciAlreadyDownloaded = true; _ciDownloadedAt = ts; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $saved child health records downloaded for offline use!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Download failed: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 8),
      ));
    } finally {
      if (mounted) setState(() => _isDownloadingCI = false);
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

      // 1. Fetch Members (Local First)
      final localMembers = await DataCacheService().fetchMembersLocally(fCode);
      
      // 2. Fetch from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: fCode)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 4));

      final Map<String, Map<String, dynamic>> memberMap = {};
      final Set<String> allNames = {};
      
      void processMember(Map<String, dynamic> data, {bool fromFirestore = false}) async {
        final name = data['Name']?.toString() ?? '';
        if (name.isEmpty) return;
        
        // Store EVERYONE in memberMap for lookup purposes (e.g. mother name)
        memberMap[name] = data;
        
        // Show in dropdown if: mother name OR father name is present (not default)
        // OR birth weight is filled — but exclude anyone with BOTH set to defaults
        final mName = (data['Mother_Name'] ?? '').toString().trim();
        final fName = (data['Father_Name'] ?? '').toString().trim();
        final bWeight = data['Birth_weight'] ?? data['Birth_Weight'];

        final hasMotherName = mName.isNotEmpty && mName != 'No Mother';
        final hasFatherName = fName.isNotEmpty && fName != 'No Father';
        final hasBirthWeight = bWeight != null && bWeight.toString().isNotEmpty;

        if (hasMotherName || hasFatherName || hasBirthWeight) {
          allNames.add(name);
        }
        
        if (fromFirestore) {
          await DataCacheService().addMember(data);
        }
      }

      // Process local first
      for (var local in localMembers) processMember(local);
      
      // Process firestore and cache
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['firestoreDocId'] = doc.id;
        processMember(data, fromFirestore: true);
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




  void _onNameSelected(String? name) async {
    setState(() {
      selectedMemberName = name;
      _nameController.text = name ?? '';
    });
    
    if (name == null) return;

    final baseData = _allMembersData[name];
    if (baseData != null && !_isEditMode) {
      _registrationNumber.text = (baseData['uniq_Registration_Number'] ?? baseData['Registration_Number'] ?? baseData['Registration_Number1'] ?? '').toString();
      _age.text = baseData['Age']?.toString() ?? '';
      
      // Resolve Mother Name by Lookup
      String mIdentifier = baseData['Mother_Name']?.toString() ?? '';
      if (mIdentifier.isNotEmpty) {
        bool found = false;
        // Search all family members for one whose ID matches mIdentifier
        for (final member in _allMembersData.values) {
          final id1 = member['uniq_Registration_Number']?.toString();
          final id2 = member['Registration_Number']?.toString();
          final id3 = member['Registration_Number1']?.toString();
          
          if (id1 == mIdentifier || id2 == mIdentifier || id3 == mIdentifier) {
            _motherName.text = member['Name']?.toString() ?? '';
            found = true;
            break;
          }
        }
        if (!found) _motherName.text = mIdentifier; // Fallback to raw value
      } else {
        _motherName.text = '';
      }

      if (baseData['Date_of_Birth'] != null) {
        dob = baseData['Date_of_Birth'] is Timestamp ? (baseData['Date_of_Birth'] as Timestamp).toDate() : null;
      }
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();

        // 1. Check local SQLite first (instant offline)
        final localRecord = await LocalDatabaseService().getChildImmunizationByName(fCode, name);
        if (localRecord != null && baseData != null) {
          setState(() {
            final merged = {...baseData!, ...localRecord};
            _populateForm(merged);
          });
        }

        // 2. Firestore for fresh data (with timeout)
        final snapshot = await FirebaseFirestore.instance
            .collection('child_immunization')
            .where('Family_Code', isEqualTo: fCode)
            .where('Name', isEqualTo: name)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 5));

        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          setState(() {
            _editDocId = doc.id;
            final merged = {...?baseData, ...localRecord ?? {}, ...doc.data()};
            _populateForm(merged);
          });
        } else if (localRecord == null && baseData != null) {
          _populateForm(baseData!);
        }
      } catch (e) {
        debugPrint('CI: Firestore fetch failed, using local: $e');
        if (baseData != null) _populateForm(baseData!);
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
    selectedFamilyCode = d['Family_Code'] ?? d['Family_code'] ?? d['Family_ID'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _locationVillage  = (d['Village']  ?? d['village'])?.toString();
    _locationMandal   = (d['Mandal']   ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState    = (d['State']    ?? d['state'])?.toString();
    _nameController.text = selectedMemberName ?? '';
    _motherName.text = d['Mother_Name']?.toString() ?? '';
    _age.text = d['Age']?.toString() ?? '';
    selectEntryScreen = d['Entry_Screen'] ?? d['Select_Entry_Screen'];
    
    final rawInterviewDate = d['Date_of_Interview'] ?? d['Interview_Date'];
    if (rawInterviewDate != null) {
      if (rawInterviewDate is Timestamp) {
        dateOfInterview = rawInterviewDate.toDate();
      } else {
        try {
          dateOfInterview = DateFormat('dd-MMM-yyyy').parse(rawInterviewDate.toString());
        } catch (_) {
          try {
            dateOfInterview = DateTime.parse(rawInterviewDate.toString());
          } catch (_) {}
        }
      }
    }
    
    final rawDob = d['DOB'] ?? d['Date_of_Birth'];
    if (rawDob != null) {
      if (rawDob is Timestamp) {
        dob = rawDob.toDate();
      } else {
        try {
          dob = DateFormat('dd-MMM-yyyy').parse(rawDob.toString());
        } catch (_) {
          dob = DateTime.tryParse(rawDob.toString());
        }
      }
    }
    interviewersName = matchInterviewerName(d['Interviewer_s_Name'] ?? d['Interviewer_Name'] ?? d['INTNAME'], interviewerList);

    // Normalize REACH 1/0 → '(1) Yes'/'(0) No' for vaccine given status
    String normVaccineGiven(dynamic raw) {
      if (raw == null) return '(0) No';
      final s = raw.toString().trim();
      if (s == '1' || s == '(1) Yes') return '(1) Yes';
      return '(0) No';
    }
    // Normalize REACH 0/1/2 place codes → app option strings
    String normVaccinePlace(dynamic raw) {
      if (raw == null) return '(0) RHC';
      final s = raw.toString().trim();
      if (s == '0' || s == '(0) RHC') return '(0) RHC';
      if (s == '1' || s == '(1) PVT') return '(1) PVT';
      if (s == '2' || s == '(2) GOVT') return '(2) GOVT';
      return '(0) RHC';
    }

    // Map vaccine: app Firestore keys first, then REACH CHILD_HEALTH fallbacks
    void mapVaccine(String key, String ynKey, String dtKey, String byKey,
        [String? reachYn, String? reachDt, String? reachBy]) {
      vaccines[key]!['given'] = normVaccineGiven(d[ynKey] ?? (reachYn != null ? d[reachYn] : null));
      final val = d[dtKey] ?? (reachDt != null ? d[reachDt] : null);
      if (val != null) {
        if (val is Timestamp) {
          vaccines[key]!['date'] = val.toDate();
        } else {
          try {
            vaccines[key]!['date'] = DateFormat('dd-MMM-yyyy').parse(val.toString());
          } catch (_) {
            vaccines[key]!['date'] = DateTime.tryParse(val.toString());
          }
        }
      }
      vaccines[key]!['by'] = normVaccinePlace(d[byKey] ?? (reachBy != null ? d[reachBy] : null));
    }

    // At Birth
    mapVaccine('BCG',   'BCG_Given_Y_N',   'BCG_Dt',   'BCG_Given_By',   'BCG',    'BCG_DT',      'BCG_PL');
    mapVaccine('OPV0',  'OPVO_Given_Y_N',  'OPV0_Dt',  'OPVO_Given_By',  'POLIO0', 'POLIO_0_DT',  'POLIO_0_PL');
    mapVaccine('HepB0', 'HepB0_Given_Y_N', 'HepB0_Dt', 'HepB0_Given_By', 'HEP_I',  'HEP_I_DT',    'HEP_I_PL');
    // 6 Weeks
    mapVaccine('OPV1',  'OPVO_Given_By1',  'OPV_1_Dt', 'OPV1_Given_By',  'POLIO1', 'POLIO_1_DT',  'POLIO_1_PL');
    mapVaccine('RV1',   'RV1_Given_Y_N',   'RV1_Dt',   'RV1_Given_By');
    mapVaccine('IPV1',  'IPV1_Given_Y_N',  'IPV1_Dt',  'IPV1_Given_By');
    mapVaccine('Penta1','DPT1_Given_Y_N',  'DPT1_Dt3', 'DPT1_Given_Y_N1','DPT1',   'DPT_1_DT',    'DPT_1_PL');
    mapVaccine('PCV1',  'PCV1_Given_Y_N',  'PCV1_Dt',  'PCV1_Given_By');
    // 10 Weeks
    mapVaccine('OPV2',  'OPV2_Given_yes_no','OPV2_Dt', 'Drop_OPV2_Given_By','POLIO2','POLIO_2_DT', 'POLIO_2_PL');
    mapVaccine('RV2',   'RV2_Given_Y_N',   'RV2_Dt',   'RV2_Given_By');
    mapVaccine('Penta2','DPT2_Given_Y_N2', 'DPT2_Dt',  'DPT2_Given_By',  'DPT2',   'DPT_2_DT',    'DPT_2_PL');
    // 14 Weeks
    mapVaccine('OPV3',  'OPV3_Given_by_Y_N','OPV3_Dt', 'OPV2_Given_By2', 'POLIO3', 'POLIO_3_DT',  'POLIO_3_PL');
    mapVaccine('RV3',   'RV3_Given_Y_N',   'RV3_Dt',   'RV3_Given_By');
    mapVaccine('IPV2',  'IPV2_Given_Y_N',  'IPV2_Dt',  'IPV2_Given_By');
    mapVaccine('Penta3','DPT3_Given_Y_N3', 'DPT3_Dt',  'DPT3_Given_By',  'DPT3',   'DPT_3_DT',    'DPT_3_PL');
    mapVaccine('PCV2',  'PCV2_Given_Y_N',  'PCV2_Dt',  'PCV2_Given_By');
    // 9-12 Months
    mapVaccine('MR1',   'Measles1',        'Measles_Dt','Measles_Given_Y_N','MEASLES','MEASLES_DT', 'MEASLES_PL');
    mapVaccine('JE1',   'JE1_Given_Y_N',   'JE1_Dt',   'JE1_Given_By');
    mapVaccine('VitA1', 'VitA1_Given_Y_N', 'VitA1_Dt', 'VitA1_Given_By', 'VIT_A_1','VIT_A_1_DT',  'VIT_A_1_PL');
    mapVaccine('PCVB',  'PCVB_Given_Y_N',  'PCVB_Dt',  'PCVB_Given_By');
    // 16-24 Months
    mapVaccine('MR2',   'MR2_Given_Y_N',   'MR2_Dt',   'MR2_Given_By');
    mapVaccine('JE2',   'JE2_Given_Y_N',   'JE2_Dt',   'JE2_Given_By');
    mapVaccine('OPVB',  'OPV_B_Given_Y_N', 'OPV_B_Dt', 'OPV2_Given_By1', 'POLIO_B','POLIO_B_DT',  'POLIO_B_PL');
    mapVaccine('DPTB1', 'DPTB_Given_Y_N',  'DPT_B_Dt', 'DPTB_Given_Y_N1','DPT_B',  'DPT_B_DT',    'DPT_B_PL');
    // Booster Doses
    mapVaccine('DPTB2', 'DPTB2_Given_Y_N', 'DPTB2_Dt', 'DPTB2_Given_By');
    mapVaccine('Td1',   'DT_Given_Y_N',    'DT_Dt',    'DT_Given_By',    'DT',     'DT_DT',       'DT_PL');
    mapVaccine('Td2',   'Td2_Given_Y_N',   'Td2_Dt',   'Td2_Given_By');
    // Vitamin A doses: app fields → REACH VIT_A_* fallbacks
    mapVaccine('VitA2', 'VitA2_Given_Y_N', 'VitA2_Dt', 'VitA2_Given_By', 'VIT_A_2','VIT_A_2_DT',  'VIT_A_2_PL');
    mapVaccine('VitA3', 'VitA3_Given_Y_N1','VitA3_Dt', 'V',              'VIT_A_3','VIT_A_3_DT',  'VIT_A_3_PL');
    mapVaccine('VitA4', 'Vita4_Given_Y_N', 'VitA4_Dt', 'VitA4_Given_By', 'VIT_A_4','VIT_A_4_DT',  'VIT_A_4_PL');
    mapVaccine('VitA5', 'VitA5_Given_Y_N', 'VitA5_Dt', 'VitA5_Given_By', 'VIT_A_b','VIT_A_b_DT',  'VIT_A_b_PL');
    mapVaccine('VitA6', 'VitA6_Given_Y_N', 'VitA6_Dt', 'VitA6_Given_By');
    mapVaccine('VitA7', 'VitA7_Given_Y_N', 'VitA7_Dt', 'VitA7_Given_By');
    mapVaccine('VitA8', 'VitA8_Given_Y_N', 'VitA8_Dt', 'VitA8_Given_By');
    mapVaccine('VitA9', 'VitA9_Given_Y_N', 'VitA9_Dt', 'VitA9_Given_By');

    _remarksController.text = d['Remarks1'] ?? d['Remarks'] ?? '';
    // Birth weight/height → REACH WEIGHT/HEIGHT fallbacks
    _birthWeight.text = (d['Birth_Weight'] ?? d['WEIGHT'])?.toString() ?? '';
    _birthHeight.text = (d['Birth_Height'] ?? d['HEIGHT'])?.toString() ?? '';
    // Diarrhea/Breastfeeding → REACH 1/0 normalization
    final rawDia = d['Diarrhea'] ?? d['DIARRHOEA'];
    hasDiarrhea = (rawDia != null) ? (rawDia.toString() == '1' ? 'Yes' : rawDia.toString() == '0' ? 'No' : rawDia.toString()) : null;
    final rawBf = d['Breastfeeding'] ?? d['BREASTFEEDING'];
    isBreastfeeding = (rawBf != null) ? (rawBf.toString() == '1' ? 'Yes' : rawBf.toString() == '0' ? 'No' : rawBf.toString()) : null;

    // Load missed doses
    final missedRaw = d['missed_doses'];
    if (missedRaw is List) {
      for (int i = 0; i < missedRaw.length && i < 5; i++) {
        final m = missedRaw[i] as Map;
        missedDoses[i] = {
          'name': m['name']?.toString() ?? '',
          'date': m['date']?.toString() ?? '',
          'reason': m['reason']?.toString() ?? '',
          'nextDate': m['nextDate']?.toString() ?? '',
          'worker': m['worker']?.toString() ?? '',
        };
      }
    }

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
      _motherName.clear();
      _remarksController.clear();
      _birthWeight.clear();
      _birthHeight.clear();
      selectedFamilyCode = null;
      selectedMemberName = null;
      _locationVillage = null; _locationMandal = null; _locationDistrict = null; _locationState = null;
      _age.clear();
      dateOfInterview = DateTime.now();
      dob = null;
      selectEntryScreen = null;
      interviewersName = null;
      hasDiarrhea = null;
      isBreastfeeding = null;
      familyMemberNames = [];
      vaccines.forEach((k, v) {
        v['given'] = '(0) No';
        v['date'] = null;
        v['by'] = '(0) RHC';
      });
      missedDoses = List.generate(5, (_) => {
        'name': '', 'date': '', 'reason': '', 'nextDate': '', 'worker': ''
      });
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
        'Mother_Name': _motherName.text,
        'Age': int.tryParse(_age.text),
        'DOB': dob != null ? Timestamp.fromDate(dob!) : null,
        'Entry_Screen': selectEntryScreen,
        'Select_Entry_Screen': selectEntryScreen,
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'Interviewer_s_Name': interviewersName,
        'Remarks1': _remarksController.text,
        'Birth_Weight': double.tryParse(_birthWeight.text),
        'Birth_Height': _birthHeight.text,
        'Diarrhea': hasDiarrhea,
        'Breastfeeding': isBreastfeeding,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // --- All Vaccines mapping to Firestore ---
      void setVaccine(String key, String ynKey, String dtKey, String byKey) {
        data[ynKey] = vaccines[key]!['given'];
        data[dtKey] = vaccines[key]!['date'] != null ? Timestamp.fromDate(vaccines[key]!['date']) : null;
        data[byKey] = vaccines[key]!['by'];
      }

      setVaccine('BCG', 'BCG_Given_Y_N', 'BCG_Dt', 'BCG_Given_By');
      setVaccine('OPV0', 'OPVO_Given_Y_N', 'OPV0_Dt', 'OPVO_Given_By');
      setVaccine('HepB0', 'HepB0_Given_Y_N', 'HepB0_Dt', 'HepB0_Given_By');

      setVaccine('OPV1', 'OPVO_Given_By1', 'OPV_1_Dt', 'OPV1_Given_By');
      setVaccine('RV1', 'RV1_Given_Y_N', 'RV1_Dt', 'RV1_Given_By');
      setVaccine('IPV1', 'IPV1_Given_Y_N', 'IPV1_Dt', 'IPV1_Given_By');
      setVaccine('Penta1', 'DPT1_Given_Y_N', 'DPT1_Dt3', 'DPT1_Given_Y_N1');
      setVaccine('PCV1', 'PCV1_Given_Y_N', 'PCV1_Dt', 'PCV1_Given_By');

      setVaccine('OPV2', 'OPV2_Given_yes_no', 'OPV2_Dt', 'Drop_OPV2_Given_By');
      setVaccine('RV2', 'RV2_Given_Y_N', 'RV2_Dt', 'RV2_Given_By');
      setVaccine('Penta2', 'DPT2_Given_Y_N2', 'DPT2_Dt', 'DPT2_Given_By');

      setVaccine('OPV3', 'OPV3_Given_by_Y_N', 'OPV3_Dt', 'OPV2_Given_By2');
      setVaccine('RV3', 'RV3_Given_Y_N', 'RV3_Dt', 'RV3_Given_By');
      setVaccine('IPV2', 'IPV2_Given_Y_N', 'IPV2_Dt', 'IPV2_Given_By');
      setVaccine('Penta3', 'DPT3_Given_Y_N3', 'DPT3_Dt', 'DPT3_Given_By');
      setVaccine('PCV2', 'PCV2_Given_Y_N', 'PCV2_Dt', 'PCV2_Given_By');

      setVaccine('MR1', 'Measles1', 'Measles_Dt', 'Measles_Given_Y_N');
      setVaccine('JE1', 'JE1_Given_Y_N', 'JE1_Dt', 'JE1_Given_By');
      setVaccine('VitA1', 'VitA1_Given_Y_N', 'VitA1_Dt', 'VitA1_Given_By');
      setVaccine('PCVB', 'PCVB_Given_Y_N', 'PCVB_Dt', 'PCVB_Given_By');

      setVaccine('MR2', 'MR2_Given_Y_N', 'MR2_Dt', 'MR2_Given_By');
      setVaccine('JE2', 'JE2_Given_Y_N', 'JE2_Dt', 'JE2_Given_By');
      setVaccine('OPVB', 'OPV_B_Given_Y_N', 'OPV_B_Dt', 'OPV2_Given_By1');
      setVaccine('DPTB1', 'DPTB_Given_Y_N', 'DPT_B_Dt', 'DPTB_Given_Y_N1');

      setVaccine('DPTB2', 'DPTB2_Given_Y_N', 'DPTB2_Dt', 'DPTB2_Given_By');
      setVaccine('Td1', 'DT_Given_Y_N', 'DT_Dt', 'DT_Given_By');
      setVaccine('Td2', 'Td2_Given_Y_N', 'Td2_Dt', 'Td2_Given_By');

      setVaccine('VitA2', 'VitA2_Given_Y_N', 'VitA2_Dt', 'VitA2_Given_By');
      setVaccine('VitA3', 'VitA3_Given_Y_N1', 'VitA3_Dt', 'V');
      setVaccine('VitA4', 'Vita4_Given_Y_N', 'VitA4_Dt', 'VitA4_Given_By');
      setVaccine('VitA5', 'VitA5_Given_Y_N', 'VitA5_Dt', 'VitA5_Given_By');
      setVaccine('VitA6', 'VitA6_Given_Y_N', 'VitA6_Dt', 'VitA6_Given_By');
      setVaccine('VitA7', 'VitA7_Given_Y_N', 'VitA7_Dt', 'VitA7_Given_By');
      setVaccine('VitA8', 'VitA8_Given_Y_N', 'VitA8_Dt', 'VitA8_Given_By');
      setVaccine('VitA9', 'VitA9_Given_Y_N', 'VitA9_Dt', 'VitA9_Given_By');

      data['missed_doses'] = missedDoses;

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('child_immunization', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Immunization updated! Syncing...' : 'Immunization saved! Syncing...'),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Child Immunization Chart'),
        elevation: 0,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isDownloadingCI
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(Icons.sync, color: _ciAlreadyDownloaded ? Colors.greenAccent : Colors.white),
            tooltip: _ciAlreadyDownloaded ? 'Downloaded on $_ciDownloadedAt' : 'Sync Child Health Records',
            onPressed: _isDownloadingCI ? null : () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(_ciAlreadyDownloaded ? 'Re-Sync Child Health' : 'Sync Child Health Records'),
                  content: Text(_ciAlreadyDownloaded
                      ? 'Records were last downloaded on $_ciDownloadedAt.\n\nRe-download to get latest data?'
                      : 'Download 18,000+ child immunization records for offline use. One-time download.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start')),
                  ],
                ),
              );
              if (confirm == true) _downloadCIFromStorage();
            },
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIdentitySection(),
                    const SizedBox(height: 24),

                    // Main Chart Sections
                    _buildAgeCategory('At Birth', [
                      _vaccineInfo('BCG', 'BCG', Colors.pink.shade100),
                      _vaccineInfo('OPV0', 'OPV 0', Colors.red.shade100),
                      _vaccineInfo(
                          'HepB0', 'Hep B (Birth)', Colors.green.shade100),
                    ]),

                    _buildAgeCategory('6 Weeks', [
                      _vaccineInfo('OPV1', 'OPV 1', Colors.pink.shade100),
                      _vaccineInfo('RV1', 'RVV 1', Colors.green.shade100),
                      _vaccineInfo('IPV1', 'fIPV 1', Colors.indigo.shade100),
                      _vaccineInfo('Penta1', 'Penta 1', Colors.purple.shade100),
                      _vaccineInfo('PCV1', 'PCV 1', Colors.orange.shade100),
                    ]),

                    _buildAgeCategory('10 Weeks', [
                      _vaccineInfo('OPV2', 'OPV 2', Colors.pink.shade100),
                      _vaccineInfo('RV2', 'RVV 2', Colors.green.shade100),
                      _vaccineInfo('Penta2', 'Penta 2', Colors.purple.shade100),
                    ]),

                    _buildAgeCategory('14 Weeks', [
                      _vaccineInfo('OPV3', 'OPV 3', Colors.pink.shade100),
                      _vaccineInfo('RV3', 'RVV 3', Colors.green.shade100),
                      _vaccineInfo('IPV2', 'fIPV 2', Colors.indigo.shade100),
                      _vaccineInfo('Penta3', 'Penta 3', Colors.purple.shade100),
                      _vaccineInfo('PCV2', 'PCV 2', Colors.orange.shade100),
                    ]),

                    _buildAgeCategory('9 - 12 Months', [
                      _vaccineInfo('MR1', 'MR 1', Colors.red.shade100),
                      _vaccineInfo('JE1', 'JE 1', Colors.green.shade100),
                      _vaccineInfo('VitA1', 'Vit A 1', Colors.purple.shade100),
                      _vaccineInfo(
                          'PCVB', 'PCV Booster', Colors.orange.shade100),
                    ]),

                    _buildAgeCategory('16 - 24 Months', [
                      _vaccineInfo('MR2', 'MR 2', Colors.red.shade100),
                      _vaccineInfo('JE2', 'JE 2', Colors.green.shade100),
                      _vaccineInfo('OPVB', 'OPV Booster', Colors.pink.shade100),
                      _vaccineInfo(
                          'DPTB1', 'DPT Booster 1', Colors.green.shade50),
                    ]),

                    _buildAgeCategory('Booster Doses', [
                      _vaccineInfo('DPTB2', 'DPT Booster 2 (5-6Y)',
                          Colors.green.shade50),
                      _vaccineInfo('Td1', 'Td 1 (10Y)', Colors.orange.shade50),
                      _vaccineInfo('Td2', 'Td 2 (16Y)', Colors.orange.shade50),
                    ]),

                    _buildVitaminASection(),

                    const SizedBox(height: 24),
                    _buildMissedDosesSection(),
                    const SizedBox(height: 24),
                    _buildHealthInfoSection(),
                    const SizedBox(height: 48),
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
                  final code = _familyCodeController.text.trim();
                  if (code.isNotEmpty) _fetchMembersByFamily(code);
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

  Widget _buildAgeCategory(String title, List<_VaccineBoxInfo> vaccineInfos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.indigo.shade100),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.indigo.shade900,
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: vaccineInfos.length,
          itemBuilder: (context, index) {
            final info = vaccineInfos[index];
            return _buildVaccineField(info);
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildVaccineField(_VaccineBoxInfo info) {
    final vData = vaccines[info.key]!;
    final DateTime? date = vData['date'];
    final bool isGiven = vData['given'] == '(1) Yes';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          info.label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: !_isActionActive ? null : () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                vaccines[info.key]!['date'] = picked;
                vaccines[info.key]!['given'] = '(1) Yes';
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isGiven ? info.bgColor.withValues(alpha: 0.2) : Colors.white,
              border: Border.all(
                color: isGiven ? info.bgColor : Colors.grey.shade300,
                width: isGiven ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date != null ? DateFormat('dd-MMM-yyyy').format(date) : 'Select Date',
                    style: TextStyle(
                      fontSize: 13,
                      color: date != null ? Colors.black87 : Colors.grey.shade500,
                      fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
                if (date != null)
                  GestureDetector(
                    onTap: !_isActionActive ? null : () {
                      setState(() {
                        vaccines[info.key]!['date'] = null;
                        vaccines[info.key]!['given'] = '(0) No';
                      });
                    },
                    child: const Icon(Icons.close, size: 18, color: Colors.grey),
                  )
                else
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVitaminASection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.brown.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.brown.shade100),
          ),
          child: Text(
            'Vitamin A',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.brown.shade900,
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: 8, // VitA2 to VitA9
          itemBuilder: (context, index) {
            final doseNum = index + 2;
            return _buildVaccineField(_VaccineBoxInfo(
              'VitA$doseNum',
              'Vitamin A - Dose $doseNum',
              Colors.brown.shade100,
            ));
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMissedDosesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Missed Doses Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(120),
            border: TableBorder.all(color: Colors.grey.shade300),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.indigo.shade50),
                children: const [
                  Padding(padding: EdgeInsets.all(8), child: Text('Dose Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Missed Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Reason', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Next Appt Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Worker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
              ...List.generate(5, (index) => TableRow(
                children: [
                  _buildTableCell(index, 'name'),
                  _buildTableCell(index, 'date'),
                  _buildTableCell(index, 'reason'),
                  _buildTableCell(index, 'nextDate'),
                  _buildTableCell(index, 'worker'),
                ],
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(int rowIndex, String field) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: TextField(
        style: const TextStyle(fontSize: 12),
        enabled: _isActionActive,
        decoration: const InputDecoration(border: InputBorder.none, isDense: true),
        onChanged: (v) => missedDoses[rowIndex][field] = v,
        controller: TextEditingController(text: missedDoses[rowIndex][field])..selection = TextSelection.collapsed(offset: missedDoses[rowIndex][field]!.length),
      ),
    );
  }

  Widget _buildHealthInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Health Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField('Birth Weight (kg)', _birthWeight, enabled: _isActionActive, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: formTextField('Birth Height (cm)', _birthHeight, enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, 'Diarrhea', ['Yes', 'No'], hasDiarrhea, (v) => setState(() => hasDiarrhea = v), enabled: _isActionActive)),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, 'Breastfeeding', ['Yes', 'No'], isBreastfeeding, (v) => setState(() => isBreastfeeding = v), enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 16),
        formTextField('Remarks', _remarksController, enabled: _isActionActive, maxLines: 2),
      ],
    );
  }



  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
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
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
              fillColor: Colors.white,
              filled: true,
            ),
            child: Text(
              selectedDate == null ? 'dd-MMM-yyyy' : DateFormat('dd-MMM-yyyy').format(selectedDate),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        children: [
          formSearchField(
            'Family Code',
            _familyCodeController,
            onSearch: () {
              if (_familyCodeController.text.isNotEmpty) {
                _fetchMembersByFamily(_familyCodeController.text);
              }
            },
            isLoading: _isLoadingMembers,
            enabled: _isActionActive,
            readOnly: _familyIdReadOnly,
            focusNode: _familyCodeNode,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          formSearchableDropdown(
            context,
            'Name',
            {
              ...familyMemberNames,
              if (selectedMemberName != null && selectedMemberName!.isNotEmpty) selectedMemberName!,
            }.toList(),
            selectedMemberName,
            _onNameSelected,
            isLoading: _isLoadingMembers,
            enabled: _isActionActive,
          ),
          if (_locationVillage != null || _locationMandal != null || _locationDistrict != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text('Location', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade700, fontSize: 12)),
                  ]),
                  const SizedBox(height: 6),
                  _buildLocationRow('Village', _locationVillage),
                  _buildLocationRow('Mandal', _locationMandal),
                  _buildLocationRow('District', _locationDistrict),
                  _buildLocationRow('State', _locationState),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: formTextField('Mother Name', _motherName, enabled: _isActionActive)),
              const SizedBox(width: 12),
              Expanded(child: _buildDatePicker('DOB', dob, (v) => setState(() => dob = v))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: formTextField('Reg No.', _registrationNumber, enabled: false)),
              const SizedBox(width: 12),
              Expanded(child: formTextField('Age', _age, enabled: _isActionActive, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          _buildDatePicker('Interview Date', dateOfInterview, (v) => setState(() => dateOfInterview = v)),
        ],
      ),
    );
  }
}

class _VaccineBoxInfo {
  final String key;
  final String label;
  final Color bgColor;
  _VaccineBoxInfo(this.key, this.label, this.bgColor);
}

_VaccineBoxInfo _vaccineInfo(String key, String label, Color color) => _VaccineBoxInfo(key, label, color);
