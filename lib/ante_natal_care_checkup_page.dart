import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';
import 'language_provider.dart';

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
          content: Text(wasEditing ? tr('ANC Checkup updated! Syncing...') : tr('ANC Checkup saved! Syncing...')),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Error saving')}: $e'), backgroundColor: Colors.red));
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
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageProvider.instance.isTeluguNotifier,
      builder: (context, isTelugu, _) {
      return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: Text(tr('ANC Checkup')), elevation: 0, actions: const [LanguageToggleButton()]),
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
                      title: tr('Checkup Details'),
                      icon: Icons.assignment_outlined,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildDatePicker(tr('Checkup Date'), checkupDt, (v) => setState(() => checkupDt = v))),
                            const SizedBox(width: 12),
                            Expanded(child: formSearchableDropdown(context, tr('Place'), ['Subcentre', 'PHC', 'CHC', 'Dist Hosp', 'Others'], checkupPlace, (v) => setState(() => checkupPlace = v))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: formTextField(tr('Weight (kg)'), _weight, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField(tr('Height (cm)'), _height, keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: formTextField(tr('Systolic'), _systolic, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField(tr('Diastolic'), _diastolic, keyboardType: TextInputType.number)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: tr('Tests & Screenings'),
                      icon: Icons.biotech_outlined,
                      children: [
                        Row(
                          children: [
                            Expanded(child: formSearchableDropdown(context, tr('HBsAg'), ['Pos', 'Neg'], hbsag, (v) => setState(() => hbsag = v))),
                            const SizedBox(width: 12),
                            Expanded(child: formSearchableDropdown(context, tr('HIV'), ['Pos', 'Neg'], hiv, (v) => setState(() => hiv = v))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: formSearchableDropdown(context, tr('Hb'), ['Normal', 'Anemic'], hb, (v) => setState(() => hb = v))),
                            const SizedBox(width: 12),
                            Expanded(child: formSearchableDropdown(context, tr('VDRL'), ['Pos', 'Neg'], vdrl, (v) => setState(() => vdrl = v))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: formSearchableDropdown(context, tr('USG'), ['Normal', 'Abnormal'], ultraS, (v) => setState(() => ultraS = v))),
                            const SizedBox(width: 12),
                            Expanded(child: formSearchableDropdown(context, tr('Urine'), ['Normal', 'Abnormal'], urine, (v) => setState(() => urine = v))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: tr('Remarks'),
                      icon: Icons.description_outlined,
                      children: [
                        formTextField(tr('General Remarks'), _remarks, maxLines: 3),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
    });
  }

  Widget _buildIdentitySection() {
    return buildSectionCard(
      context: context,
      title: tr('Member Identity'),
      icon: Icons.person_outline,
      children: [
        formSearchField(
          tr('Family Code'),
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
          tr('Name'),
          (<String>{...familyMemberNames, ..._existingRecords.map((r) => r['Name']?.toString() ?? '')}
              .where((n) => n.isNotEmpty)
              .toList()
            ..sort()),
          selectedName,
          _onNameSelected,
          isLoading: _isLoadingMembers,
          validator: (v) => (v == null || v.isEmpty) ? tr('Required') : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField(tr('Visit No'), _visitNo, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker(tr('LMP Date'), lmpDate, (v) => setState(() => lmpDate = v))),
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
