import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'local_database_service.dart';
import 'sync_service.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isActionActive = false;
  final FocusNode _familyCodeNode = FocusNode();
  bool _familyIdReadOnly = true;

  bool _isDownloadingFBS = false;
  bool _fbsAlreadyDownloaded = false;
  String? _fbsDownloadedAt;

  // --- Identity Fields ---
  final _registrationNumber = TextEditingController();
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  final _nameController = TextEditingController();
  String? selectedFamilyCode;
  String? selectedName;
  String? selectedGender;
  final _age = TextEditingController();
  DateTime? dateOfInterview = DateTime.now();
  String? interviewersName;
  List<Map<String, dynamic>> _allPersonRecords = [];
  List<String> _availableVisitDates = [];
  String? _selectedVisitDate;

  final _otherReasonController = TextEditingController();
  final _lastMealDateController = TextEditingController();
  final _lastMealTimeController = TextEditingController();
  final _fbsResultController = TextEditingController();

  String? _notDoneReason;

  List<String> familyMembers = []; // List of names
  Map<String, Map<String, dynamic>> _allMembersData = {};
  // Location (auto-populated from Family Code)
  String? _locationVillage;
  String? _locationMandal;
  String? _locationDistrict;
  String? _locationState;
 // Full details
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
    _loadFBSDownloadStatus();
    if (widget.existingData != null) {
      _isEditMode = true;
      _editDocId = widget.docId;
      _loadExistingData();
      final familyCode = (widget.existingData!['Family_Code'] ?? widget.existingData!['Family_code'] ?? widget.existingData!['Family_Code_Creation'] ?? '').toString();
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
    _familyCodeController.dispose();
    _nameController.dispose();
    _age.dispose();
    _otherReasonController.dispose();
    _lastMealDateController.dispose();
    _lastMealTimeController.dispose();
    _fbsResultController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadExistingData() {
    setState(() {
      _populateForm(widget.existingData!);
    });
  }

  void _populateForm(Map<String, dynamic> d) {
    _registrationNumber.text = (d['Registration_Number'] ?? d['REGNO'] ?? d['Regno'] ?? '').toString();
    selectedFamilyCode = d['Family_code'] ?? d['Family_Code_Creation'] ?? d['Family_Code'] ?? d['FAM_ID'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedName = d['Name'];
    _locationVillage  = (d['Village']  ?? d['village'])?.toString();
    _locationMandal   = (d['Mandal']   ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState    = (d['State']    ?? d['state'])?.toString();
    _nameController.text = selectedName ?? '';
    selectedGender = normalizeGender(d['Gender']);
    _age.text = d['Age']?.toString() ?? '';
    // Interview date: current field OR old TETRA INTDT
    final rawDate = d['Date_of_Interview'] ?? d['Interview_Date'] ?? d['INTDT'];
    if (rawDate != null) {
      if (rawDate is Timestamp) {
        dateOfInterview = rawDate.toDate();
      } else {
        try {
          dateOfInterview = DateFormat('dd-MMM-yyyy').parse(rawDate.toString());
        } catch (_) {
          try {
            dateOfInterview = DateTime.parse(rawDate.toString());
          } catch (_) {}
        }
      }
    }
    interviewersName = matchInterviewerName(d['Interviewer_s_Name'] ?? d['interviewer_name'] ?? d['interviewer'] ?? d['Interviewer_Name'] ?? d['INTNAME'], ['KIRANMAI K', 'REVATHI CH', 'RAMADEVI Y', 'LAVANYA KASPOJU', 'PUSHPA K', 'G RAMADEVI', 'BHASKAR K', 'ASHA', 'KUSUMA G', 'B JYOTHI', 'RAMADEVI G', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU']);
    // Not done reason: current field OR old TETRA NA_DL (1=Not available, 2=Refused, 3=Door Locked, 4=Other)
    final naCode = d['NA_DL']?.toString().trim();
    _notDoneReason = d['If_not_done_reason'] ?? const {
      '1': '(1) Not available',
      '2': '(2) Refused for current visit',
      '3': '(3) Door Locked',
      '4': '(4) Other',
    }[naCode];
    _otherReasonController.text = d['reason'] ?? '';
    // Last meal: current fields OR old TETRA FOODDT / FOODTIME
    _lastMealDateController.text = d['Date_of_Last_Meal']?.toString() ?? d['FOODDT']?.toString() ?? '';
    _lastMealTimeController.text = d['Time_of_Last_Meal']?.toString() ?? d['FOODTIME']?.toString() ?? '';
    // FBS result: current field OR old TETRA SUGARREAD
    _fbsResultController.text = (d['FBS_Test_Result'] ?? d['SUGARREAD'])?.toString() ?? '';

    if (!_isEditMode && selectedFamilyCode != null && familyMembers.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  Future<void> _loadFBSDownloadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString('fbs_download_timestamp');
    if (mounted) setState(() { _fbsAlreadyDownloaded = ts != null; _fbsDownloadedAt = ts; });
  }

  Future<void> _downloadFBSFromStorage() async {
    if (_isDownloadingFBS) return;
    final prefs = await SharedPreferences.getInstance();

    if (_fbsAlreadyDownloaded) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Already Downloaded'),
          content: Text('FBS data was downloaded on $_fbsDownloadedAt.\n\nDownload again to refresh?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Re-download')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isDownloadingFBS = true);
    try {
      final ref = FirebaseStorage.instance.ref('exports/fbs_records.json');
      final url = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final List<dynamic> jsonList = jsonDecode(response.body);
      final records = jsonList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await LocalDatabaseService().saveFbsRecords(records, clearFirst: true);
      final downloadedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      await prefs.setString('fbs_download_timestamp', downloadedAt);
      if (mounted) {
        setState(() { _fbsAlreadyDownloaded = true; _fbsDownloadedAt = downloadedAt; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('FBS data downloaded (${records.length} records)'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Download failed: $e'), backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isDownloadingFBS = false);
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
      for (var doc in snapshot.docs) processMember(doc.data());
      for (var local in localMembers) processMember(local);
      setState(() {
        _allMembersData = memberMap;
        familyMembers = allNames.toList()..sort();
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
          .collection('blood_sugar_fasting')
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

  String? _dateStringFromRecord(Map<String, dynamic> r) {
    final raw = r['Date_of_Interview'] ?? r['Interview_Date'];
    if (raw == null) return null;
    if (raw is Timestamp) return DateFormat('dd-MMM-yyyy').format(raw.toDate());
    try { return DateFormat('dd-MMM-yyyy').format(DateFormat('dd-MMM-yyyy').parse(raw.toString())); } catch (_) {}
    try { return DateFormat('dd-MMM-yyyy').format(DateTime.parse(raw.toString())); } catch (_) {}
    return raw.toString();
  }

  void _onVisitDateSelected(String? dateStr) {
    if (dateStr == null) return;
    setState(() => _selectedVisitDate = dateStr);
    final rec = _allPersonRecords.firstWhere(
      (r) => _dateStringFromRecord(r) == dateStr,
      orElse: () => _allPersonRecords.first,
    );
    _editDocId = rec['firestoreDocId']?.toString();
    setState(() => _populateForm(rec));
  }

  void _onNameSelected(String? name) async {
    setState(() {
      selectedName = name;
      _nameController.text = name ?? '';
      _allPersonRecords = [];
      _availableVisitDates = [];
      _selectedVisitDate = null;
    });

    if (name == null) return;

    final baseData = _allMembersData[name];
    if (baseData != null && !_isEditMode) {
      _registrationNumber.text = (baseData['uniq_Registration_Number'] ?? baseData['Registration_Number'] ?? baseData['Registration_Number1'] ?? '').toString();
      selectedGender = baseData['Gender']?.toString();
      _age.text = baseData['Age']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        List<Map<String, dynamic>> records = [];

        try {
          var snapshot = await FirebaseFirestore.instance
              .collection('blood_sugar_fasting')
              .where('Family_code', isEqualTo: fCode)
              .where('Name', isEqualTo: name)
              .orderBy('clientUpdatedAt', descending: true)
              .get()
              .timeout(const Duration(seconds: 5));

          if (snapshot.docs.isEmpty) {
            snapshot = await FirebaseFirestore.instance
                .collection('blood_sugar_fasting')
                .where('Family_Code', isEqualTo: fCode)
                .where('Name', isEqualTo: name)
                .orderBy('clientUpdatedAt', descending: true)
                .get()
                .timeout(const Duration(seconds: 5));
          }

          for (final doc in snapshot.docs) {
            records.add({...?baseData, ...doc.data(), 'firestoreDocId': doc.id});
          }
        } catch (e) {
          debugPrint('FBS: Firestore lookup failed: $e');
        }

        if (records.isEmpty) {
          final localRecord = await LocalDatabaseService().getFbsRecordByName(fCode, name);
          if (localRecord != null) records.add({...?baseData, ...localRecord});
        }
        if (records.isEmpty && baseData != null) records.add(baseData);

        final dates = records
            .map((r) => _dateStringFromRecord(r))
            .where((d) => d != null)
            .cast<String>()
            .toList();

        if (mounted) {
          setState(() {
            _allPersonRecords = records;
            _availableVisitDates = dates;
          });
          if (records.length == 1) {
            _editDocId = records.first['firestoreDocId']?.toString();
            setState(() => _populateForm(records.first));
          }
        }
      } catch (e) {
        debugPrint('Error in FBS _onNameSelected: $e');
        if (baseData != null) _populateForm(baseData);
      } finally {
        if (mounted) setState(() => _isLoadingMembers = false);
      }
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
      selectedName = null;
      selectedGender = null;
      _locationVillage = null;
      _locationMandal = null;
      _locationDistrict = null;
      _locationState = null;
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
      _allPersonRecords = [];
      _availableVisitDates = [];
      _selectedVisitDate = null;
    });
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate High Sugar
    double? sugarValue = double.tryParse(_fbsResultController.text);
    if (sugarValue != null && sugarValue > 140) {
      bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('High Blood Sugar Detected', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text('The entered sugar reading ($sugarValue) indicates High Blood Sugar.\n\nAre you sure you want to save this reading?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Acknowledge & Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isLoading = true);
    try {
      final data = {
        'Registration_Number': _registrationNumber.text,
        'Family_code': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedName : _nameController.text,
        'Gender': selectedGender,
        'Village': _locationVillage,
        'Mandal': _locationMandal,
        'District': _locationDistrict,
        'State': _locationState,
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

      // 2. Trigger Background Sync (Handles Firestore push)
      SyncService().syncPendingSubmissions();

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
      if (mounted) setState(() {
        _isLoading = false;
        _isActionActive = false; // Add this
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Blood Sugar Form(After Eating)'),
        elevation: 0,
        actions: [
          _isDownloadingFBS
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : IconButton(
                  icon: Icon(Icons.cloud_download_outlined, color: _fbsAlreadyDownloaded ? Colors.greenAccent : Colors.white),
                  tooltip: _fbsAlreadyDownloaded ? 'Downloaded: $_fbsDownloadedAt' : 'Download for offline',
                  onPressed: _downloadFBSFromStorage,
                ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('blood_sugar_fasting_scroll'),
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
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
                          (v) => setState(() => _notDoneReason = v as String?),
                          enabled: _isActionActive,
                        ),
                        if (_notDoneReason == "(4) Other") ...[
                          const SizedBox(height: 12),
                          formTextField('If Others Please Mention', _otherReasonController, enabled: _isActionActive),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: formTextField('Date of Last Meal', _lastMealDateController, enabled: _isActionActive, hint: 'dd-MMM-yyyy')),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTimePicker('Time of Last Meal', _lastMealTimeController)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('(Note: Use 24-hour format)', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                        const SizedBox(height: 16),
                        formTextField('FBS Test Result (mg/dL)', _fbsResultController, enabled: _isActionActive, keyboardType: TextInputType.number),
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
      bottomNavigationBar: _isLoading
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
              onSave: _saveForm,
              onEdit: () {
                setState(() {
                  _isEditMode = true;
                  _isActionActive = true;
                  _familyIdReadOnly = false;
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
              isSaving: _isLoading,
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
            if (_familyCodeController.text.isNotEmpty) {
              _fetchMembersByFamily(_familyCodeController.text);
              _fetchExistingRecords(_familyCodeController.text);
            }
          },
          isLoading: _isLoadingMembers,
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
          (<String>{...familyMembers, ..._existingRecords.map((r) => r['Name']?.toString() ?? '')}
              .where((n) => n.isNotEmpty)
              .toList()
            ..sort()),
          selectedName,
          _onNameSelected,
          isLoading: _isLoadingMembers,
          enabled: _isActionActive,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        if (_isEditMode && _availableVisitDates.isNotEmpty) ...[
          const SizedBox(height: 12),
          formSearchableDropdown(
            context, 'Select Visit Date', _availableVisitDates, _selectedVisitDate,
            (v) => _onVisitDateSelected(v?.toString()),
            enabled: _isActionActive,
            key: ValueKey('fbs_visit_${_availableVisitDates.length}'),
          ),
        ],
        const SizedBox(height: 12),
        const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('(1) Male'),
                value: '(1) Male',
                groupValue: selectedGender,
                onChanged: !_isActionActive ? null : (v) => setState(() => selectedGender = v as String?),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('(0) Female'),
                value: '(0) Female',
                groupValue: selectedGender,
                onChanged: !_isActionActive ? null : (v) => setState(() => selectedGender = v as String?),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField('Age', _age, enabled: _isActionActive, keyboardType: TextInputType.number, hint: 'e.g. 45')),
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
          (v) => setState(() => interviewersName = v as String?),
          enabled: _isActionActive,
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
          onTap: !_isActionActive ? null : () async {
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

  Widget _buildTimePicker(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        InkWell(
          onTap: !_isActionActive ? null : () async {
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
