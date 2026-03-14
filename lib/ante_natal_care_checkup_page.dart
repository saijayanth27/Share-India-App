import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
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
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;

  // --- Identity Fields ---
  final _familyCodeController = TextEditingController();
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
      final Set<String> names = {};
      
      void processMember(Map<String, dynamic> data) {
        final name = data['Name']?.toString() ?? '';
        if (name.isEmpty) return;
        memberMap[name] = data;
        names.add(name);
      }

      for (var doc in snapshot.docs) processMember(doc.data());
      for (var local in localMembers) processMember(local);
      
      setState(() {
        _allMembersData = memberMap;
        familyMemberNames = names.toList()..sort();
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
          .collection('ante_natal_checkup')
          .where('Family_ID', isEqualTo: familyCode)
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

  void _onNameSelected(String? name) {
    setState(() {
      selectedName = name;
      _nameController.text = name ?? '';
      if (name != null) {
        if (_isEditMode) {
          final record = _existingRecords.firstWhere((r) => r['Name'] == name, orElse: () => {});
          if (record.isNotEmpty) {
            _editDocId = record['id'];
            _populateForm(record);
          }
        } else if (_allMembersData.containsKey(name)) {
          final data = _allMembersData[name]!;
          selectedGender = data['Gender']?.toString();
        }
      }
    });
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
    _nameController.text = selectedName ?? '';
    selectedGender = d['Gender'];
    _visitNo.text = d['Visit_No']?.toString() ?? '';
    
    if (d['LMP_Date'] != null) {
      if (d['LMP_Date'] is Timestamp) {
        lmpDate = (d['LMP_Date'] as Timestamp).toDate();
      } else {
        try {
          lmpDate = DateFormat('dd-MMM-yyyy').parse(d['LMP_Date'].toString());
        } catch (_) {}
      }
    }
    
    _countOfCheckup.text = d['Count_of_Checkup']?.toString() ?? '';
    
    if (d['Checkup_Date'] != null) {
      if (d['Checkup_Date'] is Timestamp) {
        checkupDt = (d['Checkup_Date'] as Timestamp).toDate();
      } else {
        try {
          checkupDt = DateFormat('dd-MMM-yyyy').parse(d['Checkup_Date'].toString());
        } catch (_) {}
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

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      selectedFamilyCode = null;
      selectedName = null;
      selectedGender = null;
      _familyCodeController.clear();
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

      // 2. Background Sync (Non-blocking)
      _performANCSync(data);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _performANCSync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('ante_natal_checkup').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('ante_natal_checkup').add(data);
      }
    } catch (e) {
      debugPrint('ANC Checkup Background Sync Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('ANC Checkup'), elevation: 0),
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
                      title: 'Checkup Details',
                      icon: Icons.assignment_outlined,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildDatePicker('Checkup Date', checkupDt, (v) => setState(() => checkupDt = v))),
                            const SizedBox(width: 12),
                            Expanded(child: formSearchableDropdown(context, 'Place', ['Subcentre', 'PHC', 'CHC', 'Dist Hosp', 'Others'], checkupPlace, (v) => setState(() => checkupPlace = v))),
                          ],
                        ),
                        const SizedBox(height: 16),
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
                            Expanded(child: formTextField('Systolic', _systolic, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField('Diastolic', _diastolic, keyboardType: TextInputType.number)),
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
                            Expanded(child: formSearchableDropdown(context, 'HBsAg', ['Pos', 'Neg'], hbsag, (v) => setState(() => hbsag = v))),
                            const SizedBox(width: 12),
                            Expanded(child: formSearchableDropdown(context, 'HIV', ['Pos', 'Neg'], hiv, (v) => setState(() => hiv = v))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: formSearchableDropdown(context, 'Hb', ['Normal', 'Anemic'], hb, (v) => setState(() => hb = v))),
                            const SizedBox(width: 12),
                            Expanded(child: formSearchableDropdown(context, 'VDRL', ['Pos', 'Neg'], vdrl, (v) => setState(() => vdrl = v))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: formSearchableDropdown(context, 'USG', ['Normal', 'Abnormal'], ultraS, (v) => setState(() => ultraS = v))),
                            const SizedBox(width: 12),
                            Expanded(child: formSearchableDropdown(context, 'Urine', ['Normal', 'Abnormal'], urine, (v) => setState(() => urine = v))),
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
                        formTextField('General Remarks', _remarks, maxLines: 3),
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
        ),
        const SizedBox(height: 12),
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
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField('Visit No', _visitNo, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('LMP Date', lmpDate, (v) => setState(() => lmpDate = v))),
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
