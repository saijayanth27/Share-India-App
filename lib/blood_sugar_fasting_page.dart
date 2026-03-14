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
  final _nameController = TextEditingController();
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
    _nameController.text = selectedName ?? '';
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
        familyMembers = allNames.toList()..sort();
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
          .collection('blood_sugar_fasting')
          .where('Family_code', isEqualTo: familyCode)
          .get();
      setState(() {
        _existingRecords = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error fetching records: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  void _onNameSelected(String? name) {
    setState(() {
      selectedName = name;
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
          selectedGender = data['Gender']?.toString();
          _age.text = data['Age']?.toString() ?? '';
        }
      }
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _registrationNumber.clear();
      _familyCodeController.clear();
      _nameController.clear();
      selectedFamilyCode = null;
      selectedName = null;
      selectedGender = null;
      _age.clear();
      dateOfInterview = DateTime.now();
      interviewersName = null;
      _otherReasonController.clear();
      _lastMealDateController.clear();
      _lastMealTimeController.clear();
      _fbsResultController.clear();
      _notDoneReason = null;
      familyMembers = [];
      _existingRecords = [];
    });
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final data = {
        'Registration_Number': _registrationNumber.text,
        'Family_code': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedName : _nameController.text,
        'Gender': selectedGender,
        'Age': int.tryParse(_age.text),
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'Interviewer_s_Name': interviewersName,
        'If_not_done_reason': _notDoneReason,
        'reason': _otherReasonController.text,
        'Date_of_Last_Meal': _lastMealDateController.text,
        'Time_of_Last_Meal': _lastMealTimeController.text,
        'FBS_Test_Result': double.tryParse(_fbsResultController.text),
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };
      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST
      await DataCacheService().saveOfflineSubmission('blood_sugar_fasting', data);

      // 2. Background Sync (Non-blocking)
      _performFastingSync(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Blood Sugar updated! Syncing...' : 'Blood Sugar saved! Syncing...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ));
        if (widget.docId != null) {
          Navigator.pop(context);
        } else if (!wasEditing) {
          _resetForm();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _performFastingSync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('blood_sugar_fasting').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('blood_sugar_fasting').add(data);
      }
    } catch (e) {
      debugPrint('Fasting Blood Sugar Background Sync Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Blood Sugar Form(After Eating)'),
        elevation: 0,
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('blood_sugar_fasting_scroll'),
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
                      onSave: _saveForm,
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
                      isSaving: _isLoading,
                    ),
                    const SizedBox(height: 16),
                    _buildIdentitySection(),
                    buildSectionCard(
                      context: context,
                      title: 'Blood Sugar Screening',
                      icon: Icons.bloodtype_outlined,
                      children: [
                        formSearchableDropdown(context, 
                          'If FBS not done, give reason',
                          _reasonList,
                          _notDoneReason,
                          (v) => setState(() => _notDoneReason = v),
                        ),
                        if (_notDoneReason == "(4) Other") ...[
                          const SizedBox(height: 12),
                          formTextField('If Others Please Mention', _otherReasonController),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: formTextField('Date of Last Meal', _lastMealDateController, hint: 'dd-MMM-yyyy')),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTimePicker('Time of Last Meal', _lastMealTimeController)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('(Note: Use 24-hour format)', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                        const SizedBox(height: 16),
                        formTextField('FBS Test Result (mg/dL)', _fbsResultController, keyboardType: TextInputType.number),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          if (_isLoading) // Assuming _isSaving refers to _isLoading
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildIdentitySection() {
    return buildSectionCard(
      context: context,
      title: 'Patient Identity',
      icon: Icons.person_outline,
      children: [
        formTextField('Registration Number', _registrationNumber),
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
          (<String>{...familyMembers, ..._existingRecords.map((r) => r['Name']?.toString() ?? '')}
              .where((n) => n.isNotEmpty)
              .toList()
            ..sort()),
          selectedName,
          _onNameSelected,
          isLoading: _isLoadingMembers,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField('Age', _age, keyboardType: TextInputType.number, hint: 'e.g. 45')),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Date of Interview', dateOfInterview, (v) => setState(() => dateOfInterview = v))),
          ],
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(
          context,
          'Interviewer’s Name',
          ['KIRANMAI K', 'REVATHI CH', 'RAMADEVI Y', 'LAVANYA KASPOJU', 'PUSHPA K', 'G RAMADEVI', 'BHASKAR K', 'ASHA', 'KUSUMA G', 'B JYOTHI', 'RAMADEVI G', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU'],
          interviewersName,
          (v) => setState(() => interviewersName = v),
        ),
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

  Widget _buildTimePicker(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
            if (picked != null) {
              final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              controller.text = formatted;
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: const Icon(Icons.access_time, size: 18),
            ),
            child: Text(controller.text.isEmpty ? 'HH:mm' : controller.text),
          ),
        ),
      ],
    );
  }
}
