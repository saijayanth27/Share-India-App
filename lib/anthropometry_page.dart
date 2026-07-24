import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'local_database_service.dart';
import 'sync_service.dart';
import 'widget.dart';

class AnthropometryPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const AnthropometryPage({super.key, this.existingData, this.docId});

  @override
  State<AnthropometryPage> createState() => _AnthropometryPageState();
}

class _AnthropometryPageState extends State<AnthropometryPage> {
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
  List<Map<String, dynamic>> _allPersonRecords = [];
  List<String> _availableVisitDates = [];
  String? _selectedVisitDate;

  final _waistMeasurement = TextEditingController();
  final _weight = TextEditingController();
  final _hipMeasurement = TextEditingController();
  final _height = TextEditingController();
  final _otherDetails = TextEditingController();
  final _notDoneOther = TextEditingController();

  String? notDoneReason;
  String? chvName;

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
    _waistMeasurement.dispose();
    _weight.dispose();
    _hipMeasurement.dispose();
    _height.dispose();
    _otherDetails.dispose();
    _notDoneOther.dispose();
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
          .collection('anthropometry')
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
              .collection('anthropometry')
              .where('Family_code', isEqualTo: fCode)
              .where('Name', isEqualTo: name)
              .orderBy('clientUpdatedAt', descending: true)
              .get()
              .timeout(const Duration(seconds: 5));
          if (snapshot.docs.isEmpty) {
            snapshot = await FirebaseFirestore.instance
                .collection('anthropometry')
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
          debugPrint('Anthro: Firestore lookup failed: $e');
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
        debugPrint('Error in Anthro _onNameSelected: $e');
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
    _registrationNumber.text = (d['Registration_Number'] ?? d['REGNO'] ?? d['Regno'] ?? '').toString();
    selectedFamilyCode = d['Family_code'] ?? d['Family_Code'] ?? d['Family_ID'] ?? d['FAM_ID'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _locationVillage  = (d['Village']  ?? d['village'])?.toString();
    _locationMandal   = (d['Mandal']   ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState    = (d['State']    ?? d['state'])?.toString();
    _nameController.text = selectedMemberName ?? '';
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
    interviewersName = matchInterviewerName(d['Interviewer_s_Name'] ?? d['interviewer_name'] ?? d['interviewer'] ?? d['Interviewer_Name'] ?? d['INTNAME'], interviewerList);
    // Measurements: current fields OR old TETRA HT/WT/HIP/WAIST
    _waistMeasurement.text = (d['Waist_Measurement'] ?? d['WAIST'])?.toString() ?? '';
    _weight.text = (d['Weight'] ?? d['WT'])?.toString() ?? '';
    _hipMeasurement.text = (d['Hip_Measurement'] ?? d['HIP'])?.toString() ?? '';
    _height.text = (d['Height'] ?? d['HT'])?.toString() ?? '';
    _otherDetails.text = d['Other_Details'] ?? '';
    // Not done reason: current field OR old TETRA NA_DL (1=Refused, 2=Sick, 3=Others)
    final naCode = d['NA_DL']?.toString().trim();
    notDoneReason = d['Not_Done_Reason'] ?? const {
      '1': '(1) Refused',
      '2': '(2) Sick',
      '3': '(3) Others',
    }[naCode];
    _notDoneOther.text = d['Not_Done_Other'] ?? '';
    chvName = d['CHV_Name'];

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
      _waistMeasurement.clear();
      _weight.clear();
      _hipMeasurement.clear();
      _height.clear();
      _otherDetails.clear();
      notDoneReason = null;
      _notDoneOther.clear();
      chvName = null;
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
        'Waist_Measurement': double.tryParse(_waistMeasurement.text),
        'Weight': double.tryParse(_weight.text),
        'Hip_Measurement': double.tryParse(_hipMeasurement.text),
        'Height': double.tryParse(_height.text),
        'Other_Details': _otherDetails.text,
        'Not_Done_Reason': notDoneReason,
        'Not_Done_Other': _notDoneOther.text,
        'CHV_Name': chvName,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('anthropometry', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Anthropometry updated! Syncing...' : 'Anthropometry saved! Syncing...'),
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
      appBar: AppBar(title: const Text('Anthropometry'), elevation: 0),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('anthropometry_scroll'),
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
                      title: 'Measurements',
                      icon: Icons.straighten_outlined,
                      children: [
                        Row(
                          children: [
                            Expanded(child: formTextField('Weight (kg)', _weight, enabled: _isActionActive, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField('Height (cm)', _height, enabled: _isActionActive, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: formTextField('Waist (cm)', _waistMeasurement, enabled: _isActionActive, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField('Hip (cm)', _hipMeasurement, enabled: _isActionActive, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        formTextField('Other Details', _otherDetails, enabled: _isActionActive, maxLines: 2),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Status',
                      icon: Icons.info_outline,
                      children: [
                        formSearchableDropdown(context, 'Reason if Not Done', ['(1) Refused', '(2) Sick', '(3) Others'], notDoneReason, (v) => setState(() => notDoneReason = v as String?), enabled: _isActionActive),
                        if (notDoneReason == '(3) Others') formTextField('Specify Other Reason', _notDoneOther, enabled: _isActionActive),
                        const SizedBox(height: 16),
                        formTextField('CHV Name', chvName != null ? TextEditingController(text: chvName) : TextEditingController(), enabled: _isActionActive, onChanged: (v) => chvName = v), // Minimal fix for CHV Name
                      ],
                    ),
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
        formTextField(
          'Registration Number',
          _registrationNumber,
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
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
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
            Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: '(1) Male', groupValue: selectedGender, onChanged: !_isActionActive ? null : (v) => setState(() => selectedGender = v as String?), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: '(0) Female', groupValue: selectedGender, onChanged: !_isActionActive ? null : (v) => setState(() => selectedGender = v as String?), contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField(
              'Age',
              _age,
              enabled: _isActionActive,
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Interview Date', dateOfInterview, (v) => setState(() => dateOfInterview = v), enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(context, 
          'Interviewer Name',
          interviewerList,
          interviewersName,
          (v) => setState(() => interviewersName = v as String?),
          enabled: _isActionActive,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
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
            final picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
            if (picked != null) {
              onPicked(picked);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) _scrollController.jumpTo(offset);
              });
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), suffixIcon: const Icon(Icons.calendar_today, size: 18)),
            child: Text(selectedDate == null ? 'dd-MMM-yyyy' : DateFormat('dd-MMM-yyyy').format(selectedDate)),
          ),
        ),
      ],
    );
  }
}
