import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

class QuarterlySurveyPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const QuarterlySurveyPage({super.key, this.existingData, this.docId});

  @override
  State<QuarterlySurveyPage> createState() => _QuarterlySurveyPageState();
}

class _QuarterlySurveyPageState extends State<QuarterlySurveyPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;

  // Controllers
  final _regNoController = TextEditingController();
  final _familyIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _visitOthersController = TextEditingController();
  final _dmMedNamesController = TextEditingController();
  final _dmMedOthersController = TextEditingController();
  final _htnMedNamesController = TextEditingController();
  final _htnMedOthersController = TextEditingController();

  // State
  String? selectedFamilyId;
  String? selectedName;
  String? selectedGender;
  String? selectedInterviewer;
  DateTime? interviewDate = DateTime.now();
  
  // Section 1: Health Facility
  String? visitedFacility;
  final Map<String, bool> visitReasons = {
    '(1) Heart problem': false,
    '(2) Kidney related': false,
    '(3) Paralysis': false,
    '(4) others': false,
  };

  // Section 2: Diabetes
  String? takingDmMed;
  String? dmMedSource;
  String? dmForget;
  String? dmNeglected;
  String? dmStoppedBetter;
  String? dmStoppedWorse;

  // Section 3: Hypertension
  String? takingHtnMed;
  String? htnMedSource;
  String? htnForget;
  String? htnNeglected;
  String? htnStoppedBetter;
  String? htnStoppedWorse;

  // Data for lookups
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};

  final List<String> interviewerList = ["KIRANMAI K", "LAVANYA KASPOJU", "RAMADEVI Y", "REVATHI CH"];
  final List<String> dmMedSourceChoices = ["(1) Private Hospital", "(2) Government Hospital", "(3) TETRA", "(4) Others"];
  final List<String> htnMedSourceChoices = ["(1) Private Hospital", "(2) Government Hospital", "GOVT", "OTHER", "PVT", "TETRA"];
  final List<String> yesNo12Choices = ["(1) Yes", "(2) No"];
  final List<String> yesNo10Choices = ["(1) Yes", "(0) No"];

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
      final Set<String> names = {};
      
      void processMember(Map<String, dynamic> data) {
        final name = data['Name']?.toString() ?? '';
        if (name.isEmpty) return;
        memberMap[name] = data;
        names.add(name);
      }

      for (var doc in snapshot.docs) processMember(doc.data());
      for (var local in localMembers) processMember(local);
      
      setState(() {
        _allMembersData = memberMap;
        familyMemberNames = names.toList()..sort();
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
          .collection('quarterly_survey')
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
          _regNoController.text = data['Registration_Number']?.toString() ?? '';
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
    _regNoController.text = d['Registration_Number']?.toString() ?? '';
    selectedFamilyId = d['Family_Code'] ?? d['Family_code'];
    _familyIdController.text = selectedFamilyId ?? '';
    selectedName = d['Name'];
    _nameController.text = selectedName ?? '';
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
    
    selectedInterviewer = d['Interviewer_s_Name'];
    visitedFacility = d['Past_3_months_are_you_visited_health_care_facility1'];

    final reasons = d['If_yes_specify_reason'];
    if (reasons is List) {
      for (var r in reasons) {
        if (visitReasons.containsKey(r.toString())) {
          visitReasons[r.toString()] = true;
        }
      }
    } else if (reasons != null) {
      if (visitReasons.containsKey(reasons.toString())) {
        visitReasons[reasons.toString()] = true;
      }
    }
    _visitOthersController.text = d['VISIT_OTHERS'] ?? '';

    takingDmMed = d['Are_you_currently_taking_medicines_for_Diabetes'];
    dmMedSource = d['Where_did_you_received_medicines'];
    _dmMedOthersController.text = d['specify_others'] ?? '';
    _dmMedNamesController.text = d['Medicnes_Names_Diabetes'] ?? '';
    dmForget = d['Did_you_ever_forget_to_take_medicines'];
    dmNeglected = d['Do_You_ever_neglected_taking_medicines'];
    dmStoppedBetter = d['Have_you_ever_stopped_taking_medicines_on_feeling_better'];
    dmStoppedWorse = d['Have_you_ever_stopped_taking_medicines_on_feeling_more_worsening_of_your_health'];

    takingHtnMed = d['Are_you_currently_taking_medicines_for_Blood_Pressure'];
    htnMedSource = d['Where_did_you_received_medicnes1'];
    _htnMedOthersController.text = d['specify_others1'] ?? '';
    _htnMedNamesController.text = d['Medicnes_Names_Hypertension'] ?? '';
    htnForget = d['Did_you_ever_forget_to_take_medicines1'];
    htnNeglected = d['Do_You_ever_neglected_taking_medicines1'];
    htnStoppedBetter = d['Have_you_ever_stopped_taking_medicines_on_feeling_better1'];
    htnStoppedWorse = d['Have_you_ever_stopped_taking_medicines_on_feeling_more_worsening_of_your_health1'];

    if (selectedFamilyId != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyId!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _regNoController.clear();
      _familyIdController.clear();
      _nameController.clear();
      selectedFamilyId = null;
      selectedName = null;
      selectedGender = null;
      _ageController.clear();
      interviewDate = DateTime.now();
      selectedInterviewer = null;

      visitedFacility = null;
      visitReasons.updateAll((key, value) => false);
      _visitOthersController.clear();

      takingDmMed = null;
      dmMedSource = null;
      _dmMedOthersController.clear();
      _dmMedNamesController.clear();
      dmForget = null;
      dmNeglected = null;
      dmStoppedBetter = null;
      dmStoppedWorse = null;

      takingHtnMed = null;
      htnMedSource = null;
      _htnMedOthersController.clear();
      _htnMedNamesController.clear();
      htnForget = null;
      htnNeglected = null;
      htnStoppedBetter = null;
      htnStoppedWorse = null;

      familyMemberNames = [];
      _existingRecords = [];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final List<String> selectedReasons = visitReasons.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final data = {
        'Registration_Number': _regNoController.text,
        'Family_Code': selectedFamilyId ?? _familyIdController.text,
        'Name': _isEditMode ? selectedName : _nameController.text,
        'Gender': selectedGender,
        'Age': int.tryParse(_ageController.text),
        'Date_of_Interview': interviewDate != null ? DateFormat('dd-MMM-yyyy').format(interviewDate!) : null,
        'Interviewer_s_Name': selectedInterviewer,
        'Past_3_months_are_you_visited_health_care_facility1': visitedFacility,
        'If_yes_specify_reason': selectedReasons,
        'VISIT_OTHERS': _visitOthersController.text,
        'Are_you_currently_taking_medicines_for_Diabetes': takingDmMed,
        'Where_did_you_received_medicines': dmMedSource,
        'specify_others': _dmMedOthersController.text,
        'Medicnes_Names_Diabetes': _dmMedNamesController.text,
        'Did_you_ever_forget_to_take_medicines': dmForget,
        'Do_You_ever_neglected_taking_medicines': dmNeglected,
        'Have_you_ever_stopped_taking_medicines_on_feeling_better': dmStoppedBetter,
        'Have_you_ever_stopped_taking_medicines_on_feeling_more_worsening_of_your_health': dmStoppedWorse,
        'Are_you_currently_taking_medicines_for_Blood_Pressure': takingHtnMed,
        'Where_did_you_received_medicnes1': htnMedSource,
        'specify_others1': _htnMedOthersController.text,
        'Medicnes_Names_Hypertension': _htnMedNamesController.text,
        'Did_you_ever_forget_to_take_medicines1': htnForget,
        'Do_You_ever_neglected_taking_medicines1': htnNeglected,
        'Have_you_ever_stopped_taking_medicines_on_feeling_better1': htnStoppedBetter,
        'Have_you_ever_stopped_taking_medicines_on_feeling_more_worsening_of_your_health1': htnStoppedWorse,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('quarterly_survey', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Survey updated! Syncing...' : 'Survey saved! Syncing...'),
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
      _performSurveySync(data);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _performSurveySync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('quarterly_survey').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('quarterly_survey').add(data);
      }
    } catch (e) {
      debugPrint('Survey Background Sync Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Quarterly Survey Questionnaire'), elevation: 0),
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
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Health Facility visit',
                      icon: Icons.local_hospital_outlined,
                      children: [
                        formSearchableDropdown(context, '1.Past 3 months are you visited health care facility', yesNo12Choices, visitedFacility, (v) => setState(() => visitedFacility = v)),
                        if (visitedFacility == '(1) Yes') ...[
                          const SizedBox(height: 12),
                          const Text('If yes, specify reason', style: TextStyle(fontWeight: FontWeight.w500)),
                          ...visitReasons.keys.map((key) => CheckboxListTile(
                            title: Text(key),
                            value: visitReasons[key],
                            onChanged: (val) => setState(() => visitReasons[key] = val ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          )),
                          if (visitReasons['(4) others'] == true) ...[
                            const SizedBox(height: 12),
                            formTextField('specify others', _visitOthersController),
                          ],
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Diabetes',
                      icon: Icons.medication_outlined,
                      children: [
                        formSearchableDropdown(context, 'Are you currently taking medicines for Diabetes?', yesNo12Choices, takingDmMed, (v) => setState(() => takingDmMed = v)),
                        if (takingDmMed == '(1) Yes') ...[
                          const SizedBox(height: 12),
                          formSearchableDropdown(context, 'Where did you received medicines?', dmMedSourceChoices, dmMedSource, (v) => setState(() => dmMedSource = v)),
                          if (dmMedSource == '(4) Others') ...[
                            const SizedBox(height: 12),
                            formTextField('specify others', _dmMedOthersController),
                          ],
                          const SizedBox(height: 12),
                          formTextField('Medicnes Names (Diabetes)', _dmMedNamesController, maxLines: 2),
                          const SizedBox(height: 12),
                          formSearchableDropdown(context, '1.Did you ever forget to take medicines?', yesNo12Choices, dmForget, (v) => setState(() => dmForget = v)),
                          formSearchableDropdown(context, '2.Do You ever neglected taking medicines', yesNo12Choices, dmNeglected, (v) => setState(() => dmNeglected = v)),
                          formSearchableDropdown(context, '3.Have you ever stopped taking medicines on feeling better', yesNo12Choices, dmStoppedBetter, (v) => setState(() => dmStoppedBetter = v)),
                          formSearchableDropdown(context, '4.Have you ever stopped taking medicines on feeling more worsening of your health', yesNo12Choices, dmStoppedWorse, (v) => setState(() => dmStoppedWorse = v)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Blood Pressure',
                      icon: Icons.monitor_heart_outlined,
                      children: [
                        formSearchableDropdown(context, '3. Are you currently taking medicines for Blood Pressure', yesNo12Choices, takingHtnMed, (v) => setState(() => takingHtnMed = v)),
                        if (takingHtnMed == '(1) Yes') ...[
                          const SizedBox(height: 12),
                          formSearchableDropdown(context, 'Where did you received medicnes?', htnMedSourceChoices, htnMedSource, (v) => setState(() => htnMedSource = v)),
                          if (htnMedSource == 'OTHER' || htnMedSource == '(4) Others') ...[
                            const SizedBox(height: 12),
                            formTextField('specify others', _htnMedOthersController),
                          ],
                          const SizedBox(height: 12),
                          formTextField('Medicnes Names (Hypertension)', _htnMedNamesController, maxLines: 2),
                          const SizedBox(height: 12),
                          formSearchableDropdown(context, '1.Did you ever forget to take medicines', yesNo10Choices, htnForget, (v) => setState(() => htnForget = v)),
                          formSearchableDropdown(context, '2.Do You ever neglected taking medicines', yesNo10Choices, htnNeglected, (v) => setState(() => htnNeglected = v)),
                          formSearchableDropdown(context, '3.Have you ever stopped taking medicines on feeling better', yesNo10Choices, htnStoppedBetter, (v) => setState(() => htnStoppedBetter = v)),
                          formSearchableDropdown(context, '4.Have you ever stopped taking medicines on feeling more worsening of your health', yesNo10Choices, htnStoppedWorse, (v) => setState(() => htnStoppedWorse = v)),
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
      title: 'Respondent Identity',
      icon: Icons.person_outline,
      children: [
        formTextField('Registration Number', _regNoController),
        const SizedBox(height: 12),
        formSearchField(
          'Family Code',
          _familyIdController,
          onSearch: () {
            if (_familyIdController.text.isNotEmpty) {
              _fetchMembersByFamily(_familyIdController.text);
              _fetchExistingRecords(_familyIdController.text);
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
          selectedName,
          _onNameSelected,
          isLoading: _isLoadingMembers,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
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
            Expanded(child: formTextField('Age', _ageController, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Interview Date', interviewDate, (v) => setState(() => interviewDate = v))),
          ],
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(context, 'Interviewer Name', interviewerList, selectedInterviewer, (v) => setState(() => selectedInterviewer = v)),
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
