import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';

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
    try {
      final snapshot = await FirebaseFirestore.instance.collection('client').get();
      final codes = snapshot.docs.map((doc) => doc.data()['family_id']?.toString()).whereType<String>().toSet().toList();
      setState(() {
        allFamilyCodes = codes..sort();
      });
    } catch (e) {
      debugPrint('Error fetching family codes: $e');
    }
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
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Personal Details'),
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
                    title: 'Identity & Registration',
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Family Code', border: OutlineInputBorder()),
                        value: selectedFamilyCode,
                        items: allFamilyCodes.map((code) => DropdownMenuItem(value: code, child: Text(code))).toList(),
                        onChanged: (v) {
                          setState(() {
                            selectedFamilyCode = v;
                            motherName = null;
                            fatherName = null;
                          });
                          if (v != null) _fetchMembersByFamily(v);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _spouseNo, decoration: const InputDecoration(labelText: 'Spouse', border: OutlineInputBorder(), hintText: '#######'), keyboardType: TextInputType.number)),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _mapNo, decoration: const InputDecoration(labelText: 'Map No.', border: OutlineInputBorder(), hintText: '#######'), keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _firstName, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), helperText: 'First Name')),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _gen, decoration: const InputDecoration(labelText: 'Gen', border: OutlineInputBorder(), hintText: '#######'), keyboardType: TextInputType.number)),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _siNo, decoration: const InputDecoration(labelText: 'SI No', border: OutlineInputBorder(), hintText: '#######'), keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: '(1) Male', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
                          Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: '(0) Female', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _regNo, decoration: const InputDecoration(labelText: 'Registration Number', border: OutlineInputBorder(), hintText: '#######', helperText: 'System will auto-generate or user input')),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Personal Info',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(context: context, initialDate: dateOfBirth ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
                                if (picked != null) setState(() => dateOfBirth = picked);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Date of Birth', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                                child: Text(dateOfBirth == null ? 'dd-MMM-yyyy' : DateFormat('dd-MMM-yyyy').format(dateOfBirth!)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _age, decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder(), hintText: '#######'), keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Live Status', border: OutlineInputBorder()),
                                  value: liveStatus,
                                  items: const [
                                    DropdownMenuItem(value: '(1) Alive', child: Text('(1) Alive')),
                                    DropdownMenuItem(value: '(0) Dead', child: Text('(0) Dead')),
                                  ],
                                  onChanged: (v) => setState(() => liveStatus = v),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'A/v Status', border: OutlineInputBorder()),
                                  value: avStatus,
                                  items: const [
                                    DropdownMenuItem(value: '(1) Active', child: Text('(1) Active')),
                                    DropdownMenuItem(value: '(0) Vacant', child: Text('(0) Vacant')),
                                  ],
                                  onChanged: (v) => setState(() => avStatus = v),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Marital Status', border: OutlineInputBorder()),
                                  value: maritalStatus,
                                  items: const [
                                    DropdownMenuItem(value: '(0) Unmarried', child: Text('(0) Unmarried', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: '(1) Married', child: Text('(1) Married', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: '(2) Divorce', child: Text('(2) Divorce', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: '(3) Widow', child: Text('(3) Widow', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: '(4) Not Eligible', child: Text('(4) Not Eligible', overflow: TextOverflow.ellipsis)),
                                  ],
                                  onChanged: (v) => setState(() => maritalStatus = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Education', border: OutlineInputBorder()),
                                  value: selectedEducation,
                                  items: [
                                    '(0) ILLITIRATE', '(1) CAN READ ONLY', '(2) CAN READ AND WRITE',
                                    '(3) PRIMARY SCHOOL', '(4) MIDDLE SCHOOL', '(5) HIGH SCHOOL',
                                    '(6) GRADUATE', '(7) POST GRADUATE'
                                  ].map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() => selectedEducation = v),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Occupation', border: OutlineInputBorder()),
                                  value: selectedOccupation,
                                  items: [
                                    '(1) HOUSE WIFE', '(2) AGRICULTURE', '(3) UNEMPLOYED', '(4)LABOUR',
                                    '(5) SELF-EMPLOYED', '(6) PRIVATE EMPLOYEE', '(7) ANGANWADI TEACHER',
                                    '(8) C.H.V', '(9) PENSION', '(10) GOVT EMPLOYEE', '(99) DONT KNOW'
                                  ].map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() => selectedOccupation = v),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(controller: _income, decoration: const InputDecoration(labelText: 'Income', border: OutlineInputBorder())),
                                const SizedBox(height: 16),
                                TextFormField(controller: _aadharNo, decoration: const InputDecoration(labelText: 'Aadhar No.', border: OutlineInputBorder())),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Relations',
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Mother Name',
                          border: const OutlineInputBorder(),
                          suffixIcon: _isLoadingFamily ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                        ),
                        value: motherName,
                        items: femaleMembers.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                        onChanged: (v) => setState(() => motherName = v),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Father Name',
                          border: const OutlineInputBorder(),
                          suffixIcon: _isLoadingFamily ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                        ),
                        value: fatherName,
                        items: maleMembers.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                        onChanged: (v) => setState(() => fatherName = v),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Relation with Head', border: OutlineInputBorder()),
                        value: relationWithHead,
                        items: const [
                          DropdownMenuItem(value: 'Self', child: Text('Self')),
                          DropdownMenuItem(value: 'Spouse', child: Text('Spouse')),
                          DropdownMenuItem(value: 'Son', child: Text('Son')),
                          DropdownMenuItem(value: 'Daughter', child: Text('Daughter')),
                          DropdownMenuItem(value: 'Father', child: Text('Father')),
                          DropdownMenuItem(value: 'Mother', child: Text('Mother')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (v) => setState(() => relationWithHead = v),
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
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _spouseNameText,
                          decoration: const InputDecoration(labelText: 'Spouse Name', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Marriage Type', border: OutlineInputBorder()),
                          value: marriageType,
                          items: const [
                            DropdownMenuItem(value: 'Arrange Marriage', child: Text('Arrange Marriage')),
                            DropdownMenuItem(value: 'Love Marriage', child: Text('Love Marriage')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (v) => setState(() => marriageType = v),
                          validator: (v) => showSpouseDetails && (v == null || v.isEmpty) ? 'Please select marriage type' : null,
                        ),
                      ],
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Diseases',
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
                                Text(d, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
}
