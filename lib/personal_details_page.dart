import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

class PersonalDetailsPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const PersonalDetailsPage({super.key, this.existingData, this.docId});

  @override
  State<PersonalDetailsPage> createState() => _PersonalDetailsPageState();
}

class _PersonalDetailsPageState extends State<PersonalDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // --- Identity & Registration Controllers ---
  String? selectedFamilyCode;
  final _spouseNo = TextEditingController();
  final _mapNo = TextEditingController();
  final _newFamilyId = TextEditingController();
  final _serialNumber = TextEditingController();
  final _fatherRegNo = TextEditingController();
  final _parentsId = TextEditingController();
  final _relationCode = TextEditingController();
  final _firstName = TextEditingController();
  final _gen = TextEditingController();
  final _siNo = TextEditingController();
  String? selectedGender;
  final _birthWeight = TextEditingController();
  final _regNo = TextEditingController();

  // --- Personal Info Controllers ---
  DateTime? dateOfBirth;
  final _age = TextEditingController();
  String? liveStatus = '(1) Alive';
  String? selectedEducation;
  String? avStatus = '(1) Active';
  String? selectedOccupation;
  String? maritalStatus = '(0) Unmarried';
  final _income = TextEditingController();
  final _aadharNo = TextEditingController();

  // --- Relations Controllers ---
  String? motherName;
  String? fatherName;
  String? relationWithHead;
  bool showSpouseDetails = false;
  String? spouseNameLookup;
  final _spouseNameText = TextEditingController();
  String? marriageType;

  // Family Members for Dropdowns
  List<String> maleMembers = [];
  List<String> femaleMembers = [];
  List<String> allFamilyCodes = [];
  bool _isLoadingFamily = false;

  // --- Diseases (1) Yes / (2) No ---
  Map<String, String?> diseases = {
    'Asthma?': '(2) No',
    'Diabetes?': '(2) No',
    'Hypertensive?': '(2) No',
    'Thyroid?': '(2) No',
    'Malaria(last 6m)': '(2) No',
    'jaundice(last 6m)': '(2) No',
    'Panmasala(currently)': '(2) No',
    'Drink alcohol(currently)?': '(2) No',
    'Smoke (currently)?': '(2) No',
  };

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
    setState(() => _isLoadingFamily = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyCode)
          .get();

      final males = <String>[];
      final females = <String>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data['Name']?.toString() ?? '';
        final gender = data['Gender']?.toString() ?? '';
        if (gender.contains('(1) Male')) {
          males.add(name);
        } else if (gender.contains('(0) Female')) {
          females.add(name);
        }
      }

      setState(() {
        maleMembers = males..sort();
        femaleMembers = females..sort();
        _isLoadingFamily = false;
      });
    } catch (e) {
      debugPrint('Error fetching members: $e');
      setState(() => _isLoadingFamily = false);
    }
  }

  void _loadExistingData() {
    final d = widget.existingData!;
    setState(() {
      selectedFamilyCode = d['Family_Code'];
      _spouseNo.text = d['Spouse']?.toString() ?? '';
      _mapNo.text = d['Map_No']?.toString() ?? '';
      _newFamilyId.text = d['New_Family_ID'] ?? '';
      _serialNumber.text = d['Registration_Number1'] ?? '';
      _fatherRegNo.text = d['Father_Registration_Number'] ?? '';
      _parentsId.text = d['Parents_ID'] ?? '';
      _relationCode.text = d['Relation_Code'] ?? '';
      _firstName.text = d['Name'] ?? ''; // From subfields column_name: first_name
      _gen.text = d['Gen']?.toString() ?? '';
      _siNo.text = d['SI_No']?.toString() ?? '';
      selectedGender = d['Gender'];
      _birthWeight.text = d['Birth_weight']?.toString() ?? '';
      _regNo.text = d['uniq_Registration_Number']?.toString() ?? '';
      
      if (d['Date_of_Birth'] != null) {
        dateOfBirth = (d['Date_of_Birth'] as Timestamp).toDate();
      }
      _age.text = d['Age']?.toString() ?? '';
      liveStatus = d['Live_Status'] ?? '(1) Alive';
      selectedEducation = d['Education'];
      avStatus = d['A_v_Status'] ?? '(1) Active';
      selectedOccupation = d['Occupation'];
      maritalStatus = d['Marital_Status'] ?? '(0) Unmarried';
      _income.text = d['Income'] ?? '';
      _aadharNo.text = d['Aadhar_No1'] ?? '';

      motherName = d['Mother_Name'];
      fatherName = d['Father_Name'];
      relationWithHead = d['Relation_with_Head'];
      showSpouseDetails = d['Spouse_Details1'] ?? false;
      spouseNameLookup = d['Name2'];
      _spouseNameText.text = d['Name1'] ?? '';
      marriageType = d['Marriage_Type'];

      diseases['Asthma?'] = d['Asthma'] ?? '(2) No';
      diseases['Diabetes?'] = d['Diabetes'] ?? '(2) No';
      diseases['Hypertensive?'] = d['Hypertensive'] ?? '(2) No';
      diseases['Thyroid?'] = d['Thyroid'] ?? '(2) No';
      diseases['Malaria(last 6m)'] = d['Malaria_last_6m'] ?? '(2) No';
      diseases['jaundice(last 6m)'] = d['jaundice_last_6m'] ?? '(2) No';
      diseases['Panmasala(currently)'] = d['Panmasala_currently'] ?? '(2) No';
      diseases['Drink alcohol(currently)?'] = d['Drink_alcohol_currently'] ?? '(2) No';
      diseases['Smoke (currently)?'] = d['Smoke_currently'] ?? '(2) No';
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      selectedFamilyCode = null;
      _spouseNo.clear();
      _mapNo.clear();
      _newFamilyId.clear();
      _serialNumber.clear();
      _fatherRegNo.clear();
      _parentsId.clear();
      _relationCode.clear();
      _firstName.clear();
      _gen.clear();
      _siNo.clear();
      selectedGender = null;
      _birthWeight.clear();
      _regNo.clear();
      dateOfBirth = null;
      _age.clear();
      liveStatus = '(1) Alive';
      selectedEducation = null;
      avStatus = '(1) Active';
      selectedOccupation = null;
      maritalStatus = '(0) Unmarried';
      _income.clear();
      _aadharNo.clear();
      motherName = null;
      fatherName = null;
      relationWithHead = null;
      showSpouseDetails = false;
      spouseNameLookup = null;
      _spouseNameText.clear();
      marriageType = null;
      diseases.updateAll((key, value) => '(2) No');
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Family_Code': selectedFamilyCode,
        'Spouse': int.tryParse(_spouseNo.text),
        'Map_No': int.tryParse(_mapNo.text),
        'New_Family_ID': _newFamilyId.text,
        'Registration_Number1': _serialNumber.text,
        'Father_Registration_Number': _fatherRegNo.text,
        'Parents_ID': _parentsId.text,
        'Relation_Code': _relationCode.text,
        'Name': _firstName.text,
        'Gen': int.tryParse(_gen.text),
        'SI_No': int.tryParse(_siNo.text),
        'Gender': selectedGender,
        'Birth_weight': double.tryParse(_birthWeight.text),
        'uniq_Registration_Number': int.tryParse(_regNo.text),
        'Date_of_Birth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
        'Age': int.tryParse(_age.text),
        'Live_Status': liveStatus,
        'Education': selectedEducation,
        'A_v_Status': avStatus,
        'Occupation': selectedOccupation,
        'Marital_Status': maritalStatus,
        'Income': _income.text,
        'Aadhar_No1': _aadharNo.text,
        'Mother_Name': motherName,
        'Father_Name': fatherName,
        'Relation_with_Head': relationWithHead,
        'Spouse_Details1': showSpouseDetails,
        'Name2': spouseNameLookup,
        'Name1': _spouseNameText.text,
        'Marriage_Type': marriageType,
        'Asthma': diseases['Asthma?'],
        'Diabetes': diseases['Diabetes?'],
        'Hypertensive': diseases['Hypertensive?'],
        'Thyroid': diseases['Thyroid?'],
        'Malaria_last_6m': diseases['Malaria(last 6m)'],
        'jaundice_last_6m': diseases['jaundice(last 6m)'],
        'Panmasala_currently': diseases['Panmasala(currently)'],
        'Drink_alcohol_currently': diseases['Drink_alcohol_currently?'],
        'Smoke_currently': diseases['Smoke (currently)?'],
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('personal_details').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('personal_details').add(data);
      }

      if (mounted) {
        // Update local cache so this person appears in dropdowns immediately
        DataCacheService().addGeneratedDetail(data);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Personal details saved successfully!'), backgroundColor: Colors.green),
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

  Widget _buildRadioGroup(String title, String key, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ...options.map((opt) => RadioListTile<String>(
              title: Text(opt),
              value: opt,
              groupValue: (key == 'Gender') ? selectedGender : (key == 'Live_Status' ? liveStatus : (key == 'A_v_Status' ? avStatus : maritalStatus)),
              onChanged: (val) {
                setState(() {
                  if (key == 'Gender') selectedGender = val;
                  else if (key == 'Live_Status') liveStatus = val;
                  else if (key == 'A_v_Status') avStatus = val;
                  else maritalStatus = val;
                });
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Personal Details', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade700, Colors.blue.shade600],
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
                padding: const EdgeInsets.all(20),
                children: [
                  buildHeader(
                    context: context,
                    title: 'Personal Details',
                    subtitle: 'Register and manage individual member health profiles',
                  ),
                  buildSectionCard(
                    context: context,
                    title: 'Identity & Registration',
                    icon: Icons.fingerprint_outlined,
                    children: [
                      _buildDropdown('Family Code', allFamilyCodes, selectedFamilyCode, (v) {
                        setState(() {
                          selectedFamilyCode = v;
                          motherName = null;
                          fatherName = null;
                        });
                        if (v != null) _fetchMembersByFamily(v);
                      }),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Spouse', _spouseNo, keyboardType: TextInputType.number, hint: '#######')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Map No.', _mapNo, keyboardType: TextInputType.number, hint: '#######')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField('Name', _firstName, helper: 'First Name'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Gen', _gen, keyboardType: TextInputType.number, hint: '#######')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('SI No', _siNo, keyboardType: TextInputType.number, hint: '#######')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: '(1) Male', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
                          Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: '(0) Female', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField('Registration Number', _regNo, hint: '#######', helper: 'System will auto-generate or user input'),
                    ],
                  ),
                  buildSectionCard(
                    context: context,
                    title: 'Personal Info',
                    icon: Icons.person_outline,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDatePicker('Date of Birth', dateOfBirth, (v) => setState(() => dateOfBirth = v))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Age', _age, keyboardType: TextInputType.number, hint: '#######')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _buildDropdown('Live Status', ['(1) Alive', '(0) Dead'], liveStatus, (v) => setState(() => liveStatus = v)),
                                const SizedBox(height: 12),
                                _buildDropdown('A/v Status', ['(1) Active', '(0) Vacant'], avStatus, (v) => setState(() => avStatus = v)),
                                const SizedBox(height: 12),
                                _buildDropdown(
                                  'Marital Status',
                                  ['(0) Unmarried', '(1) Married', '(2) Divorce', '(3) Widow', '(4) Not Eligible'],
                                  maritalStatus,
                                  (v) => setState(() => maritalStatus = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                _buildDropdown(
                                  'Education',
                                  [
                                    '(0) ILLITIRATE', '(1) CAN READ ONLY', '(2) CAN READ AND WRITE',
                                    '(3) PRIMARY SCHOOL', '(4) MIDDLE SCHOOL', '(5) HIGH SCHOOL',
                                    '(6) GRADUATE', '(7) POST GRADUATE'
                                  ],
                                  selectedEducation,
                                  (v) => setState(() => selectedEducation = v),
                                ),
                                const SizedBox(height: 12),
                                _buildDropdown(
                                  'Occupation',
                                  [
                                    '(1) HOUSE WIFE', '(2) AGRICULTURE', '(3) UNEMPLOYED', '(4)LABOUR',
                                    '(5) SELF-EMPLOYED', '(6) PRIVATE EMPLOYEE', '(7) ANGANWADI TEACHER',
                                    '(8) C.H.V', '(9) PENSION', '(10) GOVT EMPLOYEE', '(99) DONT KNOW'
                                  ],
                                  selectedOccupation,
                                  (v) => setState(() => selectedOccupation = v),
                                ),
                                const SizedBox(height: 12),
                                _buildTextField('Income', _income),
                                const SizedBox(height: 12),
                                _buildTextField('Aadhar No.', _aadharNo),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  buildSectionCard(
                    context: context,
                    title: 'Relations',
                    icon: Icons.family_restroom_outlined,
                    children: [
                      _buildDropdown('Mother Name', femaleMembers, motherName, (v) => setState(() => motherName = v), isLoading: _isLoadingFamily),
                      const SizedBox(height: 12),
                      _buildDropdown('Father Name', maleMembers, fatherName, (v) => setState(() => fatherName = v), isLoading: _isLoadingFamily),
                      const SizedBox(height: 12),
                      _buildDropdown(
                        'Relation with Head',
                        ['Self', 'Spouse', 'Son', 'Daughter', 'Father', 'Mother', 'Other'],
                        relationWithHead,
                        (v) => setState(() => relationWithHead = v),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text('Spouse Details'),
                        value: showSpouseDetails,
                        onChanged: (v) => setState(() => showSpouseDetails = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (showSpouseDetails) ...[
                        const SizedBox(height: 12),
                        _buildTextField('Spouse Name', _spouseNameText),
                        const SizedBox(height: 12),
                        _buildDropdown(
                          'Marriage Type',
                          ['Arrange Marriage', 'Love Marriage', 'Other'],
                          marriageType,
                          (v) => setState(() => marriageType = v),
                        ),
                      ],
                    ],
                  ),
                  buildSectionCard(
                    context: context,
                    title: 'Diseases',
                    icon: Icons.health_and_safety_outlined,
                    children: [
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: diseases.keys.map((d) {
                          return SizedBox(
                            width: (MediaQuery.of(context).size.width - 64) / 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                RadioListTile<String>(
                                  title: const Text('(1) Yes', style: TextStyle(fontSize: 12)),
                                  value: '(1) Yes',
                                  groupValue: diseases[d],
                                  onChanged: (v) => setState(() => diseases[d] = v),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                                RadioListTile<String>(
                                  title: const Text('(2) No', style: TextStyle(fontSize: 12)),
                                  value: '(2) No',
                                  groupValue: diseases[d],
                                  onChanged: (v) => setState(() => diseases[d] = v),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Add Family Member', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _resetForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, String? hint, String? helper, int maxLines = 1}) {
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
          maxLines: maxLines,
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
