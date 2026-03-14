import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isLoadingMembers = false;

  // --- Controllers & State ---
  String? selectedFamilyCode;
  final _familyCodeController = TextEditingController();
  final _nameController = TextEditingController();
  String? selectedMemberName;
  String? selectedGender;
  final _registrationNumberController = TextEditingController();
  final _ageController = TextEditingController();
  DateTime? selectedPrescriptionDate = DateTime.now();

  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};

  final List<Map<String, dynamic>> _medicines = [];
  final _medicineNameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _durationController = TextEditingController();
  final _remarksController = TextEditingController();

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

  void _onNameSelected(String? name) {
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
    _registrationNumberController.text = d['Registration_Number'] ?? '';
    selectedFamilyCode = d['Family_code'] ?? d['Family_Code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    _ageController.text = d['Age']?.toString() ?? '';
    
    if (d['Prescription_Date'] != null) {
      if (d['Prescription_Date'] is Timestamp) {
        selectedPrescriptionDate = (d['Prescription_Date'] as Timestamp).toDate();
      } else {
        try {
          selectedPrescriptionDate = DateFormat('dd-MMM-yyyy').parse(d['Prescription_Date'].toString());
        } catch (_) {}
      }
    }
    
    _medicines.clear();
    if (d['Medicines'] != null) {
      _medicines.addAll(List<Map<String, dynamic>>.from(d['Medicines']));
    }

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _registrationNumberController.clear();
      _nameController.clear();
      selectedFamilyCode = null;
      selectedMemberName = null;
      selectedGender = null;
      _ageController.clear();
      selectedPrescriptionDate = DateTime.now();
      _medicines.clear();
      _familyCodeController.clear();
      familyMemberNames = [];
      _existingRecords = [];
    });
  }

  void _addMedicine() {
    if (_medicineNameController.text.isEmpty) return;
    setState(() {
      _medicines.add({
        'name': _medicineNameController.text,
        'dosage': _dosageController.text,
        'frequency': _frequencyController.text,
        'duration': _durationController.text,
        'remarks': _remarksController.text,
      });
      _medicineNameController.clear();
      _dosageController.clear();
      _frequencyController.clear();
      _durationController.clear();
      _remarksController.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number': _registrationNumberController.text,
        'Family_code': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Age': int.tryParse(_ageController.text),
        'Prescription_Date': selectedPrescriptionDate != null ? Timestamp.fromDate(selectedPrescriptionDate!) : null,
        'Medicines': _medicines,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;

      // Capture BEFORE reset
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('doctor_prescriptions', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Prescription updated! Syncing...' : 'Prescription saved! Syncing...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ));
        
        // If editing, stay on form; if new, reset for next entry
        if (widget.docId != null) {
          Navigator.pop(context);
        } else if (!wasEditing) {
          _resetForm();
        }
      }

      // 2. Background Sync (Non-blocking)
      _performPrescriptionSync(data);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _performPrescriptionSync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('doctor_prescriptions').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('doctor_prescriptions').add(data);
      }
    } catch (e) {
      debugPrint('Prescription Background Sync Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Doctor Prescription'), elevation: 0),
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
                      title: 'Prescription Details',
                      icon: Icons.history_edu_outlined,
                      children: [
                        _buildDatePicker('Prescription Date', selectedPrescriptionDate, (v) => setState(() => selectedPrescriptionDate = v)),
                        const SizedBox(height: 24),
                        const Text('Add Medicine', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(),
                        formTextField('Medicine Name', _medicineNameController),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: formTextField('Dosage', _dosageController)),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField('Frequency', _frequencyController)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: formTextField('Duration', _durationController)),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField('Remarks', _remarksController)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addMedicine,
                            icon: const Icon(Icons.add),
                            label: const Text('Add to List'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        if (_medicines.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text('Medicines List', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _medicines.length,
                            itemBuilder: (context, index) {
                              final med = _medicines[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  title: Text(med['name'] ?? ''),
                                  subtitle: Text('${med['dosage'] ?? ''} - ${med['frequency'] ?? ''} (${med['duration'] ?? ''})'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                    onPressed: () => setState(() => _medicines.removeAt(index)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
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
        formTextField('Registration Number', _registrationNumberController),
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
        formTextField('Age', _ageController, keyboardType: TextInputType.number),
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
