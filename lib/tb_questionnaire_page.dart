import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'data_cache_service.dart';
import 'widget.dart';

class TBQuestionnairePage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const TBQuestionnairePage({super.key, this.existingData, this.docId});

  @override
  State<TBQuestionnairePage> createState() => _TBQuestionnairePageState();
}

class _TBQuestionnairePageState extends State<TBQuestionnairePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;

  // --- Main Form Controllers & State ---
  final _nameController = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _familyCodeController = TextEditingController();
  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectedGender;
  final _ageController = TextEditingController();
  DateTime? interviewDate = DateTime.now();
  String? selectedInterviewer;
  String? selectedReason;

  // Questions State (Yes/No)
  Map<String, String?> answers = {
    'cough_2wks': '(2) No',
    'fever_2wks': '(2) No',
    'weight_loss': '(2) No',
    'night_sweats': '(2) No',
    'haemoptysis': '(2) No',
    'tb_before': '(2) No',
    'tb_exposure': '(2) No',
    'respiratory_history': '(2) No',
    'recent_infection': '(2) No',
    'crowded_places': '(2) No',
    'tb_household': '(2) No',
    'healthcare_work': '(2) No',
    'high_risk_env': '(2) No',
    'smoking': '(2) No',
    'alcohol': '(2) No',
    'recent_tests': '(2) No',
  };

  final _tbDetailsController = TextEditingController();
  final _respiratoryDetailsController = TextEditingController();

  // Dropdown Options
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};

  final List<String> interviewers = [
    "KIRANMAI K", "REVATHI CH", "RAMADEVI Y", "LAVANYA KASPOJU", "PUSHPA K",
    "G RAMADEVI", "BHASKAR K", "ASHA", "KUSUMA G", "B JYOTHI", "RAMADEVI G",
    "LAVANYA METU", "N POOJA", "POOJA N", "K BHASKAR", "LAVANYA M", "LAVANYA METTU"
  ];

  final List<String> reasons = [
    "(1) Not available", "(2) Refused for current visit", "(3) Door Locked", "(4) Other"
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
      for (var doc in snapshot.docs) {
        processMember(doc.data());
      }
      for (var local in localMembers) {
        processMember(local);
      }
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
          .collection('tb_questionnaire')
          .where('Family_Code', isEqualTo: familyCode)
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
    selectedFamilyCode = d['Family_Code'] ?? d['Family_code'] ?? d['Family_ID'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    _ageController.text = d['Age']?.toString() ?? '';
    
    if (d['Interview_Date'] != null) {
      if (d['Interview_Date'] is Timestamp) {
        interviewDate = (d['Interview_Date'] as Timestamp).toDate();
      } else {
        try {
          interviewDate = DateFormat('dd-MMM-yyyy').parse(d['Interview_Date'].toString());
        } catch (_) {}
      }
    }
    
    selectedInterviewer = d['Interviewer_Name'];
    selectedReason = d['Reason'];
    
    final savedAnswers = d['Answers'] as Map<String, dynamic>?;
    if (savedAnswers != null) {
      savedAnswers.forEach((key, value) {
        if (answers.containsKey(key)) {
          answers[key] = value?.toString();
        }
      });
    }
    
    _tbDetailsController.text = d['TB_Details'] ?? '';
    _respiratoryDetailsController.text = d['Respiratory_Details'] ?? '';

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _registrationNumber.clear();
      _familyCodeController.clear();
      _nameController.clear();
      selectedFamilyCode = null;
      selectedMemberName = null;
      selectedGender = null;
      _ageController.clear();
      interviewDate = DateTime.now();
      selectedInterviewer = null;
      selectedReason = null;
      answers.updateAll((key, value) => '(2) No');
      _tbDetailsController.clear();
      _respiratoryDetailsController.clear();
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
        'Family_Code': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Age': int.tryParse(_ageController.text),
        'Interview_Date': interviewDate != null ? Timestamp.fromDate(interviewDate!) : null,
        'Interviewer_Name': selectedInterviewer,
        'Reason': selectedReason,
        'Answers': answers,
        'TB_Details': _tbDetailsController.text,
        'Respiratory_Details': _respiratoryDetailsController.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('tb_questionnaire', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'TB Questionnaire updated! Syncing...' : 'TB Questionnaire saved! Syncing...'),
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
      _performTBQuestionnaireSync(data);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _performTBQuestionnaireSync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('tb_questionnaire').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('tb_questionnaire').add(data);
      }
    } catch (e) {
      debugPrint('TB Questionnaire Background Sync Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('TB Questionnaire'), elevation: 0),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('tb_questionnaire_scroll'),
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
                      title: 'Symptom Screening (In last 2 weeks)',
                      icon: Icons.personal_injury_outlined,
                      children: [
                        _buildQuestionRow('Cough for more than 2 weeks?', 'cough_2wks'),
                        _buildQuestionRow('Fever for more than 2 weeks?', 'fever_2wks'),
                        _buildQuestionRow('Unintentional Weight Loss?', 'weight_loss'),
                        _buildQuestionRow('Night Sweats?', 'night_sweats'),
                        _buildQuestionRow('Haemoptysis (Coughing blood)?', 'haemoptysis'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'TB History & Exposure',
                      icon: Icons.history_outlined,
                      children: [
                        _buildQuestionRow('History of TB before?', 'tb_before'),
                        if (answers['tb_before'] == '(1) Yes') formTextField('Specify Details', _tbDetailsController),
                        _buildQuestionRow('Family/Household exposure to TB?', 'tb_household'),
                        _buildQuestionRow('Contact with TB patient?', 'tb_exposure'),
                        _buildQuestionRow('History of respiratory illness?', 'respiratory_history'),
                        if (answers['respiratory_history'] == '(1) Yes') formTextField('Specify Details', _respiratoryDetailsController),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Risk Factors & Environment',
                      icon: Icons.warning_amber_outlined,
                      children: [
                        _buildQuestionRow('Living in crowded places?', 'crowded_places'),
                        _buildQuestionRow('Healthcare worker?', 'healthcare_work'),
                        _buildQuestionRow('High risk environment exposure?', 'high_risk_env'),
                        _buildQuestionRow('Smoking habit?', 'smoking'),
                        _buildQuestionRow('Alcohol consumption?', 'alcohol'),
                        _buildQuestionRow('Any recent infections?', 'recent_infection'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isSaving)
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
            final v = _familyCodeController.text;
            setState(() {
              selectedFamilyCode = v;
              selectedMemberName = null;
              familyMemberNames = [];
            });
            if (v.isNotEmpty) {
              if (_isEditMode) {
                _fetchExistingRecords(v);
              } else {
                _fetchMembersByFamily(v);
              }
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
            Expanded(child: formTextField('Age', _ageController, keyboardType: TextInputType.number, hint: 'e.g. 45')),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Date of Interview', interviewDate, (v) => setState(() => interviewDate = v))),
          ],
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(
          context,
          'Interviewer’s Name',
          interviewers,
          selectedInterviewer,
          (v) => setState(() => selectedInterviewer = v),
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(
          context,
          'Reason if not available',
          reasons,
          selectedReason,
          (v) => setState(() => selectedReason = v),
        ),
      ],
    );
  }

  Widget _buildQuestionRow(String question, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(question, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        const SizedBox(height: 4),
        formSearchableDropdown(context, 'Answer', ['(1) Yes', '(0) No'], answers[key], (v) => setState(() => answers[key] = v)),
        const Divider(),
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
