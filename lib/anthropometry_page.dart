import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
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
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;

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

  final List<String> interviewerList = ['KIRANMAI K', 'REVATHI CH', 'RAMADEVI Y', 'LAVANYA KASPOJU', 'PUSHPA K', 'G RAMADEVI', 'BHASKAR K', 'ASHA', 'KUSUMA G', 'B JYOTHI', 'RAMADEVI G', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU'];

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
          .collection('anthropometry')
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
      _registrationNumber.text = (baseData['uniq_Registration_Number'] ?? baseData['Registration_Number'] ?? baseData['Registration_Number1'] ?? '').toString();
      selectedGender = baseData['Gender']?.toString();
      _age.text = baseData['Age']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        final snapshot = await FirebaseFirestore.instance
            .collection('anthropometry')
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
        debugPrint('Error fetching anthropometry record: $e');
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
    _registrationNumber.text = d['Registration_Number'] ?? '';
    selectedFamilyCode = d['Family_code'] ?? d['Family_Code'] ?? d['Family_ID'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    _age.text = d['Age']?.toString() ?? '';
    
    final rawDate = d['Date_of_Interview'] ?? d['Interview_Date'];
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
    
    interviewersName = d['Interviewer_s_Name'];
    _waistMeasurement.text = d['Waist_Measurement']?.toString() ?? '';
    _weight.text = d['Weight']?.toString() ?? '';
    _hipMeasurement.text = d['Hip_Measurement']?.toString() ?? '';
    _height.text = d['Height']?.toString() ?? '';
    _otherDetails.text = d['Other_Details'] ?? '';
    notDoneReason = d['Not_Done_Reason'];
    _notDoneOther.text = d['Not_Done_Other'] ?? '';
    chvName = d['CHV_Name'];

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _registrationNumber.clear();
      _familyCodeController.clear();
      _nameController.clear();
      selectedFamilyCode = null;
      selectedMemberName = null;
      selectedGender = null;
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

      // 2. Background Sync (Non-blocking)
      _performAnthropometrySync(data);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _performAnthropometrySync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('anthropometry').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('anthropometry').add(data);
      }
    } catch (e) {
      debugPrint('Anthropometry Background Sync Error: $e');
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
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  formActionButtons(
                      context: context,
                      isEditMode: _isEditMode,
                      onNew: () { setState(() { _isEditMode = false; _resetForm(); }); },
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
                      title: 'Measurements',
                      icon: Icons.straighten_outlined,
                      children: [
                        Row(
                          children: [
                            Expanded(child: formTextField('Weight (kg)', _weight, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField('Height (cm)', _height, keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: formTextField('Waist (cm)', _waistMeasurement, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField('Hip (cm)', _hipMeasurement, keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        formTextField('Other Details', _otherDetails, maxLines: 2),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Status',
                      icon: Icons.info_outline,
                      children: [
                        formSearchableDropdown(context, 'Reason if Not Done', ['(1) Refused', '(2) Sick', '(3) Others'], notDoneReason, (v) => setState(() => notDoneReason = v)),
                        if (notDoneReason == '(3) Others') formTextField('Specify Other Reason', _notDoneOther),
                        const SizedBox(height: 16),
                        formTextField('CHV Name', chvName != null ? TextEditingController(text: chvName) : TextEditingController(), onChanged: (v) => chvName = v), // Minimal fix for CHV Name
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField(
              'Age',
              _age,
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Interview Date', dateOfInterview, (v) => setState(() => dateOfInterview = v))),
          ],
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(context, 
          'Interviewer Name',
          interviewerList,
          interviewersName,
          (v) => setState(() => interviewersName = v),
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
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
            final picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
            if (picked != null) onPicked(picked);
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
