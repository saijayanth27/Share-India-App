import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'data_cache_service.dart';
import 'widget.dart';
import 'language_provider.dart';

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
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectedGender;
  final _ageController = TextEditingController();
  final _reasonIfOtherController = TextEditingController();
  DateTime? interviewDate = DateTime.now();
  String? selectedInterviewer;
  String? selectedReason;

  // Questions State (Yes/No)
  Map<String, String?> answers = {
    'Have_you_had_a_cough_for_more_than_2_weeks': '(2) No',
    'Have_you_had_a_fever_for_more_than_2_weeks': '(2) No',
    'Do_you_feel_like_you_have_lost_weight': '(2) No',
    'Are_you_experiencing_excessive_sweating_at_night_Night_sweats': '(2) No',
    'Haemoptysis_coughing_up_blood': '(2) No',
    'Medical_History1': '(2) No',
    'Medical_History2': '(2) No',
    'Respiratory_and_General_Health1': '(2) No',
    'Respiratory_and_General_Health2': '(2) No',
    'Social_and_Environmental_Factors1': '(2) No',
    'Social_and_Environmental_Factors2': '(2) No',
    'Occupational_History1': '(2) No',
    'Occupational_History2': '(2) No',
    'Behavioural_Risk_Factors1': '(2) No',
    'Behavioural_Risk_Factors2': '(2) No',
    'Diagnostic_Tests1': '(2) No',
  };

  final _ifYesProvideDetailsController = TextEditingController();
  final _ifYesPleaseProvideDetailsController = TextEditingController();

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
    });
    
    if (name == null) return;

    final baseData = _allMembersData[name];
    if (baseData != null && !_isEditMode) {
      _registrationNumber.text = baseData['Registration_Number']?.toString() ?? '';
      selectedGender = baseData['Gender']?.toString();
      _ageController.text = baseData['Age']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        final snapshot = await FirebaseFirestore.instance
            .collection('tb_questionnaire')
            .where('Family_Code', isEqualTo: fCode)
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
        debugPrint('Error fetching TB record: $e');
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
    selectedFamilyCode = d['Family_Code'] ?? d['Family_code'] ?? d['Family_ID'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    _ageController.text = d['Age']?.toString() ?? '';
    
    final rawDate = d['Interview_Date'] ?? d['Date_of_Interview'];
    if (rawDate != null) {
      if (rawDate is Timestamp) {
        interviewDate = rawDate.toDate();
      } else {
        try {
          interviewDate = DateFormat('dd-MMM-yyyy').parse(rawDate.toString());
        } catch (_) {
          try {
            interviewDate = DateTime.parse(rawDate.toString());
          } catch (_) {}
        }
      }
    }
    
    selectedInterviewer = d['Interviewer_s_Name'] ?? d['Interviewer_Name'];
    selectedReason = d['If_not_done_reason'] ?? d['Reason'];
    _reasonIfOtherController.text = d['Single_Line'] ?? '';
    
    // Support both flattened and nested (legacy) data maps
    final oldAnswers = d['Answers'] as Map<String, dynamic>?;
    
    // Map of old keys to new Zoho link names
    final keyMap = {
      'cough_2wks': 'Have_you_had_a_cough_for_more_than_2_weeks',
      'fever_2wks': 'Have_you_had_a_fever_for_more_than_2_weeks',
      'weight_loss': 'Do_you_feel_like_you_have_lost_weight',
      'night_sweats': 'Are_you_experiencing_excessive_sweating_at_night_Night_sweats',
      'haemoptysis': 'Haemoptysis_coughing_up_blood',
      'tb_before': 'Medical_History1',
      'tb_exposure': 'Medical_History2',
      'respiratory_history': 'Respiratory_and_General_Health1',
      'recent_infection': 'Respiratory_and_General_Health2',
      'crowded_places': 'Social_and_Environmental_Factors1',
      'tb_household': 'Social_and_Environmental_Factors2',
      'healthcare_work': 'Occupational_History1',
      'high_risk_env': 'Occupational_History2',
      'smoking': 'Behavioural_Risk_Factors1',
      'alcohol': 'Behavioural_Risk_Factors2',
      'recent_tests': 'Diagnostic_Tests1',
    };

    answers.forEach((key, _) {
      // Try flat first, then nested
      answers[key] = d[key]?.toString() ?? oldAnswers?[keyMap.entries.firstWhere((e) => e.value == key, orElse: () => const MapEntry('', '')).key]?.toString() ?? '(2) No';
    });
    
    _ifYesProvideDetailsController.text = d['If_yes_provide_details'] ?? d['TB_Details'] ?? '';
    _ifYesPleaseProvideDetailsController.text = d['If_yes_please_provide_details'] ?? d['Respiratory_Details'] ?? '';

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
      _reasonIfOtherController.clear();
      answers.updateAll((key, value) => '(2) No');
      _ifYesProvideDetailsController.clear();
      _ifYesPleaseProvideDetailsController.clear();
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
        'Family_code': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Age': int.tryParse(_ageController.text),
        'Date_of_Interview': interviewDate != null ? Timestamp.fromDate(interviewDate!) : null,
        'Interviewer_s_Name': selectedInterviewer,
        'If_not_done_reason': selectedReason,
        'Single_Line': _reasonIfOtherController.text,
        ...answers,
        'If_yes_provide_details': _ifYesProvideDetailsController.text,
        'If_yes_please_provide_details': _ifYesPleaseProvideDetailsController.text,
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
          content: Text(wasEditing ? tr('TB Questionnaire updated! Syncing...') : tr('TB Questionnaire saved! Syncing...')),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Error saving')}: $e'), backgroundColor: Colors.red));
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
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageProvider.instance.isTeluguNotifier,
      builder: (context, isTelugu, _) {
      return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: Text(tr('TB Questionnaire')), elevation: 0, actions: const [LanguageToggleButton()]),
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
                      title: tr('(1) Current Symptoms'),
                      icon: Icons.personal_injury_outlined,
                      children: [
                        _buildQuestionRow(tr('Have you had a cough for more than 2 weeks?'), 'Have_you_had_a_cough_for_more_than_2_weeks'),
                        _buildQuestionRow(tr('Have you had a fever for more than 2 weeks?'), 'Have_you_had_a_fever_for_more_than_2_weeks'),
                        _buildQuestionRow(tr('Do you feel like you have lost weight?'), 'Do_you_feel_like_you_have_lost_weight'),
                        _buildQuestionRow(tr('Are you experiencing excessive sweating at night (Night sweats)?'), 'Are_you_experiencing_excessive_sweating_at_night_Night_sweats'),
                        _buildQuestionRow(tr('Haemoptysis (coughing up blood):'), 'Haemoptysis_coughing_up_blood'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: tr('(2) Medical History'),
                      icon: Icons.history_outlined,
                      children: [
                        _buildQuestionRow(tr('Have you been diagnosed with tuberculosis before? If yes, please provide details'), 'Medical_History1'),
                        if (answers['Medical_History1'] == '(1) Yes') formTextField(tr('If yes , provide details'), _ifYesProvideDetailsController),
                        _buildQuestionRow(tr('Do you have a history of exposure to someone with confirmed TB? '), 'Medical_History2'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: tr('(3) Respiratory and General Health'),
                      icon: Icons.medical_services_outlined,
                      children: [
                        _buildQuestionRow(tr('Any history of chronic respiratory conditions (e.g., asthma, chronic bronchitis)? '), 'Respiratory_and_General_Health1'),
                        if (answers['Respiratory_and_General_Health1'] == '(1) Yes') formTextField(tr(' If yes, please provide details.'), _ifYesPleaseProvideDetailsController),
                        _buildQuestionRow(tr('Any recent respiratory infections or illnesses?'), 'Respiratory_and_General_Health2'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: tr('(4) Social and Environmental Factors:'),
                      icon: Icons.people_outline,
                      children: [
                        _buildQuestionRow(tr(' Are you living or working in crowded places? '), 'Social_and_Environmental_Factors1'),
                        _buildQuestionRow(tr('Is there a history of TB in your household or close contacts?'), 'Social_and_Environmental_Factors2'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: tr('(5) Occupational History:'),
                      icon: Icons.work_outline,
                      children: [
                        _buildQuestionRow(tr('Do you work in healthcare, correctional facilities, or others? '), 'Occupational_History1'),
                        _buildQuestionRow(tr('environments with an increased risk of TB exposure? '), 'Occupational_History2'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: tr('(6) Behavioural Risk Factors'),
                      icon: Icons.warning_amber_outlined,
                      children: [
                        _buildQuestionRow(tr('Do you smoke or have a history of smoking?'), 'Behavioural_Risk_Factors1'),
                        _buildQuestionRow(tr(' Do you consume alcohol regularly?'), 'Behavioural_Risk_Factors2'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: tr('(7) Diagnostic Tests:'),
                      icon: Icons.biotech_outlined,
                      children: [
                        _buildQuestionRow(tr('Have you had any recent chest X-rays or other respiratory tests?'), 'Diagnostic_Tests1'),
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
    });
  }

  Widget _buildIdentitySection() {
    return buildSectionCard(
      context: context,
      title: tr('Patient Identity'),
      icon: Icons.person_outline,
      children: [
        formTextField(tr('Registration Number'), _registrationNumber),
        const SizedBox(height: 12),
        formSearchField(
          tr('Family Code'),
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
        Text(tr('Gender'), style: const TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: Text(tr('(1) Male')), value: '(1) Male', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: Text(tr('(0) Female')), value: '(0) Female', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField(tr('Age'), _ageController, keyboardType: TextInputType.number, hint: 'e.g. 45')),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker(tr('Date of Interview'), interviewDate, (v) => setState(() => interviewDate = v))),
          ],
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        formSearchableDropdown(
          context,
          tr('Interviewer\'s Name'),
          interviewers,
          selectedInterviewer,
          (v) => setState(() => selectedInterviewer = v),
        ),
        const SizedBox(height: 16),
        Text(tr('If not done, reason'), style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: reasons.map((r) => _buildCompactRadio(
            label: r,
            value: r,
            groupValue: selectedReason,
            onChanged: (v) => setState(() => selectedReason = v),
          )).toList(),
        ),
        if (selectedReason == '(4) Other') 
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: formTextField(tr('Specify if other'), _reasonIfOtherController, hint: 'Single Line'),
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
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            _buildCompactRadio(
              label: '(1) Yes',
              value: '(1) Yes',
              groupValue: answers[key],
              onChanged: (v) => setState(() => answers[key] = v),
            ),
            _buildCompactRadio(
              label: '(2) No',
              value: '(2) No',
              groupValue: answers[key],
              onChanged: (v) => setState(() => answers[key] = v),
            ),
          ],
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildCompactRadio({
    required String label,
    required String value,
    required String? groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final bool isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.deepOrange.shade700 : Colors.grey.shade300,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? Colors.deepOrange.shade50 : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Radio<String>(
                value: value,
                groupValue: groupValue,
                onChanged: onChanged,
                activeColor: Colors.deepOrange.shade700,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.deepOrange.shade900 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
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
