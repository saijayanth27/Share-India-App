import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
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
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;

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

  final List<String> interviewerList = ['KIRANMAI K', 'REVATHI CH', 'RAMADEVI Y', 'LAVANYA KASPOJU', 'PUSHPA K', 'G RAMADEVI', 'BHASKAR K', 'ASHA', 'KUSUMA G', 'B JYOTHI', 'RAMADEVI G', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU'];

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
        
        memberMap[name] = data;
        allNames.add(name);
        
        if (fromFirestore) {
          // NEW: Persist to local cache for offline availability
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
    } catch (e) {
      debugPrint('Error fetching members: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }


  Future<void> _fetchExistingRecords(String familyCode, {String? entryScreen}) async {
    setState(() => _isLoadingMembers = true);
    try {
      Query query = FirebaseFirestore.instance.collection('child_immunization').where('Family_Code', isEqualTo: familyCode);
      if (entryScreen != null) query = query.where('Entry_Screen', isEqualTo: entryScreen);
      final snapshot = await query.get();
      setState(() {
        _existingRecords = snapshot.docs.map((doc) => {...(doc.data() as Map<String, dynamic>), 'id': doc.id}).toList();
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
      _age.text = baseData['Age']?.toString() ?? '';
      _motherName.text = baseData['Mother_Name']?.toString() ?? '';
      if (baseData['Date_of_Birth'] != null) {
        dob = baseData['Date_of_Birth'] is Timestamp ? (baseData['Date_of_Birth'] as Timestamp).toDate() : null;
      }
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        final snapshot = await FirebaseFirestore.instance
            .collection('child_immunization')
            .where('Family_Code', isEqualTo: fCode)
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
        debugPrint('Error fetching immunization record: $e');
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
    selectedFamilyCode = d['Family_Code'] ?? d['Family_code'] ?? d['Family_ID'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
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
    interviewersName = d['Interviewer_s_Name'];

    // Map vaccine data
    void mapVaccine(String key, String ynKey, String dtKey, String byKey) {
      vaccines[key]!['given'] = d[ynKey] ?? '(0) No';
      final val = d[dtKey];
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
      vaccines[key]!['by'] = d[byKey] ?? '(0) RHC';
    }

    mapVaccine('BCG', 'BCG_Given_Y_N', 'BCG_Dt', 'BCG_Given_By');
    mapVaccine('OPV0', 'OPVO_Given_Y_N', 'OPV0_Dt', 'OPVO_Given_By');
    mapVaccine('HepB0', 'HepB0_Given_Y_N', 'HepB0_Dt', 'HepB0_Given_By');

    mapVaccine('OPV1', 'OPVO_Given_By1', 'OPV_1_Dt', 'OPV1_Given_By');
    mapVaccine('RV1', 'RV1_Given_Y_N', 'RV1_Dt', 'RV1_Given_By');
    mapVaccine('IPV1', 'IPV1_Given_Y_N', 'IPV1_Dt', 'IPV1_Given_By');
    mapVaccine('Penta1', 'DPT1_Given_Y_N', 'DPT1_Dt3', 'DPT1_Given_Y_N1'); // Reusing existing DPT1 field
    mapVaccine('PCV1', 'PCV1_Given_Y_N', 'PCV1_Dt', 'PCV1_Given_By');

    mapVaccine('OPV2', 'OPV2_Given_yes_no', 'OPV2_Dt', 'Drop_OPV2_Given_By');
    mapVaccine('RV2', 'RV2_Given_Y_N', 'RV2_Dt', 'RV2_Given_By');
    mapVaccine('Penta2', 'DPT2_Given_Y_N2', 'DPT2_Dt', 'DPT2_Given_By'); // Reusing existing DPT2 field

    mapVaccine('OPV3', 'OPV3_Given_by_Y_N', 'OPV3_Dt', 'OPV2_Given_By2');
    mapVaccine('RV3', 'RV3_Given_Y_N', 'RV3_Dt', 'RV3_Given_By');
    mapVaccine('IPV2', 'IPV2_Given_Y_N', 'IPV2_Dt', 'IPV2_Given_By');
    mapVaccine('Penta3', 'DPT3_Given_Y_N3', 'DPT3_Dt', 'DPT3_Given_By'); // Reusing existing DPT3 field
    mapVaccine('PCV2', 'PCV2_Given_Y_N', 'PCV2_Dt', 'PCV2_Given_By');

    mapVaccine('MR1', 'Measles1', 'Measles_Dt', 'Measles_Given_Y_N'); // Reusing existing Measles field
    mapVaccine('JE1', 'JE1_Given_Y_N', 'JE1_Dt', 'JE1_Given_By');
    mapVaccine('VitA1', 'VitA1_Given_Y_N', 'VitA1_Dt', 'VitA1_Given_By');
    mapVaccine('PCVB', 'PCVB_Given_Y_N', 'PCVB_Dt', 'PCVB_Given_By');

    mapVaccine('MR2', 'MR2_Given_Y_N', 'MR2_Dt', 'MR2_Given_By');
    mapVaccine('JE2', 'JE2_Given_Y_N', 'JE2_Dt', 'JE2_Given_By');
    mapVaccine('OPVB', 'OPV_B_Given_Y_N', 'OPV_B_Dt', 'OPV2_Given_By1'); // Reusing existing OPVB field
    mapVaccine('DPTB1', 'DPTB_Given_Y_N', 'DPT_B_Dt', 'DPTB_Given_Y_N1'); // Reusing existing DPTB field

    mapVaccine('DPTB2', 'DPTB2_Given_Y_N', 'DPTB2_Dt', 'DPTB2_Given_By');
    mapVaccine('Td1', 'DT_Given_Y_N', 'DT_Dt', 'DT_Given_By'); // Reusing existing DT field for Td1
    mapVaccine('Td2', 'Td2_Given_Y_N', 'Td2_Dt', 'Td2_Given_By');

    mapVaccine('VitA2', 'VitA2_Given_Y_N', 'VitA2_Dt', 'VitA2_Given_By');
    mapVaccine('VitA3', 'VitA3_Given_Y_N1', 'VitA3_Dt', 'V');
    mapVaccine('VitA4', 'Vita4_Given_Y_N', 'VitA4_Dt', 'VitA4_Given_By');
    mapVaccine('VitA5', 'VitA5_Given_Y_N', 'VitA5_Dt', 'VitA5_Given_By');
    mapVaccine('VitA6', 'VitA6_Given_Y_N', 'VitA6_Dt', 'VitA6_Given_By');
    mapVaccine('VitA7', 'VitA7_Given_Y_N', 'VitA7_Dt', 'VitA7_Given_By');
    mapVaccine('VitA8', 'VitA8_Given_Y_N', 'VitA8_Dt', 'VitA8_Given_By');
    mapVaccine('VitA9', 'VitA9_Given_Y_N', 'VitA9_Dt', 'VitA9_Given_By');

    _remarksController.text = d['Remarks1'] ?? d['Remarks'] ?? '';
    _birthWeight.text = d['Birth_Weight']?.toString() ?? '';
    _birthHeight.text = d['Birth_Height']?.toString() ?? '';
    hasDiarrhea = d['Diarrhea'];
    isBreastfeeding = d['Breastfeeding'];

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
      _registrationNumber.clear();
      _familyCodeController.clear();
      _nameController.clear();
      _motherName.clear();
      _remarksController.clear();
      _birthWeight.clear();
      _birthHeight.clear();
      selectedFamilyCode = null;
      selectedMemberName = null;
      _age.clear();
      dateOfInterview = DateTime.now();
      dob = null;
      selectEntryScreen = null;
      interviewersName = null;
      hasDiarrhea = null;
      isBreastfeeding = null;
      familyMemberNames = [];
      _existingRecords = [];
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

      // 2. Background Sync (Non-blocking)
      _performImmunizationSync(data);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _performImmunizationSync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('child_immunization').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('child_immunization').add(data);
      }
    } catch (e) {
      debugPrint('Immunization Background Sync Error: $e');
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
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          if (code.isNotEmpty) _fetchMembersByFamily(code);
                        });
                      },
                      onCancel: _resetForm,
                      onExit: () => Navigator.pop(context),
                      isSaving: _isSaving,
                    ),
                    const SizedBox(height: 16),
                    _buildIdentitySection(),
                    const SizedBox(height: 24),
                    
                    // Main Chart Sections
                    _buildAgeCategory('At Birth', [
                      _vaccineInfo('BCG', 'BCG', Colors.pink.shade100),
                      _vaccineInfo('OPV0', 'OPV 0', Colors.red.shade100),
                      _vaccineInfo('HepB0', 'Hep B (Birth)', Colors.green.shade100),
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
                      _vaccineInfo('PCVB', 'PCV Booster', Colors.orange.shade100),
                    ]),

                    _buildAgeCategory('16 - 24 Months', [
                      _vaccineInfo('MR2', 'MR 2', Colors.red.shade100),
                      _vaccineInfo('JE2', 'JE 2', Colors.green.shade100),
                      _vaccineInfo('OPVB', 'OPV Booster', Colors.pink.shade100),
                      _vaccineInfo('DPTB1', 'DPT Booster 1', Colors.green.shade50),
                    ]),

                    _buildAgeCategory('Booster Doses', [
                      _vaccineInfo('DPTB2', 'DPT Booster 2 (5-6Y)', Colors.green.shade50),
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
    );
  }

  Widget _buildAgeCategory(String title, List<_VaccineBoxInfo> vaccineInfos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: vaccineInfos.map((info) => _buildVaccineBox(info)).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildVaccineBox(_VaccineBoxInfo info) {
    final vData = vaccines[info.key]!;
    final bool isGiven = vData['given'] == '(1) Yes';
    
    return InkWell(
      onTap: () => _showVaccineEditDialog(info.key),
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
          color: isGiven ? info.bgColor.withOpacity(0.5) : Colors.white,
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: info.bgColor,
              child: Text(
                info.label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isGiven && vData['date'] != null)
                      Text(
                        DateFormat('dd/MM/yy').format(vData['date']),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      )
                    else
                      Text(
                        '_____',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      isGiven ? 'Given' : 'Due',
                      style: TextStyle(fontSize: 10, color: isGiven ? Colors.green.shade700 : Colors.red),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVaccineEditDialog(String key) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Update $key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              formSearchableDropdown(context, 'Given?', ['(1) Yes', '(0) No'], vaccines[key]!['given'], (v) {
                setState(() => vaccines[key]!['given'] = v);
                setDialogState(() {});
              }),
              const SizedBox(height: 16),
              _buildDatePicker('Date', vaccines[key]!['date'], (v) {
                setState(() => vaccines[key]!['date'] = v);
                setDialogState(() {});
              }),
              const SizedBox(height: 16),
              formSearchableDropdown(context, 'Given By', ['(0) RHC', '(1) PVT', '(2) GOVT'], vaccines[key]!['by'], (v) {
                setState(() => vaccines[key]!['by'] = v);
                setDialogState(() {});
              }),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  Widget _buildVitaminASection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(color: Colors.brown.shade100, borderRadius: BorderRadius.circular(4)),
          child: const Text('Vitamin A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 2; i <= 9; i++)
              _buildVaccineBox(_VaccineBoxInfo('VitA$i', 'Vit A - $i', Colors.brown.shade50)),
          ],
        ),
        const SizedBox(height: 20),
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
            Expanded(child: formTextField('Birth Weight (kg)', _birthWeight, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: formTextField('Birth Height (cm)', _birthHeight)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, 'Diarrhea', ['Yes', 'No'], hasDiarrhea, (v) => setState(() => hasDiarrhea = v))),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, 'Breastfeeding', ['Yes', 'No'], isBreastfeeding, (v) => setState(() => isBreastfeeding = v))),
          ],
        ),
        const SizedBox(height: 16),
        formTextField('Remarks', _remarksController, maxLines: 2),
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
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) onPicked(picked);
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
          Row(
            children: [
              Expanded(
                child: formSearchField(
                  'Family Code',
                  _familyCodeController,
                  onSearch: () {
                    if (_familyCodeController.text.isNotEmpty) {
                      _fetchMembersByFamily(_familyCodeController.text);
                    }
                  },
                  isLoading: _isLoadingMembers,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: formSearchableDropdown(
                  context,
                  'Name',
                  familyMemberNames,
                  selectedMemberName,
                  _onNameSelected,
                  isLoading: _isLoadingMembers,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: formTextField('Mother Name', _motherName)),
              const SizedBox(width: 12),
              Expanded(child: _buildDatePicker('DOB', dob, (v) => setState(() => dob = v))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: formTextField('Reg No.', _registrationNumber, enabled: false)),
              const SizedBox(width: 12),
              Expanded(child: formTextField('Age', _age, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _buildDatePicker('Interview Date', dateOfInterview, (v) => setState(() => dateOfInterview = v))),
            ],
          ),
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
