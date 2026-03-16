import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
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
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;

  // --- Main Form Controllers ---
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _familyCodeController = TextEditingController();
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
      _loadExistingData();
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
          .get();
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
      _regNoController.text = (baseData['uniq_Registration_Number'] ?? baseData['Registration_Number'] ?? baseData['Registration_Number1'] ?? '').toString();
      selectedGender = baseData['Gender']?.toString();
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        final snapshot = await FirebaseFirestore.instance
            .collection('cytology_screening')
            .where('Family_code', isEqualTo: fCode)
            .where('Name', isEqualTo: name)
            .limit(1)
            .get();

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
        debugPrint('Error fetching cytology record: $e');
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
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    
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

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _regNoController.clear();
      _familyCodeController.clear();
      _nameController.clear();
      selectedFamilyCode = null;
      selectedMemberName = null;
      selectedGender = null;
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
      await DataCacheService().saveOfflineSubmission('cytology', data);

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

      // 2. Background Sync (Non-blocking)
      _performCytologySync(data);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _performCytologySync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('cytology_screening').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('cytology_screening').add(data);
      }
    } catch (e) {
      debugPrint('Cytology Background Sync Error: $e');
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
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  formActionButtons(
                      context: context,
                      isEditMode: _isEditMode,
                      onNew: () {
                        setState(() {
                          _isEditMode = false;
                          _resetForm();
                        });
                      },
                      onSave: _save,
                      onEdit: () {
                        setState(() {
                          _isEditMode = true;
                          final code = _familyCodeController.text.trim();
                          if (code.isNotEmpty) {
                            _fetchMembersByFamily(code);
                            _fetchExistingRecords(code);
                          }
                        });
                      },
                      onCancel: _resetForm,
                      onExit: () => Navigator.pop(context),
                      isSaving: _isSaving,
                    ),
                    const SizedBox(height: 16),
                    _buildIdentitySection(),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Cytology Details',
                      icon: Icons.biotech_outlined,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildDatePicker('Date received in lab', dateReceived, (v) => setState(() => dateReceived = v))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildDatePicker('Date read and reported', dateRead, (v) => setState(() => dateRead = v))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        formSearchableDropdown(context, 'Cytology adequacy?', adequacyChoices, selectedAdequacy, (v) => setState(() => selectedAdequacy = v)),
                        if (selectedAdequacy != adequacyChoices[0]) ...[
                          const SizedBox(height: 12),
                          const Text('Adequacy reasons', style: TextStyle(fontWeight: FontWeight.w500)),
                          ...adequacyReasonChoices.map((c) => CheckboxListTile(
                                title: Text(c, style: const TextStyle(fontSize: 13)),
                                value: selectedAdequacyReasons.contains(c),
                                onChanged: (v) => setState(() => v == true ? selectedAdequacyReasons.add(c) : selectedAdequacyReasons.remove(c)),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              )),
                          if (selectedAdequacyReasons.contains("(6) Other")) formTextField('Specify Other Reason', _otherAdequacyReasonController),
                        ],
                        const SizedBox(height: 16),
                        const Text('Infections identified', style: TextStyle(fontWeight: FontWeight.w500)),
                        ...infectionChoices.map((c) => CheckboxListTile(
                              title: Text(c, style: const TextStyle(fontSize: 13)),
                              value: selectedInfections.contains(c),
                              onChanged: (v) => setState(() => v == true ? selectedInfections.add(c) : selectedInfections.remove(c)),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            )),
                        const SizedBox(height: 16),
                        formSearchableDropdown(context, 'Epithelial abnormality diagnosis', epithelialDiagnosisChoices, selectedEpithelialDiagnosis, (v) => setState(() => selectedEpithelialDiagnosis = v)),
                        const SizedBox(height: 16),
                        const Text('Squamous cell abnormalities', style: TextStyle(fontWeight: FontWeight.w500)),
                        ...squamousCellChoices.map((c) => CheckboxListTile(
                              title: Text(c, style: const TextStyle(fontSize: 13)),
                              value: selectedSquamousCells.contains(c),
                              onChanged: (v) => setState(() => v == true ? selectedSquamousCells.add(c) : selectedSquamousCells.remove(c)),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            )),
                        formTextField('Other Neoplastic', _otherNeoplasticController),
                        const SizedBox(height: 16),
                        const Text('Glandular cell abnormalities', style: TextStyle(fontWeight: FontWeight.w500)),
                        ...glandularCellChoices.map((c) => CheckboxListTile(
                              title: Text(c, style: const TextStyle(fontSize: 13)),
                              value: selectedGlandularCells.contains(c),
                              onChanged: (v) => setState(() => v == true ? selectedGlandularCells.add(c) : selectedGlandularCells.remove(c)),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            )),
                        formTextField('Other Non-Neoplastic Cell Changes', _otherNonNeoplasticController),
                        const SizedBox(height: 16),
                        formTextField('Comments', _commentController, maxLines: 3),
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
        ),
        const SizedBox(height: 12),
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
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: 'Male', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: 'Female', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
          ],
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
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) onPicked(picked);
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
