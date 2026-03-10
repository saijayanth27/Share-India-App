import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';

class CervicalCancerScreeningPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const CervicalCancerScreeningPage({super.key, this.existingData, this.docId});

  @override
  State<CervicalCancerScreeningPage> createState() => _CervicalCancerScreeningPageState();
}

class _CervicalCancerScreeningPageState extends State<CervicalCancerScreeningPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // --- Controllers ---
  // --- Controllers ---
  final _registrationNumber = TextEditingController();
  final _ageController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _schoolLevelController = TextEditingController();
  final _occupationController = TextEditingController();
  final _monthlyIncomeController = TextEditingController();
  final _familyMembersCountController = TextEditingController();
  final _age1Controller = TextEditingController();

  // --- State ---
  String? selectedFamilyId;
  String? selectedMemberName;
  String? selectedGender;
  DateTime? examDate;
  DateTime? dateOfBirth;
  String? selectedAttendedSchool;
  String? selectedReligion;
  String? selectedMaritalStatus;

  // Lookup Options
  List<String> allFamilyCodes = [];
  List<String> familyMemberNames = [];
  bool _isLoadingMembers = false;

  @override
  void initState() {
    super.initState();
    _fetchFamilyCodes();
    if (widget.existingData != null) {
      _loadExistingData();
    } else {
      examDate = DateTime.now();
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
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyCode)
          .get();

      final names = snapshot.docs.map((doc) => doc.data()['Name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();

      setState(() {
        familyMemberNames = names..sort();
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error fetching members: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  void _loadExistingData() {
    final d = widget.existingData!;
    setState(() {
      _registrationNumber.text = d['Registration_Number'] ?? '';
      selectedFamilyId = d['Family_ID'];
      selectedMemberName = d['Name'];
      selectedGender = d['Gender'];
      _ageController.text = d['Age']?.toString() ?? '';
      if (d['Exam_Date'] != null) examDate = (d['Exam_Date'] as Timestamp).toDate();
      _firstNameController.text = d['Interviewer_s_Name_first_name'] ?? '';
      _lastNameController.text = d['Interviewer_s_Name_last_name'] ?? '';
      if (d['Date_of_Birth'] != null) dateOfBirth = (d['Date_of_Birth'] as Timestamp).toDate();
      selectedAttendedSchool = d['Have_you_ever_attended'];
      _schoolLevelController.text = d['What_was_the_highest_level_of_school_you_completed'] ?? '';
      _occupationController.text = d['What_is_your_occupation'] ?? '';
      selectedReligion = d['Religion'];
      _monthlyIncomeController.text = d['What_is_the_total_monthly_income_of_your_family']?.toString() ?? '';
      _familyMembersCountController.text = d['How_many_family_members_are_there_in_your_house']?.toString() ?? '';
      selectedMaritalStatus = d['Marital_status'];
      _age1Controller.text = d['Age1']?.toString() ?? '';
    });
    if (selectedFamilyId != null) _fetchMembersByFamily(selectedFamilyId!);
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _registrationNumber.clear();
      selectedFamilyId = null;
      selectedMemberName = null;
      selectedGender = null;
      _ageController.clear();
      examDate = DateTime.now();
      _firstNameController.clear();
      _lastNameController.clear();
      dateOfBirth = null;
      selectedAttendedSchool = null;
      _schoolLevelController.clear();
      _occupationController.clear();
      selectedReligion = null;
      _monthlyIncomeController.clear();
      _familyMembersCountController.clear();
      selectedMaritalStatus = null;
      _age1Controller.clear();
      familyMemberNames = [];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number': _registrationNumber.text,
        'Family_ID': selectedFamilyId,
        'Name': selectedMemberName,
        'Gender': selectedGender,
        'Age': int.tryParse(_ageController.text),
        'Exam_Date': examDate != null ? Timestamp.fromDate(examDate!) : null,
        'Interviewer_s_Name_first_name': _firstNameController.text,
        'Interviewer_s_Name_last_name': _lastNameController.text,
        'Date_of_Birth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
        'Have_you_ever_attended': selectedAttendedSchool,
        'What_was_the_highest_level_of_school_you_completed': _schoolLevelController.text,
        'What_is_your_occupation': _occupationController.text,
        'Religion': selectedReligion,
        'What_is_the_total_monthly_income_of_your_family': _monthlyIncomeController.text.isNotEmpty ? int.tryParse(_monthlyIncomeController.text) : null,
        'How_many_family_members_are_there_in_your_house': _familyMembersCountController.text.isNotEmpty ? int.tryParse(_familyMembersCountController.text) : null,
        'Marital_status': selectedMaritalStatus,
        'Age1': _age1Controller.text.isNotEmpty ? int.tryParse(_age1Controller.text) : null,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('cervical_screening').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('cervical_screening').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Screening record saved successfully!'), backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cervical Screening Questionnaire')),
      drawer: const AppDrawer(),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildIdentitySection(),
                    _buildSectionCard(
                      title: 'Socio-Demographic Details',
                      children: [
                         Row(
                          children: [
                            Expanded(child: _buildDatePicker('Date of Birth', dateOfBirth, (v) {
                              setState(() {
                                dateOfBirth = v;
                                final age = DateTime.now().year - v.year;
                                _age1Controller.text = age.toString();
                              });
                            })),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField('Age', _age1Controller, keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Have you ever attended school?', style: TextStyle(fontWeight: FontWeight.w500)),
                        Row(
                          children: [
                            Expanded(child: RadioListTile<String>(title: const Text('Yes'), value: 'Yes', groupValue: selectedAttendedSchool, onChanged: (v) => setState(() => selectedAttendedSchool = v), contentPadding: EdgeInsets.zero, dense: true)),
                            Expanded(child: RadioListTile<String>(title: const Text('No'), value: 'No', groupValue: selectedAttendedSchool, onChanged: (v) => setState(() => selectedAttendedSchool = v), contentPadding: EdgeInsets.zero, dense: true)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTextField('Highest level of school completed?', _schoolLevelController),
                        const SizedBox(height: 12),
                        _buildTextField('What is your occupation?', _occupationController),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildDropdown('Religion', ['Hindu', 'Muslim', 'Christian', 'Others'], selectedReligion, (v) => setState(() => selectedReligion = v))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildDropdown('Marital status', ['Single', 'Married', 'Widowed', 'Divorced'], selectedMaritalStatus, (v) => setState(() => selectedMaritalStatus = v))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildTextField('Total monthly income (Rs.)', _monthlyIncomeController, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField('Family members count', _familyMembersCountController, keyboardType: TextInputType.number)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(widget.docId == null ? 'Submit Screening' : 'Update Screening', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildIdentitySection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Patient Identity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const Divider(),
            _buildTextField('Registration Number', _registrationNumber),
            const SizedBox(height: 12),
            _buildDropdown('Family Code', allFamilyCodes, selectedFamilyId, (v) {
              setState(() { selectedFamilyId = v; selectedMemberName = null; familyMemberNames = []; });
              if (v != null) _fetchMembersByFamily(v);
            }),
            const SizedBox(height: 12),
            _buildDropdown('Name', familyMemberNames, selectedMemberName, (v) => setState(() => selectedMemberName = v), isLoading: _isLoadingMembers),
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
                Expanded(child: _buildTextField('Age (years)', _ageController, keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _buildDatePicker('Exam Date', examDate, (v) => setState(() => examDate = v))),
              ],
            ),
            const SizedBox(height: 12),
            const Text("Interviewer's Name", style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: _buildTextField('First Name', _firstNameController)),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField('Last Name', _lastNameController)),
              ],
            ),
          ],
        ),
      ),
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
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, String? hint, String? helper}) {
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
            helperText: helper,
          ),
          keyboardType: keyboardType,
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? selectedValue, Function(String?) onChanged, {bool isLoading = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: selectedValue,
          isExpanded: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: isLoading ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
          ),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
          hint: const Text('-Select-'),
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
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
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(selectedDate == null ? 'dd-MMM-yyyy' : DateFormat('dd-MMM-yyyy').format(selectedDate)),
          ),
        ),
      ],
    );
  }
}
