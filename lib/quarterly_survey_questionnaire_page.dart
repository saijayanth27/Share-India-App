import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'local_database_service.dart';
import 'sync_service.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;
  bool _isActionActive = false; // Add this
  final FocusNode _familyCodeNode = FocusNode();
  bool _familyIdReadOnly = true;

  // Controllers
  final _regNoController = TextEditingController();
  final _familyIdController = TextEditingController(text: 'TSRRMED');
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
  // Location (auto-populated from Family Code)
  String? _locationVillage;
  String? _locationMandal;
  String? _locationDistrict;
  String? _locationState;


  final List<String> interviewerList = ["KIRANMAI K", "LAVANYA KASPOJU", "RAMADEVI Y", "REVATHI CH"];
  final List<String> dmMedSourceChoices = ["(1) Private Hospital", "(2) Government Hospital", "(3) TETRA", "(4) Others"];
  final List<String> htnMedSourceChoices = ["(1) Private Hospital", "(2) Government Hospital", "GOVT", "OTHER", "PVT", "TETRA"];
  final List<String> yesNo12Choices = ["(1) Yes", "(2) No"];
  final List<String> yesNo10Choices = ["(1) Yes", "(0) No"];

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _isEditMode = true;
      _editDocId = widget.docId;
      _loadExistingData();
      final familyCode = (widget.existingData!['Family_Code'] ?? widget.existingData!['Family_code'] ?? widget.existingData!['Family_ID'] ?? widget.existingData!['Family_ID1'] ?? '').toString();
      if (familyCode.isNotEmpty) {
        _fetchMembersByFamily(familyCode);
        _fetchExistingRecords(familyCode);
      }
    }
  }

  @override
  void dispose() {
    _familyCodeNode.dispose();
    _regNoController.dispose();
    _familyIdController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _visitOthersController.dispose();
    _dmMedNamesController.dispose();
    _dmMedOthersController.dispose();
    _htnMedNamesController.dispose();
    _htnMedOthersController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembersByFamily(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      final fCode = familyCode.trim().toUpperCase();
      if (fCode.isEmpty) {
        setState(() => _isLoadingMembers = false);
        return;
      }

      // 1. Fetch Local Members immediately (Fastest for offline)
      final localMembers = await DataCacheService().fetchMembersLocally(fCode);
      
      // 2. Try Firestore for fresh data, but with a short timeout
      List<Map<String, dynamic>> firestoreMembers = [];
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('personal_details')
            .where('Family_Code', isEqualTo: fCode)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 3));
        
        firestoreMembers = snapshot.docs.map((d) => d.data() as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint('QuarterlySurvey: Firestore lookup failed/timeout, relying on LOCAL: $e');
      }

      final Map<String, Map<String, dynamic>> memberMap = {};
      final Set<String> names = {};
      
      // Process both, preferring Firestore but ensuring Local captures everything else
      final combined = [...firestoreMembers, ...localMembers];

      for (var data in combined) {
        final name = data['Name']?.toString() ?? '';
        if (name.isEmpty) continue;

        // Filter: only members aged 18 or older
        final age = int.tryParse(data['Age']?.toString() ?? '0') ?? 0;
        if (age < 18) continue;

        memberMap[name] = data;
        names.add(name);
      }

      setState(() {
        _allMembersData = memberMap;
        familyMemberNames = names.toList()..sort();
        selectedFamilyId = fCode;
      });
          _fetchFamilyLocation(familyCode);
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
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 8));
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
      selectedName = name;
      _nameController.text = name ?? '';
    });
    
    if (name == null) return;

    final baseData = _allMembersData[name];
    if (baseData != null && !_isEditMode) {
      _regNoController.text = baseData['Registration_Number']?.toString() ?? '';
      selectedGender = baseData['Gender']?.toString();
      _ageController.text = baseData['Age']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyIdController.text.trim();
        final snapshot = await FirebaseFirestore.instance
            .collection('quarterly_survey')
            .where('Family_Code', isEqualTo: fCode)
            .where('Name', isEqualTo: name)
            .limit(1)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 8));

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
        debugPrint('Error fetching survey record: $e');
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
    _regNoController.text = _extractValue(d['Registration_Number'] ?? d['Registration_No'] ?? d['REGNO'] ?? d['Regno']) ?? '';
    selectedFamilyId = _extractValue(d['Family_Code'] ?? d['Family_code'] ?? d['Family_ID'] ?? d['Family_ID1']);
    _familyIdController.text = selectedFamilyId ?? '';
    selectedName = d['Name'];
    _locationVillage  = (d['Village']  ?? d['village'])?.toString();
    _locationMandal   = (d['Mandal']   ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState    = (d['State']    ?? d['state'])?.toString();
    _nameController.text = selectedName ?? '';
    selectedGender = normalizeGender(d['Gender']);
    _ageController.text = d['Age']?.toString() ?? '';

    // Date: app field → TETRA INTDT fallback
    final rawDate = d['Date_of_Interview'] ?? d['Interview_Date'] ?? d['INTDT'];
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

    selectedInterviewer = matchInterviewerName(d['Interviewer_s_Name'] ?? d['Interviewer_Name'] ?? d['Interviewer_s_Name1'] ?? d['INTNAME'], interviewerList);
    visitedFacility = _mapChoice(d['Past_3_months_are_you_visited_health_care_facility1']);

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

    takingDmMed = _mapChoice(d['Are_you_currently_taking_medicines_for_Diabetes']);
    dmMedSource = _extractValue(d['Where_did_you_received_medicines']);
    _dmMedOthersController.text = _extractValue(d['specify_others']) ?? '';
    _dmMedNamesController.text = _extractValue(d['Medicnes_Names_Diabetes']) ?? '';
    dmForget = _mapChoice(d['Did_you_ever_forget_to_take_medicines']);
    dmNeglected = _mapChoice(d['Do_You_ever_neglected_taking_medicines']);
    dmStoppedBetter = _mapChoice(d['Have_you_ever_stopped_taking_medicines_on_feeling_better']);
    dmStoppedWorse = _mapChoice(d['Have_you_ever_stopped_taking_medicines_on_feeling_more_worsening_of_your_health']);

    takingHtnMed = _mapChoice(d['Are_you_currently_taking_medicines_for_Blood_Pressure']);
    htnMedSource = _extractValue(d['Where_did_you_received_medicnes1']);
    _htnMedOthersController.text = _extractValue(d['specify_others1']) ?? '';
    _htnMedNamesController.text = _extractValue(d['Medicnes_Names_Hypertension']) ?? '';
    htnForget = _mapChoice(d['Did_you_ever_forget_to_take_medicines1']);
    htnNeglected = _mapChoice(d['Do_You_ever_neglected_taking_medicines1']);
    htnStoppedBetter = _mapChoice(d['Have_you_ever_stopped_taking_medicines_on_feeling_better1']);
    htnStoppedWorse = _mapChoice(d['Have_you_ever_stopped_taking_medicines_on_feeling_more_worsening_of_your_health1']);

    if (!_isEditMode && selectedFamilyId != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyId!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _isActionActive = false;
      _regNoController.clear();
      // _familyIdController.text = 'TSRRMED'; // Preserved
      _nameController.clear();
      // selectedFamilyId = null; // Preserved
      selectedName = null;
      selectedGender = null;
      _locationVillage = null;
      _locationMandal = null;
      _locationDistrict = null;
      _locationState = null;
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
        'Village': _locationVillage,
        'Mandal': _locationMandal,
        'District': _locationDistrict,
        'State': _locationState,
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

      // 2. Trigger Background Sync (Handles Firestore push)
      SyncService().syncPendingSubmissions();

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() {
        _isSaving = false;
        _isActionActive = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
          title: const Text('Quarterly Survey Questionnaire'), elevation: 0),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildIdentitySection(),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Health Facility visit',
                      icon: Icons.local_hospital_outlined,
                      children: [
                        formSearchableDropdown(
                            context,
                            '1.Past 3 months are you visited health care facility',
                            yesNo12Choices,
                            visitedFacility,
                            (v) => setState(() => visitedFacility = v as String?),
                            enabled: _isActionActive),
                        if (visitedFacility == '(1) Yes') ...[
                          const SizedBox(height: 12),
                          const Text('If yes, specify reason',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: visitReasons.keys.map<Widget>((key) => formCheckboxOption(
                                  label: key,
                                  value: visitReasons[key] ?? false,
                                  onChanged: !_isActionActive ? null : (val) => setState(
                                      () => visitReasons[key] = val ?? false),
                                )).toList(),
                          ),
                          if (visitReasons['(4) others'] == true) ...[
                            const SizedBox(height: 12),
                            formTextField(
                                'specify others', _visitOthersController, enabled: _isActionActive),
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
                        formSearchableDropdown(
                            context,
                            'Are you currently taking medicines for Diabetes?',
                            yesNo12Choices,
                             takingDmMed,
                            (v) => setState(() => takingDmMed = v as String?),
                            enabled: _isActionActive),
                        if (takingDmMed == '(1) Yes') ...[
                          const SizedBox(height: 12),
                          formSearchableDropdown(
                              context,
                              'Where did you received medicines?',
                              dmMedSourceChoices,
                              dmMedSource,
                              (v) => setState(() => dmMedSource = v as String?),
                              enabled: _isActionActive),
                          if (dmMedSource == '(4) Others') ...[
                            const SizedBox(height: 12),
                            formTextField(
                                'specify others', _dmMedOthersController, enabled: _isActionActive),
                          ],
                          const SizedBox(height: 12),
                          formTextField(
                              'Medicnes Names (Diabetes)', _dmMedNamesController,
                              enabled: _isActionActive,
                              maxLines: 2),
                          const SizedBox(height: 12),
                          formSearchableDropdown(
                              context,
                              '1.Did you ever forget to take medicines?',
                              yesNo12Choices,
                              dmForget,
                              (v) => setState(() => dmForget = v as String?),
                              enabled: _isActionActive),
                          formSearchableDropdown(
                              context,
                              '2.Do You ever neglected taking medicines',
                              yesNo12Choices,
                              dmNeglected,
                              (v) => setState(() => dmNeglected = v as String?),
                              enabled: _isActionActive),
                          formSearchableDropdown(
                              context,
                              '3.Have you ever stopped taking medicines on feeling better',
                              yesNo12Choices,
                              dmStoppedBetter,
                              (v) => setState(() => dmStoppedBetter = v as String?),
                              enabled: _isActionActive),
                          formSearchableDropdown(
                              context,
                              '4.Have you ever stopped taking medicines on feeling more worsening of your health',
                              yesNo12Choices,
                              dmStoppedWorse,
                              (v) => setState(() => dmStoppedWorse = v as String?),
                              enabled: _isActionActive),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Blood Pressure',
                      icon: Icons.monitor_heart_outlined,
                      children: [
                        formSearchableDropdown(
                            context,
                            '3. Are you currently taking medicines for Blood Pressure',
                            yesNo12Choices,
                            takingHtnMed,
                            (v) => setState(() => takingHtnMed = v as String?),
                            enabled: _isActionActive),
                        if (takingHtnMed == '(1) Yes') ...[
                          const SizedBox(height: 12),
                          formSearchableDropdown(
                              context,
                              'Where did you received medicnes?',
                              htnMedSourceChoices,
                              htnMedSource,
                              (v) => setState(() => htnMedSource = v as String?),
                              enabled: _isActionActive),
                          if (htnMedSource == 'OTHER' ||
                              htnMedSource == '(4) Others') ...[
                            const SizedBox(height: 12),
                            formTextField(
                                'specify others', _htnMedOthersController, enabled: _isActionActive),
                          ],
                          const SizedBox(height: 12),
                          formTextField('Medicnes Names (Hypertension)',
                              _htnMedNamesController,
                              enabled: _isActionActive,
                              maxLines: 2),
                          const SizedBox(height: 12),
                          formSearchableDropdown(
                              context,
                              '1.Did you ever forget to take medicines',
                              yesNo12Choices,
                              htnForget,
                              (v) => setState(() => htnForget = v as String?),
                              enabled: _isActionActive),
                          formSearchableDropdown(
                              context,
                              '2.Do You ever neglected taking medicines',
                              yesNo12Choices,
                              htnNeglected,
                              (v) => setState(() => htnNeglected = v as String?),
                              enabled: _isActionActive),
                          formSearchableDropdown(
                              context,
                              '3.Have you ever stopped taking medicines on feeling better',
                              yesNo12Choices,
                              htnStoppedBetter,
                              (v) => setState(() => htnStoppedBetter = v as String?),
                              enabled: _isActionActive),
                          formSearchableDropdown(
                              context,
                              '4.Have you ever stopped taking medicines on feeling more worsening of your health',
                              yesNo12Choices,
                              htnStoppedWorse,
                              (v) => setState(() => htnStoppedWorse = v as String?),
                              enabled: _isActionActive),
                        ],
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _isSaving
          ? null
          : formActionButtons(
              context: context,
              isEditMode: _isEditMode,
              onNew: () {
                setState(() {
                  _isEditMode = false;
                  _resetForm();
                  _isActionActive = true;
                  _familyIdReadOnly = false;
                  _familyCodeNode.requestFocus();
                });
              },
              onSave: _save,
              onEdit: () {
                setState(() {
                  _isEditMode = true;
                  _isActionActive = true;
                  _familyIdReadOnly = false;
                  _familyCodeNode.requestFocus();
                  final code = _familyIdController.text.trim();
                  if (code.isNotEmpty) {
                    _fetchMembersByFamily(code);
                    _fetchExistingRecords(code);
                  }
                });
              },
              onCancel: () {
                setState(() {
                  _isActionActive = false;
                  _resetForm();
                });
              },
              onExit: () => Navigator.pop(context),
              isSaving: _isSaving,
              isActionActive: _isActionActive,
            ),
    );
  }


  Future<void> _fetchFamilyLocation(String familyCode) async {
    try {
      var detail = await LocalDatabaseService().getSingleFamilyDetail(familyCode.trim().toUpperCase());
      detail ??= await LocalDatabaseService().getSingleFamilyDetail(familyCode.trim());

      if (detail == null) {
        final snap = await FirebaseFirestore.instance
            .collection('Family Code Creation')
            .doc(familyCode.trim().toUpperCase())
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 6));
        if (snap.exists) detail = snap.data();
      }

      if (detail != null && mounted) {
        setState(() {
          _locationVillage  = (detail!['village']  ?? detail['Village'])?.toString();
          _locationMandal   = (detail['mandal']    ?? detail['Mandal'])?.toString();
          _locationDistrict = (detail['district']  ?? detail['District'])?.toString();
          _locationState    = (detail['state']     ?? detail['State'])?.toString();
        });
      }
    } catch (e) {
      debugPrint('_fetchFamilyLocation: $e');
    }
  }

  Widget _buildLocationRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text('$label:', style: const TextStyle(fontSize: 12, color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildIdentitySection() {
    return buildSectionCard(
      context: context,
      title: 'Respondent Identity',
      icon: Icons.person_outline,
      children: [
        formTextField('Registration Number', _regNoController, enabled: _isActionActive),
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
          enabled: _isActionActive,
          readOnly: _familyIdReadOnly,
          focusNode: _familyCodeNode,
        ),
        const SizedBox(height: 12),
        if (_locationVillage != null || _locationMandal != null || _locationDistrict != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text('Location', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade700, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildLocationRow('Village', _locationVillage),
                  _buildLocationRow('Mandal', _locationMandal),
                  _buildLocationRow('District', _locationDistrict),
                  _buildLocationRow('State', _locationState),
                ],
              ),
            ),
          ),
        formSearchableDropdown(
          context,
          'Name',
          (<String>{...familyMemberNames, ..._existingRecords.map((r) => r['Name']?.toString() ?? '')}
              .where((n) => n.isNotEmpty)
              .toList()
            ..sort()),
          selectedName,
          (v) => _onNameSelected(v as String?),
          isLoading: _isLoadingMembers,
          enabled: _isActionActive,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: '(1) Male', groupValue: selectedGender, onChanged: !_isActionActive ? null : (v) => setState(() => selectedGender = v as String?), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: '(0) Female', groupValue: selectedGender, onChanged: !_isActionActive ? null : (v) => setState(() => selectedGender = v as String?), contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField('Age', _ageController, enabled: _isActionActive, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Date of Interview', interviewDate, (v) => setState(() => interviewDate = v), enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(context, 'Interviewer Name', interviewerList, selectedInterviewer, (v) => setState(() => selectedInterviewer = v as String?), enabled: _isActionActive),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onPicked, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        InkWell(
        onTap: !enabled ? null : () async {
            final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              onPicked(picked);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) _scrollController.jumpTo(offset);
              });
            }
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
  String? _mapChoice(dynamic value) {
    if (value == null) return null;
    String s = _extractValue(value)?.trim() ?? '';
    if (s.isEmpty) return null;
    
    // Normalize to (1) Yes / (2) No format
    final norm = s.toLowerCase();
    if (norm == '1' || norm == 'yes' || norm.contains('(1)') || norm.startsWith('yes')) return '(1) Yes';
    if (norm == '0' || norm == '2' || norm == 'no' || norm.contains('(0)') || norm.contains('(2)') || norm.startsWith('no')) return '(2) No';
    
    return s;
  }

  String? _extractValue(dynamic val) {
    if (val == null) return null;
    if (val is String) return val.trim();
    if (val is Map) {
      final res = val['display_value']?.toString() ?? 
                  val['zc_display_value']?.toString() ?? 
                  val.values.firstOrNull?.toString();
      return res?.trim();
    }
    if (val is List && val.isNotEmpty) return _extractValue(val.first);
    return val.toString().trim();
  }
}
