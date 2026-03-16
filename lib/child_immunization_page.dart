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
  final _familyCodeController = TextEditingController();
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

  // Vaccine Data Map
  Map<String, Map<String, dynamic>> vaccines = {
    'BCG': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'DPT1': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'DPT2': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'DPT3': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'DPTB': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'OPV0': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'OPV1': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'OPV2': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'OPV3': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'OPVB': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'Measles': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'HepB1': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'HepB2': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'HepB3': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'VitA1': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'VitA2': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'VitA3': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'VitA4': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'VitAB': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
    'DT': {'given': '(0) No', 'date': null, 'by': '(0) RHC'},
  };

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
    mapVaccine('DPT1', 'DPT1_Given_Y_N', 'DPT1_Dt3', 'DPT1_Given_Y_N1');
    mapVaccine('DPT2', 'DPT2_Given_Y_N2', 'DPT2_Dt', 'DPT2_Given_By');
    mapVaccine('DPT3', 'DPT3_Given_Y_N3', 'DPT3_Dt', 'DPT3_Given_By');
    mapVaccine('DPTB', 'DPTB_Given_Y_N', 'DPT_B_Dt', 'DPTB_Given_Y_N1');
    mapVaccine('OPV0', 'OPVO_Given_Y_N', 'OPV0_Dt', 'OPVO_Given_By');
    mapVaccine('OPV1', 'OPVO_Given_By1', 'OPV_1_Dt', 'OPV1_Given_By');
    mapVaccine('OPV2', 'OPV2_Given_yes_no', 'OPV2_Dt', 'Drop_OPV2_Given_By');
    mapVaccine('OPV3', 'OPV3_Given_by_Y_N', 'OPV3_Dt', 'OPV2_Given_By2');
    mapVaccine('OPVB', 'OPV_B_Given_Y_N', 'OPV_B_Dt', 'OPV2_Given_By1');
    mapVaccine('Measles', 'Measles1', 'Measles_Dt', 'Measles_Given_Y_N');
    mapVaccine('HepB1', 'HepB1_Given_Y_N', 'HepB1_Dt', 'HepB1_Given_By');
    mapVaccine('HepB2', 'HepB2_Given_Y_N', 'HepB2_Dt', 'HepB2');
    mapVaccine('HepB3', 'HepB3_Given_Y_N', 'HepB3_Dt', 'HepB3_Given_By');
    mapVaccine('VitA1', 'VitA1_Given_Y_N', 'VitA1_Dt', 'VitA1_Given_By');
    mapVaccine('VitA2', 'VitA2_Given_Y_N', 'VitA2_Dt', 'VitA2_Given_By');
    mapVaccine('VitA3', 'VitA3_Given_Y_N1', 'VitA3_Dt', 'V');
    mapVaccine('VitA4', 'Vita4_Given_Y_N', 'VitA4_Dt', 'VitA4_Given_By');
    mapVaccine('VitAB', 'VitAB_Given_Y_N', 'VitAB_Dt1', 'VitAB_Given_By');
    mapVaccine('DT', 'DT_Given_Y_N', 'DT_Dt', 'DT_Given_By');

    _remarksController.text = d['Remarks1'] ?? d['Remarks'] ?? '';
    _birthWeight.text = d['Birth_Weight']?.toString() ?? '';
    _birthHeight.text = d['Birth_Height']?.toString() ?? '';
    hasDiarrhea = d['Diarrhea'];
    isBreastfeeding = d['Breastfeeding'];

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

      // BCG
      data['BCG_Given_Y_N'] = vaccines['BCG']!['given'];
      data['BCG_Dt'] = vaccines['BCG']!['date'] != null ? Timestamp.fromDate(vaccines['BCG']!['date']) : null;
      data['BCG_Given_By'] = vaccines['BCG']!['by'];

      // DPT
      data['DPT1_Given_Y_N'] = vaccines['DPT1']!['given'];
      data['DPT1_Dt3'] = vaccines['DPT1']!['date'] != null ? Timestamp.fromDate(vaccines['DPT1']!['date']) : null;
      data['DPT1_Given_Y_N1'] = vaccines['DPT1']!['by'];
      data['DPT2_Given_Y_N2'] = vaccines['DPT2']!['given'];
      data['DPT2_Dt'] = vaccines['DPT2']!['date'] != null ? Timestamp.fromDate(vaccines['DPT2']!['date']) : null;
      data['DPT2_Given_By'] = vaccines['DPT2']!['by'];
      data['DPT3_Given_Y_N3'] = vaccines['DPT3']!['given'];
      data['DPT3_Dt'] = vaccines['DPT3']!['date'] != null ? Timestamp.fromDate(vaccines['DPT3']!['date']) : null;
      data['DPT3_Given_By'] = vaccines['DPT3']!['by'];
      data['DPTB_Given_Y_N'] = vaccines['DPTB']!['given'];
      data['DPT_B_Dt'] = vaccines['DPTB']!['date'] != null ? Timestamp.fromDate(vaccines['DPTB']!['date']) : null;
      data['DPTB_Given_Y_N1'] = vaccines['DPTB']!['by'];

      // OPV
      data['OPVO_Given_Y_N'] = vaccines['OPV0']!['given'];
      data['OPV0_Dt'] = vaccines['OPV0']!['date'] != null ? Timestamp.fromDate(vaccines['OPV0']!['date']) : null;
      data['OPVO_Given_By'] = vaccines['OPV0']!['by'];
      data['OPVO_Given_By1'] = vaccines['OPV1']!['given'];
      data['OPV_1_Dt'] = vaccines['OPV1']!['date'] != null ? Timestamp.fromDate(vaccines['OPV1']!['date']) : null;
      data['OPV1_Given_By'] = vaccines['OPV1']!['by'];
      data['OPV2_Given_yes_no'] = vaccines['OPV2']!['given'];
      data['OPV2_Dt'] = vaccines['OPV2']!['date'] != null ? Timestamp.fromDate(vaccines['OPV2']!['date']) : null;
      data['Drop_OPV2_Given_By'] = vaccines['OPV2']!['by'];
      data['OPV3_Given_by_Y_N'] = vaccines['OPV3']!['given'];
      data['OPV3_Dt'] = vaccines['OPV3']!['date'] != null ? Timestamp.fromDate(vaccines['OPV3']!['date']) : null;
      data['OPV2_Given_By2'] = vaccines['OPV3']!['by'];
      data['OPV_B_Given_Y_N'] = vaccines['OPVB']!['given'];
      data['OPV_B_Dt'] = vaccines['OPVB']!['date'] != null ? Timestamp.fromDate(vaccines['OPVB']!['date']) : null;
      data['OPV2_Given_By1'] = vaccines['OPVB']!['by'];

      // Measles
      data['Measles1'] = vaccines['Measles']!['given'];
      data['Measles_Dt'] = vaccines['Measles']!['date'] != null ? Timestamp.fromDate(vaccines['Measles']!['date']) : null;
      data['Measles_Given_Y_N'] = vaccines['Measles']!['by'];

      // HepB
      data['HepB1_Given_Y_N'] = vaccines['HepB1']!['given'];
      data['HepB1_Dt'] = vaccines['HepB1']!['date'] != null ? Timestamp.fromDate(vaccines['HepB1']!['date']) : null;
      data['HepB1_Given_By'] = vaccines['HepB1']!['by'];
      data['HepB2_Given_Y_N'] = vaccines['HepB2']!['given'];
      data['HepB2_Dt'] = vaccines['HepB2']!['date'] != null ? Timestamp.fromDate(vaccines['HepB2']!['date']) : null;
      data['HepB2'] = vaccines['HepB2']!['by'];
      data['HepB3_Given_Y_N'] = vaccines['HepB3']!['given'];
      data['HepB3_Dt'] = vaccines['HepB3']!['date'] != null ? Timestamp.fromDate(vaccines['HepB3']!['date']) : null;
      data['HepB3_Given_By'] = vaccines['HepB3']!['by'];

      // VitA
      data['VitA1_Given_Y_N'] = vaccines['VitA1']!['given'];
      data['VitA1_Dt'] = vaccines['VitA1']!['date'] != null ? Timestamp.fromDate(vaccines['VitA1']!['date']) : null;
      data['VitA1_Given_By'] = vaccines['VitA1']!['by'];
      data['VitA2_Given_Y_N'] = vaccines['VitA2']!['given'];
      data['VitA2_Dt'] = vaccines['VitA2']!['date'] != null ? Timestamp.fromDate(vaccines['VitA2']!['date']) : null;
      data['VitA2_Given_By'] = vaccines['VitA2']!['by'];
      data['VitA3_Given_Y_N1'] = vaccines['VitA3']!['given'];
      data['VitA3_Dt'] = vaccines['VitA3']!['date'] != null ? Timestamp.fromDate(vaccines['VitA3']!['date']) : null;
      data['V'] = vaccines['VitA3']!['by'];
      data['Vita4_Given_Y_N'] = vaccines['VitA4']!['given'];
      data['VitA4_Dt'] = vaccines['VitA4']!['date'] != null ? Timestamp.fromDate(vaccines['VitA4']!['date']) : null;
      data['VitA4_Given_By'] = vaccines['VitA4']!['by'];
      data['VitAB_Given_Y_N'] = vaccines['VitAB']!['given'];
      data['VitAB_Dt1'] = vaccines['VitAB']!['date'] != null ? Timestamp.fromDate(vaccines['VitAB']!['date']) : null;
      data['VitAB_Given_By'] = vaccines['VitAB']!['by'];

      // DT
      data['DT_Given_Y_N'] = vaccines['DT']!['given'];
      data['DT_Dt'] = vaccines['DT']!['date'] != null ? Timestamp.fromDate(vaccines['DT']!['date']) : null;
      data['DT_Given_By'] = vaccines['DT']!['by'];

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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Child Immunization'), elevation: 0),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                            _fetchExistingRecords(code, entryScreen: selectEntryScreen);
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
                    buildSectionCard(
                      context: context,
                      title: 'Immunization Details',
                      icon: Icons.vaccines_outlined,
                      children: [
                        formSearchableDropdown(context, 'Select Entry Screen', ['BCG', 'DPT', 'OPV', 'Measles', 'HepB', 'Vitamin A', 'DT', 'Remarks'], selectEntryScreen, (v) {
                          setState(() { selectEntryScreen = v; });
                          if (selectedFamilyCode != null) _fetchExistingRecords(selectedFamilyCode!, entryScreen: v);
                        }),
                        const SizedBox(height: 16),
                        _buildDatePicker('DOB', dob, (v) => setState(() => dob = v)),
                        const SizedBox(height: 16),
                        _buildVaccineSections(),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildVaccineSections() {
    if (selectEntryScreen == null) return const SizedBox.shrink();

    switch (selectEntryScreen) {
      case 'BCG':
        return _buildVaccineGroup('BCG', ['BCG']);
      case 'DPT':
        return _buildVaccineGroup('DPT', ['DPT1', 'DPT2', 'DPT3', 'DPTB']);
      case 'OPV':
        return _buildVaccineGroup('OPV', ['OPV0', 'OPV1', 'OPV2', 'OPV3', 'OPVB']);
      case 'Measles':
        return _buildVaccineGroup('Measles', ['Measles']);
      case 'HepB':
        return _buildVaccineGroup('HepB', ['HepB1', 'HepB2', 'HepB3']);
      case 'Vitamin A':
        return _buildVaccineGroup('Vitamin A', ['VitA1', 'VitA2', 'VitA3', 'VitA4', 'VitAB']);
      case 'DT':
        return _buildVaccineGroup('DT', ['DT']);
      case 'Remarks':
        return Column(
          children: [
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
            formTextField('Remarks', _remarksController, maxLines: 3),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildVaccineGroup(String title, List<String> doses) {
    return buildSectionCard(
      context: context,
      title: title,
      icon: Icons.vaccines_outlined,
      children: [
        ...doses.map((dose) => _buildVaccineDoseRow(dose)),
      ],
    );
  }

  Widget _buildVaccineDoseRow(String doseLabel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(doseLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: formSearchableDropdown(
                  context,
                  'Given?',
                  ['(1) Yes', '(0) No'],
                  vaccines[doseLabel]!['given'],
                  (v) => setState(() => vaccines[doseLabel]!['given'] = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDatePicker(
                  'Date',
                  vaccines[doseLabel]!['date'],
                  (v) => setState(() => vaccines[doseLabel]!['date'] = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          formSearchableDropdown(
            context,
            'Given By',
            ['(0) RHC', '(1) PVT', '(2) GOVT'],
            vaccines[doseLabel]!['by'],
            (v) => setState(() => vaccines[doseLabel]!['by'] = v),
          ),
        ],
      ),
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
    return buildSectionCard(
      context: context,
      title: 'Member Identity',
      icon: Icons.person_outline,
      children: [
        formTextField(
          'Registration Number',
          _registrationNumber,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        formSearchField(
          'Family Code',
          _familyCodeController,
          onSearch: () {
            if (_familyCodeController.text.isNotEmpty) {
              _fetchMembersByFamily(_familyCodeController.text);
              _fetchExistingRecords(_familyCodeController.text, entryScreen: selectEntryScreen);
            }
          },
          isLoading: _isLoadingMembers,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
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
        formTextField('Mother Name', _motherName),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField(
              'Age',
              _age,
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Interview Date', dateOfInterview, (v) => setState(() => dateOfInterview = v))),
          ],
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(context, 
          'Interviewer Name',
          interviewerList,
          interviewersName,
          (v) => setState(() => interviewersName = v),
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
      ],
    );
  }
}
