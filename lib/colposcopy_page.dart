import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
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
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;

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
          .collection('colposcopy_screening')
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
            .collection('colposcopy_screening')
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
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    
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
        'Interview_Date': interviewDate != null ? Timestamp.fromDate(interviewDate!) : null,
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
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('colposcopy_screening', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Colposcopy updated! Syncing...' : 'Colposcopy saved! Syncing...'),
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
      _performColposcopySync(data);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _performColposcopySync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('colposcopy_screening').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('colposcopy_screening').add(data);
      }
    } catch (e) {
      debugPrint('Colposcopy Background Sync Error: $e');
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
                      title: 'Assessment',
                      icon: Icons.assignment_outlined,
                      children: [
                        _buildDatePicker('Interview Date', interviewDate, (v) => setState(() => interviewDate = v)),
                        const SizedBox(height: 16),
                        formSearchableDropdown(context, 'Visit Number', visitChoices, selectedVisitNumber, (v) => setState(() => selectedVisitNumber = v)),
                        const SizedBox(height: 16),
                        _buildRadioGroup('5 Colposcopy adequacy?', ['Satisfactory', 'Unsatisfactory'], selectedAdequacy, (v) => setState(() => selectedAdequacy = v)),
                        const SizedBox(height: 16),
                        _buildVerticalRadioGroup('6 Level of new squamo-columnar junction (SCJ)', scjChoices, selectedSCJ, (v) => setState(() => selectedSCJ = v)),
                        const SizedBox(height: 16),
                        _buildVerticalRadioGroup('7 Colposcopic impression?', impressionChoices, selectedImpression, (v) => setState(() => selectedImpression = v)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Procedure Recommended',
                      icon: Icons.recommend_outlined,
                      children: [
                        const Text('8. Procedure recommended', style: TextStyle(fontWeight: FontWeight.w600)),
                        ...procedureChoices.map((c) => CheckboxListTile(
                              title: Text(c),
                              value: procedureRecommended.contains(c),
                              onChanged: (v) => setState(() => v == true ? procedureRecommended.add(c) : procedureRecommended.remove(c)),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            )),
                        if (procedureRecommended.contains("(4) Others")) formTextField('If Others Please Mention', _otherRecommendedController),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Procedure Performed',
                      icon: Icons.task_alt_outlined,
                      children: [
                        const Text('9. Procedure performed', style: TextStyle(fontWeight: FontWeight.w600)),
                        ...procedureChoices.map((c) => CheckboxListTile(
                              title: Text(c),
                              value: procedurePerformed.contains(c),
                              onChanged: (v) => setState(() => v == true ? procedurePerformed.add(c) : procedurePerformed.remove(c)),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            )),
                        if (procedurePerformed.contains("(4) Others")) formTextField('If Others Please Mention', _otherPerformedController),
                        const SizedBox(height: 24),
                        _buildRadioGroup('10 Number of cervical biopsies taken', ['1', '2', '3', '4'], selectedBiopsiesCount, (v) => setState(() => selectedBiopsiesCount = v)),
                        const SizedBox(height: 16),
                        _buildRadioGroup('12. How many colposcopy images were taken?', ['0', '1', '2'], selectedImagesCount, (v) => setState(() => selectedImagesCount = v)),
                        const SizedBox(height: 16),
                        formTextField('12a. Comments', _commentsController, maxLines: 3),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Findings',
                      icon: Icons.description_outlined,
                      children: [
                        formTextField('13. Procedure details, findings and comments:', _detailsController, maxLines: 5),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
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

  Widget _buildRadioGroup(String title, List<String> options, String? currentValue, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: options.map((opt) => Expanded(
            child: RadioListTile<String>(
              title: Text(opt, style: const TextStyle(fontSize: 13)),
              value: opt,
              groupValue: currentValue,
              onChanged: (val) => val != null ? onChanged(val) : null,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildVerticalRadioGroup(String title, List<String> options, String? currentValue, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ...options.map((opt) => RadioListTile<String>(
          title: Text(opt, style: const TextStyle(fontSize: 13)),
          value: opt,
          groupValue: currentValue,
          onChanged: (val) => val != null ? onChanged(val) : null,
          contentPadding: EdgeInsets.zero,
          dense: true,
        )),
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
