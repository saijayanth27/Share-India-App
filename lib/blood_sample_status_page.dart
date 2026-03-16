import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

class BloodSampleStatusPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const BloodSampleStatusPage({super.key, this.existingData, this.docId});

  @override
  State<BloodSampleStatusPage> createState() => _BloodSampleStatusPageState();
}

class _BloodSampleStatusPageState extends State<BloodSampleStatusPage> {
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
  final _age = TextEditingController();
  
  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectedGender;
  DateTime? dateOfInterview = DateTime.now();
  String? interviewersName;
  String? notDoneReason;

  // Status Fields
  String? collectBloodSample;
  String? collectHBA1C;
  String? collectThyroid;
  String? collectCRE;
  String? collectSputumTB;
  String? collectVaginalSwabHPV;
  String? collectUrine;

  // Date Fields
  DateTime? dateCBP;
  DateTime? dateHBA1C;
  DateTime? dateThyroid;
  DateTime? dateCRE;
  DateTime? dateSputumTB;
  DateTime? dateVaginalSwabHPV;
  DateTime? dateUrine;

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

  Future<void> _fetchExistingRecords(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('blood_sample_status')
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
      _registrationNumber.text = baseData['Registration_Number']?.toString() ?? '';
      selectedGender = baseData['Gender']?.toString();
      _age.text = baseData['Age']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        final snapshot = await FirebaseFirestore.instance
            .collection('blood_sample_status')
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
        debugPrint('Error fetching sample status record: $e');
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
    selectedFamilyCode = d['Family_code'] ?? d['Family_Code'] ?? d['Family_ID'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    _age.text = d['Age']?.toString() ?? '';
    
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
    notDoneReason = d['Not_Done_Reason'];

    collectBloodSample = d['Collect_Blood_Sample'];
    collectHBA1C = d['Collect_HBA1C'];
    collectThyroid = d['Collect_Thyroid'];
    collectCRE = d['Collect_CRE'];
    collectSputumTB = d['Collect_Sputum_TB'];
    collectVaginalSwabHPV = d['Collect_Vaginal_Swab_HPV'];
    collectUrine = d['Collect_Urine'];

    DateTime? _parseSampleDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      return DateTime.tryParse(val.toString()) ?? ((){
        try { return DateFormat('dd-MMM-yyyy').parse(val.toString()); } catch(_) { return null; }
      }());
    }

    if (d['Date_CBP'] != null) dateCBP = _parseSampleDate(d['Date_CBP']);
    if (d['Date_HBA1C'] != null) dateHBA1C = _parseSampleDate(d['Date_HBA1C']);
    if (d['Date_Thyroid'] != null) dateThyroid = _parseSampleDate(d['Date_Thyroid']);
    if (d['Date_CRE'] != null) dateCRE = _parseSampleDate(d['Date_CRE']);
    if (d['Date_Sputum_TB'] != null) dateSputumTB = _parseSampleDate(d['Date_Sputum_TB']);
    if (d['Date_Vaginal_Swab_HPV'] != null) dateVaginalSwabHPV = _parseSampleDate(d['Date_Vaginal_Swab_HPV']);
    if (d['Date_Urine'] != null) dateUrine = _parseSampleDate(d['Date_Urine']);

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
      dateOfInterview = DateTime.now();
      interviewersName = null;
      notDoneReason = null;
      collectBloodSample = null;
      collectHBA1C = null;
      collectThyroid = null;
      collectCRE = null;
      collectSputumTB = null;
      collectVaginalSwabHPV = null;
      collectUrine = null;
      dateCBP = null;
      dateHBA1C = null;
      dateThyroid = null;
      dateCRE = null;
      dateSputumTB = null;
      dateVaginalSwabHPV = null;
      dateUrine = null;
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
        'Family_code': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Age': int.tryParse(_age.text),
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'Interviewer_s_Name': interviewersName,
        'Not_Done_Reason': notDoneReason,
        'Collect_Blood_Sample': collectBloodSample,
        'Collect_HBA1C': collectHBA1C,
        'Collect_Thyroid': collectThyroid,
        'Collect_CRE': collectCRE,
        'Collect_Sputum_TB': collectSputumTB,
        'Collect_Vaginal_Swab_HPV': collectVaginalSwabHPV,
        'Collect_Urine': collectUrine,
        'Date_CBP': dateCBP != null ? Timestamp.fromDate(dateCBP!) : null,
        'Date_HBA1C': dateHBA1C != null ? Timestamp.fromDate(dateHBA1C!) : null,
        'Date_Thyroid': dateThyroid != null ? Timestamp.fromDate(dateThyroid!) : null,
        'Date_CRE': dateCRE != null ? Timestamp.fromDate(dateCRE!) : null,
        'Date_Sputum_TB': dateSputumTB != null ? Timestamp.fromDate(dateSputumTB!) : null,
        'Date_Vaginal_Swab_HPV': dateVaginalSwabHPV != null ? Timestamp.fromDate(dateVaginalSwabHPV!) : null,
        'Date_Urine': dateUrine != null ? Timestamp.fromDate(dateUrine!) : null,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;

      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('blood_sample_status', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Blood Sample Status updated! Syncing...' : 'Blood Sample Status saved! Syncing...'),
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
      _performBloodSampleStatusSync(data);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _performBloodSampleStatusSync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('blood_sample_status').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('blood_sample_status').add(data);
      }
    } catch (e) {
      debugPrint('Blood Sample Status Background Sync Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Blood Sample Status'), elevation: 0),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('blood_sample_status_scroll'),
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
                    buildSectionCard(
                      context: context,
                      title: 'Sample Collection Status',
                      icon: Icons.bloodtype_outlined,
                      children: [
                        _buildCollectionRow('Blood Sample (CBP/Glu)', collectBloodSample, dateCBP, (v) => setState(() => collectBloodSample = v), (d) => setState(() => dateCBP = d)),
                        _buildCollectionRow('HbA1c', collectHBA1C, dateHBA1C, (v) => setState(() => collectHBA1C = v), (d) => setState(() => dateHBA1C = d)),
                        _buildCollectionRow('Thyroid (T3/T4/TSH)', collectThyroid, dateThyroid, (v) => setState(() => collectThyroid = v), (d) => setState(() => dateThyroid = d)),
                        _buildCollectionRow('Creatinine (CRE)', collectCRE, dateCRE, (v) => setState(() => collectCRE = v), (d) => setState(() => dateCRE = d)),
                        _buildCollectionRow('Sputum (TB)', collectSputumTB, dateSputumTB, (v) => setState(() => collectSputumTB = v), (d) => setState(() => dateSputumTB = d)),
                        _buildCollectionRow('Vaginal Swab (HPV)', collectVaginalSwabHPV, dateVaginalSwabHPV, (v) => setState(() => collectVaginalSwabHPV = v), (d) => setState(() => dateVaginalSwabHPV = d)),
                        _buildCollectionRow('Urine', collectUrine, dateUrine, (v) => setState(() => collectUrine = v), (d) => setState(() => dateUrine = d)),
                      ],
                    ),
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
            Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: 'Male', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: 'Female', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
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
        formSearchableDropdown(context, 'Interviewer Name', interviewerList, interviewersName, (v) => setState(() => interviewersName = v)),
      ],
    );
  }

  Widget _buildCollectionRow(String label, String? value, DateTime? date, ValueChanged<String?> onChanged, Function(DateTime) onDateChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, 'Status', ['(1) Collected', '(0) Not Collected'], value, onChanged)),
            if (value == '(1) Collected') ...[
              const SizedBox(width: 12),
              Expanded(child: _buildDatePicker('Date', date, onDateChanged)),
            ],
          ],
        ),
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
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
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
