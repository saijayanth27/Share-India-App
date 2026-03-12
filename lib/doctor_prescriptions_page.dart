import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

class DoctorPrescriptionsPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const DoctorPrescriptionsPage({super.key, this.existingData, this.docId});

  @override
  State<DoctorPrescriptionsPage> createState() => _DoctorPrescriptionsPageState();
}

class _DoctorPrescriptionsPageState extends State<DoctorPrescriptionsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoading = false;

  // --- Controllers & State ---
  String? selectedFamilyCode;
  final _familyCodeController = TextEditingController();
  final _nameController = TextEditingController();
  String? selectedMemberName;
  String? selectedGender;
  final _registrationNumberController = TextEditingController();
  final _ageController = TextEditingController();
  DateTime? selectedPrescriptionDate;

  List<String> allFamilyCodes = [];
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  bool _isLoadingMembers = false;

  @override
  void initState() {
    super.initState();
    _fetchFamilyCodes();
    if (widget.existingData != null) {
      _loadExistingData();
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
          .collection('doctor_prescriptions')
          .where('Family_code', isEqualTo: familyCode)
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
          _registrationNumberController.text = data['Registration_Number']?.toString() ?? '';
          selectedGender = data['Gender']?.toString();
          _ageController.text = data['Age']?.toString() ?? '';
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
    selectedFamilyCode = d['Family_code'] ?? d['Family_Code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    _ageController.text = d['Age']?.toString() ?? '';
    
    if (d['Doctor_s_Prescription_date'] != null) {
      if (d['Doctor_s_Prescription_date'] is Timestamp) {
        selectedPrescriptionDate = (d['Doctor_s_Prescription_date'] as Timestamp).toDate();
      } else {
        try {
          selectedPrescriptionDate = DateFormat('dd-MMM-yyyy').parse(d['Doctor_s_Prescription_date'].toString());
        } catch (_) {
          try {
             selectedPrescriptionDate = DateTime.parse(d['Doctor_s_Prescription_date'].toString());
          } catch (_) {}
        }
      }
    }

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      selectedFamilyCode = null;
      selectedMemberName = null;
      _nameController.clear();
      selectedGender = null;
      _ageController.clear();
      selectedPrescriptionDate = null;
      familyMemberNames = [];
      _existingRecords = [];
      _editDocId = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Family_code': selectedFamilyCode,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Age': int.tryParse(_ageController.text),
        'Doctor_s_Prescription_date': selectedPrescriptionDate,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('doctor_prescriptions').doc(_editDocId).update(data);
      } else if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('doctor_prescriptions').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('doctor_prescriptions').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription saved successfully!'), backgroundColor: Colors.green),
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

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, String? hint, Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            hintText: hint,
          ),
          keyboardType: keyboardType,
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Doctor Prescriptions', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade700, Colors.indigo.shade400],
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
                    title: 'Prescription Entry',
                    subtitle: 'Record medical prescriptions for family members',
                  ),

                  buildSectionCard(
                    context: context,
                    title: 'Prescription Details',
                    icon: Icons.medical_services_outlined,
                    children: [
                      // Family Code Lookup
                      _buildTextField('Family code', _familyCodeController, onChanged: (v) {
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
                      }),
                      const SizedBox(height: 16),

                      // Name Lookup (Member of Family)
                      _isEditMode
                          ? DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Select Name to Edit',
                                border: const OutlineInputBorder(),
                                suffixIcon: _isLoadingMembers ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                              ),
                              value: selectedMemberName,
                              items: _existingRecords.map((r) => DropdownMenuItem(value: r['Name']?.toString() ?? 'Unknown', child: Text(r['Name']?.toString() ?? 'Unknown'))).toList(),
                              onChanged: _onNameSelected,
                              validator: (v) => v == null ? 'Please select a name' : null,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), hintText: 'Type name or pick from dropdown'),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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
                      const SizedBox(height: 16),

                      // Gender Radio
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600)),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('(1) Male'),
                                  value: '(1) Male',
                                  groupValue: selectedGender,
                                  onChanged: (v) => setState(() => selectedGender = v),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('(0) Female'),
                                  value: '(0) Female',
                                  groupValue: selectedGender,
                                  onChanged: (v) => setState(() => selectedGender = v),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Age
                      TextFormField(
                        controller: _ageController,
                        decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder(), hintText: '#######'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // Prescription Date
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedPrescriptionDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => selectedPrescriptionDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: "Doctor's Prescription date", border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                          child: Text(selectedPrescriptionDate == null ? 'Select Date' : DateFormat('dd-MMM-yyyy').format(selectedPrescriptionDate!)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_isEditMode ? 'Update Prescription' : 'Save Prescription', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                ],
              ),
            ),
    );
  }
}
