import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';

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
  bool _isLoading = false;

  // --- Main Form Controllers & State ---
  String? selectedFamilyCode;
  final _familyCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();
  String? selectedGender;
  DateTime? selectedDate;
  String? selectedInterviewer;
  String? selectedMemberName;
  final _ageController = TextEditingController();
  String? selectedSource;
  final _otherSourceController = TextEditingController();
  final _doctorNameController = TextEditingController();
  final _remarksController = TextEditingController();
  final _medForController = TextEditingController(); // MED_FOR
  final _medNameController = TextEditingController(); // MED_NAME

  // --- Subform State (Prescription List) ---
  List<Map<String, dynamic>> prescriptionList = [];

  // Dropdown Options
  List<String> allFamilyCodes = [];
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  bool _isLoadingMembers = false;

  final List<String> interviewers = ["KIRANMAI K", "LAVANYA KASPOJU", "RAMADEVI Y", "REVATHI CH"];
  final List<String> messageSources = ["104", "COMPANY", "GOVT", "Other", "PVT", "TETRA"];
  final List<String> dosages = ["BD", "OD", "TDS"];
  final List<String> timeSlots = ["AF", "BF"];

  @override
  void initState() {
    super.initState();
    _fetchFamilyCodes();
    if (widget.existingData != null) {
      _loadExistingData();
    } else {
      selectedDate = DateTime.now();
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
          .collection('medicines_entry')
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
    selectedFamilyCode = d['Family_Code'] ?? d['Family_code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    _regNoController.text = d['Registration_Number'] ?? '';
    selectedGender = d['Gender'];
    if (d['Date_field'] != null) {
      if (d['Date_field'] is Timestamp) {
        selectedDate = (d['Date_field'] as Timestamp).toDate();
      } else {
        try {
          selectedDate = DateFormat('dd-MMM-yyyy').parse(d['Date_field'].toString());
        } catch (_) {}
      }
    }
    selectedInterviewer = d['Interviewer_s_Name_ID'];
    selectedMemberName = d['Name'];
    _ageController.text = d['Age']?.toString() ?? '';
    selectedSource = d['Source_of_Medicine'];
    _otherSourceController.text = d['Other'] ?? '';
    _doctorNameController.text = d['Doctor_Name'] ?? '';
    _remarksController.text = d['Remarks'] ?? '';
    _medForController.text = d['MED_FOR']?.toString() ?? '';
    _medNameController.text = d['MED_NAME']?.toString() ?? '';
    
    if (d['SubForm1'] != null) {
      prescriptionList = List<Map<String, dynamic>>.from(d['SubForm1']);
    }

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      selectedFamilyCode = null;
      _regNoController.clear();
      selectedGender = null;
      selectedDate = DateTime.now();
      selectedInterviewer = null;
      selectedMemberName = null;
      _ageController.clear();
      selectedSource = null;
      _otherSourceController.clear();
      _doctorNameController.clear();
      _remarksController.clear();
      _medForController.clear();
      _medNameController.clear();
      prescriptionList = [];
      familyMemberNames = [];
      _existingRecords = [];
      _editDocId = null;
    });
  }

  void _addPrescriptionRow() {
    setState(() {
      prescriptionList.add({
        'Medicine_For': null,
        'Medicines': null,
        'Duration_Days': '',
        'Dosage': null,
        'Morning': null,
        'Afternoon': null,
        'Night': null,
      });
    });
  }

  void _removePrescriptionRow(int index) {
    setState(() {
      prescriptionList.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final data = {
        'Family_Code': selectedFamilyCode,
        'Registration_Number': _regNoController.text,
        'Gender': selectedGender,
        'Date_field': selectedDate != null ? Timestamp.fromDate(selectedDate!) : null,
        'Interviewer_s_Name_ID': selectedInterviewer,
        'Name': selectedMemberName,
        'Age': int.tryParse(_ageController.text),
        'Source_of_Medicine': selectedSource,
        'Other': _otherSourceController.text,
        'SubForm1': prescriptionList,
        'Doctor_Name': _doctorNameController.text,
        'Remarks': _remarksController.text,
        'MED_FOR': int.tryParse(_medForController.text),
        'MED_NAME': int.tryParse(_medNameController.text),
        'Created_time': widget.docId == null ? DateFormat('HH:mm:ss').format(now) : widget.existingData?['Created_time'],
        'Modified_time1': DateFormat('HH:mm:ss').format(now),
        'clientUpdatedAt': now.millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('medicines_entry').doc(_editDocId).update(data);
      } else if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('medicines_entry').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('medicines_entry').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medicines entry saved successfully!'), backgroundColor: Colors.green),
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

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Medicines Entry Form'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      drawer: const AppDrawer(),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [

                  _buildSectionCard(
                    title: 'Basic Information',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField('Family Code', _familyCodeController, onChanged: (v) {
                              setState(() {
                                selectedFamilyCode = v;
                                selectedMemberName = null;
                                familyMemberNames = [];
                              });
                              if (v != null && v.isNotEmpty) {
                                if (_isEditMode) {
                                  _fetchExistingRecords(v);
                                } else {
                                  _fetchMembersByFamily(v);
                                }
                              }
                            }),
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
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _regNoController, decoration: const InputDecoration(labelText: 'Registration Number', border: OutlineInputBorder()))),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _ageController, decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600)),
                                Row(
                                  children: [
                                    Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: '(1) Male', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
                                    Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: '(0) Female', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                                if (picked != null) setState(() => selectedDate = picked);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                                child: Text(selectedDate == null ? 'Select Date' : DateFormat('dd-MMM-yyyy').format(selectedDate!)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: "Interviewer's Name/ID", border: OutlineInputBorder()),
                        value: selectedInterviewer,
                        items: interviewers.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => selectedInterviewer = v),
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Medicine Source',
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: "Source of Medicine:", border: OutlineInputBorder()),
                        value: selectedSource,
                        items: messageSources.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => selectedSource = v),
                      ),
                      const SizedBox(height: 16),
                      if (selectedSource == "Other")
                        TextFormField(controller: _otherSourceController, decoration: const InputDecoration(labelText: 'Other ?', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextFormField(controller: _doctorNameController, decoration: const InputDecoration(labelText: 'Doctor Name', border: OutlineInputBorder())),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Prescription List',
                    children: [
                      if (prescriptionList.isNotEmpty)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 20,
                            columns: const [
                              DataColumn(label: Text('Med For')),
                              DataColumn(label: Text('Medicines')),
                              DataColumn(label: Text('Duration')),
                              DataColumn(label: Text('Dosage')),
                              DataColumn(label: Text('Morn')),
                              DataColumn(label: Text('Aft')),
                              DataColumn(label: Text('Night')),
                              DataColumn(label: Text('')),
                            ],
                            rows: prescriptionList.asMap().entries.map((entry) {
                              int idx = entry.key;
                              Map<String, dynamic> row = entry.value;
                              return DataRow(cells: [
                                DataCell(SizedBox(width: 100, child: TextFormField(initialValue: row['Medicine_For'], onChanged: (v) => row['Medicine_For'] = v, decoration: const InputDecoration(hintText: 'For...')))),
                                DataCell(SizedBox(width: 100, child: TextFormField(initialValue: row['Medicines'], onChanged: (v) => row['Medicines'] = v, decoration: const InputDecoration(hintText: 'Name...')))),
                                DataCell(SizedBox(width: 60, child: TextFormField(initialValue: row['Duration_Days'], onChanged: (v) => row['Duration_Days'] = v, decoration: const InputDecoration(hintText: 'Days')))),
                                DataCell(DropdownButton<String>(value: row['Dosage'], items: dosages.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => row['Dosage'] = v))),
                                DataCell(DropdownButton<String>(value: row['Morning'], items: timeSlots.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => row['Morning'] = v))),
                                DataCell(DropdownButton<String>(value: row['Afternoon'], items: timeSlots.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => row['Afternoon'] = v))),
                                DataCell(DropdownButton<String>(value: row['Night'], items: timeSlots.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => row['Night'] = v))),
                                DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _removePrescriptionRow(idx))),
                              ]);
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton.icon(
                          onPressed: _addPrescriptionRow,
                          icon: const Icon(Icons.add),
                          label: const Text('Add New Prescription'),
                        ),
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Additional Info',
                    children: [
                      TextFormField(controller: _remarksController, maxLines: 3, decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _medForController, decoration: const InputDecoration(labelText: 'MED_FOR', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _medNameController, decoration: const InputDecoration(labelText: 'MED_NAME', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: Text(_isEditMode ? 'Update Entry' : 'Save Entry', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _resetForm,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
