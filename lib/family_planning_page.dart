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

class FamilyPlanningPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;
  final String? initialFamilyCode;

  const FamilyPlanningPage({super.key, this.existingData, this.docId, this.initialFamilyCode});

  @override
  State<FamilyPlanningPage> createState() => _FamilyPlanningPageState();
}

class _FamilyPlanningPageState extends State<FamilyPlanningPage> {
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

  bool _isDownloadingFP = false;
  bool _fpAlreadyDownloaded = false;
  String? _fpDownloadedAt;

  // --- Basic Information ---
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  final _nameController = TextEditingController();
  final _husbandNameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _remarksController = TextEditingController();

  // --- Contraceptives Controllers ---
  final _howLongOralController = TextEditingController();
  final _ifYesOtherController = TextEditingController();
  final _howLongUseOralController = TextEditingController();
  final _ifYesController = TextEditingController();

  // --- State ---
  String? selectedFamilyCode;
  String? selectedName;
  String? selectedGender;
  String? selectEntryScreen;

  // Permanent Fields
  String? permanentUsed;
  DateTime? permanentDate;
  String? permanentPlace;

  // Temporary Fields
  String? usedOralContraceptives;
  DateTime? lastUseOralDate;
  String? usedCondoms;
  String? usedCopperT;
  String? usedInjectable;
  String? howLongInjectable;
  DateTime? lastUseInjectableDate;
  DateTime? temporaryDate;
  String? usedOther;

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
    _loadFPDownloadStatus();
    if (widget.initialFamilyCode != null) {
      _familyCodeController.text = widget.initialFamilyCode!;
      _fetchMembersByFamily(widget.initialFamilyCode!);
      _fetchExistingRecords(widget.initialFamilyCode!);
    }
    if (widget.existingData != null) {
      _isEditMode = true;
      _editDocId = widget.docId;
      _loadExistingData();
      final familyCode = (widget.existingData!['Family_Code'] ?? widget.existingData!['Family_code'] ?? '').toString();
      if (familyCode.isNotEmpty) {
        _fetchMembersByFamily(familyCode).then((_) {
          if (mounted && _husbandNameController.text.isEmpty && selectedName != null) {
            final memberData = _allMembersData[selectedName];
            if (memberData != null) {
              final hName = (memberData['Name2'] ?? '').toString();
              if (hName.isNotEmpty) setState(() => _husbandNameController.text = hName);
            }
          }
        });
        _fetchExistingRecords(familyCode);
      }
    }
  }

  @override
  void dispose() {
    _familyCodeNode.dispose();
    _familyCodeController.dispose();
    _nameController.dispose();
    _husbandNameController.dispose();
    _regNoController.dispose();
    _remarksController.dispose();
    _howLongOralController.dispose();
    _ifYesOtherController.dispose();
    _howLongUseOralController.dispose();
    _ifYesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFPDownloadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString('family_planning_download_timestamp');
    if (mounted) setState(() { _fpAlreadyDownloaded = ts != null; _fpDownloadedAt = ts; });
  }

  Future<void> _downloadFPFromStorage() async {
    if (_isDownloadingFP) return;
    final prefs = await SharedPreferences.getInstance();

    if (_fpAlreadyDownloaded) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Already Downloaded'),
          content: Text('Family Planning data was downloaded on $_fpDownloadedAt.\n\nDownload again to refresh?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Re-download')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isDownloadingFP = true);
    try {
      final ref = FirebaseStorage.instance.ref('exports/family_planning.json');
      final url = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final List<dynamic> jsonList = jsonDecode(response.body);
      final records = jsonList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await LocalDatabaseService().saveFamilyPlanningRecords(records, clearFirst: true);
      final downloadedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      await prefs.setString('family_planning_download_timestamp', downloadedAt);
      if (mounted) {
        setState(() { _fpAlreadyDownloaded = true; _fpDownloadedAt = downloadedAt; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Family Planning data downloaded (${records.length} records)'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Download failed: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isDownloadingFP = false);
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
            .where('Select_Entry_Screen', isEqualTo: '(1) Permanent')
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
        debugPrint('FP: Firestore lookup failed/timeout, relying on LOCAL: $e');
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

        // Filter: (0) Female AND (1) Married AND (1) Active AND Not in excludedNames
        bool isEligibleFemale = gender == '(0) Female' && 
                               maritalStatus == '(1) Married' &&
                               avStatus == '(1) Active';
        
        if (isEligibleFemale && !excludedNames.contains(name)) {
          memberMap[name] = data;
          names.add(name);
        }
      }
      
      setState(() {
        _allMembersData = memberMap;
        familyMemberNames = names.toList()..sort();
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
      final fCode = familyCode.trim().toUpperCase();
      final localRecords = await LocalDatabaseService().getFamilyPlanningByFamily(fCode);

      List<Map<String, dynamic>> firestoreRecords = [];
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('family_planning')
            .where('Family_Code', isEqualTo: familyCode)
            .get()
            .timeout(const Duration(seconds: 5));
        firestoreRecords = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
      } catch (e) {
        debugPrint('FP: Firestore fetch failed, using local: $e');
      }

      final Map<String, Map<String, dynamic>> merged = {};
      for (final r in localRecords) {
        final key = r['Name']?.toString() ?? r['Registration_Number']?.toString() ?? '';
        if (key.isNotEmpty) merged[key] = r;
      }
      for (final r in firestoreRecords) {
        final key = r['Name']?.toString() ?? r['Registration_Number']?.toString() ?? '';
        if (key.isNotEmpty) merged[key] = r;
      }

      setState(() {
        _existingRecords = merged.values.toList();
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error fetching FP records: $e');
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
      _regNoController.text = (baseData['uniq_Registration_Number'] ?? baseData['Registration_Number'] ?? baseData['Registration_Number1'] ?? '').toString();
      final hName = (baseData['Name2'] ?? '').toString();
      if (hName.isNotEmpty) {
        _husbandNameController.text = hName;
      }
      selectedGender = baseData['Gender']?.toString();
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();

        // Check local SQLite first
        final localRecord = await LocalDatabaseService().getFamilyPlanningByName(fCode, name);
        if (localRecord != null) {
          final merged = {...?baseData, ...localRecord};
          if (mounted) setState(() => _populateForm(merged));
        }

        // Then try Firestore with timeout to get the doc ID for saving
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('family_planning')
              .where('Family_Code', isEqualTo: fCode)
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
          debugPrint('FP: Firestore name lookup failed, using local: $e');
          if (localRecord == null && baseData != null) _populateForm(baseData);
        }
      } catch (e) {
        debugPrint('Error in _onNameSelected FP: $e');
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

  String? _matchOption(dynamic raw, List<String> options) {
    if (raw == null) return null;
    final v = raw.toString().trim();
    if (v.isEmpty) return null;
    for (final o in options) if (o == v) return o;
    for (final o in options) {
      final m = RegExp(r'^\((\d+)\)').firstMatch(o);
      if (m != null && m.group(1) == v) return o;
    }
    final lower = v.toLowerCase();
    for (final o in options) {
      final label = o.replaceAll(RegExp(r'^\(\d+\)\s*'), '').toLowerCase();
      if (label == lower || o.toLowerCase().contains(lower) || lower.contains(label)) return o;
    }
    return null;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is Map) {
      final s = raw['_seconds'] ?? raw['seconds'];
      if (s != null) return DateTime.fromMillisecondsSinceEpoch((s as int) * 1000);
    }
    final s = raw.toString();
    return DateTime.tryParse(s) ?? (() { try { return DateFormat('dd-MMM-yyyy').parse(s); } catch (_) { return null; } })();
  }

  void _populateForm(Map<String, dynamic> d) {
    _regNoController.text = d['Registration_Number']?.toString() ?? '';
    selectedFamilyCode = d['Family_Code'] ?? d['Family_code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedName = d['Name'];
    _locationVillage  = (d['Village']  ?? d['village'])?.toString();
    _locationMandal   = (d['Mandal']   ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState    = (d['State']    ?? d['state'])?.toString();
    _nameController.text = selectedName ?? '';
    _husbandNameController.text = (d['Husband_Name']?.toString().isNotEmpty == true) ? d['Husband_Name'].toString() : (d['Name2'] ?? '').toString();
    selectedGender = d['Gender'];
    // Entry screen: current fields OR old REACH METHOD_TYPE (0=Temporary, 1=Permanent)
    selectEntryScreen = _matchOption(
      d['Select_Entry_Screen'] ?? d['select_entry_screen'] ?? d['fp_type'] ?? d['entry_screen'] ?? d['METHOD_TYPE'],
      ['(1) Permanent', '(0) Temporary'],
    );

    // Permanent: current fields OR old REACH METHOD_USED / FP_DATE / FP_PLACE
    permanentUsed = _matchOption(
      d['Used'] ?? d['fp_method'] ?? d['perm_method'] ?? d['METHOD_USED'],
      ['(0) Tubectomy', '(1) Vasectomy', '(2) Hysectomy'],
    );
    permanentDate = _parseDate(d['Date_field1'] ?? d['perm_date'] ?? d['date_field1'] ?? d['FP_DATE']);
    permanentPlace = _matchOption(
      d['Place'] ?? d['fp_place'] ?? d['perm_place'] ?? d['FP_PLACE'],
      ['(0) RHC', '(1) PVT', '(2) GOVT'],
    );
    _remarksController.text = d['Remarks']?.toString() ?? '';

    // Temporary: current fields OR old REACH CC_ prefixed field names
    final yesNo = ['(1) Yes', '(0) No'];
    usedOralContraceptives = _matchOption(d['Used_oral_contraceptives'] ?? d['oral_contra'] ?? d['CC_USE_ORAL_CON'], yesNo);
    _howLongUseOralController.text = d['How_long_use_oral1']?.toString() ?? d['CC_LONG_USE_ORAL_CON']?.toString() ?? '';
    lastUseOralDate = _parseDate(d['Last_use_oral_contraceptives'] ?? d['last_oral_date'] ?? d['CC_LAST_USE_ORAL_CON']);
    usedCondoms = _matchOption(d['Used_condoms'] ?? d['condoms'] ?? d['CC_USE_CONDOMS'], yesNo);
    usedCopperT = _matchOption(d['Used_an_Copper_T'] ?? d['copper_t'] ?? d['coppert'] ?? d['CC_USE_IUCD'], yesNo);
    usedInjectable = _matchOption(d['Used_injectable_contraceptives'] ?? d['injectable'] ?? d['CC_USE_INJE_CON'], yesNo);
    howLongInjectable = d['How_long_using_injectable_contraceptives']?.toString() ?? d['CC_LONG_USE_INJE_CON']?.toString();
    lastUseInjectableDate = _parseDate(d['Last_use_injectable_contraceptives'] ?? d['last_inject_date'] ?? d['CC_LAST_USE_INJEL_CON']);
    temporaryDate = _parseDate(d['Date_field2'] ?? d['temp_date'] ?? d['date_field2']);
    usedOther = _matchOption(d['Used_other'] ?? d['other_method'] ?? d['CC_OTH_BIRTH_CONT'], yesNo);
    _ifYesController.text = d['If_yes']?.toString() ?? d['CC_OTH_BIRTH_CONT_YES']?.toString() ?? '';

    if (!_isEditMode && selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _isActionActive = false;
      _regNoController.clear();
      _familyCodeController.text = 'TSRRMED';
      _nameController.clear();
      _husbandNameController.clear();
      _remarksController.clear();
      _howLongOralController.clear();
      _ifYesOtherController.clear();
      _howLongUseOralController.clear();
      _ifYesController.clear();

      selectedFamilyCode = null;
      selectedName = null;
      selectedGender = null;
      _locationVillage = null;
      _locationMandal = null;
      _locationDistrict = null;
      _locationState = null;
      selectEntryScreen = null;
      permanentUsed = null;
      permanentDate = null;
      permanentPlace = null;
      usedOralContraceptives = null;
      lastUseOralDate = null;
      usedCondoms = null;
      usedCopperT = null;
      usedInjectable = null;
      howLongInjectable = null;
      lastUseInjectableDate = null;
      temporaryDate = null;
      usedOther = null;

      familyMemberNames = [];
      _existingRecords = [];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number': _regNoController.text,
        'Family_Code': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedName : _nameController.text,
        'Husband_Name': _husbandNameController.text,
        'Gender': selectedGender,
        'Village': _locationVillage,
        'Mandal': _locationMandal,
        'District': _locationDistrict,
        'State': _locationState,
        'Select_Entry_Screen': selectEntryScreen,

        // Permanent
        'Used': permanentUsed,
        'Date_field1': permanentDate != null ? Timestamp.fromDate(permanentDate!) : null,
        'Place': permanentPlace,
        'Remarks': _remarksController.text,

        // Temporary
        'Used_oral_contraceptives': usedOralContraceptives,
        'How_long_use_oral1': _howLongUseOralController.text,
        'Last_use_oral_contraceptives': lastUseOralDate != null ? Timestamp.fromDate(lastUseOralDate!) : null,
        'Used_condoms': usedCondoms,
        'Used_an_Copper_T': usedCopperT,
        'Used_injectable_contraceptives': usedInjectable,
        'How_long_using_injectable_contraceptives': howLongInjectable,
        'Last_use_injectable_contraceptives': lastUseInjectableDate != null ? Timestamp.fromDate(lastUseInjectableDate!) : null,
        'Date_field2': temporaryDate != null ? Timestamp.fromDate(temporaryDate!) : null,
        'Used_other': usedOther,
        'If_yes': _ifYesController.text,

        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('family_planning', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Family Planning updated! Syncing...' : 'Family Planning saved! Syncing...'),
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
        title: const Text('Family Planning'),
        elevation: 0,
        actions: [
          _isDownloadingFP
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                )
              : IconButton(
                  icon: Icon(Icons.cloud_download_outlined, color: _fpAlreadyDownloaded ? Colors.greenAccent : Colors.white),
                  tooltip: _fpAlreadyDownloaded ? 'Downloaded: $_fpDownloadedAt' : 'Download for offline',
                  onPressed: _downloadFPFromStorage,
                ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('family_planning_scroll'),
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
                      title: 'Entry Selection',
                      icon: Icons.settings_outlined,
                      children: [
                        formSearchableDropdown(
                            context,
                            'Select Entry Screen',
                            ['(1) Permanent', '(0) Temporary'],
                            selectEntryScreen,
                            (v) => setState(() => selectEntryScreen = v as String?),
                            enabled: _isActionActive),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (selectEntryScreen == '(1) Permanent')
                      _buildPermanentSection(),
                    if (selectEntryScreen == '(0) Temporary')
                      _buildTemporarySection(),
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
        formTextField('Registration Number', _regNoController, enabled: _isActionActive),
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
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
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
          _onNameSelected,
          isLoading: _isLoadingMembers,
          enabled: _isActionActive,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        formTextField('Husband Name', _husbandNameController, enabled: _isActionActive),
      ],
    );
  }

  Widget _buildPermanentSection() {
    return buildSectionCard(
      context: context,
      title: 'Permanent Method',
      icon: Icons.verified_user_outlined,
      children: [
        formSearchableDropdown(context, 'Used?', ['(0) Tubectomy', '(1) Vasectomy', '(2) Hysectomy'], permanentUsed, (v) => setState(() => permanentUsed = v as String?), enabled: _isActionActive),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildDatePicker('Date?', permanentDate, (v) => setState(() => permanentDate = v), enabled: _isActionActive)),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, 'Place?', ['(0) RHC', '(1) PVT', '(2) GOVT'], permanentPlace, (v) => setState(() => permanentPlace = v as String?), enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 12),
        formTextField('Remarks', _remarksController, enabled: _isActionActive, maxLines: 3),
      ],
    );
  }

  Widget _buildTemporarySection() {
    return buildSectionCard(
      context: context,
      title: 'Temporary Method',
      icon: Icons.history_outlined,
      children: [
        _buildDropdownRow('Used oral contraceptives?', ['(1) Yes', '(0) No'], usedOralContraceptives, (v) => setState(() => usedOralContraceptives = v as String?), enabled: _isActionActive),
        if (usedOralContraceptives == '(1) Yes') ...[
          formTextField('How long use oral', _howLongUseOralController, enabled: _isActionActive),
          const SizedBox(height: 12),
          _buildDatePicker('Last use oral contraceptives?', lastUseOralDate, (v) => setState(() => lastUseOralDate = v), enabled: _isActionActive),
          const SizedBox(height: 16),
        ],
        _buildDropdownRow('Used condoms?', ['(1) Yes', '(0) No'], usedCondoms, (v) => setState(() => usedCondoms = v as String?), enabled: _isActionActive),
        const SizedBox(height: 12),
        _buildDropdownRow('Used an Copper-T?', ['(1) Yes', '(0) No'], usedCopperT, (v) => setState(() => usedCopperT = v as String?), enabled: _isActionActive),
        const SizedBox(height: 12),
        _buildDropdownRow('Used injectable contraceptives?', ['(1) Yes', '(0) No'], usedInjectable, (v) => setState(() => usedInjectable = v as String?), enabled: _isActionActive),
        if (usedInjectable == '(1) Yes') ...[
          formSearchableDropdown(context, 'How long using injectable?', ['Choice 1', 'Choice 2', 'Choice 3'], howLongInjectable, (v) => setState(() => howLongInjectable = v as String?), enabled: _isActionActive),
          const SizedBox(height: 12),
          _buildDatePicker('Last use injectable date', lastUseInjectableDate, (v) => setState(() => lastUseInjectableDate = v), enabled: _isActionActive),
          const SizedBox(height: 16),
        ],
        _buildDatePicker('Temporary Date?', temporaryDate, (v) => setState(() => temporaryDate = v), enabled: _isActionActive),
        const SizedBox(height: 12),
        _buildDropdownRow('Used other?', ['(1) Yes', '(0) No'], usedOther, (v) => setState(() => usedOther = v as String?), enabled: _isActionActive),
        if (usedOther == '(1) Yes') formTextField('If yes,', _ifYesController, enabled: _isActionActive),
      ],
    );
  }

  Widget _buildDropdownRow(String label, List<String> choices, String? value, ValueChanged<String?> onChanged, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        formSearchableDropdown(context, '', choices, value, onChanged, enabled: enabled),
      ],
    );
  }

   Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onPicked, {bool enabled = true}) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
