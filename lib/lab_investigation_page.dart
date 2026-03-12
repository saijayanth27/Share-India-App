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
  bool _isLoading = false;

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
  
  // New Identification State
  String? selectedFamilyCode;
  String? selectedMemberName;
  List<String> allFamilyCodes = [];
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  bool _isLoadingMembers = false;

  DateTime? investigationDate;

  @override
  void initState() {
    super.initState();
    _fetchFamilyCodes();
    if (widget.existingData != null) {
      _loadExistingData();
    } else {
      investigationDate = DateTime.now();
    }
  }

  Future<void> _fetchFamilyCodes() async {
    final codes = await DataCacheService().fetchFamilyCodes();
    setState(() {
      allFamilyCodes = codes;
    });
  }

  Future<void> _fetchMembersByFamily(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      // 1. Fetch from Firestore (Cache favored)
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyCode)
          .get(const GetOptions(source: Source.serverAndCache));

      // 2. Fetch from Local SQLite for offline support
      final localMembers = await DataCacheService().fetchMembersLocally(familyCode);

      // 3. Merge logic
      final Map<String, Map<String, dynamic>> memberMap = {};
      final Set<String> allNames = {};
      
      void processMember(Map<String, dynamic> data) {
        final name = data['Name']?.toString() ?? '';
        if (name.isEmpty) return;
        memberMap[name] = data;
        allNames.add(name);
      }

      for (var doc in snapshot.docs) {
        processMember(doc.data());
      }
      for (var local in localMembers) {
        processMember(local);
      }

      setState(() {
        _allMembersData = memberMap;
        familyMemberNames = allNames.toList()..sort();
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error fetching members: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _fetchExistingRecords(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('lab_investigation')
          .where('Family_Code', isEqualTo: familyCode)
          .get();
      
      setState(() {
        _existingRecords = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error fetching existing records: $e');
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
          _regNoController.text = data['Registration_Number']?.toString() ?? '';
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
    _regNoController.text = d['Registration_Number_of'] ?? d['Registration_Number'] ?? '';
    selectedFamilyCode = d['Family_Code'] ?? d['Family_code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    
    if (d['Date_of_Lab_Investigation'] != null) {
      if (d['Date_of_Lab_Investigation'] is Timestamp) {
        investigationDate = (d['Date_of_Lab_Investigation'] as Timestamp).toDate();
      } else {
        try {
          investigationDate = DateFormat('dd-MMM-yyyy').parse(d['Date_of_Lab_Investigation'].toString());
        } catch (_) {}
      }
    }
    
    _fastingSugarController.text = d['Fasting_blood_sugar']?.toString() ?? '';
    _hba1cController.text = d['hemoglobin_A1c']?.toString() ?? '';
    _glycosylatedHbController.text = d['Glycosylated_Hemoglobin']?.toString() ?? '';
    _meanGlucoseController.text = d['Mean_Blood_Glucose']?.toString() ?? '';
    _creatinineController.text = d['Creatinine']?.toString() ?? '';
    _urineAlbuminController.text = d['urine_albumin']?.toString() ?? '';
    _albuminRatioController.text = d['albumin_ratio']?.toString() ?? '';
    _proteinUrineSpotController.text = d['protein_urine_spot']?.toString() ?? '';
    _creatinineUrineSpotController.text = d['Creatinine_urine_spot']?.toString() ?? '';
    _proteinCreatinineRatioController.text = d['protein_Creatinine_ratio']?.toString() ?? '';

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _regNoController.clear();
      _nameController.clear();
      selectedFamilyCode = null;
      selectedMemberName = null;
      familyMemberNames = [];
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
      _existingRecords = [];
      _editDocId = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number_of': _regNoController.text,
        'Family_Code': selectedFamilyCode,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Date_of_Lab_Investigation': investigationDate != null ? Timestamp.fromDate(investigationDate!) : null,
        'Fasting_blood_sugar': double.tryParse(_fastingSugarController.text),
        'hemoglobin_A1c': double.tryParse(_hba1cController.text),
        'Glycosylated_Hemoglobin': double.tryParse(_glycosylatedHbController.text),
        'Mean_Blood_Glucose': double.tryParse(_meanGlucoseController.text),
        'Creatinine': double.tryParse(_creatinineController.text),
        'urine_albumin': double.tryParse(_urineAlbuminController.text),
        'albumin_ratio': double.tryParse(_albuminRatioController.text),
        'protein_urine_spot': double.tryParse(_proteinUrineSpotController.text),
        'Creatinine_urine_spot': double.tryParse(_creatinineUrineSpotController.text),
        'protein_Creatinine_ratio': double.tryParse(_proteinCreatinineRatioController.text),
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('lab_investigation').doc(_editDocId).update(data);
      } else if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('lab_investigation').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('lab_investigation').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lab Investigation record saved successfully!'), backgroundColor: Colors.green),
        );
        if (widget.docId != null) {
          Navigator.pop(context);
        } else {
          _resetForm();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildNumericField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Lab Investigation', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.indigo.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  buildHeader(
                    context: context,
                    title: 'Lab Diagnostics',
                    subtitle: 'Record and track patient laboratory results',
                  ),

                  buildSectionCard(
                    context: context,
                    title: 'Identification',
                    icon: Icons.badge_outlined,
                    children: [
                      TextFormField(
                        controller: _regNoController,
                        decoration: const InputDecoration(
                          labelText: 'Registration Number of the participant',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _familyCodeController,
                              decoration: const InputDecoration(labelText: 'Family code', border: OutlineInputBorder()),
                              onChanged: (v) {
                                setState(() {
                                  selectedFamilyCode = v;
                                  selectedMemberName = null;
                                  familyMemberNames = [];
                                });
                                if (v.isNotEmpty) {
                                  if (_isEditMode) {
                                    _fetchExistingRecords(v);
                                  } else {
                                    _fetchMembersByFamily(v);
                                  }
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _isEditMode
                              ? DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Select Name to Edit',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: _isLoadingMembers ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                                ),
                                value: selectedMemberName,
                                items: _existingRecords.map((r) => DropdownMenuItem(value: r['Name']?.toString() ?? 'Unknown', child: Text(r['Name']?.toString() ?? 'Unknown'))).toList(),
                                onChanged: _onNameSelected,
                              )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      controller: _nameController,
                                      decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), hintText: 'Type name or pick from dropdown'),
                                    ),
                                    if (familyMemberNames.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          labelText: 'Pick from Family Members',
                                          border: const OutlineInputBorder(),
                                          suffixIcon: _isLoadingMembers ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                                        ),
                                        value: null,
                                        items: familyMemberNames.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                                        onChanged: _onNameSelected,
                                        hint: const Text('--Select Member--'),
                                      ),
                                    ],
                                  ],
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: investigationDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => investigationDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date of Lab Investigation',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(investigationDate == null ? 'Select Date' : DateFormat('dd-MMM-yyyy').format(investigationDate!)),
                        ),
                      ),
                    ],
                  ),
                  buildSectionCard(
                    context: context,
                    title: 'Investigations',
                    icon: Icons.science_outlined,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildNumericField('Fasting blood sugar', _fastingSugarController)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildNumericField('urine albumin', _urineAlbuminController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildNumericField('hemoglobin A1c', _hba1cController)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildNumericField('albumin ratio', _albuminRatioController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildNumericField('Glycosylated Hemoglobin', _glycosylatedHbController)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildNumericField('protein urine spot', _proteinUrineSpotController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildNumericField('Mean Blood Glucose', _meanGlucoseController)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildNumericField('Creatinine urine spot', _creatinineUrineSpotController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildNumericField('Creatinine', _creatinineController)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildNumericField('protein Creatinine ratio', _proteinCreatinineRatioController)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_isEditMode ? 'Update Lab Results' : 'Save Lab Results', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _resetForm,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Reset Form', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
