import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';
import 'language_provider.dart';

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
  bool _isLoadingMembers = false;

  // --- Controllers ---
  final _nameController = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _familyIdController = TextEditingController(text: 'TSRRMED');
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
  DateTime? examDate = DateTime.now();
  DateTime? dateOfBirth;
  String? selectedAttendedSchool;
  String? selectedReligion;
  String? selectedMaritalStatus;
  String? selectedMenopause;
  String? selectedVIA;
  String? selectedTreatment;

  // Lookup Options
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};

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
        selectedFamilyId = familyCode;
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
          .collection('cervical_screening')
          .where('Family_ID', isEqualTo: familyCode)
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

  void _onNameSelected(String? name) async {
    setState(() {
      selectedMemberName = name;
      _nameController.text = name ?? '';
    });
    
    if (name == null) return;

    final baseData = _allMembersData[name];
    if (baseData != null && !_isEditMode) {
      _registrationNumber.text = (baseData['uniq_Registration_Number'] ?? baseData['Registration_Number'] ?? baseData['Registration_Number1'] ?? '').toString();
      selectedGender = baseData['Gender']?.toString();
      _ageController.text = baseData['Age']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyIdController.text.trim();
        final snapshot = await FirebaseFirestore.instance
            .collection('cervical_screening')
            .where('Family_ID', isEqualTo: fCode)
            .where('Name', isEqualTo: name)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          setState(() {
            _editDocId = doc.id;
            final merged = {...?baseData, ...doc.data()};
            _populateForm(merged);
          });
        } else if (baseData != null) {
          _populateForm(baseData);
        }
      } catch (e) {
        debugPrint('Error fetching cervical screening: $e');
        if (baseData != null) _populateForm(baseData);
      } finally {
        if (mounted) setState(() => _isLoadingMembers = false);
      }
    }
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
    
    final rawExamDate = d['Exam_Date'];
    if (rawExamDate != null) {
      if (rawExamDate is Timestamp) {
        examDate = rawExamDate.toDate();
      } else {
        try {
          examDate = DateFormat('dd-MMM-yyyy').parse(rawExamDate.toString());
        } catch (_) {
          try {
            examDate = DateTime.parse(rawExamDate.toString());
          } catch (_) {}
        }
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
      _familyIdController.clear();
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
        'Family_ID': selectedFamilyId ?? _familyIdController.text,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Age': int.tryParse(_ageController.text),
        'Exam_Date': examDate != null ? Timestamp.fromDate(examDate!) : null,
        'Interviewer_s_Name_first_name': _firstNameController.text,
        'Interviewer_s_Name_last_name': _lastNameController.text,
        'Date_of_Birth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
        'Have_you_attended_school': selectedAttendedSchool,
        'If_Yes_What_was_the_highest_level_attended': _schoolLevelController.text,
        'Occupation': _occupationController.text,
        'Religion': selectedReligion,
        'Monthly_Household_Income': _monthlyIncomeController.text.isNotEmpty ? int.tryParse(_monthlyIncomeController.text) : null,
        'Total_Number_of_household_living_at_home': _familyMembersCountController.text.isNotEmpty ? int.tryParse(_familyMembersCountController.text) : null,
        'Marital_status': selectedMaritalStatus,
        'Age1': _age1Controller.text.isNotEmpty ? int.tryParse(_age1Controller.text) : null,
        'Menopause_Status': selectedMenopause,
        'VIA_Examination_Result': selectedVIA,
        'Treatment_Provided': selectedTreatment,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('cervical_screening', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? tr('Screening updated! Syncing...') : tr('Screening saved! Syncing...')),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ));
        if (widget.docId != null) {
          Navigator.pop(context);
        } else if (!wasEditing) {
          _resetForm();
        }
      }

      // 2. Background Sync (Non-blocking)
      _performScreeningSync(data);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Error saving')}: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _performScreeningSync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('cervical_screening').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('cervical_screening').add(data);
      }
    } catch (e) {
      debugPrint('Screening Background Sync Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageProvider.instance.isTeluguNotifier,
      builder: (context, isTelugu, _) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(tr('Cervical Screening'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                          final code = _familyIdController.text.trim();
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
                      title: tr('Socio-Demographic Details'),
                      icon: Icons.info_outline,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildDatePicker(tr('Date of Birth'), dateOfBirth, (v) {
                              setState(() {
                                dateOfBirth = v;
                                final age = DateTime.now().year - v.year;
                                _age1Controller.text = age.toString();
                              });
                            })),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField(tr('Age'), _age1Controller, keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(tr('Have you ever attended school?'), style: const TextStyle(fontWeight: FontWeight.w500)),
                        Row(
                          children: [
                            Expanded(child: RadioListTile<String>(title: Text(tr('Yes')), value: 'Yes', groupValue: selectedAttendedSchool, onChanged: (v) => setState(() => selectedAttendedSchool = v), contentPadding: EdgeInsets.zero, dense: true)),
                            Expanded(child: RadioListTile<String>(title: Text(tr('No')), value: 'No', groupValue: selectedAttendedSchool, onChanged: (v) => setState(() => selectedAttendedSchool = v), contentPadding: EdgeInsets.zero, dense: true)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        formTextField(tr('Highest level of school completed?'), _schoolLevelController),
                        const SizedBox(height: 16),
                        formTextField(tr('What is your occupation?'), _occupationController),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: formSearchableDropdown(context, tr('Religion'), ['Hindu', 'Muslim', 'Christian', 'Others'], selectedReligion, (v) => setState(() => selectedReligion = v))),
                            const SizedBox(width: 12),
                            Expanded(child: formSearchableDropdown(context, tr('Marital status'), ['Single', 'Married', 'Widowed', 'Divorced'], selectedMaritalStatus, (v) => setState(() => selectedMaritalStatus = v))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: formTextField(tr('Total monthly income (Rs.)'), _monthlyIncomeController, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField(tr('Family members count'), _familyMembersCountController, keyboardType: TextInputType.number)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
    });
  }

  Widget _buildIdentitySection() {
    return buildSectionCard(
      context: context,
      title: tr('Patient Identity'),
      icon: Icons.person_outline,
      children: [
        formTextField(
          tr('Registration Number'),
          _registrationNumber,
          validator: (v) => (v == null || v.isEmpty) ? tr('Required') : null,
        ),
        const SizedBox(height: 12),
        formSearchField(
          tr('Family Code'),
          _familyIdController,
          onSearch: () {
            if (_familyIdController.text.isNotEmpty) {
              _fetchMembersByFamily(_familyIdController.text);
              _fetchExistingRecords(_familyIdController.text);
            }
          },
          isLoading: _isLoadingMembers,
          validator: (v) => (v == null || v.isEmpty) ? tr('Required') : null,
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(
          context,
          tr('Name'),
          (<String>{...familyMemberNames, ..._existingRecords.map((r) => r['Name']?.toString() ?? '')}
              .where((n) => n.isNotEmpty)
              .toList()
            ..sort()),
          selectedMemberName,
          _onNameSelected,
          isLoading: _isLoadingMembers,
          validator: (v) => (v == null || v.isEmpty) ? tr('Required') : null,
        ),
        const SizedBox(height: 12),
        Text(tr('Gender'), style: const TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: Text(tr('(1) Male')), value: 'Male', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: Text(tr('(0) Female')), value: 'Female', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField(
              tr('Age (years)'),
              _ageController,
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.isEmpty) ? tr('Required') : null,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker(tr('Exam Date'), examDate, (v) => setState(() => examDate = v))),
          ],
        ),
        const SizedBox(height: 16),
        Text(tr("Interviewer's Name"), style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: formTextField(tr('First Name'), _firstNameController)),
            const SizedBox(width: 12),
            Expanded(child: formTextField(tr('Last Name'), _lastNameController)),
          ],
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
            child: Text(selectedDate == null ? tr('Select Date') : DateFormat('dd-MMM-yyyy').format(selectedDate)),
          ),
        ),
      ],
    );
  }
}
