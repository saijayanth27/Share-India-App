import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

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
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoading = false;

  // --- Controllers ---
  final _nameController = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _familyIdController = TextEditingController();
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
  String? selectedMenopause;
  String? selectedVIA;
  String? selectedTreatment;

  // Lookup Options
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
          .collection('cervical_screening')
          .where('Family_ID', isEqualTo: familyCode)
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
          _registrationNumber.text = data['Registration_Number']?.toString() ?? '';
          
          final gender = data['Gender']?.toString();
          if (gender != null) {
            if (gender.contains('Male')) {
              selectedGender = 'Male';
            } else if (gender.contains('Female')) {
              selectedGender = 'Female';
            }
          }
          
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
    _registrationNumber.text = d['Registration_Number'] ?? '';
    selectedFamilyId = d['Family_ID'] ?? d['Family_Code'] ?? d['Family_code'];
    _familyIdController.text = selectedFamilyId ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    _ageController.text = d['Age']?.toString() ?? '';
    
    if (d['Exam_Date'] != null) {
      if (d['Exam_Date'] is Timestamp) {
        examDate = (d['Exam_Date'] as Timestamp).toDate();
      } else {
        try {
          examDate = DateFormat('dd-MMM-yyyy').parse(d['Exam_Date'].toString());
        } catch (_) {}
      }
    }
    
    _firstNameController.text = d['Interviewer_s_Name_first_name'] ?? '';
    _lastNameController.text = d['Interviewer_s_Name_last_name'] ?? '';
    
    if (d['Date_of_Birth'] != null) {
      if (d['Date_of_Birth'] is Timestamp) {
        dateOfBirth = (d['Date_of_Birth'] as Timestamp).toDate();
      } else {
        try {
          dateOfBirth = DateFormat('dd-MMM-yyyy').parse(d['Date_of_Birth'].toString());
        } catch (_) {}
      }
    }
    
    selectedAttendedSchool = d['Have_you_attended_school'];
    _schoolLevelController.text = d['If_Yes_What_was_the_highest_level_attended'] ?? '';
    _occupationController.text = d['Occupation'] ?? '';
    _monthlyIncomeController.text = d['Monthly_Household_Income']?.toString() ?? '';
    _familyMembersCountController.text = d['Total_Number_of_household_living_at_home']?.toString() ?? '';
    _age1Controller.text = d['Age1']?.toString() ?? '';
    selectedMenopause = d['Menopause_Status'];
    selectedVIA = d['VIA_Examination_Result'];
    selectedTreatment = d['Treatment_Provided'];

    if (selectedFamilyId != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyId!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _registrationNumber.clear();
      _nameController.clear();
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
      selectedMenopause = null;
      selectedVIA = null;
      selectedTreatment = null;
      selectedVIA = null;
      selectedTreatment = null;
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
        'Family_ID': selectedFamilyId,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Age': int.tryParse(_ageController.text),
        'Exam_Date': examDate != null ? Timestamp.fromDate(examDate!) : null,
        'Interviewer_s_Name_first_name': _firstNameController.text,
        'Interviewer_s_Name_last_name': _lastNameController.text,
        'Date_of_Birth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
        'Have_you_attended_school': selectedAttendedSchool, // Changed key
        'If_Yes_What_was_the_highest_level_attended': _schoolLevelController.text, // Changed key
        'Occupation': _occupationController.text, // Changed key
        'Religion': selectedReligion,
        'Monthly_Household_Income': _monthlyIncomeController.text.isNotEmpty ? int.tryParse(_monthlyIncomeController.text) : null, // Changed key
        'Total_Number_of_household_living_at_home': _familyMembersCountController.text.isNotEmpty ? int.tryParse(_familyMembersCountController.text) : null, // Changed key
        'Marital_status': selectedMaritalStatus,
        'Age1': _age1Controller.text.isNotEmpty ? int.tryParse(_age1Controller.text) : null,
        'Menopause_Status': selectedMenopause,
        'VIA_Examination_Result': selectedVIA,
        'Treatment_Provided': selectedTreatment,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('cervical_screening').doc(_editDocId).update(data);
      } else if (widget.docId != null) {
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Cervical Screening', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade700, Colors.teal.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
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
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(_isEditMode ? 'Update Screening' : 'Submit Screening', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildIdentitySection() {
    return _buildSectionCard(
      title: 'Patient Identity',
      icon: Icons.person_outline,
      children: [
            _buildTextField('Registration Number', _registrationNumber),
            const SizedBox(height: 12),
            _buildTextField('Family Code', _familyIdController, onChanged: (v) {
              setState(() {
                selectedFamilyId = v;
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
            const SizedBox(height: 12),
            if (_isEditMode)
              _buildDropdown('Select Name to Edit', _existingRecords.map((r) => r['Name']?.toString() ?? 'Unknown').toList(), selectedMemberName, (v) {
                 final record = _existingRecords.firstWhere((r) => r['Name'] == v);
                 setState(() {
                   selectedMemberName = v;
                   _editDocId = record['id'];
                   _populateForm(record);
                 });
              }, isLoading: _isLoadingMembers)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField('Name', _nameController),
                  if (familyMemberNames.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDropdown('Pick from Family Members', familyMemberNames, null, _onNameSelected, isLoading: _isLoadingMembers),
                  ],
                ],
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
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return buildSectionCard(
      context: context,
      title: title,
      children: children,
      icon: icon,
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, String? hint, String? helper, Function(String)? onChanged}) {
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
          onChanged: onChanged,
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
