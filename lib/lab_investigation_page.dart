import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'local_database_service.dart';
import 'sync_service.dart';
import 'widget.dart';

class LabInvestigationPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const LabInvestigationPage({super.key, this.existingData, this.docId});

  @override
  State<LabInvestigationPage> createState() => _LabInvestigationPageState();
}

class _LabInvestigationPageState extends State<LabInvestigationPage> {
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

  // --- Controllers ---
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  final _fastingSugarController = TextEditingController();
  final _hba1cController = TextEditingController();
  final _glycosylatedHbController = TextEditingController();
  final _meanGlucoseController = TextEditingController();
  final _creatinineController = TextEditingController();
  final _urineAlbuminController = TextEditingController();
  final _albuminRatioController = TextEditingController();
  final _proteinUrineSpotController = TextEditingController();
  final _creatinineUrineSpotController = TextEditingController();
  final _proteinCreatinineRatioController = TextEditingController();
  
  // Identification State
  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectedGender;
  List<Map<String, dynamic>> _allPersonRecords = [];
  List<String> _availableVisitDates = [];
  String? _selectedVisitDate;
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};

  // Location (auto-populated from Family Code)
  String? _locationVillage;
  String? _locationMandal;
  String? _locationDistrict;
  String? _locationState;

  DateTime? investigationDate = DateTime.now();

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
    _fastingSugarController.dispose();
    _hba1cController.dispose();
    _glycosylatedHbController.dispose();
    _meanGlucoseController.dispose();
    _creatinineController.dispose();
    _urineAlbuminController.dispose();
    _albuminRatioController.dispose();
    _proteinUrineSpotController.dispose();
    _creatinineUrineSpotController.dispose();
    _proteinCreatinineRatioController.dispose();
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

      // Fetch location from Family Code Creation record
      _fetchFamilyLocation(familyCode);
    } catch (e) {
      debugPrint('Error fetching members: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _fetchFamilyLocation(String familyCode) async {
    try {
      // 1. Check local SQLite first (instant)
      var detail = await LocalDatabaseService().getSingleFamilyDetail(familyCode.trim().toUpperCase());
      detail ??= await LocalDatabaseService().getSingleFamilyDetail(familyCode.trim());

      if (detail == null) {
        // 2. Fall back to Firestore with timeout
        final snap = await FirebaseFirestore.instance
            .collection('Family Code Creation')
            .doc(familyCode.trim().toUpperCase())
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 6));
        if (snap.exists) detail = snap.data();
      }

      if (detail != null && mounted) {
        setState(() {
          _locationVillage = (detail!['village'] ?? detail['Village'])?.toString();
          _locationMandal  = (detail['mandal']  ?? detail['Mandal'])?.toString();
          _locationDistrict = (detail['district'] ?? detail['District'])?.toString();
          _locationState   = (detail['state']   ?? detail['State'])?.toString();
        });
      }
    } catch (e) {
      debugPrint('_fetchFamilyLocation: $e');
    }
  }

  Future<void> _fetchExistingRecords(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('lab_investigation')
          .where('Family_ID', isEqualTo: familyCode)
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
    final raw = r['Date_of_Investigation'] ?? r['Interview_Date'];
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
              .collection('lab_investigation')
              .where('Family_ID', isEqualTo: fCode)
              .where('Name', isEqualTo: name)
              .orderBy('clientUpdatedAt', descending: true)
              .get()
              .timeout(const Duration(seconds: 5));
          for (final doc in snapshot.docs) {
            records.add({...?baseData, ...doc.data(), 'firestoreDocId': doc.id});
          }
        } catch (e) {
          debugPrint('Lab: Firestore lookup failed: $e');
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
        debugPrint('Error in Lab _onNameSelected: $e');
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
    _regNoController.text = (d['Registration_Number'] ?? d['REGNO'] ?? d['Regno'] ?? '').toString();
    selectedFamilyCode = d['Family_ID'] ?? d['Family_Code'] ?? d['Family_Code_Creation'] ?? d['FAM_ID'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    selectedGender = normalizeGender(d['Gender']);
    _locationVillage  = (d['Village']  ?? d['village'])?.toString();
    _locationMandal   = (d['Mandal']   ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState    = (d['State']    ?? d['state'])?.toString();
    // Investigation date: current field OR old TETRA TESTDT
    final rawDate = d['Date_of_Investigation'] ?? d['Interview_Date'] ?? d['TESTDT'];
    if (rawDate != null) {
      if (rawDate is Timestamp) {
        investigationDate = rawDate.toDate();
      } else {
        try {
          investigationDate = DateFormat('dd-MMM-yyyy').parse(rawDate.toString());
        } catch (_) {
          try {
            investigationDate = DateTime.parse(rawDate.toString());
          } catch (_) {}
        }
      }
    }
    // Lab values: current app fields OR old TETRA field names
    _fastingSugarController.text = (d['Fasting_Sugar'] ?? d['FBS'])?.toString() ?? '';
    _hba1cController.text = (d['HbA1c'] ?? d['HBA1c'] ?? d['HBA1C'])?.toString() ?? '';
    _glycosylatedHbController.text = (d['Glycosylated_Hb'] ?? d['GH'])?.toString() ?? '';
    _meanGlucoseController.text = (d['Mean_Glucose'] ?? d['FBS_M'])?.toString() ?? '';
    _creatinineController.text = (d['Creatinine'] ?? d['CREATININE'])?.toString() ?? '';
    _urineAlbuminController.text = (d['Urine_Albumin'] ?? d['URINE_ALBUMIN'])?.toString() ?? '';
    _albuminRatioController.text = (d['Albumin_Ratio'] ?? d['ALBUM_RATIO'])?.toString() ?? '';
    _proteinUrineSpotController.text = (d['Protein_Urine_Spot'] ?? d['protein_urine_spot'] ?? d['PROT_URINE'])?.toString() ?? '';
    _creatinineUrineSpotController.text = (d['Creatinine_Urine_Spot'] ?? d['creat_urine_spot'] ?? d['CREAT_URINE'])?.toString() ?? '';
    _proteinCreatinineRatioController.text = (d['Protein_Creatinine_Ratio'] ?? d['prot_creat_ratio'] ?? d['PROT_CREAT'])?.toString() ?? '';

    if (!_isEditMode && selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _isActionActive = false;
      _regNoController.clear();
      _nameController.clear();
      // _familyCodeController.text = 'TSRRMED'; // Preserved
      // selectedFamilyCode = null; // Preserved
      selectedMemberName = null;
      selectedGender = null;
      _locationVillage = null;
      _locationMandal = null;
      _locationDistrict = null;
      _locationState = null;
      investigationDate = DateTime.now();
      _fastingSugarController.clear();
      _hba1cController.clear();
      _glycosylatedHbController.clear();
      _meanGlucoseController.clear();
      _creatinineController.clear();
      _urineAlbuminController.clear();
      _albuminRatioController.clear();
      _proteinUrineSpotController.clear();
      _creatinineUrineSpotController.clear();
      _proteinCreatinineRatioController.clear();
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
        'Family_ID': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Village': _locationVillage,
        'Mandal': _locationMandal,
        'District': _locationDistrict,
        'State': _locationState,
        'Date_of_Investigation': investigationDate != null ? Timestamp.fromDate(investigationDate!) : null,
        'Fasting_Sugar': double.tryParse(_fastingSugarController.text),
        'HbA1c': double.tryParse(_hba1cController.text),
        'Glycosylated_Hb': double.tryParse(_glycosylatedHbController.text),
        'Mean_Glucose': double.tryParse(_meanGlucoseController.text),
        'Creatinine': double.tryParse(_creatinineController.text),
        'Urine_Albumin': double.tryParse(_urineAlbuminController.text),
        'Albumin_Ratio': double.tryParse(_albuminRatioController.text),
        'Protein_Urine_Spot': double.tryParse(_proteinUrineSpotController.text),
        'Creatinine_Urine_Spot': double.tryParse(_creatinineUrineSpotController.text),
        'Protein_Creatinine_Ratio': double.tryParse(_proteinCreatinineRatioController.text),
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('lab_investigation', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Lab Investigation updated! Syncing...' : 'Lab Investigation saved! Syncing...'),
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
      appBar: AppBar(title: const Text('Lab Investigation'), elevation: 0),
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
                      title: 'Investigation Details',
                      icon: Icons.biotech_outlined,
                      children: [
                        _buildDatePicker('Investigation Date',
                            investigationDate, (v) => setState(() => investigationDate = v), enabled: _isActionActive),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: formTextField('Fasting Sugar (mg/dL)',
                                    _fastingSugarController,
                                    enabled: _isActionActive,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: formTextField('HbA1c (%)',
                                    _hba1cController,
                                    enabled: _isActionActive,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: formTextField('Glycosylated Hb',
                                    _glycosylatedHbController,
                                    enabled: _isActionActive,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: formTextField('Mean Glucose',
                                    _meanGlucoseController,
                                    enabled: _isActionActive,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: formTextField('Creatinine',
                                    _creatinineController,
                                    enabled: _isActionActive,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: formTextField('Urine Albumin',
                                    _urineAlbuminController,
                                    enabled: _isActionActive,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        formTextField('Albumin/Creatinine Ratio',
                            _albuminRatioController,
                            enabled: _isActionActive,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: formTextField('Protein (Urine Spot)',
                                    _proteinUrineSpotController,
                                    enabled: _isActionActive,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: formTextField('Creatinine (Urine Spot)',
                                    _creatinineUrineSpotController,
                                    enabled: _isActionActive,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        formTextField('Protein/Creatinine Ratio',
                            _proteinCreatinineRatioController,
                            enabled: _isActionActive,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
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
            key: ValueKey('lab_visit_${_availableVisitDates.length}'),
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
