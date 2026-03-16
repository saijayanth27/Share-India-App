import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

class RefusedFormPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const RefusedFormPage({super.key, this.existingData, this.docId});

  @override
  State<RefusedFormPage> createState() => _RefusedFormPageState();
}

class _RefusedFormPageState extends State<RefusedFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;

  // Controllers
  final _registrationNumberController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _familyCodeController = TextEditingController();
  final _specifyOtherController = TextEditingController();

  // Selected Values
  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectedGender;
  DateTime? dateOfInterview = DateTime.now();
  String? selectedInterviewer;
  String? selectedRespondent;
  String? selectedReason;
  DateTime? deathDate;

  // Lists for Lookups
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};

  final List<String> interviewers = [
    "KIRANMAI K", "LAVANYA KASPOJU", "RAMADEVI Y", "REVATHI CH", "PUSHPA K", "KUSUMA",
    "CHV", "SHAKUNTHALA(CHV AT)", "ASHA", "HEMALATHA(CHV AT)", "LAXMI", "BHASKAR",
    "KUSUMA G", "KARUNAKAR", "KRISHNAVENI", "B JYOTHI", "MADHAVI(CHV GR)", "ANNAPURNA",
    "BALAMANI(CHV GR)", "SALOMI", "UDYASHREE", "JOHN", "BHASKAR K", "SUNITHA",
    "KOMARIAH", "MADAV"
  ];

  final List<String> respondents = [
    "Participant", "Family members", "Neighbors", "CHV", "TETRA Team"
  ];

  final List<String> withdrawalReasons = [
    "(1) Left the Village", "(2) Died", "(3) Double code", "(4) Not Interested / Refused"
  ];

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
          .collection('refused_form')
          .where('Family_code', isEqualTo: familyCode)
          .get();
      if (snapshot.docs.isEmpty) {
        // Fallback to old collection
        final oldSnapshot = await FirebaseFirestore.instance
            .collection('withdrawal_refusal_form')
            .where('Family_Code', isEqualTo: familyCode)
            .get();
        setState(() {
          _existingRecords = oldSnapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
        });
      } else {
        setState(() {
          _existingRecords = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
        });
      }
      setState(() => _isLoadingMembers = false);
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
      _registrationNumberController.text = baseData['Registration_Number']?.toString() ?? '';
      selectedGender = baseData['Gender']?.toString();
      _ageController.text = baseData['Age']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        final snapshot = await FirebaseFirestore.instance
            .collection('refused_form')
            .where('Family_code', isEqualTo: fCode)
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
        } else {
          // Fallback to withdrawal_refusal_form
          final oldSnapshot = await FirebaseFirestore.instance
              .collection('withdrawal_refusal_form')
              .where('Family_Code', isEqualTo: fCode)
              .where('Name', isEqualTo: name)
              .limit(1)
              .get();
          if (oldSnapshot.docs.isNotEmpty) {
            final doc = oldSnapshot.docs.first;
            setState(() {
              _editDocId = doc.id;
              final merged = {...?baseData, ...doc.data()};
              _populateForm(merged);
            });
          } else if (baseData != null) {
            _populateForm(baseData);
          }
        }
      } catch (e) {
        debugPrint('Error fetching refusal record: $e');
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
    _registrationNumberController.text = d['Registration_Number'] ?? '';
    selectedFamilyCode = d['Family_code'] ?? d['Family_Code'] ?? d['Family_ID'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    _ageController.text = d['Age']?.toString() ?? d['Age1']?.toString() ?? '';
    
    final rawInterviewDate = d['Date_of_Interview'] ?? d['Interview_Date'];
    if (rawInterviewDate != null) {
      if (rawInterviewDate is Timestamp) {
        dateOfInterview = rawInterviewDate.toDate();
      } else {
        try {
          dateOfInterview = DateFormat('dd-MMM-yyyy').parse(rawInterviewDate.toString());
        } catch (_) {
          try {
            dateOfInterview = DateTime.parse(rawInterviewDate.toString());
          } catch (_) {}
        }
      }
    }
    
    selectedInterviewer = d['Interviewer_s_Name'] ?? d['Interviewer_Name'];
    selectedRespondent = d['Respondent'];
    selectedReason = d['Reason_for_withdrawing_from_study'] ?? d['Reason'];
    final rawDeathDate = d['Death_Date'];
    if (rawDeathDate != null) {
      if (rawDeathDate is Timestamp) {
        deathDate = rawDeathDate.toDate();
      } else {
        try {
          deathDate = DateFormat('dd-MMM-yyyy').parse(rawDeathDate.toString());
        } catch (_) {
          deathDate = DateTime.tryParse(rawDeathDate.toString());
        }
      }
    }
    _specifyOtherController.text = d['other_reasons_specified'] ?? d['Specify_Other_Reason'] ?? '';

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _registrationNumberController.clear();
      _familyCodeController.clear();
      _nameController.clear();
      selectedFamilyCode = null;
      selectedMemberName = null;
      selectedGender = null;
      _ageController.clear();
      dateOfInterview = DateTime.now();
      selectedInterviewer = null;
      selectedRespondent = null;
      selectedReason = null;
      deathDate = null;
      _specifyOtherController.clear();
      familyMemberNames = [];
      _existingRecords = [];
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
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'Interviewer_s_Name': selectedInterviewer,
        'Respondent': selectedRespondent,
        'Reason_for_withdrawing_from_study': selectedReason,
        'Death_Date': deathDate != null ? Timestamp.fromDate(deathDate!) : null,
        'other_reasons_specified': _specifyOtherController.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('refused_form', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Refusal form updated! Syncing...' : 'Refusal form saved! Syncing...'),
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
      // Note: DataCacheService already triggers background sync via SyncService if online.
    } catch (e) {
      debugPrint('Error saving refusal form: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save refusal form.'),
          backgroundColor: Colors.red,
        ));
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
        title: const Text('Withdrawal Consent Form', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      title: 'Withdrawal / Refusal Details',
                      icon: Icons.cancel_outlined,
                      children: [
                        formSearchableDropdown(context, 'Information given by whom?', respondents, selectedRespondent, (v) => setState(() => selectedRespondent = v)),
                        const SizedBox(height: 16),
                        formSearchableDropdown(context, 'Reason for Withdrawal/Refusal', withdrawalReasons, selectedReason, (v) => setState(() => selectedReason = v)),
                        if (selectedReason == '(2) Died') ...[
                          const SizedBox(height: 12),
                          _buildDatePicker('Date of Death', deathDate, (v) => setState(() => deathDate = v)),
                        ],
                        if (selectedReason == '(4) Not Interested / Refused') ...[
                          const SizedBox(height: 12),
                          formTextField('Specify Other Reasons', _specifyOtherController, maxLines: 2),
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
      title: 'Member Identity',
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
        Row(
          children: [
            Expanded(child: formTextField('Age', _ageController, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Interview Date', dateOfInterview, (v) => setState(() => dateOfInterview = v))),
          ],
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(context, 'Interviewer Name', interviewers, selectedInterviewer, (v) => setState(() => selectedInterviewer = v)),
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
