import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';
import 'language_provider.dart';

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
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;

  // --- Basic Information ---
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  final _finalFamilyCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _nameIdController = TextEditingController();
  final _husbandNameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _motherRegNoController = TextEditingController();
  final _fatherRegNoController = TextEditingController();
  final _familyNoController = TextEditingController();
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
  String? marriageType;

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

  @override
  void initState() {
    super.initState();
    if (widget.initialFamilyCode != null) {
      _familyCodeController.text = widget.initialFamilyCode!;
      _fetchMembersByFamily(widget.initialFamilyCode!);
      _fetchExistingRecords(widget.initialFamilyCode!);
    }
    if (widget.existingData != null) {
      _loadExistingData();
    }
  }

  Future<void> _fetchMembersByFamily(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      // 1. Fetch members with Permanent Family Planning to exclude them
      final fpSnapshot = await FirebaseFirestore.instance
          .collection('family_planning')
          .where('Family_Code', isEqualTo: familyCode)
          .where('Select_Entry_Screen', isEqualTo: '(1) Permanent')
          .get();
      final excludedNames = fpSnapshot.docs
          .map((doc) => doc.data()['Name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toSet();

      // 2. Fetch Personal Details
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyCode)
          .get(const GetOptions(source: Source.serverAndCache));
      final localMembers = await DataCacheService().fetchMembersLocally(familyCode);
      
      final Map<String, Map<String, dynamic>> memberMap = {};
      final Set<String> names = {};
      
      void processMember(Map<String, dynamic> data) {
        final name = data['Name']?.toString() ?? '';
        final gender = data['Gender']?.toString() ?? '';
        final maritalStatus = data['Marital_Status']?.toString() ?? '';
        final avStatus = data['A_v_Status']?.toString() ?? '';

        if (name.isEmpty) return;

        // Filter: (0) Female AND (1) Married AND (1) Active AND Not in excludedNames
        bool isEligibleFemale = gender == '(0) Female' && 
                               maritalStatus == '(1) Married' &&
                               avStatus == '(1) Active';
        
        if (isEligibleFemale && !excludedNames.contains(name)) {
          memberMap[name] = data;
          names.add(name);
        }
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
          .collection('family_planning')
          .where('Family_Code', isEqualTo: familyCode)
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

    final baseData = _allMembersData[name];
    if (baseData != null && !_isEditMode) {
      _regNoController.text = (baseData['uniq_Registration_Number'] ?? baseData['Registration_Number'] ?? baseData['Registration_Number1'] ?? '').toString();
      _husbandNameController.text = (baseData['Name2'] ?? baseData['Name1'] ?? '').toString();
      selectedGender = baseData['Gender']?.toString();
      _nameIdController.text = baseData['ID']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        final snapshot = await FirebaseFirestore.instance
            .collection('family_planning')
            .where('Family_Code', isEqualTo: fCode)
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
        debugPrint('Error fetching family planning record: $e');
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
    _regNoController.text = d['Registration_Number']?.toString() ?? '';
    selectedFamilyCode = d['Family_Code'] ?? d['Family_code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    _finalFamilyCodeController.text = d['Final_family_code']?.toString() ?? '';
    selectedName = d['Name'];
    _nameController.text = selectedName ?? '';
    _nameIdController.text = d['fam_id']?.toString() ?? '';
    _husbandNameController.text = d['Husband_Name']?.toString() ?? '';
    selectedGender = d['Gender'];
    selectEntryScreen = d['Select_Entry_Screen'];
    _motherRegNoController.text = d['Mother_Registration_Number']?.toString() ?? '';
    _fatherRegNoController.text = d['Father_Registration_Number']?.toString() ?? '';
    _familyNoController.text = d['Family_No']?.toString() ?? '';
    marriageType = d['Marriage_Type'];

    // Permanent
    permanentUsed = d['Used'];
    final rawDate1 = d['Date_field1'];
    if (rawDate1 != null) {
      if (rawDate1 is Timestamp) {
        permanentDate = rawDate1.toDate();
      } else {
        try {
          permanentDate = DateFormat('dd-MMM-yyyy').parse(rawDate1.toString());
        } catch (_) {
          permanentDate = DateTime.tryParse(rawDate1.toString());
        }
      }
    }
    permanentPlace = d['Place'];
    _remarksController.text = d['Remarks']?.toString() ?? '';

    // Temporary
    usedOralContraceptives = d['Used_oral_contraceptives'];
    _howLongUseOralController.text = d['How_long_use_oral1']?.toString() ?? '';
    final rawOralDate = d['Last_use_oral_contraceptives'];
    if (rawOralDate != null) {
      if (rawOralDate is Timestamp) {
        lastUseOralDate = rawOralDate.toDate();
      } else {
        try {
          lastUseOralDate = DateFormat('dd-MMM-yyyy').parse(rawOralDate.toString());
        } catch (_) {
          lastUseOralDate = DateTime.tryParse(rawOralDate.toString());
        }
      }
    }
    usedCondoms = d['Used_condoms'];
    usedCopperT = d['Used_an_Copper_T'];
    usedInjectable = d['Used_injectable_contraceptives'];
    howLongInjectable = d['How_long_using_injectable_contraceptives'];
    final rawInjectableDate = d['Last_use_injectable_contraceptives'];
    if (rawInjectableDate != null) {
      if (rawInjectableDate is Timestamp) {
        lastUseInjectableDate = rawInjectableDate.toDate();
      } else {
        try {
          lastUseInjectableDate = DateFormat('dd-MMM-yyyy').parse(rawInjectableDate.toString());
        } catch (_) {
          lastUseInjectableDate = DateTime.tryParse(rawInjectableDate.toString());
        }
      }
    }
    final rawDate2 = d['Date_field2'];
    if (rawDate2 != null) {
      if (rawDate2 is Timestamp) {
        temporaryDate = rawDate2.toDate();
      } else {
        try {
          temporaryDate = DateFormat('dd-MMM-yyyy').parse(rawDate2.toString());
        } catch (_) {
          temporaryDate = DateTime.tryParse(rawDate2.toString());
        }
      }
    }
    usedOther = d['Used_other'];
    _ifYesController.text = d['If_yes']?.toString() ?? '';

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _regNoController.clear();
      _familyCodeController.clear();
      _finalFamilyCodeController.clear();
      _nameController.clear();
      _nameIdController.clear();
      _husbandNameController.clear();
      _motherRegNoController.clear();
      _fatherRegNoController.clear();
      _familyNoController.clear();
      _remarksController.clear();
      _howLongOralController.clear();
      _ifYesOtherController.clear();
      _howLongUseOralController.clear();
      _ifYesController.clear();

      selectedFamilyCode = null;
      selectedName = null;
      selectedGender = null;
      selectEntryScreen = null;
      marriageType = null;
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
        'Final_family_code': _finalFamilyCodeController.text,
        'Name': _isEditMode ? selectedName : _nameController.text,
        'fam_id': _nameIdController.text,
        'Husband_Name': _husbandNameController.text,
        'Gender': selectedGender,
        'Select_Entry_Screen': selectEntryScreen,
        'Mother_Registration_Number': int.tryParse(_motherRegNoController.text),
        'Father_Registration_Number': int.tryParse(_fatherRegNoController.text),
        'Family_No': int.tryParse(_familyNoController.text),
        'Marriage_Type': marriageType,

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
          content: Text(wasEditing ? tr('Family Planning updated! Syncing...') : tr('Family Planning saved! Syncing...')),
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
      _performFamilyPlanningSync(data);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('Error saving')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _performFamilyPlanningSync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('family_planning').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('family_planning').add(data);
      }
    } catch (e) {
      debugPrint('Family Planning Background Sync Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageProvider.instance.isTeluguNotifier,
      builder: (context, isTelugu, _) {
      return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: Text(tr('Family Planning')), elevation: 0, actions: const [LanguageToggleButton()]),
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
                      title: tr('Entry Selection'),
                      icon: Icons.settings_outlined,
                      children: [
                        formSearchableDropdown(context, tr('Select Entry Screen'), ['(1) Permanent', '(0) Temporary'], selectEntryScreen, (v) => setState(() => selectEntryScreen = v)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (selectEntryScreen == '(1) Permanent') _buildPermanentSection(),
                    if (selectEntryScreen == '(0) Temporary') _buildTemporarySection(),
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
        Row(
          children: [
            Expanded(child: formTextField(tr('Registration Number'), _regNoController, readOnly: true)),
            const SizedBox(width: 8),
            Expanded(child: formTextField(tr('Family No'), _familyNoController, keyboardType: TextInputType.number)),
          ],
        ),
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
          validator: (v) => (v == null || v.isEmpty) ? tr('Required') : null,
        ),
        const SizedBox(height: 12),
        formTextField(tr('Final Family Code'), _finalFamilyCodeController),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: formSearchableDropdown(
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
            ),
            const SizedBox(width: 8),
            Expanded(child: formTextField(tr('Name ID'), _nameIdController, readOnly: true)),
          ],
        ),
        const SizedBox(height: 12),
        formTextField(tr('Husband Name'), _husbandNameController),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField(tr('Mother Reg No'), _motherRegNoController, keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: formTextField(tr('Father Reg No'), _fatherRegNoController, keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(context, tr('Marriage Type'), ['Married In', 'Married Out'], marriageType, (v) => setState(() => marriageType = v)),
      ],
    );
  }

  Widget _buildPermanentSection() {
    return buildSectionCard(
      context: context,
      title: tr('Permanent Method'),
      icon: Icons.verified_user_outlined,
      children: [
        formSearchableDropdown(context, tr('Used?'), ['(0) Tubectomy', '(1) Vasectomy', '(2) Hysectomy'], permanentUsed, (v) => setState(() => permanentUsed = v)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildDatePicker(tr('Date?'), permanentDate, (v) => setState(() => permanentDate = v))),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, tr('Place?'), ['(0) RHC', '(1) PVT', '(2) GOVT'], permanentPlace, (v) => setState(() => permanentPlace = v))),
          ],
        ),
        const SizedBox(height: 12),
        formTextField(tr('Remarks'), _remarksController, maxLines: 3),
      ],
    );
  }

  Widget _buildTemporarySection() {
    return buildSectionCard(
      context: context,
      title: tr('Temporary Method'),
      icon: Icons.history_outlined,
      children: [
        _buildDropdownRow(tr('Used oral contraceptives?'), ['(1) Yes', '(0) No'], usedOralContraceptives, (v) => setState(() => usedOralContraceptives = v)),
        if (usedOralContraceptives == '(1) Yes') ...[
          formTextField(tr('How long use oral'), _howLongUseOralController),
          const SizedBox(height: 12),
          _buildDatePicker(tr('Last use oral contraceptives?'), lastUseOralDate, (v) => setState(() => lastUseOralDate = v)),
          const SizedBox(height: 16),
        ],
        _buildDropdownRow(tr('Used condoms?'), ['(1) Yes', '(0) No'], usedCondoms, (v) => setState(() => usedCondoms = v)),
        const SizedBox(height: 12),
        _buildDropdownRow(tr('Used an Copper-T?'), ['(1) Yes', '(0) No'], usedCopperT, (v) => setState(() => usedCopperT = v)),
        const SizedBox(height: 12),
        _buildDropdownRow(tr('Used injectable contraceptives?'), ['(1) Yes', '(0) No'], usedInjectable, (v) => setState(() => usedInjectable = v)),
        if (usedInjectable == '(1) Yes') ...[
          formSearchableDropdown(context, tr('How long using injectable?'), ['Choice 1', 'Choice 2', 'Choice 3'], howLongInjectable, (v) => setState(() => howLongInjectable = v)),
          const SizedBox(height: 12),
          _buildDatePicker(tr('Last use injectable date'), lastUseInjectableDate, (v) => setState(() => lastUseInjectableDate = v)),
          const SizedBox(height: 16),
        ],
        _buildDatePicker(tr('Temporary Date?'), temporaryDate, (v) => setState(() => temporaryDate = v)),
        const SizedBox(height: 12),
        _buildDropdownRow(tr('Used other?'), ['(1) Yes', '(0) No'], usedOther, (v) => setState(() => usedOther = v)),
        if (usedOther == '(1) Yes') formTextField(tr('If yes,'), _ifYesController),
      ],
    );
  }

  Widget _buildDropdownRow(String label, List<String> choices, String? value, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        formSearchableDropdown(context, '', choices, value, onChanged),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
            child: Text(
              selectedDate == null
                  ? tr('dd-MMM-yyyy')
                  : DateFormat('dd-MMM-yyyy').format(selectedDate),
            ),
          ),
        ),
      ],
    );
  }
}
