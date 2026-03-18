import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

class MedicinesEntryPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const MedicinesEntryPage({super.key, this.existingData, this.docId});

  @override
  State<MedicinesEntryPage> createState() => _MedicinesEntryPageState();
}

class _MedicinesEntryPageState extends State<MedicinesEntryPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;

  // --- Main Form Controllers & State ---
  String? selectedFamilyCode;
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();
  String? selectedGender;
  DateTime? selectedDate = DateTime.now();
  String? selectedInterviewer;
  String? selectedMemberName;
  final _ageController = TextEditingController();
  String? selectedSource;
  final _otherSourceController = TextEditingController();
  final _doctorNameController = TextEditingController();
  final _remarksController = TextEditingController();

  // --- Subform State (Prescription List) ---
  List<Map<String, dynamic>> prescriptionList = [];

  // Dropdown Options
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};

  final List<String> interviewers = ["KIRANMAI K", "LAVANYA KASPOJU", "RAMADEVI Y", "REVATHI CH"];
  final List<String> messageSources = ["104", "COMPANY", "GOVT", "Other", "PVT", "TETRA"];
  final List<String> dosagesList = ["BD", "OD", "TDS"];
  final List<String> timeSlots = ["AF", "BF"];

  final Map<String, int> medicineForMap = {
    "Diabetes": 1,
    "Blood Pressure & Heart Health": 2,
    "Glaucoma & Eye Care": 3,
    "Neuro Health & Mental": 4,
    "Gastrointestinal Health": 5,
    "Vitamins & Nutritional Health": 6,
    "Others": 7,
  };
  late final List<String> medicineCategories;

  // Static hardcoded medicines grouped by category ID
  final Map<int, List<String>> staticMedicines = {
    1: [
      "DAONIL 2.5 Tab", "DAONIL 5 Tab", "GLICLAZIDE 80 Tab", "GLIMEPIRIDE 0.5 Tab", "GLIMEPIRIDE 1 MG TAB",
      "GLIMEPIRIDE 2 MG TAB", "GLIMEPIRIDE 4 MG TAB", "GLIMEPIRIDE 500 Tab", "GLIPIZIDE 10 MG TAB",
      "GLIPIZIDE 2.5 Tab", "GLIPIZIDE 5 MG TAB", "GLYBURIDE 1.25 MG TAB", "GLYBURIDE 2.5 MG TAB",
      "GLYBURIDE 5 MG TAB", "GLYBURIDE(2.5 MG) + METFORMIN HCL(500 MG) TAB",
      "GLYBURIDE(5 MG) + METFORMIN HCL(500 MG) TAB", "HUMAN MIXTARD 30/70 U INJ", "HUMAN MIXTARD-50/50 U INJ",
      "HUMAN RECOMBINANT DNA INSULIN 40IU=1ML Inj", "INSULIN MIXTARD 30/70 Inj", "METFORMIN 250MG Tab",
      "METFORMIN HCL 1000 MG TAB", "METFORMIN HCL 500 MG TAB", "METFORMIN HCL 850 MG TAB",
      "METFORMIN HCL SR 500 MG TAB", "METFORMIN(500MG)+GLIMEPIRIDE(2MG) TAB",
      "METFORMIN(500MG)+GLIMIPERIDE(1MG) TAB", "METFORMIN+GLICLAZIDE 500+60 Tab",
      "METFORMIN+GLIMIPRIDE+VOGLIBOSE\u007f 500+2+0.2MG Tab", "PIOGLITAZONE 15 MG TAB", "PIOGLITAZONE 30 MG TAB",
      "PIOGLITAZONE 45 MG TAB", "SEMI DAONIL 2.5 MG TAB", "SEMI DAONIL 5 MG TAB", "VOGLIBOSE 0.2 Tab"
    ],
    2: [
      "AMLODIPINE BESYLATE 10 MG TAB", "AMLODIPINE BESYLATE 2.5 MG TAB", "AMLODIPINE BESYLATE 5 MG TAB",
      "ATENOLOL 100 MG TAB", "ATENOLOL 25 MG TAB", "ATENOLOL 50 MG TAB", "ATENOLOL+AMLODEPINE 50+5MG Tab",
      "ATORVASTATIN 10MG Tab", "BENAZEPRIL HCL 10 MG TAB", "BENAZEPRIL HCL 20 MG TAB", "BENAZEPRIL HCL 40 MG TAB",
      "BISOPROLOL FUMARATE 10 MG TAB", "BISOPROLOL FUMARATE 5 MG TAB", "BISOPROLOL FUMARATE/HCTZ 10-6.25 MG TAB",
      "BISOPROLOL FUMARATE/HCTZ 2.5-6.25 MG TAB", "BISOPROLOL FUMARATE/HCTZ 5-6.25 MG TAB", "CARVEDILOL 12.5 MG TAB",
      "CARVEDILOL 25 MG TAB", "CARVEDILOL 3.125 MG TAB", "CARVEDILOL 6.25 MG TAB", "CHLORTHALIDONE 12.5 Syp",
      "CHLORTHALIDONE 25 Tab", "CILINDIPINE 10MG Tab", "CILINDIPINE 5 Tab", "CLONIDINE HCL 0.1 MG TAB",
      "CLONIDINE HCL 0.2 MG TAB", "CLONIDINE HCL 0.3 MG TAB", "CLOPIDOGRIL 75MG Tab", "DILTIAZEM HCL 30 MG TAB",
      "ECOSPRIN 150MG Tab", "ENALAPRIL MALEATE 10 MG TAB", "ENALAPRIL MALEATE 2.5 MG TAB",
      "ENALAPRIL MALEATE 20 MG TAB", "ENALAPRIL MALEATE 5 MG TAB", "FOSINOPRIL SODIUM 10 MG TAB",
      "FOSINOPRIL SODIUM 20 MG TAB", "FOSINOPRIL SODIUM 40 MG TAB", "FUROSEMIDE 20 MG TAB", "FUROSEMIDE 40 MG TAB",
      "FUROSEMIDE 80 MG TAB", "GEMFIBROZIL 600 MG TAB", "HYDRALAZINE HCL 10 MG TAB", "HYDRALAZINE HCL 25 MG TAB",
      "HYDRALAZINE HCL 50 MG TAB", "HYDROCHLOROTHIAZIDE 1 Tab", "INDAPAMIDE 1.25 MG TAB", "INDAPAMIDE 2.5 MG TAB",
      "ISOSORTITRATE MONONITRATE 10MG Tab", "LISINOPRIL 10 MG TAB", "LISINOPRIL 2.5 MG TAB", "LISINOPRIL 20 MG TAB",
      "LISINOPRIL 30 MG TAB", "LISINOPRIL 40 MG TAB", "LISINOPRIL 5 MG TAB", "LISINOPRIL-HCTZ 10-12.5 MG TAB",
      "LISINOPRIL-HCTZ 20-12.5 MG TAB", "LISINOPRIL-HCTZ 20-25 MG TAB", "LOSARTAN 100 MG TAB", "LOSARTAN 25 MG TAB",
      "LOSARTAN 50 MG TAB", "LOSARTAN/HCTZ 50-12.5 MG TAB", "LOVASTATIN 10 MG TAB", "LOVASTATIN 20 MG TAB",
      "LOVASTATIN 40 MG TAB", "MET XL 12.5 Tab", "MET XL 25 TTab", "MET XL 25 Tab", "MET XL 50 MG TAB",
      "MET-XL AM 25MG/5MG Tab", "METOPROLOL TARTRATE 100 MG TAB", "METOPROLOL TARTRATE 25 MG TAB",
      "METOPROLOL TARTRATE 50 MG TAB", "METOPROLOL XL 50 MG TAB", "NEBIVOLOL+AMLODIPINE 5+5 Tab",
      "NICARDIA RETARD 10 MG TAB", "NICARDIA RETARD 20 MG TAB", "NICARDIA RETARD 30 MG TAB",
      "NIFEDIPINE SR 10 MG TAB", "NIFEDIPINE SR 30 MG TAB", "OLMESARTAN 10 Tab", "OLMESARTAN 20MG Tab",
      "OLMESARTAN(40 MG) + HCT (17.5 MG) TAB", "OLMESARTAN(40MG) 40MG Tab", "PERINDOTRIL 4MG Tab",
      "PERINDOTRIL+AMLODEPINE 4+5MG Tab", "PRAZOSIN HCL 1 MG CAP", "QUINAPRIL HCL 10 MG TAB",
      "QUINAPRIL HCL 20 MG TAB", "QUINAPRIL HCL 40 MG TAB", "QUINAPRIL HCL 5 MG TAB", "RAMIPRIL 10 MG CAP",
      "RAMIPRIL 2.5 MG CAP", "RAMIPRIL 2.5MG Tab", "RAMIPRIL 5 MG CAP", "SIMVASTATIN 10 MG TAB",
      "SIMVASTATIN 20 MG TAB", "SIMVASTATIN 40 MG TAB", "SIMVASTATIN 5 MG TAB", "SIMVASTATIN 80 MG TAB",
      "SOTALOL HCL 80 MG TAB", "SPIRONOLACTONE 25 MG TAB", "SPIRONOLACTONE 50 MG TAB",
      "TELMAKIND(40 MG) + BETA(50 MG) TAB", "TELMISARTAN(40 MG) + AMLODIPINE(5 MG) TAB",
      "TELMISARTAN(40 MG) + HCTZ(12.5) TAB", "TELMISARTAN+METOPROLOL 40+12.5MG Tab", "TEMISARTAN 20 MG TAB",
      "TEMISARTAN 40 MG TAB", "TEMISARTAN 80 MG TAB", "TERAZOSIN HCL 1 MG CAP", "TERAZOSIN HCL 10 MG CAP",
      "TERAZOSIN HCL 2 MG CAP", "TERAZOSIN HCL 5 MG CAP", "TORSEMIDE 10 MG TAB", "TORSEMIDE 20 MG TAB",
      "TRIAMTERENE/HCTZ 37.5-25 MG CAP", "TRIAMTERENE/HCTZ 37.5-25 MG TAB", "TRIAMTERENE/HCTZ 75/50 MG TAB",
      "VERAPAMIL HCL 120 MG TAB", "VERAPAMIL HCL 180 MG TAB", "VERAPAMIL HCL 240 MG TAB", "WARFARIN SODIUM 1 MG TAB",
      "WARFARIN SODIUM 10 MG TAB", "WARFARIN SODIUM 2 MG TAB", "WARFARIN SODIUM 2.5 MG TAB",
      "WARFARIN SODIUM 3 MG TAB", "WARFARIN SODIUM 4 MG TAB", "WARFARIN SODIUM 5 MG TAB", "WARFARIN SODIUM 6 MG TAB",
      "WARFARIN SODIUM 7.5 MG TAB"
    ],
    3: [
      "BRIMONIDINE TARTRATE 0.2 % DROPS", "DICLOFENAC SODIUM 0.1 % DROPS", "FLURBIPROFEN SODIUM 0.03 % DROPS",
      "LEVOBUNOLOL HCL 0.5 % DROPS", "TIMOLOL MALEATE 0.25 % DROPS", "TIMOLOL MALEATE 0.5 % DROPS"
    ],
    4: [
      "BUSPIRONE HCL 10 MG TAB", "BUSPIRONE HCL 15 MG TAB", "BUSPIRONE HCL 5 MG TAB", "CITALOPRAM HBR 10 MG TAB",
      "CITALOPRAM HBR 20 MG TAB", "CITALOPRAM HBR 40 MG TAB", "DONEPEZIL HCL 10 MG TAB", "DONEPEZIL HCL 5 MG TAB",
      "DOXEPIN HCL 10 MG CAP", "FLUOXETINE HCL 10 MG CAP", "FLUOXETINE HCL 20 MG CAP", "FLUOXETINE HCL 40 MG CAP",
      "GUANFACINE HCL 1 MG TAB", "GUANFACINE HCL 2 MG TAB", "HYDROXYZINE HCL 10 MG TAB", "HYDROXYZINE HCL 25 MG TAB",
      "HYDROXYZINE HCL 50 MG TAB", "HYDROXYZINE PAMOATE 25 MG CAP", "HYDROXYZINE PAMOATE 50 MG CAP",
      "MIRTAZAPINE 30 MG TAB", "NORTRIPTYLINE HCL 10 MG CAP", "NORTRIPTYLINE HCL 25 MG CAP",
      "NORTRIPTYLINE HCL 50 MG CAP", "PAROXETINE HCL 10 MG TAB", "PAROXETINE HCL 20 MG TAB",
      "PAROXETINE HCL 30 MG TAB", "PAROXETINE HCL 40 MG TAB", "SERTRALINE HCL 100 MG TAB", "SERTRALINE HCL 25 MG TAB",
      "SERTRALINE HCL 50 MG TAB", "TRAZODONE HCL 100 MG TAB", "TRAZODONE HCL 150 MG TAB", "TRAZODONE HCL 50 MG TAB",
      "TRIHEXYPHENIDYL HCL 2 MG TAB"
    ],
    5: [
      "DICYCLOMINE HCL 10 MG CAP", "DICYCLOMINE HCL 20 MG TAB", "FAMOTIDINE 20 MG TAB", "FAMOTIDINE 40 MG TAB",
      "METOCLOPRAMIDE HCL 10 MG TAB", "METOCLOPRAMIDE HCL 5 MG TAB", "PANTAPROZOLE 40MG Tab",
      "PROMETHAZINE HCL 12.5 MG TAB", "PROMETHAZINE HCL 25 MG TAB", "RANITIDINE HCL 300 MG TAB"
    ],
    6: [
      "FERROUS SULFATE 15 MG/ML DROPS", "FERROUS SULFATE 325 MG TAB", "FOLIC ACID 1 MG TAB", "MATILDA PLUS NA Cap",
      "METHYLCOBALAMINE 1500MCG Cap", "PANTAPRAZOLE 40MG Tab", "POTASSIUM CHLORIDE 20 MEQ/15 ML LIQUID",
      "PREGAB.M 75MG Tab", "PRENAPLUS TAB", "PRENATABS FA TAB", "PRENATAL AD TAB", "PRENATAL PLUS TAB 30 90",
      "PRENATAL TAB", "SODIUM FLUORIDE 1.1 % GEL"
    ],
    7: ["NORFLOX-TZ 400-600 Tab"]
  };

  @override
  void initState() {
    super.initState();
    medicineCategories = medicineForMap.keys.toList()..sort();
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
          .collection('medicines_entry')
          .where('Family_code', isEqualTo: familyCode)
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
      _regNoController.text = baseData['Registration_Number']?.toString() ?? '';
      selectedGender = baseData['Gender']?.toString();
      _ageController.text = baseData['Age']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        final snapshot = await FirebaseFirestore.instance
            .collection('medicines_entry')
            .where('Family_code', isEqualTo: fCode)
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
        debugPrint('Error fetching medicines record: $e');
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
    _regNoController.text = d['Registration_Number'] ?? '';
    selectedFamilyCode = d['Family_code'] ?? d['Family_Code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    _ageController.text = d['Age']?.toString() ?? '';
    
    final rawDate = d['Date'] ?? d['Interview_Date'] ?? d['Date_of_Interview'];
    if (rawDate != null) {
      if (rawDate is Timestamp) {
        selectedDate = rawDate.toDate();
      } else {
        try {
          selectedDate = DateFormat('dd-MMM-yyyy').parse(rawDate.toString());
        } catch (_) {
          try {
            selectedDate = DateTime.parse(rawDate.toString());
          } catch (_) {}
        }
      }
    }
    
    selectedInterviewer = d['Interviewer_s_Name_ID'];
    selectedSource = d['Source_of_Medicine'];
    _otherSourceController.text = d['Other']?.toString() ?? '';
    _doctorNameController.text = d['Doctor_Name']?.toString() ?? '';
    _remarksController.text = d['Remarks']?.toString() ?? '';
    
    prescriptionList.clear();
    if (d['SubForm1'] != null) {
      prescriptionList.addAll(List<Map<String, dynamic>>.from(d['SubForm1']));
    }

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _regNoController.clear();
      _familyCodeController.clear();
      _nameController.clear();
      selectedFamilyCode = null;
      selectedMemberName = null;
      selectedGender = null;
      _ageController.clear();
      selectedDate = DateTime.now();
      selectedInterviewer = null;
      selectedSource = null;
      _otherSourceController.clear();
      _doctorNameController.clear();
      _remarksController.clear();
      prescriptionList.clear();
      familyMemberNames = [];
      _existingRecords = [];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number': _regNoController.text,
        'Family_Code': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Age': int.tryParse(_ageController.text),
        'Date_field': selectedDate != null ? DateFormat('dd-MMM-yyyy').format(selectedDate!) : null,
        'Interviewer_s_Name_ID': selectedInterviewer,
        'Source_of_Medicine': selectedSource,
        'Other': _otherSourceController.text,
        'SubForm1': prescriptionList,
        'Doctor_Name': _doctorNameController.text,
        'Remarks': _remarksController.text,
        'MED_FOR': (prescriptionList.isNotEmpty && prescriptionList.first['Medicine_For'] != null) ? medicineForMap[prescriptionList.first['Medicine_For']] : null,
        'Created_time': DateFormat('HH:mm:ss').format(DateTime.now()),
        'Modified_time1': DateFormat('HH:mm:ss').format(DateTime.now()),
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('medicines_entry', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Medicines updated! Syncing...' : 'Medicines saved! Syncing...'),
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
      _performMedicinesSync(data);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _performMedicinesSync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('medicines_entry').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('medicines_entry').add(data);
      }
    } catch (e) {
      debugPrint('Medicines Background Sync Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Medicines Entry'), elevation: 0),
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
                      onNew: () {
                        setState(() {
                          _isEditMode = false;
                          _resetForm();
                        });
                      },
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
                    _buildPrescriptionList(),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Medicine Details',
                      icon: Icons.medication_outlined,
                      children: [
                        _buildDatePicker('Date', selectedDate, (v) => setState(() => selectedDate = v)),
                        const SizedBox(height: 16),
                        formSearchableDropdown(context, 'Source of Medicine:', messageSources, selectedSource, (v) => setState(() => selectedSource = v)),
                        const SizedBox(height: 16),
                        formTextField('Other ?', _otherSourceController),
                        const SizedBox(height: 16),
                        formTextField('Doctor Name', _doctorNameController),
                        const SizedBox(height: 16),
                        formTextField('Remarks', _remarksController, maxLines: 2),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildIdentitySection() {
    return buildSectionCard(
      context: context,
      title: 'Medicines Entry',
      icon: Icons.person_outline,
      children: [
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
        Row(
          children: [
            Expanded(child: formTextField('Registration Number', _regNoController)),
            const SizedBox(width: 12),
            Expanded(child: formTextField('Age', _ageController, keyboardType: TextInputType.number)),
          ],
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
        formSearchableDropdown(context, 'Interviewer’s Name/ID', interviewers, selectedInterviewer, (v) => setState(() => selectedInterviewer = v)),
      ],
    );
  }

  Widget _buildPrescriptionList() {
    return buildSectionCard(
      context: context,
      title: 'Prescription List',
      icon: Icons.list_alt_outlined,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: prescriptionList.length,
          itemBuilder: (context, index) {
            final item = prescriptionList[index];
            final String? medFor = item['Medicine_For'];
            final int? medForId = medFor != null ? medicineForMap[medFor] : null;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: formSearchableDropdown(
                            context,
                            'Medicine For',
                            medicineCategories,
                            item['Medicine_For'],
                            (v) {
                              setState(() {
                                item['Medicine_For'] = v;
                                item['Medicines'] = null; // Reset medicine on category change
                              });
                            },
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => prescriptionList.removeAt(index))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    formSearchableDropdown(
                      context,
                      'Medicines',
                      medForId != null ? (staticMedicines[medForId] ?? []) : [],
                      item['Medicines'],
                      (v) => setState(() => item['Medicines'] = v),
                      hint: medFor == null ? 'Select category first' : '-Select Medicine-',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: formTextField('Duration(Days)', TextEditingController(text: item['Duration_Days'] ?? '')..selection = TextSelection.fromPosition(TextPosition(offset: item['Duration_Days']?.length ?? 0)), onChanged: (v) => item['Duration_Days'] = v)),
                        const SizedBox(width: 8),
                        Expanded(child: formSearchableDropdown(context, 'Dosage', dosagesList, item['Dosage'], (v) => setState(() => item['Dosage'] = v))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: formSearchableDropdown(context, 'Morning', timeSlots, item['Morning'], (v) => setState(() => item['Morning'] = v))),
                        const SizedBox(width: 4),
                        Expanded(child: formSearchableDropdown(context, 'Afternoon', timeSlots, item['Afternoon'], (v) => setState(() => item['Afternoon'] = v))),
                        const SizedBox(width: 4),
                        Expanded(child: formSearchableDropdown(context, 'Night', timeSlots, item['Night'], (v) => setState(() => item['Night'] = v))),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => setState(() => prescriptionList.add({'Medicine_For': '', 'Medicines': '', 'Duration_Days': '', 'Dosage': null, 'Morning': null, 'Afternoon': null, 'Night': null})),
          icon: const Icon(Icons.add),
          label: const Text('Add Medicine'),
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
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(selectedDate == null ? 'dd-MMM-yyyy' : DateFormat('dd-MMM-yyyy').format(selectedDate)),
          ),
        ),
      ],
    );
  }
}
