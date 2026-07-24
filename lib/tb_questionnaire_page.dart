import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'data_cache_service.dart';
import 'local_database_service.dart';
import 'sync_service.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;
  bool _isActionActive = false;
  final FocusNode _familyCodeNode = FocusNode();
  bool _familyIdReadOnly = true;

  bool _isDownloadingTB = false;
  bool _tbAlreadyDownloaded = false;
  String? _tbDownloadedAt;

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
    'Have_you_had_a_cough_for_more_than_2_weeks': null,
    'Have_you_had_a_fever_for_more_than_2_weeks': null,
    'Do_you_feel_like_you_have_lost_weight': null,
    'Are_you_experiencing_excessive_sweating_at_night_Night_sweats': null,
    'Haemoptysis_coughing_up_blood': null,
    'Medical_History1': null,
    'Medical_History2': null,
    'Respiratory_and_General_Health1': null,
    'Respiratory_and_General_Health2': null,
    'Social_and_Environmental_Factors1': null,
    'Social_and_Environmental_Factors2': null,
    'Occupational_History1': null,
    'Occupational_History2': null,
    'Behavioural_Risk_Factors1': null,
    'Behavioural_Risk_Factors2': null,
    'Diagnostic_Tests1': null,
  };

  final _ifYesProvideDetailsController = TextEditingController();
  final _ifYesPleaseProvideDetailsController = TextEditingController();

  // Dropdown Options
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  // Location (auto-populated from Family Code)
  String? _locationVillage;
  String? _locationMandal;
  String? _locationDistrict;
  String? _locationState;


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
    _loadTBDownloadStatus();
    if (widget.existingData != null) {
      _isEditMode = true;
      _editDocId = widget.docId;
      _loadExistingData();
      final familyCode = (widget.existingData!['Family_Code'] ?? widget.existingData!['Family_code'] ?? '').toString();
      if (familyCode.isNotEmpty) {
        _fetchMembersByFamily(familyCode);
        _fetchExistingRecords(familyCode);
      }
    }
  }

  @override
  void dispose() {
    _familyCodeNode.dispose();
    _registrationNumber.dispose();
    _nameController.dispose();
    _familyCodeController.dispose();
    _ageController.dispose();
    _reasonIfOtherController.dispose();
    _ifYesProvideDetailsController.dispose();
    _ifYesPleaseProvideDetailsController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTBDownloadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString('tb_download_timestamp');
    if (mounted) setState(() { _tbAlreadyDownloaded = ts != null; _tbDownloadedAt = ts; });
  }

  Future<void> _downloadTBFromStorage() async {
    if (_isDownloadingTB) return;
    final prefs = await SharedPreferences.getInstance();

    if (_tbAlreadyDownloaded) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Already Downloaded'),
          content: Text('TB data was downloaded on $_tbDownloadedAt.\n\nDownload again to refresh?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Re-download')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isDownloadingTB = true);
    try {
      final ref = FirebaseStorage.instance.ref('exports/tb_records.json');
      final url = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final List<dynamic> jsonList = jsonDecode(response.body);
      final records = jsonList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await LocalDatabaseService().saveTbRecords(records, clearFirst: true);
      final downloadedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      await prefs.setString('tb_download_timestamp', downloadedAt);
      if (mounted) {
        setState(() { _tbAlreadyDownloaded = true; _tbDownloadedAt = downloadedAt; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('TB data downloaded (${records.length} records)'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Download failed: $e'), backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isDownloadingTB = false);
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
        
        // Filter: only members aged 18 or older
        final age = int.tryParse(data['Age']?.toString() ?? '0') ?? 0;
        if (age < 18) return;

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
          .collection('tb_questionnaire')
          .where('Family_code', isEqualTo: familyCode)
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
      selectedMemberName = name;
      _nameController.text = name ?? '';
    });
    
    if (name == null) return;

    final baseData = _allMembersData[name];
    if (baseData != null && !_isEditMode) {
      _registrationNumber.text = baseData['Registration_Number']?.toString() ?? '';
      selectedGender = _getNormalizedGender(baseData['Gender']?.toString());
      _ageController.text = baseData['Age']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();

        // Check local SQLite first
        final localRecord = await LocalDatabaseService().getTbRecordByName(fCode, name);
        if (localRecord != null) {
          final merged = {...?baseData, ...localRecord};
          if (mounted) setState(() => _populateForm(merged));
        }

        // Try Firestore with timeout
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('tb_questionnaire')
              .where('Family_code', isEqualTo: fCode)
              .where('Name', isEqualTo: name)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 5));

          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            final merged = {...?baseData, ...?localRecord, ...doc.data()};
            if (mounted) setState(() { _editDocId = doc.id; _populateForm(merged); });
          } else if (localRecord == null && baseData != null) {
            _populateForm(baseData);
          }
        } catch (e) {
          debugPrint('TB: Firestore lookup failed, using local: $e');
          if (localRecord == null && baseData != null) _populateForm(baseData);
        }
      } catch (e) {
        debugPrint('Error in TB _onNameSelected: $e');
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
    _locationVillage  = (d['Village']  ?? d['village'])?.toString();
    _locationMandal   = (d['Mandal']   ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState    = (d['State']    ?? d['state'])?.toString();
    _nameController.text = selectedMemberName ?? '';
    selectedGender = _getNormalizedGender(d['Gender']?.toString());
    _ageController.text = d['Age']?.toString() ?? '';
    
    // Interview date: current field OR old TETRA INTDT
    final rawDate = d['Interview_Date'] ?? d['Date_of_Interview'] ?? d['INTDT'];
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
    
    selectedInterviewer = matchInterviewerName(d['Interviewer_s_Name'] ?? d['Interviewer_Name'] ?? d['INTNAME'], interviewers);
    // Not done reason: current field OR old TETRA NA_DL
    final tbNaCode = d['NA_DL']?.toString().trim();
    selectedReason = d['If_not_done_reason'] ?? d['Reason'] ?? const {
      '1': '(1) Not available',
      '2': '(2) Refused for current visit',
      '3': '(3) Door Locked',
      '4': '(4) Other',
    }[tbNaCode];
    _reasonIfOtherController.text = d['Single_Line'] ?? '';

    // Support both flattened and nested (legacy) data maps
    final oldAnswers = d['Answers'] as Map<String, dynamic>?;

    // Map of old Zoho keys → Flutter field names
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

    // Map of TETRA field names → Flutter field names (TETRA: 1=Yes, 2=No)
    final tetraKeyMap = {
      'COUGH':        'Have_you_had_a_cough_for_more_than_2_weeks',
      'HAEMOPTYSIS':  'Haemoptysis_coughing_up_blood',
      'FEVER':        'Have_you_had_a_fever_for_more_than_2_weeks',
      'LOST_WT':      'Do_you_feel_like_you_have_lost_weight',
      'DIAG_TB':      'Medical_History1',
      'HIST_EXP':     'Medical_History2',
      'RESP_HIST':    'Respiratory_and_General_Health1',
      'RECENT_INFECT':'Respiratory_and_General_Health2',
      'CROWDED':      'Social_and_Environmental_Factors1',
      'TB_HOUSEHOLD': 'Social_and_Environmental_Factors2',
      'OCCUPTN_HIST': 'Occupational_History1',
      'HIGH_RISK':    'Occupational_History2',
      'SMOKING':      'Behavioural_Risk_Factors1',
      'ALCOHOL':      'Behavioural_Risk_Factors2',
      'RECENT_TEST':  'Diagnostic_Tests1',
    };

    for (final key in answers.keys.toList()) {
      final oldKey = keyMap.entries
          .firstWhere((e) => e.value == key, orElse: () => const MapEntry('', ''))
          .key;
      String? val = d[key]?.toString();
      if (val == null && oldKey.isNotEmpty && oldAnswers != null) {
        val = oldAnswers[oldKey]?.toString();
      }
      // If still null, check TETRA field names and map 1→(1) Yes, 2→(2) No
      if (val == null) {
        final tetraKey = tetraKeyMap.entries
            .firstWhere((e) => e.value == key, orElse: () => const MapEntry('', ''))
            .key;
        if (tetraKey.isNotEmpty && d[tetraKey] != null) {
          final raw = d[tetraKey].toString().trim();
          if (raw == '1' || raw.toLowerCase() == 'yes') val = '(1) Yes';
          else if (raw == '2' || raw.toLowerCase() == 'no') val = '(2) No';
          else val = raw;
        }
      }
      answers[key] = val ?? '(2) No';
    }

    _ifYesProvideDetailsController.text = d['If_yes_provide_details'] ?? d['TB_Details'] ?? '';
    _ifYesPleaseProvideDetailsController.text = d['If_yes_please_provide_details'] ?? d['Respiratory_Details'] ?? '';

    if (!_isEditMode && selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _isActionActive = false;
      _registrationNumber.clear();
      // _familyCodeController.text = 'TSRRMED'; // Preserved
      _nameController.clear();
      // selectedFamilyCode = null; // Preserved
      selectedMemberName = null;
      selectedGender = null;
      _locationVillage = null;
      _locationMandal = null;
      _locationDistrict = null;
      _locationState = null;
      _ageController.clear();
      interviewDate = DateTime.now();
      selectedInterviewer = null;
      selectedReason = null;
      _reasonIfOtherController.clear();
      answers.updateAll((key, value) => null); // Cleaned
      _ifYesProvideDetailsController.clear();
      _ifYesPleaseProvideDetailsController.clear();
      familyMemberNames = [];
      _existingRecords = [];
    });
  }

  String _getNormalizedGender(String? raw) {
    if (raw == null) return '';
    final l = raw.toLowerCase().trim();
    if (l.contains('female')) return '(0) Female';
    if (l.contains('male')) return '(1) Male';
    return raw;
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
        'Village': _locationVillage,
        'Mandal': _locationMandal,
        'District': _locationDistrict,
        'State': _locationState,
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
        title: const Text('TB Questionnaire'),
        elevation: 0,
        actions: [
          _isDownloadingTB
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : IconButton(
                  icon: Icon(Icons.cloud_download_outlined, color: _tbAlreadyDownloaded ? Colors.greenAccent : Colors.white),
                  tooltip: _tbAlreadyDownloaded ? 'Downloaded: $_tbDownloadedAt' : 'Download for offline',
                  onPressed: _downloadTBFromStorage,
                ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('tb_questionnaire_scroll'),
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildIdentitySection(),
                  const SizedBox(height: 16),
                  buildSectionCard(
                    context: context,
                    title: '(1) Current Symptoms',
                    icon: Icons.personal_injury_outlined,
                    children: [
                      _buildQuestionRow(
                          'Have you had a cough for more than 2 weeks?',
                          'Have_you_had_a_cough_for_more_than_2_weeks'),
                      _buildQuestionRow(
                          'Have you had a fever for more than 2 weeks?',
                          'Have_you_had_a_fever_for_more_than_2_weeks'),
                      _buildQuestionRow('Do you feel like you have lost weight?',
                          'Do_you_feel_like_you_have_lost_weight'),
                      _buildQuestionRow(
                          'Are you experiencing excessive sweating at night (Night sweats)?',
                          'Are_you_experiencing_excessive_sweating_at_night_Night_sweats'),
                      _buildQuestionRow('Haemoptysis (coughing up blood):',
                          'Haemoptysis_coughing_up_blood'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  buildSectionCard(
                    context: context,
                    title: '(2) Medical History',
                    icon: Icons.history_outlined,
                    children: [
                      _buildQuestionRow(
                          'Have you been diagnosed with tuberculosis before? If yes, please provide details',
                          'Medical_History1'),
                      if (answers['Medical_History1'] == '(1) Yes')
                        formTextField('If yes , provide details',
                            _ifYesProvideDetailsController, enabled: _isActionActive),
                      _buildQuestionRow(
                          'Do you have a history of exposure to someone with confirmed TB? ',
                          'Medical_History2'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  buildSectionCard(
                    context: context,
                    title: '(3) Respiratory and General Health',
                    icon: Icons.medical_services_outlined,
                    children: [
                      _buildQuestionRow(
                          'Any history of chronic respiratory conditions (e.g., asthma, chronic bronchitis)? ',
                          'Respiratory_and_General_Health1'),
                      if (answers['Respiratory_and_General_Health1'] ==
                          '(1) Yes')
                        formTextField(' If yes, please provide details.',
                            _ifYesPleaseProvideDetailsController, enabled: _isActionActive),
                      _buildQuestionRow(
                          'Any recent respiratory infections or illnesses?',
                          'Respiratory_and_General_Health2'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  buildSectionCard(
                    context: context,
                    title: '(4) Social and Environmental Factors:',
                    icon: Icons.people_outline,
                    children: [
                      _buildQuestionRow(
                          ' Are you living or working in crowded places? ',
                          'Social_and_Environmental_Factors1'),
                      _buildQuestionRow(
                          'Is there a history of TB in your household or close contacts?',
                          'Social_and_Environmental_Factors2'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  buildSectionCard(
                    context: context,
                    title: '(5) Occupational History:',
                    icon: Icons.work_outline,
                    children: [
                      _buildQuestionRow(
                          'Do you work in healthcare, correctional facilities, or others? ',
                          'Occupational_History1'),
                      _buildQuestionRow(
                          'environments with an increased risk of TB exposure? ',
                          'Occupational_History2'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  buildSectionCard(
                    context: context,
                    title: '(6) Behavioural Risk Factors',
                    icon: Icons.warning_amber_outlined,
                    children: [
                      _buildQuestionRow(
                          'Do you smoke or have a history of smoking?',
                          'Behavioural_Risk_Factors1'),
                      _buildQuestionRow(' Do you consume alcohol regularly?',
                          'Behavioural_Risk_Factors2'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  buildSectionCard(
                    context: context,
                    title: '(7) Diagnostic Tests:',
                    icon: Icons.biotech_outlined,
                    children: [
                      _buildQuestionRow(
                          'Have you had any recent chest X-rays or other respiratory tests?',
                          'Diagnostic_Tests1'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
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
                  _familyIdReadOnly = false; // Allow typing for new searches
                  _familyCodeNode.requestFocus();
                });
              },
              onSave: _save,
              onEdit: () {
                setState(() {
                  _isEditMode = true;
                  _isActionActive = true;
                  _familyIdReadOnly = false; // Allow typing to search
                  _familyCodeNode.requestFocus();
                  final code = _familyCodeController.text.trim();
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
      title: 'Patient Identity',
      icon: Icons.person_outline,
      children: [
        formTextField('Registration Number', _registrationNumber, enabled: _isActionActive),
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
              _fetchMembersByFamily(v);
              _fetchExistingRecords(v);
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
          selectedMemberName,
          _onNameSelected,
          isLoading: _isLoadingMembers,
          enabled: _isActionActive,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
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
            Expanded(child: formTextField('Age', _ageController, enabled: _isActionActive, keyboardType: TextInputType.number, hint: 'e.g. 45')),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Date of Interview', interviewDate, (v) => setState(() => interviewDate = v), enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        formSearchableDropdown(
          context,
          'Interviewer’s Name',
          interviewers,
          selectedInterviewer,
          (v) => setState(() => selectedInterviewer = v as String?),
          enabled: _isActionActive,
        ),
        const SizedBox(height: 16),
        const Text('If not done, reason', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: reasons.map((r) => buildCompactRadio(
            label: r,
            value: r,
            groupValue: selectedReason,
            onChanged: !_isActionActive ? null : (v) => setState(() => selectedReason = v as String?),
            activeColor: Colors.deepOrange.shade700,
          )).toList(),
        ),
        if (selectedReason == '(4) Other') 
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: formTextField('Specify if other', _reasonIfOtherController, enabled: _isActionActive, hint: 'Single Line'),
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
            buildCompactRadio(
              label: '(1) Yes',
              value: '(1) Yes',
              groupValue: answers[key],
              onChanged: !_isActionActive ? null : (v) => setState(() => answers[key] = v as String?),
              activeColor: Colors.deepOrange.shade700,
            ),
            buildCompactRadio(
              label: '(2) No',
              value: '(2) No',
              groupValue: answers[key],
              onChanged: !_isActionActive ? null : (v) => setState(() => answers[key] = v as String?),
              activeColor: Colors.deepOrange.shade700,
            ),
          ],
        ),
        const Divider(),
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
        onTap: (!enabled || !_isActionActive) ? null : () async {
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
}
