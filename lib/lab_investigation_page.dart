import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

class LabInvestigationPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const LabInvestigationPage({super.key, this.existingData, this.docId});

  @override
  State<LabInvestigationPage> createState() => _LabInvestigationPageState();
}

class _LabInvestigationPageState extends State<LabInvestigationPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;

  // --- Controllers ---
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _familyCodeController = TextEditingController();
  final _fastingSugarController = TextEditingController();
  final _hba1cController = TextEditingController();
  final _glycosylatedHbController = TextEditingController();
  final _meanGlucoseController = TextEditingController();
  final _creatinineController = TextEditingController();
  final _urineAlbuminController = TextEditingController();
  final _albuminRatioController = TextEditingController();
  final _proteinUrineSpotController = TextEditingController();
  final _creatinineUrineSpotController = TextEditingController();
  final _proteinCreatinineRatioController = TextEditingController();
  
  // Identification State
  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectedGender;
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};

  DateTime? investigationDate = DateTime.now();

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
          .collection('lab_investigation')
          .where('Family_ID', isEqualTo: familyCode)
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
      if (name != null) {
        if (_isEditMode) {
          final record = _existingRecords.firstWhere((r) => r['Name'] == name, orElse: () => {});
          if (record.isNotEmpty) {
            _editDocId = record['id'];
            _populateForm(record);
          }
        } else if (_allMembersData.containsKey(name)) {
          final data = _allMembersData[name]!;
          _regNoController.text = (data['uniq_Registration_Number'] ?? data['Registration_Number'] ?? data['Registration_Number1'] ?? '').toString();
          selectedGender = data['Gender']?.toString();
        }
      }
    });
  }

  void _loadExistingData() {
    setState(() {
      _populateForm(widget.existingData!);
    });
  }

  void _populateForm(Map<String, dynamic> d) {
    _regNoController.text = d['Registration_Number'] ?? '';
    selectedFamilyCode = d['Family_ID'] ?? d['Family_Code'] ?? d['Family_Code_Creation'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    
    if (d['Date_of_Investigation'] != null) {
      if (d['Date_of_Investigation'] is Timestamp) {
        investigationDate = (d['Date_of_Investigation'] as Timestamp).toDate();
      } else {
        try {
          investigationDate = DateFormat('dd-MMM-yyyy').parse(d['Date_of_Investigation'].toString());
        } catch (_) {}
      }
    }

    _fastingSugarController.text = d['Fasting_Sugar']?.toString() ?? '';
    _hba1cController.text = d['HbA1c']?.toString() ?? '';
    _glycosylatedHbController.text = d['Glycosylated_Hb']?.toString() ?? '';
    _meanGlucoseController.text = d['Mean_Glucose']?.toString() ?? '';
    _creatinineController.text = d['Creatinine']?.toString() ?? '';
    _urineAlbuminController.text = d['Urine_Albumin']?.toString() ?? '';
    _albuminRatioController.text = d['Albumin_Ratio']?.toString() ?? '';
    _proteinUrineSpotController.text = d['Protein_Urine_Spot']?.toString() ?? '';
    _creatinineUrineSpotController.text = d['Creatinine_Urine_Spot']?.toString() ?? '';
    _proteinCreatinineRatioController.text = d['Protein_Creatinine_Ratio']?.toString() ?? '';

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _regNoController.clear();
      _nameController.clear();
      _familyCodeController.clear();
      selectedFamilyCode = null;
      selectedMemberName = null;
      selectedGender = null;
      investigationDate = DateTime.now();
      _fastingSugarController.clear();
      _hba1cController.clear();
      _glycosylatedHbController.clear();
      _meanGlucoseController.clear();
      _creatinineController.clear();
      _urineAlbuminController.clear();
      _albuminRatioController.clear();
      _proteinUrineSpotController.clear();
      _creatinineUrineSpotController.clear();
      _proteinCreatinineRatioController.clear();
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
        'Family_ID': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Date_of_Investigation': investigationDate != null ? Timestamp.fromDate(investigationDate!) : null,
        'Fasting_Sugar': double.tryParse(_fastingSugarController.text),
        'HbA1c': double.tryParse(_hba1cController.text),
        'Glycosylated_Hb': double.tryParse(_glycosylatedHbController.text),
        'Mean_Glucose': double.tryParse(_meanGlucoseController.text),
        'Creatinine': double.tryParse(_creatinineController.text),
        'Urine_Albumin': double.tryParse(_urineAlbuminController.text),
        'Albumin_Ratio': double.tryParse(_albuminRatioController.text),
        'Protein_Urine_Spot': double.tryParse(_proteinUrineSpotController.text),
        'Creatinine_Urine_Spot': double.tryParse(_creatinineUrineSpotController.text),
        'Protein_Creatinine_Ratio': double.tryParse(_proteinCreatinineRatioController.text),
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('lab_investigation', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Lab Investigation updated! Syncing...' : 'Lab Investigation saved! Syncing...'),
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
      _performLabInvestigationSync(data);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _performLabInvestigationSync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('lab_investigation').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('lab_investigation').add(data);
      }
    } catch (e) {
      debugPrint('Lab Investigation Background Sync Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Lab Investigation'), elevation: 0),
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
                    buildSectionCard(
                      context: context,
                      title: 'Investigation Details',
                      icon: Icons.biotech_outlined,
                      children: [
                        _buildDatePicker('Investigation Date', investigationDate, (v) => setState(() => investigationDate = v)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: formTextField('Fasting Sugar (mg/dL)', _fastingSugarController, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField('HbA1c (%)', _hba1cController, keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: formTextField('Glycosylated Hb', _glycosylatedHbController, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField('Mean Glucose', _meanGlucoseController, keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: formTextField('Creatinine', _creatinineController, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField('Urine Albumin', _urineAlbuminController, keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        formTextField('Albumin/Creatinine Ratio', _albuminRatioController, keyboardType: TextInputType.number),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: formTextField('Protein (Urine Spot)', _proteinUrineSpotController, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField('Creatinine (Urine Spot)', _creatinineUrineSpotController, keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        formTextField('Protein/Creatinine Ratio', _proteinCreatinineRatioController, keyboardType: TextInputType.number),
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
      title: 'Patient Identity',
      icon: Icons.person_outline,
      children: [
        formTextField(
          'Registration Number',
          _regNoController,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
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
        const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: 'Male', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: 'Female', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
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
