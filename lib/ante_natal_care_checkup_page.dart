import "package:flutter/material.dart";
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'local_database_service.dart';
import 'sync_service.dart';
import 'widget.dart';

class AnteNatalCareCheckupPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const AnteNatalCareCheckupPage({super.key, this.existingData, this.docId});

  @override
  State<AnteNatalCareCheckupPage> createState() => _AnteNatalCareCheckupPageState();
}

class _AnteNatalCareCheckupPageState extends State<AnteNatalCareCheckupPage> {
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
  bool _isDownloadingAncc = false;
  bool _anccAlreadyDownloaded = false;
  String? _anccDownloadedAt;

  // --- Identity Fields ---
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  final _nameController = TextEditingController();
  final _visitNo = TextEditingController();
  final _countOfCheckup = TextEditingController();

  String? selectedFamilyCode;
  String? selectedName;
  String? selectedGender;
  DateTime? lmpDate;

  // --- Checkup Details ---
  DateTime? checkupDt = DateTime.now();
  String? checkupPlace;

  // --- Medical Test Fields ---
  String? hbsag;
  String? hb;
  String? ultraS;
  String? vdrl;
  String? urine;
  String? hiv;

  // --- Vitals & BP ---
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();

  // --- Remarks ---
  final _remarks = TextEditingController();

  // Lookups
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  // Location (auto-populated from Family Code)
  String? _locationVillage;
  String? _locationMandal;
  String? _locationDistrict;
  String? _locationState;


  @override
  void initState() {
    super.initState();
    _loadAnccDownloadStatus();
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
    _familyCodeController.dispose();
    _nameController.dispose();
    _visitNo.dispose();
    _countOfCheckup.dispose();
    _weight.dispose();
    _height.dispose();
    _systolic.dispose();
    _diastolic.dispose();
    _remarks.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAnccDownloadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString('anc_checkups_download_timestamp');
    if (ts != null && mounted) {
      setState(() { _anccAlreadyDownloaded = true; _anccDownloadedAt = ts; });
    }
  }

  Future<void> _downloadAnccFromStorage() async {
    setState(() { _isDownloadingAncc = true; });
    try {
      final ref = FirebaseStorage.instance.ref().child('exports/anc_checkups.json');
      // getData() handles retries internally — no wasted bandwidth on failure
      final bytes = await ref.getData(100 * 1024 * 1024); // up to 100MB
      if (bytes == null) throw Exception('No data received');

      final List<dynamic> records = json.decode(String.fromCharCodes(bytes));
      final dbService = LocalDatabaseService();
      final List<Map<String, dynamic>> batch = [];
      int saved = 0;
      for (final r in records) {
        batch.add(Map<String, dynamic>.from(r as Map));
        if (batch.length == 500) {
          await dbService.saveAncCheckups(batch, clearFirst: saved == 0);
          saved += batch.length;
          batch.clear();
        }
      }
      if (batch.isNotEmpty) {
        await dbService.saveAncCheckups(batch, clearFirst: saved == 0);
        saved += batch.length;
      }

      final prefs = await SharedPreferences.getInstance();
      final ts = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      await prefs.setString('anc_checkups_download_timestamp', ts);

      if (mounted) {
        setState(() { _anccAlreadyDownloaded = true; _anccDownloadedAt = ts; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $saved ANC checkup records downloaded!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Download failed. Please check your network signal and try again.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ));
    } finally {
      if (mounted) setState(() => _isDownloadingAncc = false);
    }
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
      Set<String> excludedNames = {};
      List<Map<String, dynamic>> firestoreMembers = [];
      
      try {
        final fpSnapshot = await FirebaseFirestore.instance
            .collection('family_planning')
            .where('Family_Code', isEqualTo: fCode)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 3));
        
        excludedNames = fpSnapshot.docs
            .map((doc) => doc.data()['Name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toSet();

        final snapshot = await FirebaseFirestore.instance
            .collection('personal_details')
            .where('Family_Code', isEqualTo: fCode)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 3));
        
        firestoreMembers = snapshot.docs.map((d) => d.data() as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint('ANC Checkup: Firestore lookup failed/timeout, relying on LOCAL: $e');
      }

      final Map<String, Map<String, dynamic>> memberMap = {};
      final Set<String> names = {};
      
      // Process both lists, preferring Firestore but falling back to Local
      final combined = [...firestoreMembers, ...localMembers];
      
      for (var data in combined) {
        final name = data['Name']?.toString() ?? '';
        final gender = data['Gender']?.toString() ?? '';
        final maritalStatus = data['Marital_Status']?.toString() ?? '';
        final avStatus = data['A_v_Status']?.toString() ?? '';

        if (name.isEmpty) continue;

        // Filter: only members aged 18 or older
        final age = int.tryParse(data['Age']?.toString() ?? '0') ?? 0;
        if (age < 18) continue;

        // Filter: (0) Female AND ((1) Married OR (3) Widow) AND (1) Active AND Not in excludedNames
        bool isEligibleFemale = gender == '(0) Female' && 
                               (maritalStatus == '(1) Married' || maritalStatus == '(3) Widow') &&
                               avStatus == '(1) Active';
        
        if (isEligibleFemale && !excludedNames.contains(name)) {
          memberMap[name] = data;
          names.add(name);
        }
      }
      
      setState(() {
        _allMembersData = memberMap;
        familyMemberNames = names.toList()..sort();
        selectedFamilyCode = fCode;
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
      // 1. Local SQLite first (instant offline)
      final localRecords = await LocalDatabaseService().getAncCheckupsByFamily(familyCode);
      if (localRecords.isNotEmpty && mounted) {
        setState(() => _existingRecords = localRecords);
      }

      // 2. Firestore for fresh data
      final snapshot = await FirebaseFirestore.instance
          .collection('ante_natal_checkup')
          .where('Family_ID', isEqualTo: familyCode)
          .get().timeout(const Duration(seconds: 5));
      if (mounted) {
        final firestoreRecords = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
        final Map<String, Map<String, dynamic>> merged = {};
        for (final r in localRecords) { merged['${r['Registration_Number']}_${r['Visit_No']}'] = r; }
        for (final r in firestoreRecords) { merged['${r['Registration_Number'] ?? r['id']}_${r['Visit_No']}'] = r; }
        setState(() { _existingRecords = merged.values.toList(); _isLoadingMembers = false; });
      }
    } catch (e) {
      debugPrint('ANCC: Firestore fetch failed, using local: $e');
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  void _onNameSelected(String? name) async {
    setState(() {
      selectedName = name;
      _nameController.text = name ?? '';
    });
    
    if (name == null) return;

    // 1. Get base data (immediate)
    final baseData = _allMembersData[name];
    if (baseData != null && !_isEditMode) {
      selectedGender = baseData['Gender']?.toString();
    }

    // 2. Fetch specific record in Edit mode
    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        final snapshot = await FirebaseFirestore.instance
            .collection('ante_natal_checkup')
            .where('Family_ID', isEqualTo: fCode)
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
        debugPrint('Error fetching ANC Checkup: $e');
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
    selectedFamilyCode = d['Family_ID'] ?? d['Family_Code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedName = d['Name'];
    _locationVillage  = (d['Village']  ?? d['village'])?.toString();
    _locationMandal   = (d['Mandal']   ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState    = (d['State']    ?? d['state'])?.toString();
    _nameController.text = selectedName ?? '';
    selectedGender = d['Gender'];
    _visitNo.text = d['Visit_No']?.toString() ?? '';
    
    final rawLmpDate = d['LMP_Date'];
    if (rawLmpDate != null) {
      if (rawLmpDate is Timestamp) {
        lmpDate = rawLmpDate.toDate();
      } else {
        try {
          lmpDate = DateFormat('dd-MMM-yyyy').parse(rawLmpDate.toString());
        } catch (_) {
          try {
            lmpDate = DateTime.parse(rawLmpDate.toString());
          } catch (_) {}
        }
      }
    }
    
    _countOfCheckup.text = d['Count_of_Checkup']?.toString() ?? '';
    
    final rawCheckupDate = d['Checkup_Date'];
    if (rawCheckupDate != null) {
      if (rawCheckupDate is Timestamp) {
        checkupDt = rawCheckupDate.toDate();
      } else {
        try {
          checkupDt = DateFormat('dd-MMM-yyyy').parse(rawCheckupDate.toString());
        } catch (_) {
          try {
            checkupDt = DateTime.parse(rawCheckupDate.toString());
          } catch (_) {}
        }
      }
    }
    
    checkupPlace = d['Checkup_Place'];
    hbsag = d['HBsAg'];
    hb = d['Hb'];
    ultraS = d['UltraSelection'];
    vdrl = d['VDRL'];
    urine = d['Urine'];
    hiv = d['HIV'];
    _weight.text = d['Weight']?.toString() ?? '';
    _height.text = d['Height']?.toString() ?? '';
    _systolic.text = d['Systolic']?.toString() ?? '';
    _diastolic.text = d['Diastolic']?.toString() ?? '';
    _remarks.text = d['Remarks'] ?? '';

    if (!_isEditMode && selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _isActionActive = false;
      selectedFamilyCode = null;
      selectedName = null;
      selectedGender = null;
      _locationVillage = null;
      _locationMandal = null;
      _locationDistrict = null;
      _locationState = null;
      _familyCodeController.text = 'TSRRMED';
      _nameController.clear();
      _visitNo.clear();
      lmpDate = null;
      _countOfCheckup.clear();
      checkupDt = DateTime.now();
      checkupPlace = null;
      hbsag = null;
      hb = null;
      ultraS = null;
      vdrl = null;
      urine = null;
      hiv = null;
      _weight.clear();
      _height.clear();
      _systolic.clear();
      _diastolic.clear();
      _remarks.clear();
      familyMemberNames = [];
      _existingRecords = [];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Family_ID': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedName : _nameController.text,
        'Gender': selectedGender,
        'Village': _locationVillage,
        'Mandal': _locationMandal,
        'District': _locationDistrict,
        'State': _locationState,
        'Visit_No': int.tryParse(_visitNo.text),
        'LMP_Date': lmpDate != null ? Timestamp.fromDate(lmpDate!) : null,
        'Count_of_Checkup': int.tryParse(_countOfCheckup.text),
        'Checkup_Date': checkupDt != null ? Timestamp.fromDate(checkupDt!) : null,
        'Checkup_Place': checkupPlace,
        'HBsAg': hbsag,
        'Hb': hb,
        'UltraSelection': ultraS,
        'VDRL': vdrl,
        'Urine': urine,
        'HIV': hiv,
        'Weight': double.tryParse(_weight.text),
        'Height': double.tryParse(_height.text),
        'Systolic': int.tryParse(_systolic.text),
        'Diastolic': int.tryParse(_diastolic.text),
        'Remarks': _remarks.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('ante_natal_checkup', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'ANC Checkup updated! Syncing...' : 'ANC Checkup saved! Syncing...'),
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
        _isActionActive = false; // Add this
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('ANC Checkup'),
        elevation: 0,
        actions: [
          IconButton(
            icon: _isDownloadingAncc
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(Icons.sync, color: _anccAlreadyDownloaded ? Colors.greenAccent : Colors.white),
            tooltip: _anccAlreadyDownloaded ? 'Downloaded on $_anccDownloadedAt' : 'Sync ANC Checkup Records',
            onPressed: _isDownloadingAncc ? null : () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(_anccAlreadyDownloaded ? 'Re-Sync Checkup Records' : 'Sync ANC Checkup Records'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_anccAlreadyDownloaded
                          ? 'Checkup records were last downloaded on $_anccDownloadedAt.\n\nRe-download to get latest data?'
                          : 'Download ANC checkup records for offline use.'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.wifi, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'For best experience, use WiFi before downloading.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start')),
                  ],
                ),
              );
              if (confirm == true) _downloadAnccFromStorage();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('anc_checkup_scroll'),
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
                      title: 'Checkup Details',
                      icon: Icons.assignment_outlined,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildDatePicker('Checkup Date', checkupDt, (v) => setState(() => checkupDt = v), enabled: _isActionActive)),
                            const SizedBox(width: 12),
                            Expanded(child: formSearchableDropdown(context, 'Place', ['Subcentre', 'PHC', 'CHC', 'Dist Hosp', 'Others'], checkupPlace, (v) => setState(() => checkupPlace = v as String?), enabled: _isActionActive)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                             Expanded(child: formTextField('Weight (kg)', _weight, enabled: _isActionActive, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField('Height (cm)', _height, enabled: _isActionActive, keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: formTextField('Systolic', _systolic, enabled: _isActionActive, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField('Diastolic', _diastolic, enabled: _isActionActive, keyboardType: TextInputType.number)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Tests & Screenings',
                      icon: Icons.biotech_outlined,
                      children: [
                        Row(
                          children: [
                            Expanded(child: formSearchableDropdown(context, 'HBsAg', ['Pos', 'Neg'], hbsag, (v) => setState(() => hbsag = v as String?), enabled: _isActionActive)),
                            const SizedBox(width: 12),
                            Expanded(child: formSearchableDropdown(context, 'HIV', ['Pos', 'Neg'], hiv, (v) => setState(() => hiv = v as String?), enabled: _isActionActive)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: formSearchableDropdown(context, 'Hb', ['Normal', 'Anemic'], hb, (v) => setState(() => hb = v as String?), enabled: _isActionActive)),
                            const SizedBox(width: 12),
                            Expanded(child: formSearchableDropdown(context, 'VDRL', ['Pos', 'Neg'], vdrl, (v) => setState(() => vdrl = v as String?), enabled: _isActionActive)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: formSearchableDropdown(context, 'USG', ['Normal', 'Abnormal'], ultraS, (v) => setState(() => ultraS = v as String?), enabled: _isActionActive)),
                            const SizedBox(width: 12),
                            Expanded(child: formSearchableDropdown(context, 'Urine', ['Normal', 'Abnormal'], urine, (v) => setState(() => urine = v as String?), enabled: _isActionActive)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Remarks',
                      icon: Icons.description_outlined,
                      children: [
                        formTextField('General Remarks', _remarks, enabled: _isActionActive, maxLines: 3),
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
          selectedName,
          (v) => _onNameSelected(v as String?),
          isLoading: _isLoadingMembers,
          enabled: _isActionActive,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField('Visit No', _visitNo, enabled: _isActionActive, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('LMP Date', lmpDate, (v) => setState(() => lmpDate = v), enabled: _isActionActive)),
          ],
        ),
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
