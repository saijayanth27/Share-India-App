import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'local_database_service.dart';
import 'sync_service.dart';
import 'widget.dart';

class ColposcopyPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const ColposcopyPage({super.key, this.existingData, this.docId});

  @override
  State<ColposcopyPage> createState() => _ColposcopyPageState();
}

class _ColposcopyPageState extends State<ColposcopyPage> {
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

  // --- Controllers & State ---
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  final _otherRecommendedController = TextEditingController();
  final _otherPerformedController = TextEditingController();
  final _commentsController = TextEditingController();
  final _detailsController = TextEditingController();

  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectedGender;
  DateTime? interviewDate = DateTime.now();
  String? selectedVisitNumber;
  String? selectedAdequacy;
  String? selectedSCJ;
  String? selectedImpression;
  String? selectedBiopsiesCount;
  String? selectedImagesCount;

  List<String> procedureRecommended = [];
  List<String> procedurePerformed = [];

  // Dropdowns
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  // Location (auto-populated from Family Code)
  String? _locationVillage;
  String? _locationMandal;
  String? _locationDistrict;
  String? _locationState;

  final List<String> visitChoices = ["Choice 1", "Choice 2", "Choice 3"];
  final List<String> scjChoices = [
    "1) SCJ completely visible",
    "(2) SCJ partially within endocervical canal",
    "O(3) SCJ completely within the canal"
  ];
  final List<String> impressionChoices = [
    "(1)Normal",
    "(2)Leukoplakia",
    "(3)Low grade (Swede's score <5)",
    "(4) High grade (Swede's score 5 or >5)",
    "(5) upper limit AW not visible",
    "(6)Cancer"
  ];
  final List<String> procedureChoices = [
    "1) Cervical Biopsy",
    "2) LEEP or Cone",
    "(3) ECC",
    "(4) Others",
    "(5) None"
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _isEditMode = true;
      _editDocId = widget.docId;
      _loadExistingData();
      final familyCode = (widget.existingData!['Family_Code'] ??
              widget.existingData!['Family_code'] ??
              '')
          .toString();
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
    _otherRecommendedController.dispose();
    _otherPerformedController.dispose();
    _commentsController.dispose();
    _detailsController.dispose();
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
      final localMembers =
          await DataCacheService().fetchMembersLocally(familyCode);
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
          .collection('colposcopy_screening')
          .where('Family_code', isEqualTo: familyCode)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 8));
      setState(() {
        _existingRecords =
            snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
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
      _regNoController.text = (baseData['uniq_Registration_Number'] ??
              baseData['Registration_Number'] ??
              baseData['Registration_Number1'] ??
              '')
          .toString();
      selectedGender = normalizeGender(baseData['Gender']);
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        final snapshot = await FirebaseFirestore.instance
            .collection('colposcopy_screening')
            .where('Family_code', isEqualTo: fCode)
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
        debugPrint('Error fetching colposcopy record: $e');
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
    selectedFamilyCode = d['Family_code'] ?? d['Family_Code'] ?? d['Family_ID'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _locationVillage = (d['Village'] ?? d['village'])?.toString();
    _locationMandal = (d['Mandal'] ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState = (d['State'] ?? d['state'])?.toString();
    _nameController.text = selectedMemberName ?? '';
    selectedGender = normalizeGender(d['Gender']);

    final rawDate = d['Interview_Date'] ?? d['Date_of_Interview'];
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

    selectedVisitNumber = d['Visit_Number'];
    selectedAdequacy = d['Colposcopy_adequacy'];
    selectedSCJ = d['SCJ_level'];
    selectedImpression = d['Colposcopic_impression'];
    procedureRecommended = List<String>.from(d['Procedure_recommended'] ?? []);
    _otherRecommendedController.text = d['Other_recommended'] ?? '';
    procedurePerformed = List<String>.from(d['Procedure_performed'] ?? []);
    _otherPerformedController.text = d['Other_performed'] ?? '';
    selectedBiopsiesCount = d['Biopsies_count']?.toString();
    selectedImagesCount = d['Images_count']?.toString();
    _commentsController.text = d['Comments'] ?? '';
    _detailsController.text = d['Procedure_details'] ?? '';

    if (!_isEditMode &&
        selectedFamilyCode != null &&
        familyMemberNames.isEmpty) {
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
      interviewDate = DateTime.now();
      selectedVisitNumber = null;
      selectedAdequacy = null;
      selectedSCJ = null;
      selectedImpression = null;
      procedureRecommended = [];
      _otherRecommendedController.clear();
      procedurePerformed = [];
      _otherPerformedController.clear();
      selectedBiopsiesCount = null;
      selectedImagesCount = null;
      _commentsController.clear();
      _detailsController.clear();
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
        'Interview_Date':
            interviewDate != null ? Timestamp.fromDate(interviewDate!) : null,
        'Visit_Number': selectedVisitNumber,
        'Colposcopy_adequacy': selectedAdequacy,
        'SCJ_level': selectedSCJ,
        'Colposcopic_impression': selectedImpression,
        'Procedure_recommended': procedureRecommended,
        'Other_recommended': _otherRecommendedController.text,
        'Procedure_performed': procedurePerformed,
        'Other_performed': _otherPerformedController.text,
        'Biopsies_count': selectedBiopsiesCount,
        'Images_count': selectedImagesCount,
        'Comments': _commentsController.text,
        'Procedure_details': _detailsController.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] =
          (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService()
          .saveOfflineSubmission('colposcopy_screening', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing
              ? 'Colposcopy updated! Syncing...'
              : 'Colposcopy saved! Syncing...'),
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted)
        setState(() {
          _isSaving = false;
          _isActionActive = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Colposcopy Screening'), elevation: 0),
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
                      title: 'Assessment',
                      icon: Icons.assignment_outlined,
                      children: [
                        _buildDatePicker('Interview Date', interviewDate,
                            (v) => setState(() => interviewDate = v),
                            enabled: _isActionActive),
                        const SizedBox(height: 16),
                        formSearchableDropdown(
                            context,
                            'Visit Number',
                            visitChoices,
                            selectedVisitNumber,
                            (v) => setState(
                                () => selectedVisitNumber = v as String?),
                            enabled: _isActionActive),
                        const SizedBox(height: 16),
                        _buildRadioGroup(
                            '5 Colposcopy adequacy?',
                            ['Satisfactory', 'Unsatisfactory'],
                            selectedAdequacy,
                            (v) => setState(
                                () => selectedAdequacy = v as String?)),
                        const SizedBox(height: 16),
                        _buildVerticalRadioGroup(
                            '6 Level of new squamo-columnar junction (SCJ)',
                            scjChoices,
                            selectedSCJ,
                            (v) => setState(() => selectedSCJ = v as String?)),
                        const SizedBox(height: 16),
                        _buildVerticalRadioGroup(
                            '7 Colposcopic impression?',
                            impressionChoices,
                            selectedImpression,
                            (v) => setState(
                                () => selectedImpression = v as String?)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Procedure Recommended',
                      icon: Icons.recommend_outlined,
                      children: [
                        const Text('8. Procedure recommended',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        ...procedureChoices.map((c) => CheckboxListTile(
                              title: Text(c),
                              value: procedureRecommended.contains(c),
                              onChanged: !_isActionActive
                                  ? null
                                  : (v) => setState(() => v == true
                                      ? procedureRecommended.add(c)
                                      : procedureRecommended.remove(c)),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            )),
                        if (procedureRecommended.contains("(4) Others"))
                          formTextField('If Others Please Mention',
                              _otherRecommendedController,
                              enabled: _isActionActive),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Procedure Performed',
                      icon: Icons.task_alt_outlined,
                      children: [
                        const Text('9. Procedure performed',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        ...procedureChoices.map((c) => CheckboxListTile(
                              title: Text(c),
                              value: procedurePerformed.contains(c),
                              onChanged: !_isActionActive
                                  ? null
                                  : (v) => setState(() => v == true
                                      ? procedurePerformed.add(c)
                                      : procedurePerformed.remove(c)),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            )),
                        if (procedurePerformed.contains("(4) Others"))
                          formTextField('If Others Please Mention',
                              _otherPerformedController,
                              enabled: _isActionActive),
                        const SizedBox(height: 24),
                        _buildRadioGroup(
                            '10 Number of cervical biopsies taken',
                            ['1', '2', '3', '4'],
                            selectedBiopsiesCount,
                            (v) => setState(
                                () => selectedBiopsiesCount = v as String?)),
                        const SizedBox(height: 16),
                        _buildRadioGroup(
                            '12. How many colposcopy images were taken?',
                            ['0', '1', '2'],
                            selectedImagesCount,
                            (v) => setState(
                                () => selectedImagesCount = v as String?)),
                        const SizedBox(height: 16),
                        formTextField('12a. Comments', _commentsController,
                            enabled: _isActionActive, maxLines: 3),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Findings',
                      icon: Icons.description_outlined,
                      children: [
                        formTextField(
                            '13. Procedure details, findings and comments:',
                            _detailsController,
                            enabled: _isActionActive,
                            maxLines: 5),
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
      var detail = await LocalDatabaseService()
          .getSingleFamilyDetail(familyCode.trim().toUpperCase());
      detail ??=
          await LocalDatabaseService().getSingleFamilyDetail(familyCode.trim());

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
          _locationVillage =
              (detail!['village'] ?? detail['Village'])?.toString();
          _locationMandal = (detail['mandal'] ?? detail['Mandal'])?.toString();
          _locationDistrict =
              (detail['district'] ?? detail['District'])?.toString();
          _locationState = (detail['state'] ?? detail['State'])?.toString();
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
          SizedBox(
              width: 60,
              child: Text('$label:',
                  style: const TextStyle(fontSize: 12, color: Colors.black54))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500))),
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
        if (_locationVillage != null ||
            _locationMandal != null ||
            _locationDistrict != null)
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
                      Icon(Icons.location_on_outlined,
                          size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text('Location',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                              fontSize: 12)),
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
          (<String>{
            ...familyMemberNames,
            ..._existingRecords.map((r) => r['Name']?.toString() ?? '')
          }.where((n) => n.isNotEmpty).toList()
            ..sort()),
          selectedMemberName,
          _onNameSelected,
          isLoading: _isLoadingMembers,
          enabled: _isActionActive,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(
                child: RadioListTile<String>(
                    title: const Text('(1) Male'),
                    value: '(1) Male',
                    groupValue: selectedGender,
                    onChanged: !_isActionActive
                        ? null
                        : (v) => setState(() => selectedGender = v as String?),
                    contentPadding: EdgeInsets.zero,
                    dense: true)),
            Expanded(
                child: RadioListTile<String>(
                    title: const Text('(0) Female'),
                    value: '(0) Female',
                    groupValue: selectedGender,
                    onChanged: !_isActionActive
                        ? null
                        : (v) => setState(() => selectedGender = v as String?),
                    contentPadding: EdgeInsets.zero,
                    dense: true)),
          ],
        ),
      ],
    );
  }

  Widget _buildRadioGroup(String title, List<String> options,
      String? currentValue, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: options
              .map((opt) => Expanded(
                    child: RadioListTile<String>(
                      title: Text(opt, style: const TextStyle(fontSize: 13)),
                      value: opt,
                      groupValue: currentValue,
                      onChanged:
                          !_isActionActive ? null : (val) => onChanged(val),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildVerticalRadioGroup(String title, List<String> options,
      String? currentValue, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ...options.map((opt) => RadioListTile<String>(
              title: Text(opt, style: const TextStyle(fontSize: 13)),
              value: opt,
              groupValue: currentValue,
              onChanged: !_isActionActive ? null : (val) => onChanged(val),
              contentPadding: EdgeInsets.zero,
              dense: true,
            )),
      ],
    );
  }

  Widget _buildDatePicker(
      String label, DateTime? selectedDate, Function(DateTime) onPicked,
      {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        InkWell(
          onTap: !enabled
              ? null
              : () async {
                  final offset = _scrollController.hasClients
                      ? _scrollController.offset
                      : 0.0;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    onPicked(picked);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients)
                        _scrollController.jumpTo(offset);
                    });
                  }
                },
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(selectedDate == null
                ? 'dd-MMM-yyyy'
                : DateFormat('dd-MMM-yyyy').format(selectedDate)),
          ),
        ),
      ],
    );
  }
}
