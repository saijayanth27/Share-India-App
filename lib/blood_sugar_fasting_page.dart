import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

class BloodSugarFastingPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const BloodSugarFastingPage({super.key, this.existingData, this.docId});

  @override
  State<BloodSugarFastingPage> createState() => _BloodSugarFastingPageState();
}

class _BloodSugarFastingPageState extends State<BloodSugarFastingPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];

  // --- Identity Fields ---
  final _registrationNumber = TextEditingController();
  final _familyCodeController = TextEditingController();
  String? selectedFamilyCode;
  String? selectedName;
  String? selectedGender;
  final _age = TextEditingController();
  DateTime? dateOfInterview = DateTime.now();
  String? interviewersName;

  final _otherReasonController = TextEditingController();
  final _lastMealDateController = TextEditingController();
  final _lastMealTimeController = TextEditingController();
  final _fbsResultController = TextEditingController();

  String? _notDoneReason;

  List<String> allFamilyCodes = [];
  List<String> familyMembers = []; // List of names
  Map<String, Map<String, dynamic>> _allMembersData = {}; // Full details
  bool _isLoadingMembers = false;

  final List<String> _reasonList = [
    "(1) Not available",
    "(2) Refused for current visit",
    "(3) Door Locked",
    "(4) Other"
  ];

  @override
  void initState() {
    super.initState();
    _fetchFamilyCodes();
    if (widget.existingData != null) {
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    setState(() {
      _populateForm(widget.existingData!);
    });
  }

  void _populateForm(Map<String, dynamic> d) {
    _registrationNumber.text = d['Registration_Number']?.toString() ?? '';
    selectedFamilyCode = d['Family_code'] ?? d['Family_Code_Creation'] ?? d['Family_Code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedName = d['Name'];
    selectedGender = d['Gender'];
    _age.text = d['Age']?.toString() ?? '';
    if (d['Date_of_Interview'] != null) {
      if (d['Date_of_Interview'] is Timestamp) {
        dateOfInterview = (d['Date_of_Interview'] as Timestamp).toDate();
      } else {
        try {
          dateOfInterview = DateFormat('dd-MMM-yyyy').parse(d['Date_of_Interview'].toString());
        } catch (_) {}
      }
    }
    interviewersName = d['Interviewer_s_Name'];
    _notDoneReason = d['If_not_done_reason'];
    _otherReasonController.text = d['reason'] ?? '';
    _lastMealDateController.text = d['Date_of_Last_Meal'] ?? '';
    _lastMealTimeController.text = d['Time_of_Last_Meal'] ?? '';
    _fbsResultController.text = d['FBS_Test_Result']?.toString() ?? '';

    if (selectedFamilyCode != null && familyMembers.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
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
          .collection('blood_sugar_fasting')
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

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final formData = {
      'Registration_Number': _registrationNumber.text,
      'Family_code': selectedFamilyCode,
      'Name': selectedName,
      'Gender': selectedGender,
      'Age': _age.text,
      'Date_of_Interview': dateOfInterview != null ? DateFormat('dd-MMM-yyyy').format(dateOfInterview!) : '',
      'Interviewer_s_Name': interviewersName,
      'If_not_done_reason': _notDoneReason,
      'reason': _otherReasonController.text,
      'Date_of_Last_Meal': _lastMealDateController.text,
      'Time_of_Last_Meal': _lastMealTimeController.text,
      'FBS_Test_Result': _fbsResultController.text,
      'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      'needs_zoho_sync': true,
    };

    try {
      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('blood_sugar_fasting').doc(_editDocId).update(formData);
      } else if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('blood_sugar_fasting').doc(widget.docId).update(formData);
      } else {
        await FirebaseFirestore.instance.collection('blood_sugar_fasting').add(formData);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form saved successfully!')));
        if (widget.docId != null || _isEditMode) {
          Navigator.pop(context);
        } else {
          _resetForm();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      _notDoneReason = null;
      _otherReasonController.clear();
      _lastMealDateController.clear();
      _lastMealTimeController.clear();
      _fbsResultController.clear();
      familyMembers = [];
      _existingRecords = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Sugar Form', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700, Colors.red.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildHeader(
                context: context,
                title: 'Blood Sugar Monitoring',
                subtitle: 'Track blood glucose levels after meals',
              ),
              _buildIdentitySection(),
              buildSectionCard(
                context: context,
                title: 'Screening Status',
                icon: Icons.assignment_turned_in_outlined,
                children: [
                   _buildRadioGroup('If not done, reason', ['(1) Not available', '(2) Refused for current visit', '(3) Door Locked', '(4) Other'], _notDoneReason, (val) => setState(() => _notDoneReason = val)),
                   if (_notDoneReason == '(4) Other') ...[
                     const SizedBox(height: 12),
                     _buildTextField('If Others Please Mention', _otherReasonController),
                   ],
                ],
              ),
              buildSectionCard(
                context: context,
                title: 'Test Results',
                icon: Icons.biotech_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildDatePicker('Date of Last Meal', _lastMealDateController.text.isEmpty ? null : DateFormat('dd-MMM-yyyy').parse(_lastMealDateController.text), (v) => setState(() => _lastMealDateController.text = DateFormat('dd-MMM-yyyy').format(v)))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTimePicker('Time of Last Meal', _lastMealTimeController)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('(Note: Use 24-hour format)', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                  const SizedBox(height: 16),
                  _buildTextField('FBS Test Result (mg/dL)', _fbsResultController, keyboardType: TextInputType.number),
                ],
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_isEditMode ? 'Update' : 'Submit', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, int maxLines = 1, String? hint, Function(String)? onChanged}) {
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

  Widget _buildRadioGroup(String title, List<String> options, String? currentValue, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ...options.map((opt) => RadioListTile<String>(
          title: Text(opt, style: const TextStyle(fontSize: 13)),
          value: opt,
          groupValue: currentValue,
          onChanged: (val) => val != null ? onChanged(val) : null,
          contentPadding: EdgeInsets.zero,
          dense: true,
        )),
      ],
    );
  }

  Widget _buildTimePicker(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
            if (picked != null) {
              final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              controller.text = formatted;
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: Icon(Icons.access_time, size: 18),
            ),
            child: Text(controller.text.isEmpty ? 'HH:mm' : controller.text),
          ),
        ),
      ],
    );
  }
}
