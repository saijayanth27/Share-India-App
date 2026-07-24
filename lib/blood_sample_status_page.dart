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

class BloodSampleStatusPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const BloodSampleStatusPage({super.key, this.existingData, this.docId});

  @override
  State<BloodSampleStatusPage> createState() => _BloodSampleStatusPageState();
}

class _BloodSampleStatusPageState extends State<BloodSampleStatusPage> {
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

  bool _isDownloadingSamp = false;
  bool _sampAlreadyDownloaded = false;
  String? _sampDownloadedAt;

  // --- Controllers & State Variables ---
  final _registrationNumber = TextEditingController();
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  final _nameController = TextEditingController();
  final _age = TextEditingController();
  
  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectedGender;
  DateTime? dateOfInterview = DateTime.now();
  String? interviewersName;
  String? notDoneReason;
  List<Map<String, dynamic>> _allPersonRecords = [];
  List<String> _availableVisitDates = [];
  String? _selectedVisitDate;

  // Status Fields
  String? collectBloodSample;
  String? collectHBA1C;
  String? collectThyroid;
  String? collectCRE;
  String? collectSputumTB;
  String? collectVaginalSwabHPV;
  String? collectUrine;

  // Date Fields
  DateTime? dateCBP;
  DateTime? dateHBA1C;
  DateTime? dateThyroid;
  DateTime? dateCRE;
  DateTime? dateSputumTB;
  DateTime? dateVaginalSwabHPV;
  DateTime? dateUrine;

  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  // Location (auto-populated from Family Code)
  String? _locationVillage;
  String? _locationMandal;
  String? _locationDistrict;
  String? _locationState;


  final List<String> interviewerList = ['KIRANMAI K', 'REVATHI CH', 'RAMADEVI Y', 'LAVANYA KASPOJU', 'PUSHPA K', 'G RAMADEVI', 'BHASKAR K', 'ASHA', 'KUSUMA G', 'B JYOTHI', 'RAMADEVI G', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU'];

  @override
  void initState() {
    super.initState();
    _loadSampDownloadStatus();
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
    _familyCodeController.dispose();
    _nameController.dispose();
    _age.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSampDownloadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString('blood_sample_download_timestamp');
    if (mounted) setState(() { _sampAlreadyDownloaded = ts != null; _sampDownloadedAt = ts; });
  }

  Future<void> _downloadSampFromStorage() async {
    if (_isDownloadingSamp) return;
    final prefs = await SharedPreferences.getInstance();

    if (_sampAlreadyDownloaded) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Already Downloaded'),
          content: Text('Blood Sample data was downloaded on $_sampDownloadedAt.\n\nDownload again to refresh?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Re-download')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isDownloadingSamp = true);
    try {
      final ref = FirebaseStorage.instance.ref('exports/blood_sample_records.json');
      final url = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final List<dynamic> jsonList = jsonDecode(response.body);
      final records = jsonList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await LocalDatabaseService().saveBloodSampleRecords(records, clearFirst: true);
      final downloadedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      await prefs.setString('blood_sample_download_timestamp', downloadedAt);
      if (mounted) {
        setState(() { _sampAlreadyDownloaded = true; _sampDownloadedAt = downloadedAt; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Blood Sample data downloaded (${records.length} records)'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Download failed: $e'), backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isDownloadingSamp = false);
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
          .collection('blood_sample_status')
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
      selectedMemberName = name;
      _nameController.text = name ?? '';
      _allPersonRecords = [];
      _availableVisitDates = [];
      _selectedVisitDate = null;
    });

    if (name == null) return;
    final baseData = _allMembersData[name];
    if (baseData != null && !_isEditMode) {
      _registrationNumber.text = baseData['Registration_Number']?.toString() ?? '';
      selectedGender = normalizeGender(baseData['Gender']);
      _age.text = baseData['Age']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        List<Map<String, dynamic>> records = [];
        final localRecord = await LocalDatabaseService().getBloodSampleRecordByName(fCode, name);
        try {
          var snapshot = await FirebaseFirestore.instance
              .collection('blood_sample_status')
              .where('Family_code', isEqualTo: fCode)
              .where('Name', isEqualTo: name)
              .orderBy('clientUpdatedAt', descending: true)
              .get()
              .timeout(const Duration(seconds: 5));
          if (snapshot.docs.isEmpty) {
            snapshot = await FirebaseFirestore.instance
                .collection('blood_sample_status')
                .where('Family_Code', isEqualTo: fCode)
                .where('Name', isEqualTo: name)
                .orderBy('clientUpdatedAt', descending: true)
                .get()
                .timeout(const Duration(seconds: 5));
          }
          for (final doc in snapshot.docs) {
            records.add({...?baseData, ...?localRecord, ...doc.data(), 'firestoreDocId': doc.id});
          }
        } catch (e) {
          debugPrint('BloodSample: Firestore lookup failed: $e');
        }
        if (records.isEmpty && localRecord != null) records.add({...?baseData, ...localRecord});
        if (records.isEmpty && baseData != null) records.add(baseData);
        final dates = records.map((r) => _dateStringFromRecord(r)).where((d) => d != null).cast<String>().toList();
        if (mounted) {
          setState(() { _allPersonRecords = records; _availableVisitDates = dates; });
          if (records.length == 1) {
            _editDocId = records.first['firestoreDocId']?.toString();
            setState(() => _populateForm(records.first));
          }
        }
      } catch (e) {
        debugPrint('Error in BloodSample _onNameSelected: $e');
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

  String? _normCollect(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s == '1' || s == '(1) Collected') return '(1) Collected';
    if (s == '0' || s == '(0) Not Collected') return '(0) Not Collected';
    return s.isEmpty ? null : s;
  }

  void _populateForm(Map<String, dynamic> d) {
    _registrationNumber.text = (d['Registration_Number'] ?? d['REGNO'] ?? d['Regno'] ?? '').toString();
    selectedFamilyCode = d['Family_code'] ?? d['Family_Code'] ?? d['Family_ID'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _locationVillage  = (d['Village']  ?? d['village'])?.toString();
    _locationMandal   = (d['Mandal']   ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState    = (d['State']    ?? d['state'])?.toString();
    _nameController.text = selectedMemberName ?? '';
    selectedGender = normalizeGender(d['Gender']);
    _age.text = d['Age']?.toString() ?? '';

    // Date: app field → TETRA INTDT fallback
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

    interviewersName = matchInterviewerName(d['Interviewer_s_Name'] ?? d['interviewer_name'] ?? d['interviewer'] ?? d['Interviewer_Name'] ?? d['INTNAME'], interviewerList);
    // Not-done reason: NA_DL numeric codes from TETRA
    final naCode = {'1': '(1) Not available', '2': '(2) Refused for current visit', '3': '(3) Door Locked', '4': '(4) Other'};
    final rawNaDl = d['Not_Done_Reason'] ?? d['NA_DL'];
    notDoneReason = (rawNaDl != null) ? (naCode[rawNaDl.toString()] ?? rawNaDl.toString()) : null;

    // Collect status: app field OR TETRA SAMP field; normalize raw 1/0 codes
    collectBloodSample = _normCollect(d['Collect_Blood_Sample'] ?? d['CBP']);
    collectHBA1C = _normCollect(d['Collect_HBA1C'] ?? d['HBA1C']);
    collectThyroid = _normCollect(d['Collect_Thyroid'] ?? d['THYROID']);
    collectCRE = _normCollect(d['Collect_CRE'] ?? d['CRE']);
    collectSputumTB = _normCollect(d['Collect_Sputum_TB'] ?? d['SPUTUM']);
    collectVaginalSwabHPV = _normCollect(d['Collect_Vaginal_Swab_HPV'] ?? d['VS']);
    collectUrine = _normCollect(d['Collect_Urine'] ?? d['URINE']);

    DateTime? _parseSampleDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      return DateTime.tryParse(val.toString()) ?? ((){
        try { return DateFormat('dd-MMM-yyyy').parse(val.toString()); } catch(_) { return null; }
      }());
    }

    // Sample dates: app field OR TETRA SAMP DT* fields
    final dateCBPRaw = d['Date_CBP'] ?? d['DTCBP'];
    if (dateCBPRaw != null) dateCBP = _parseSampleDate(dateCBPRaw);
    final dateHBA1CRaw = d['Date_HBA1C'] ?? d['DTHBA1C'];
    if (dateHBA1CRaw != null) dateHBA1C = _parseSampleDate(dateHBA1CRaw);
    final dateThyroidRaw = d['Date_Thyroid'] ?? d['DTTHYROID'];
    if (dateThyroidRaw != null) dateThyroid = _parseSampleDate(dateThyroidRaw);
    final dateCRERaw = d['Date_CRE'] ?? d['DTCRE'];
    if (dateCRERaw != null) dateCRE = _parseSampleDate(dateCRERaw);
    final dateSputumRaw = d['Date_Sputum_TB'] ?? d['DTSPUTUM'];
    if (dateSputumRaw != null) dateSputumTB = _parseSampleDate(dateSputumRaw);
    final dateVSRaw = d['Date_Vaginal_Swab_HPV'] ?? d['DTVS'];
    if (dateVSRaw != null) dateVaginalSwabHPV = _parseSampleDate(dateVSRaw);
    final dateUrineRaw = d['Date_Urine'] ?? d['DTURINE'];
    if (dateUrineRaw != null) dateUrine = _parseSampleDate(dateUrineRaw);

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
      _age.clear();
      dateOfInterview = DateTime.now();
      interviewersName = null;
      notDoneReason = null;
      collectBloodSample = null;
      collectHBA1C = null;
      collectThyroid = null;
      collectCRE = null;
      collectSputumTB = null;
      collectVaginalSwabHPV = null;
      collectUrine = null;
      dateCBP = null;
      dateHBA1C = null;
      dateThyroid = null;
      dateCRE = null;
      dateSputumTB = null;
      dateVaginalSwabHPV = null;
      dateUrine = null;
      familyMemberNames = [];
      _existingRecords = [];
      _allPersonRecords = [];
      _availableVisitDates = [];
      _selectedVisitDate = null;
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
        'Village': _locationVillage,
        'Mandal': _locationMandal,
        'District': _locationDistrict,
        'State': _locationState,
        'Age': int.tryParse(_age.text),
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'Interviewer_s_Name': interviewersName,
        'Not_Done_Reason': notDoneReason,
        'Collect_Blood_Sample': collectBloodSample,
        'Collect_HBA1C': collectHBA1C,
        'Collect_Thyroid': collectThyroid,
        'Collect_CRE': collectCRE,
        'Collect_Sputum_TB': collectSputumTB,
        'Collect_Vaginal_Swab_HPV': collectVaginalSwabHPV,
        'Collect_Urine': collectUrine,
        'Date_CBP': dateCBP != null ? Timestamp.fromDate(dateCBP!) : null,
        'Date_HBA1C': dateHBA1C != null ? Timestamp.fromDate(dateHBA1C!) : null,
        'Date_Thyroid': dateThyroid != null ? Timestamp.fromDate(dateThyroid!) : null,
        'Date_CRE': dateCRE != null ? Timestamp.fromDate(dateCRE!) : null,
        'Date_Sputum_TB': dateSputumTB != null ? Timestamp.fromDate(dateSputumTB!) : null,
        'Date_Vaginal_Swab_HPV': dateVaginalSwabHPV != null ? Timestamp.fromDate(dateVaginalSwabHPV!) : null,
        'Date_Urine': dateUrine != null ? Timestamp.fromDate(dateUrine!) : null,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;

      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('blood_sample_status', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Blood Sample Status updated! Syncing...' : 'Blood Sample Status saved! Syncing...'),
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
        title: const Text('Blood Sample Status'),
        elevation: 0,
        actions: [
          _isDownloadingSamp
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : IconButton(
                  icon: Icon(Icons.cloud_download_outlined, color: _sampAlreadyDownloaded ? Colors.greenAccent : Colors.white),
                  tooltip: _sampAlreadyDownloaded ? 'Downloaded: $_sampDownloadedAt' : 'Download for offline',
                  onPressed: _downloadSampFromStorage,
                ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('blood_sample_status_scroll'),
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
                      title: 'Sample Collection Status',
                      icon: Icons.bloodtype_outlined,
                      children: [
                        _buildCollectionRow('Blood Sample (CBP/Glu)', collectBloodSample, dateCBP, (v) => setState(() => collectBloodSample = v), (d) => setState(() => dateCBP = d)),
                        _buildCollectionRow('HbA1c', collectHBA1C, dateHBA1C, (v) => setState(() => collectHBA1C = v), (d) => setState(() => dateHBA1C = d)),
                        _buildCollectionRow('Thyroid (T3/T4/TSH)', collectThyroid, dateThyroid, (v) => setState(() => collectThyroid = v), (d) => setState(() => dateThyroid = d)),
                        _buildCollectionRow('Creatinine (CRE)', collectCRE, dateCRE, (v) => setState(() => collectCRE = v), (d) => setState(() => dateCRE = d)),
                        _buildCollectionRow('Sputum (TB)', collectSputumTB, dateSputumTB, (v) => setState(() => collectSputumTB = v), (d) => setState(() => dateSputumTB = d)),
                        _buildCollectionRow('Vaginal Swab (HPV)', collectVaginalSwabHPV, dateVaginalSwabHPV, (v) => setState(() => collectVaginalSwabHPV = v), (d) => setState(() => dateVaginalSwabHPV = d), enabled: selectedGender != '(1) Male'),
                        _buildCollectionRow('Urine', collectUrine, dateUrine, (v) => setState(() => collectUrine = v), (d) => setState(() => dateUrine = d)),
                      ],
                    ),
                    const SizedBox(height: 40),
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
        if (_isEditMode && _availableVisitDates.isNotEmpty) ...[
          const SizedBox(height: 12),
          formSearchableDropdown(
            context, 'Select Visit Date', _availableVisitDates, _selectedVisitDate,
            (v) => _onVisitDateSelected(v?.toString()),
            enabled: _isActionActive,
            key: ValueKey('visit_${_availableVisitDates.length}'),
          ),
        ],
        const SizedBox(height: 12),
        const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: '(1) Male', groupValue: selectedGender, onChanged: !_isActionActive ? null : (v) => setState(() { selectedGender = v as String?; collectVaginalSwabHPV = null; dateVaginalSwabHPV = null; }), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: '(0) Female', groupValue: selectedGender, onChanged: !_isActionActive ? null : (v) => setState(() => selectedGender = v as String?), contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField('Age', _age, enabled: _isActionActive, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Interview Date', dateOfInterview, (v) => setState(() => dateOfInterview = v))),
          ],
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(context, 'Interviewer Name', interviewerList, interviewersName, (v) => setState(() => interviewersName = v as String?), enabled: _isActionActive),
      ],
    );
  }

  Widget _buildCollectionRow(String label, String? value, DateTime? date, ValueChanged<String?> onChanged, Function(DateTime) onDateChanged, {bool enabled = true}) {
    final isEnabled = _isActionActive && enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isEnabled ? Colors.black87 : Colors.grey.shade400)),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, 'Status', ['(1) Collected', '(0) Not Collected'], value, onChanged, enabled: isEnabled)),
            if (value == '(1) Collected') ...[
              const SizedBox(width: 12),
              Expanded(child: _buildDatePicker('Date', date, onDateChanged)),
            ],
          ],
        ),
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
          onTap: !_isActionActive ? null : () async {
            final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
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
