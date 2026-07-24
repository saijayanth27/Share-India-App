import "package:flutter/material.dart";
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

class RefusedFormPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const RefusedFormPage({super.key, this.existingData, this.docId});

  @override
  State<RefusedFormPage> createState() => _RefusedFormPageState();
}

class _RefusedFormPageState extends State<RefusedFormPage> {
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

  bool _isDownloadingRef = false;
  bool _refAlreadyDownloaded = false;
  String? _refDownloadedAt;

  // Controllers
  final _registrationNumberController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
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
  // Location (auto-populated from Family Code)
  String? _locationVillage;
  String? _locationMandal;
  String? _locationDistrict;
  String? _locationState;


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
    _loadRefDownloadStatus();
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
    _registrationNumberController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _familyCodeController.dispose();
    _specifyOtherController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRefDownloadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString('refusal_download_timestamp');
    if (mounted) setState(() { _refAlreadyDownloaded = ts != null; _refDownloadedAt = ts; });
  }

  Future<void> _downloadRefFromStorage() async {
    if (_isDownloadingRef) return;
    final prefs = await SharedPreferences.getInstance();

    if (_refAlreadyDownloaded) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Already Downloaded'),
          content: Text('Refusal data was downloaded on $_refDownloadedAt.\n\nDownload again to refresh?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Re-download')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isDownloadingRef = true);
    try {
      final ref = FirebaseStorage.instance.ref('exports/refusal_records.json');
      final url = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final List<dynamic> jsonList = jsonDecode(response.body);
      final records = jsonList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await LocalDatabaseService().saveRefusalRecords(records, clearFirst: true);
      final downloadedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      await prefs.setString('refusal_download_timestamp', downloadedAt);
      if (mounted) {
        setState(() { _refAlreadyDownloaded = true; _refDownloadedAt = downloadedAt; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Refusal data downloaded (${records.length} records)'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Download failed: $e'), backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isDownloadingRef = false);
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
          .collection('refused_form')
          .where('Family_code', isEqualTo: familyCode)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 8));
      if (snapshot.docs.isEmpty) {
        // Fallback to old collection
        final oldSnapshot = await FirebaseFirestore.instance
            .collection('withdrawal_refusal_form')
            .where('Family_Code', isEqualTo: familyCode)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 8));
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
      selectedGender = normalizeGender(baseData['Gender']);
      _ageController.text = baseData['Age']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();

        // Check local SQLite first
        final localRecord = await LocalDatabaseService().getRefusalRecordByName(fCode, name);
        if (localRecord != null) {
          final merged = {...?baseData, ...localRecord};
          if (mounted) setState(() => _populateForm(merged));
        }

        // Try Firestore with timeout
        try {
          var snapshot = await FirebaseFirestore.instance
              .collection('refused_form')
              .where('Family_code', isEqualTo: fCode)
              .where('Name', isEqualTo: name)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 5));

          if (snapshot.docs.isEmpty) {
            snapshot = await FirebaseFirestore.instance
                .collection('withdrawal_refusal_form')
                .where('Family_Code', isEqualTo: fCode)
                .where('Name', isEqualTo: name)
                .limit(1)
                .get()
                .timeout(const Duration(seconds: 5));
          }

          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            final merged = {...?baseData, ...?localRecord, ...doc.data()};
            if (mounted) setState(() { _editDocId = doc.id; _populateForm(merged); });
          } else if (localRecord == null && baseData != null) {
            _populateForm(baseData);
          }
        } catch (e) {
          debugPrint('Refusal: Firestore lookup failed, using local: $e');
          if (localRecord == null && baseData != null) _populateForm(baseData);
        }
      } catch (e) {
        debugPrint('Error in refusal _onNameSelected: $e');
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
    _registrationNumberController.text = (d['Registration_Number'] ?? d['REGNO'] ?? d['Regno'] ?? '').toString();
    selectedFamilyCode = d['Family_code'] ?? d['Family_Code'] ?? d['Family_ID'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _locationVillage  = (d['Village']  ?? d['village'])?.toString();
    _locationMandal   = (d['Mandal']   ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState    = (d['State']    ?? d['state'])?.toString();
    _nameController.text = selectedMemberName ?? '';
    selectedGender = normalizeGender(d['Gender']);
    _ageController.text = d['Age']?.toString() ?? d['Age1']?.toString() ?? '';

    // Date: app field → TETRA INTDT → CREATED_DT fallback
    final rawInterviewDate = d['Date_of_Interview'] ?? d['Interview_Date'] ?? d['INTDT'] ?? d['CREATED_DT'];
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

    selectedInterviewer = matchInterviewerName(d['Interviewer_s_Name'] ?? d['Interviewer_Name'] ?? d['INTNAME'], interviewers);
    // Respondent → TETRA RESP fallback (already text like "Family members")
    selectedRespondent = d['Respondent'] ?? d['RESP'];
    // Reason: map TETRA numeric codes 1-4 to app labels
    final rawReason = d['Reason_for_withdrawing_from_study'] ?? d['Reason'] ?? d['REASON'];
    const reasonMap = {
      '1': '(1) Left the Village',
      '2': '(2) Died',
      '3': '(3) Double code',
      '4': '(4) Not Interested / Refused',
    };
    selectedReason = (rawReason != null) ? (reasonMap[rawReason.toString()] ?? rawReason.toString()) : null;
    // Death date → TETRA DIED_DT fallback
    final rawDeathDate = d['Death_Date'] ?? d['DIED_DT'];
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
    _specifyOtherController.text = d['other_reasons_specified'] ?? d['Specify_Other_Reason'] ?? d['REASON_SPY'] ?? '';

    if (!_isEditMode && selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _isActionActive = false;
      _registrationNumberController.clear();
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
      final regNo = _registrationNumberController.text.trim();
      final data = {
        'Registration_Number': regNo,
        'Family_code': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Village': _locationVillage,
        'Mandal': _locationMandal,
        'District': _locationDistrict,
        'State': _locationState,
        'Age': int.tryParse(_ageController.text),
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'Interviewer_s_Name': selectedInterviewer,
        'Respondent': selectedRespondent,
        'Reason_for_withdrawing_from_study': selectedReason,
        'Death_Date': deathDate != null ? Timestamp.fromDate(deathDate!) : null,
        'other_reasons_specified': _specifyOtherController.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
        // Use Registration_Number as the stable doc ID so re-saving the same
        // registration number overwrites instead of creating a duplicate.
        'firestoreDocId': _editDocId ?? 'refused_$regNo',
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
      SyncService().syncPendingSubmissions();
    } catch (e) {
      debugPrint('Error saving refusal form: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save refusal form.'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() {
        _isSaving = false;
        _isActionActive = false; // Add this
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Withdrawal Consent Form',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
        actions: [
          _isDownloadingRef
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : IconButton(
                  icon: Icon(Icons.cloud_download_outlined, color: _refAlreadyDownloaded ? Colors.greenAccent : Colors.white),
                  tooltip: _refAlreadyDownloaded ? 'Downloaded: $_refDownloadedAt' : 'Download for offline',
                  onPressed: _downloadRefFromStorage,
                ),
        ],
      ),
      drawer: const AppDrawer(),
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
                    buildSectionCard(
                      context: context,
                      title: 'Withdrawal / Refusal Details',
                      icon: Icons.cancel_outlined,
                      children: [
                        formSearchableDropdown(
                            context,
                            'Information given by whom?',
                            respondents,
                            selectedRespondent,
                            (v) => setState(() => selectedRespondent = v as String?),
                            enabled: _isActionActive),
                        const SizedBox(height: 16),
                        formSearchableDropdown(
                            context,
                            'Reason for Withdrawal/Refusal',
                            withdrawalReasons,
                            selectedReason,
                            (v) => setState(() => selectedReason = v as String?),
                            enabled: _isActionActive),
                        if (selectedReason == '(2) Died') ...[
                          const SizedBox(height: 12),
                          _buildDatePicker('Date of Death', deathDate,
                              (v) => setState(() => deathDate = v), enabled: _isActionActive),
                        ],
                        if (selectedReason == '(4) Not Interested / Refused')
                          ...[
                          const SizedBox(height: 12),
                          formTextField(
                              'Specify Other Reasons', _specifyOtherController,
                              enabled: _isActionActive,
                              maxLines: 2),
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
      title: 'Member Identity',
      icon: Icons.person_outline,
      children: [
        formTextField('Registration Number', _registrationNumberController, enabled: _isActionActive),
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
            Expanded(child: _buildDatePicker('Interview Date', dateOfInterview, (v) => setState(() => dateOfInterview = v), enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(context, 'Interviewer Name', interviewers, selectedInterviewer, (v) => setState(() => selectedInterviewer = v as String?), enabled: _isActionActive),
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
}
