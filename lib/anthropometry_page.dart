import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

class AnthropometryPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const AnthropometryPage({super.key, this.existingData, this.docId});

  @override
  State<AnthropometryPage> createState() => _AnthropometryPageState();
}

class _AnthropometryPageState extends State<AnthropometryPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoading = false;

  // --- Controllers & State Variables ---
  final _registrationNumber = TextEditingController();
  final _familyCodeController = TextEditingController();
  String? selectedFamilyCode;
  String? selectedName;
  String? selectedGender;
  final _age = TextEditingController();
  DateTime? dateOfInterview = DateTime.now();
  String? interviewersName;

  final _waistMeasurement = TextEditingController();
  final _weight = TextEditingController();
  final _hipMeasurement = TextEditingController();
  final _height = TextEditingController();
  final _otherDetails = TextEditingController();
  final _notDoneOther = TextEditingController();

  String? notDoneReason;
  String? chvName;

  List<String> allFamilyCodes = [];
  List<String> familyMembers = [];
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
        familyMembers = allNames.toList()..sort();
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
          .collection('anthropometry')
          .where('Family_code', isEqualTo: familyCode)
          .get();
      
      if (snapshot.docs.isEmpty) {
        final snapshot2 = await FirebaseFirestore.instance
            .collection('anthropometry')
            .where('Family_ID', isEqualTo: familyCode)
            .get();
        setState(() {
          _existingRecords = snapshot2.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
        });
      } else {
        setState(() {
          _existingRecords = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
        });
      }
      setState(() => _isLoadingMembers = false);
    } catch (e) {
      debugPrint('Error fetching existing records: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  void _onNameSelected(String? name) async {
    setState(() {
      selectedName = name;
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
          selectedGender = data['Gender']?.toString();
          _age.text = data['Age']?.toString() ?? '';
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
    _registrationNumber.text = d['Registration_Number']?.toString() ?? '';
    selectedFamilyCode = d['Family_ID'] ?? d['Family_code'] ?? d['Family_Code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedName = d['Name'];
    selectedGender = d['Gender'];
    _age.text = d['Age']?.toString() ?? '';
    interviewersName = d['Interviewer_s_Name'];
    if (d['Date_of_Interview'] != null) {
      if (d['Date_of_Interview'] is Timestamp) {
        dateOfInterview = (d['Date_of_Interview'] as Timestamp).toDate();
      } else {
        try {
          dateOfInterview = DateFormat('dd-MMM-yyyy').parse(d['Date_of_Interview'].toString());
        } catch (_) {}
      }
    }
    notDoneReason = d['If_not_done_reason'];
    _notDoneOther.text = d['If_Other_please_mention'] ?? '';
    chvName = d['CHV'];
    _waistMeasurement.text = d['Waist_Measurement']?.toString() ?? '';
    _weight.text = d['weight']?.toString() ?? '';
    _hipMeasurement.text = d['Hip_Measurement']?.toString() ?? '';
    _height.text = d['Height']?.toString() ?? '';
    _otherDetails.text = d['Other_Details'] ?? '';

    if (selectedFamilyCode != null && familyMembers.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number': _registrationNumber.text,
        'Family_ID': selectedFamilyCode,
        'Family_code': selectedFamilyCode,
        'Name': selectedName,
        'Gender': selectedGender,
        'Age': int.tryParse(_age.text),
        'Interviewer_s_Name': interviewersName,
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'If_not_done_reason': notDoneReason,
        'If_Other_please_mention': _notDoneOther.text,
        'CHV': chvName,
        'Waist_Measurement': double.tryParse(_waistMeasurement.text),
        'weight': double.tryParse(_weight.text),
        'Hip_Measurement': double.tryParse(_hipMeasurement.text),
        'Height': double.tryParse(_height.text),
        'Other_Details': _otherDetails.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('anthropometry').doc(_editDocId).update(data);
      } else if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('anthropometry').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('anthropometry').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anthropometry records saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
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

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      if (!_isEditMode) {
        _familyCodeController.clear();
        selectedFamilyCode = null;
      }
      _registrationNumber.clear();
      selectedName = null;
      selectedGender = null;
      _age.clear();
      dateOfInterview = DateTime.now();
      notDoneReason = null;
      _notDoneOther.clear();
      _waistMeasurement.clear();
      _weight.clear();
      _hipMeasurement.clear();
      _height.clear();
      _otherDetails.clear();
      familyMembers = [];
      _existingRecords = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Anthropometry Form', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.brown.shade700, Colors.brown.shade400],
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
                    title: 'Anthropometry Measurement',
                    subtitle: 'Track physical measurements and body metrics',
                  ),
                  _buildIdentitySection(),
                  buildSectionCard(
                    context: context,
                    title: 'Interview Details',
                    icon: Icons.assignment_outlined,
                    children: [
                      _buildDropdown(
                        'If not done, reason',
                        ['(1) Not available', '(2) Refused for current visit', '(3) Door Locked', '(4) Other'],
                        notDoneReason,
                        (v) => setState(() => notDoneReason = v),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField('If Other please mention', _notDoneOther),
                      const SizedBox(height: 12),
                      _buildTextField('CHV', TextEditingController(text: chvName)), // Read-only or editable?
                    ],
                  ),
                  buildSectionCard(
                    context: context,
                    title: 'Measurements',
                    icon: Icons.straighten_outlined,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Waist Measurement (cm)', _waistMeasurement, keyboardType: TextInputType.number)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Weight (kg)', _weight, keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Hip Measurement (cm)', _hipMeasurement, keyboardType: TextInputType.number)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Height (cm)', _height, keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField('Other Details', _otherDetails, maxLines: 3),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_isEditMode ? 'Update Assessment' : 'Save Assessment', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildIdentitySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                Text('Patient Identity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              ],
            ),
            const Divider(height: 24),
            _buildTextField('Registration Number', _registrationNumber),
            const SizedBox(height: 12),
            _buildTextField('Family Code', _familyCodeController, onChanged: (v) {
              setState(() {
                selectedFamilyCode = v;
                selectedName = null;
                familyMembers = [];
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
               _buildDropdown('Select Name to Edit', _existingRecords.map((r) => r['Name']?.toString() ?? 'Unknown').toList(), selectedName, (v) {
                 final record = _existingRecords.firstWhere((r) => r['Name'] == v);
                 setState(() {
                   selectedName = v;
                   _editDocId = record['id'];
                   _populateForm(record);
                 });
               }, isLoading: _isLoadingMembers)
            else
              _buildDropdown('Name', familyMembers, selectedName, _onNameSelected, isLoading: _isLoadingMembers),
            const SizedBox(height: 12),
            const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
            Row(
              children: [
                Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: '(1) Male', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
                Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: '(0) Female', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTextField('Age', _age, keyboardType: TextInputType.number, hint: 'e.g. 45')),
                const SizedBox(width: 12),
                Expanded(child: _buildDatePicker('Date of Interview', dateOfInterview, (v) => setState(() => dateOfInterview = v))),
              ],
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              'Interviewer’s Name',
              ['KIRANMAI K', 'REVATHI CH', 'RAMADEVI Y', 'LAVANYA KASPOJU', 'PUSHPA K', 'G RAMADEVI', 'BHASKAR K', 'ASHA', 'KUSUMA G', 'B JYOTHI', 'RAMADEVI G', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU'],
              interviewersName,
              (v) => setState(() => interviewersName = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, String? hint, String? helper, int maxLines = 1, Function(String)? onChanged}) {
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
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? selectedValue, Function(String?) onChanged, {bool isLoading = false, String? hint = '-Select-'}) {
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
          hint: hint != null ? Text(hint) : null,
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
