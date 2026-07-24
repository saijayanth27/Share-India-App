import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'local_database_service.dart';
import 'sync_service.dart';
import 'widget.dart';

class CytologyPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const CytologyPage({super.key, this.existingData, this.docId});

  @override
  State<CytologyPage> createState() => _CytologyPageState();
}

class _CytologyPageState extends State<CytologyPage> {
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

  // --- Main Form Controllers ---
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  final _otherAdequacyReasonController = TextEditingController();
  final _otherNeoplasticController = TextEditingController();
  final _otherNonNeoplasticController = TextEditingController();
  final _commentController = TextEditingController();

  // --- State Variables ---
  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectedGender;
  DateTime? dateReceived;
  DateTime? dateRead;
  String? selectedAdequacy;
  List<String> selectedAdequacyReasons = [];
  List<String> selectedInfections = [];
  String? selectedEpithelialDiagnosis;
  List<String> selectedSquamousCells = [];
  List<String> selectedGlandularCells = [];

  // --- Options ---
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  List<Map<String, dynamic>> _allPersonRecords = [];
  List<String> _availableVisitDates = [];
  String? _selectedVisitDate;
  // Location (auto-populated from Family Code)
  String? _locationVillage;
  String? _locationMandal;
  String? _locationDistrict;
  String? _locationState;


  final List<String> adequacyChoices = [
    "(1) Satisfactory",
    "(2)Satisfactory, but limited by",
    "(3)Unsatisfactory for evaluation"
  ];
  final List<String> adequacyReasonChoices = [
    "1) Transformation zone component absent",
    "(2) Scant squamous epithelial component",
    "(3) Partially/totally obscuring inflammation",
    "(4) Obscuring blood",
    "(5) Air-drying artifact",
    "(6) Other"
  ];
  final List<String> infectionChoices = [
    "9a HSV",
    "9b Trichomonas",
    "09c Candida",
    "09d Coccobacilli shift in vaginal flora",
    "09e Other"
  ];
  final List<String> epithelialDiagnosisChoices = [
    "(1) Negative",
    "(2) Reactive cellular changes"
  ];
  final List<String> squamousCellChoices = [
    "(1) ASCUS, NOS",
    "(2) ASCUS, favor reactive",
    "(3) | ASCUS, rule out LSIL",
    "(4) ASCUS, metaplastic",
    "(5) LSIL, NOS",
    "(6) LSIL, cellular changes of HPV",
    "(7) LSIL, CIN 1"
  ];
  final List<String> glandularCellChoices = [
    "(1) Benign endometrial cells in a peri/postmenopausal woman",
    "(2) AGUS, NOS",
    "(3) Atypical endometrial cells, NOS",
    "(4) Atypical endocervical cells, favor reactive",
    "(5) Atypical endocervical cells, favor neoplasia",
    "(6) Adenocarcinoma in situ (AIS)",
    "(7) Adenocarcinoma, NOS",
    "(8) Endocervical adenocarcinoma",
    "(9) Endometrial adenocarcinoma"
  ];

  @override
  void initState() {
    super.initState();
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
    _nameController.dispose();
    _regNoController.dispose();
    _familyCodeController.dispose();
    _otherAdequacyReasonController.dispose();
    _otherNeoplasticController.dispose();
    _otherNonNeoplasticController.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
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
          .collection('cytology_screening')
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
    final raw = r['Date_received_in_lab'] ?? r['Date_read_reported'];
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
      _regNoController.text = (baseData['uniq_Registration_Number'] ?? baseData['Registration_Number'] ?? baseData['Registration_Number1'] ?? '').toString();
      selectedGender = normalizeGender(baseData['Gender']);
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        List<Map<String, dynamic>> records = [];
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('cytology_screening')
              .where('Family_code', isEqualTo: fCode)
              .where('Name', isEqualTo: name)
              .orderBy('clientUpdatedAt', descending: true)
              .get()
              .timeout(const Duration(seconds: 5));
          for (final doc in snapshot.docs) {
            records.add({...?baseData, ...doc.data(), 'firestoreDocId': doc.id});
          }
        } catch (e) {
          debugPrint('Cytology: Firestore lookup failed: $e');
        }
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
        debugPrint('Error in Cytology _onNameSelected: $e');
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
    _regNoController.text = d['Registration_Number'] ?? '';
    selectedFamilyCode = d['Family_code'] ?? d['Family_Code'] ?? d['Family_Code_Creation'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _locationVillage  = (d['Village']  ?? d['village'])?.toString();
    _locationMandal   = (d['Mandal']   ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState    = (d['State']    ?? d['state'])?.toString();
    _nameController.text = selectedMemberName ?? '';
    selectedGender = normalizeGender(d['Gender']);
    
    final rawDateReceived = d['Date_received_in_lab'];
    if (rawDateReceived != null) {
      if (rawDateReceived is Timestamp) {
        dateReceived = rawDateReceived.toDate();
      } else {
        try {
          dateReceived = DateFormat('dd-MMM-yyyy').parse(rawDateReceived.toString());
        } catch (_) {
          try {
            dateReceived = DateTime.parse(rawDateReceived.toString());
          } catch (_) {}
        }
      }
    }
    
    final rawDateRead = d['Date_read_reported'];
    if (rawDateRead != null) {
      if (rawDateRead is Timestamp) {
        dateRead = rawDateRead.toDate();
      } else {
        try {
          dateRead = DateFormat('dd-MMM-yyyy').parse(rawDateRead.toString());
        } catch (_) {
          try {
            dateRead = DateTime.parse(rawDateRead.toString());
          } catch (_) {}
        }
      }
    }
    
    selectedAdequacy = d['Cytology_adequacy'];
    selectedAdequacyReasons = List<String>.from(d['Adequacy_reasons'] ?? []);
    _otherAdequacyReasonController.text = d['Adequacy_other_reason'] ?? '';
    selectedInfections = List<String>.from(d['Infections_identified'] ?? []);
    selectedEpithelialDiagnosis = d['Epithelial_abnormality_diagnosis'];
    selectedSquamousCells = List<String>.from(d['Squamous_cell_abnormalities'] ?? []);
    _otherNeoplasticController.text = d['Squamous_other_neoplastic'] ?? '';
    selectedGlandularCells = List<String>.from(d['Glandular_cell_abnormalities'] ?? []);
    _otherNonNeoplasticController.text = d['Glandular_other_non_neoplastic'] ?? '';
    _commentController.text = d['Comments'] ?? '';

    if (!_isEditMode && selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _isActionActive = false;
      _regNoController.clear();
      // _familyCodeController.text = 'TSRRMED'; // Preserved
      _nameController.clear();
      // selectedFamilyCode = null; // Preserved
      selectedMemberName = null;
      selectedGender = null;
      _locationVillage = null;
      _locationMandal = null;
      _locationDistrict = null;
      _locationState = null;
      dateReceived = null;
      dateRead = null;
      selectedAdequacy = null;
      selectedAdequacyReasons = [];
      _otherAdequacyReasonController.clear();
      selectedInfections = [];
      selectedEpithelialDiagnosis = null;
      selectedSquamousCells = [];
      _otherNeoplasticController.clear();
      selectedGlandularCells = [];
      _otherNonNeoplasticController.clear();
      _commentController.clear();
      _allPersonRecords = [];
      _availableVisitDates = [];
      _selectedVisitDate = null;
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
        'Family_code': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Village': _locationVillage,
        'Mandal': _locationMandal,
        'District': _locationDistrict,
        'State': _locationState,
        'Date_received_in_lab': dateReceived != null ? Timestamp.fromDate(dateReceived!) : null,
        'Date_read_reported': dateRead != null ? Timestamp.fromDate(dateRead!) : null,
        'Cytology_adequacy': selectedAdequacy,
        'Adequacy_reasons': selectedAdequacyReasons,
        'Adequacy_other_reason': _otherAdequacyReasonController.text,
        'Infections_identified': selectedInfections,
        'Epithelial_abnormality_diagnosis': selectedEpithelialDiagnosis,
        'Squamous_cell_abnormalities': selectedSquamousCells,
        'Squamous_other_neoplastic': _otherNeoplasticController.text,
        'Glandular_cell_abnormalities': selectedGlandularCells,
        'Glandular_other_non_neoplastic': _otherNonNeoplasticController.text,
        'Comments': _commentController.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('cytology_screening', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Cytology updated! Syncing...' : 'Cytology saved! Syncing...'),
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
      appBar: AppBar(title: const Text('Cytology (Pap Smear)'), elevation: 0),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('cytology_scroll'),
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
                    title: 'Cytology Details',
                    icon: Icons.biotech_outlined,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: _buildDatePicker('Date received in lab',
                                  dateReceived, (v) => setState(() => dateReceived = v), enabled: _isActionActive)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildDatePicker('Date read and reported',
                                  dateRead, (v) => setState(() => dateRead = v), enabled: _isActionActive)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      formSearchableDropdown(context, 'Cytology adequacy?',
                          adequacyChoices, selectedAdequacy,
                          (v) => setState(() => selectedAdequacy = v as String?),
                          enabled: _isActionActive),
                      if (selectedAdequacy != adequacyChoices[0]) ...[
                        const SizedBox(height: 12),
                        const Text('Adequacy reasons',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        ...adequacyReasonChoices.map((c) => CheckboxListTile(
                              title:
                                  Text(c, style: const TextStyle(fontSize: 13)),
                               value: selectedAdequacyReasons.contains(c),
                               onChanged: !_isActionActive ? null : (v) => setState(() => v == true
                                   ? selectedAdequacyReasons.add(c)
                                   : selectedAdequacyReasons.remove(c)),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            )),
                        if (selectedAdequacyReasons.contains("(6) Other"))
                          formTextField('Specify Other Reason',
                              _otherAdequacyReasonController, enabled: _isActionActive),
                      ],
                      const SizedBox(height: 16),
                      const Text('Infections identified',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      ...infectionChoices.map((c) => CheckboxListTile(
                            title:
                                Text(c, style: const TextStyle(fontSize: 13)),
                             value: selectedInfections.contains(c),
                             onChanged: !_isActionActive ? null : (v) => setState(() => v == true
                                 ? selectedInfections.add(c)
                                 : selectedInfections.remove(c)),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          )),
                      const SizedBox(height: 16),
                      formSearchableDropdown(
                          context,
                          'Epithelial abnormality diagnosis',
                          epithelialDiagnosisChoices,
                          selectedEpithelialDiagnosis,
                          (v) => setState(() => selectedEpithelialDiagnosis = v as String?),
                          enabled: _isActionActive),
                      const SizedBox(height: 16),
                      const Text('Squamous cell abnormalities',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      ...squamousCellChoices.map((c) => CheckboxListTile(
                            title:
                                Text(c, style: const TextStyle(fontSize: 13)),
                               value: selectedSquamousCells.contains(c),
                               onChanged: !_isActionActive ? null : (v) => setState(() => v == true
                                   ? selectedSquamousCells.add(c)
                                   : selectedSquamousCells.remove(c)),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          )),
                      formTextField(
                          'Other Neoplastic', _otherNeoplasticController, enabled: _isActionActive),
                      const SizedBox(height: 16),
                      const Text('Glandular cell abnormalities',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      ...glandularCellChoices.map((c) => CheckboxListTile(
                            title:
                                Text(c, style: const TextStyle(fontSize: 13)),
                               value: selectedGlandularCells.contains(c),
                               onChanged: !_isActionActive ? null : (v) => setState(() => v == true
                                   ? selectedGlandularCells.add(c)
                                   : selectedGlandularCells.remove(c)),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          )),
                      formTextField('Other Non-Neoplastic Cell Changes',
                          _otherNonNeoplasticController, enabled: _isActionActive),
                      const SizedBox(height: 16),
                      formTextField('Comments', _commentController, enabled: _isActionActive, maxLines: 3),
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
      title: 'Patient Identity',
      icon: Icons.person_outline,
      children: [
        formTextField(
          'Registration Number',
          _regNoController,
          enabled: _isActionActive,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
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
          selectedMemberName,
          (v) => _onNameSelected(v as String?),
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
            key: ValueKey('cyt_visit_${_availableVisitDates.length}'),
          ),
        ],
        const SizedBox(height: 12),
        const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: '(1) Male', groupValue: selectedGender, onChanged: !_isActionActive ? null : (v) => setState(() => selectedGender = v as String?), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: '(0) Female', groupValue: selectedGender, onChanged: !_isActionActive ? null : (v) => setState(() => selectedGender = v as String?), contentPadding: EdgeInsets.zero, dense: true)),
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
