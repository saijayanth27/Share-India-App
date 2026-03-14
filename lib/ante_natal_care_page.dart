import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

class AnteNatalCarePage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const AnteNatalCarePage({super.key, this.existingData, this.docId});

  @override
  State<AnteNatalCarePage> createState() => _AnteNatalCarePageState();
}

class _AnteNatalCarePageState extends State<AnteNatalCarePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;

  // --- Controllers & State Variables ---
  final _registrationNumber = TextEditingController();
  final _familyCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _husbandName = TextEditingController();
  final _age = TextEditingController();

  // --- TT Dose Controllers ---
  DateTime? stDt;
  DateTime? ndDt;
  String? stGivenYN;
  String? stGivenBy;
  String? ndGivenYN;
  String? ndGivenBy;

  // --- IFA Controllers ---
  DateTime? stDt1;
  DateTime? ndDt1;
  DateTime? rdDt;
  DateTime? thDt;
  String? stGivenYN1;
  String? stGivenBy1;
  String? ndGivenYN1;
  String? ndGivenBy1;
  String? rdGivenYN;
  String? rdGivenYN1; // 3rd Given By
  String? THGivenYN;
  String? THGivenYN1; // 4th Given By

  // --- Delivery Controllers ---
  DateTime? deliveryDt;
  String? deliveryType;
  String? deliveryPlace;
  final _deliveryPlaceDetails = TextEditingController();
  String? deliveryOutcome;
  final _noOfBirths = TextEditingController();
  final _noOfBirthOfFemale = TextEditingController();
  final _totalLiveBirths = TextEditingController();

  // --- Remarks & Screen Selection ---
  final _remarks2 = TextEditingController();
  String? selectEntryScreen;

  String? selectedFamilyCode;
  String? selectedMemberName;
  DateTime? dateOfInterview = DateTime.now();
  String? interviewersName;
  DateTime? lmpDate;
  DateTime? eddDate;

  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  String? _baseRegistrationNumber;

  final List<String> interviewerList = ['KIRANMAI K', 'REVATHI CH', 'RAMADEVI Y', 'LAVANYA KASPOJU', 'PUSHPA K', 'G RAMADEVI', 'BHASKAR K', 'ASHA', 'KUSUMA G', 'B JYOTHI', 'RAMADEVI G', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU'];
  final List<String> screenChoices = ['TT Dose', 'IFA', 'Delivery', 'Remarks'];
  final List<String> yesNoChoices = ['(1) Yes', '(0) No'];
  final List<String> givenByChoices = ['(0) RHC', '(1) PVT', '(2) GOVT'];
  final List<String> deliveryTypeChoices = ['(0) Normal', '(1) Caesarian', '(2) Abortion'];
  final List<String> deliveryPlaceChoices = ['(0) RHC', '(1) PVT', '(2) GOVT', '(3) HOME'];
  final List<String> deliveryOutcomeChoices = ['(0) Live Birth', '(1) Still Birth', '(2) Premature'];

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
      // 1. Fetch Permanent Family Planning members to exclude them
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
      final Set<String> allNames = {};
      
      void processMember(Map<String, dynamic> data) {
        final name = data['Name']?.toString() ?? '';
        final gender = data['Gender']?.toString() ?? '';
        final maritalStatus = data['Marital_Status']?.toString() ?? '';
        final avStatus = data['A_v_Status']?.toString() ?? '';

        if (name.isEmpty) return;
        
        // Filter: (0) Female AND ((1) Married OR (3) Widow) AND (1) Active AND Not in excludedNames
        bool isEligibleFemale = gender == '(0) Female' && 
                               (maritalStatus == '(1) Married' || maritalStatus == '(3) Widow') &&
                               avStatus == '(1) Active';
        
        if (isEligibleFemale && !excludedNames.contains(name)) {
          memberMap[name] = data;
          allNames.add(name);
        }
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
          .collection('ante_natal_care')
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
      selectedMemberName = name;
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
          _baseRegistrationNumber = (data['uniq_Registration_Number'] ?? data['Registration_Number'] ?? '').toString();
          _husbandName.text = (data['Name2'] ?? data['Name1'] ?? '').toString();
          _age.text = data['Age']?.toString() ?? '';
          _updateRegistrationNumber();
        }
      }
    });
  }

  void _updateRegistrationNumber() {
    if (_baseRegistrationNumber != null && _baseRegistrationNumber!.isNotEmpty) {
      String newRegNo = _baseRegistrationNumber!;
      if (lmpDate != null) {
        newRegNo += DateFormat('ddMMyy').format(lmpDate!);
      }
      _registrationNumber.text = newRegNo;
    }
  }

  void _loadExistingData() {
    setState(() {
      _populateForm(widget.existingData!);
    });
  }

  void _populateForm(Map<String, dynamic> d) {
    _registrationNumber.text = d['Registration_Number'] ?? '';
    selectedFamilyCode = d['Family_Code'] ?? d['Family_code'] ?? d['Family_ID'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    _husbandName.text = d['Husband_Name'] ?? '';
    _age.text = d['Age']?.toString() ?? '';
    selectEntryScreen = d['Select_Entry_Screen'];
    
    // --- Helper for Date parsing ---
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String && val.isNotEmpty) {
        try {
          return DateFormat('dd-MMM-yyyy').parse(val);
        } catch (_) {
          try {
            return DateTime.parse(val);
          } catch (_) {}
        }
      }
      return null;
    }

    dateOfInterview = parseDate(d['Date_of_Interview']) ?? DateTime.now();
    lmpDate = parseDate(d['LMP_Date']);
    eddDate = parseDate(d['EDD_Date']);
    interviewersName = d['Interviewer_s_Name'];

    // --- TT Dose ---
    stGivenYN = d['st_Given_Y_N'];
    stGivenBy = d['st_Given_By'];
    stDt = parseDate(d['st_Dt']);
    ndGivenYN = d['nd_Given_Y_N'];
    ndGivenBy = d['nd_Given_By'];
    ndDt = parseDate(d['nd_Dt']);

    // --- IFA ---
    stGivenYN1 = d['st_Given_Y_N1'];
    stGivenBy1 = d['st_Given_By1'];
    stDt1 = parseDate(d['st_Dt1']);
    ndGivenYN1 = d['nd_Given_Y_N1'];
    ndGivenBy1 = d['nd_Given_By1'];
    ndDt1 = parseDate(d['nd_Dt1']);
    rdGivenYN = d['rd_Given_Y_N'];
    rdGivenYN1 = d['rd_Given_Y_N1'];
    rdDt = parseDate(d['rd_Dt']);
    THGivenYN = d['TH_Given_Y_N'];
    THGivenYN1 = d['TH_Given_Y_N1'];
    thDt = parseDate(d['th_Dt']);

    // --- Delivery ---
    deliveryType = d['Delivery_Type'];
    deliveryDt = parseDate(d['Delivery_Dt']);
    deliveryPlace = d['Delivery_Place'];
    _deliveryPlaceDetails.text = d['Delivery_Place_Details'] ?? '';
    deliveryOutcome = d['Delivery'];
    _noOfBirths.text = d['No_of_Births']?.toString() ?? '';
    _noOfBirthOfFemale.text = d['No_of_Birth_of_Female1']?.toString() ?? '';
    _totalLiveBirths.text = d['Total_Live_Births']?.toString() ?? '';

    // --- Remarks ---
    _remarks2.text = d['Remarks2'] ?? '';

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
      _husbandName.clear();
      selectedFamilyCode = null;
      selectedMemberName = null;
      _age.clear();
      dateOfInterview = DateTime.now();
      lmpDate = null;
      eddDate = null;
      interviewersName = null;
      _baseRegistrationNumber = null;

      // Reset TT Dose
      stDt = ndDt = null;
      stGivenYN = stGivenBy = ndGivenYN = ndGivenBy = null;

      // Reset IFA
      stDt1 = ndDt1 = rdDt = thDt = null;
      stGivenYN1 = stGivenBy1 = ndGivenYN1 = ndGivenBy1 = rdGivenYN = rdGivenYN1 = THGivenYN = THGivenYN1 = null;

      // Reset Delivery
      deliveryDt = null;
      deliveryType = deliveryPlace = deliveryOutcome = null;
      _deliveryPlaceDetails.clear();
      _noOfBirths.clear();
      _noOfBirthOfFemale.clear();
      _totalLiveBirths.clear();

      // Reset Remarks & Selection
      _remarks2.clear();
      selectEntryScreen = null;

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
        'Family_Code': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Husband_Name': _husbandName.text,
        'Age': int.tryParse(_age.text),
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'LMP_Date': lmpDate != null ? Timestamp.fromDate(lmpDate!) : null,
        'EDD_Date': eddDate != null ? Timestamp.fromDate(eddDate!) : null,
        'Interviewer_s_Name': interviewersName,
        'Select_Entry_Screen': selectEntryScreen,

        // --- TT Dose ---
        'st_Given_Y_N': stGivenYN,
        'st_Given_By': stGivenBy,
        'st_Dt': stDt != null ? Timestamp.fromDate(stDt!) : null,
        'nd_Given_Y_N': ndGivenYN,
        'nd_Given_By': ndGivenBy,
        'nd_Dt': ndDt != null ? Timestamp.fromDate(ndDt!) : null,

        // --- IFA ---
        'st_Given_Y_N1': stGivenYN1,
        'st_Given_By1': stGivenBy1,
        'st_Dt1': stDt1 != null ? Timestamp.fromDate(stDt1!) : null,
        'nd_Given_Y_N1': ndGivenYN1,
        'nd_Given_By1': ndGivenBy1,
        'nd_Dt1': ndDt1 != null ? Timestamp.fromDate(ndDt1!) : null,
        'rd_Given_Y_N': rdGivenYN,
        'rd_Given_Y_N1': rdGivenYN1,
        'rd_Dt': rdDt != null ? Timestamp.fromDate(rdDt!) : null,
        'TH_Given_Y_N': THGivenYN,
        'TH_Given_Y_N1': THGivenYN1,
        'th_Dt': thDt != null ? Timestamp.fromDate(thDt!) : null,

        // --- Delivery ---
        'Delivery_Type': deliveryType,
        'Delivery_Dt': deliveryDt != null ? Timestamp.fromDate(deliveryDt!) : null,
        'Delivery_Place': deliveryPlace,
        'Delivery_Place_Details': _deliveryPlaceDetails.text,
        'Delivery': deliveryOutcome,
        'No_of_Births': int.tryParse(_noOfBirths.text),
        'No_of_Birth_of_Female1': int.tryParse(_noOfBirthOfFemale.text),
        'Total_Live_Births': _totalLiveBirths.text,

        'Remarks2': _remarks2.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;

      // 1. Save locally FIRST (Fast)
      final bool wasEditing = _isEditMode;
      await DataCacheService().saveOfflineSubmission('ante_natal_care', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'ANC updated! Syncing...' : 'ANC saved! Syncing...'),
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
      _performAnteNatalCareSync(data);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _performAnteNatalCareSync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('ante_natal_care').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('ante_natal_care').add(data);
      }
    } catch (e) {
      debugPrint('ANC Background Sync Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Ante Natal Care'), elevation: 0),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('anc_scroll'),
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
                      title: 'Maternity Details',
                      icon: Icons.pregnant_woman_outlined,
                      children: [
                        _buildDatePicker('LMP Date', lmpDate, (v) => setState(() {
                          lmpDate = v;
                          eddDate = v.add(const Duration(days: 280));
                          _updateRegistrationNumber();
                        })),
                        const SizedBox(height: 16),
                        _buildDatePicker('EDD Date', eddDate, (v) => setState(() => eddDate = v)),
                        const SizedBox(height: 16),
                        formSearchableDropdown(context, 'Select Entry Screen', screenChoices, selectEntryScreen, (v) => setState(() => selectEntryScreen = v)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (selectEntryScreen == 'TT Dose') _buildTTDoseSection(),
                    if (selectEntryScreen == 'IFA') _buildIFASection(),
                    if (selectEntryScreen == 'Delivery') _buildDeliverySection(),
                    if (selectEntryScreen == 'Remarks') _buildRemarksSection(),
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
      title: 'Member Identity',
      icon: Icons.person_outline,
      children: [
        formTextField('Registration Number', _registrationNumber),
        const SizedBox(height: 12),
        formSearchField('Family Code', _familyCodeController, onSearch: () {
          if (_familyCodeController.text.isNotEmpty) {
            _fetchMembersByFamily(_familyCodeController.text);
            _fetchExistingRecords(_familyCodeController.text);
          }
        }, isLoading: _isLoadingMembers),
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
        ),
        const SizedBox(height: 12),
        formTextField('Husband Name', _husbandName),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField('Age', _age, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Interview Date', dateOfInterview, (v) => setState(() => dateOfInterview = v))),
          ],
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(context, 'Interviewer Name', interviewerList, interviewersName, (v) => setState(() => interviewersName = v)),
      ],
    );
  }

  Widget _buildTTDoseSection() {
    return buildSectionCard(
      context: context,
      title: 'TT Dose',
      icon: Icons.vaccines_outlined,
      children: [
        const Text('1st TT Dose', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, '1st Given Y/N', yesNoChoices, stGivenYN, (v) => setState(() => stGivenYN = v))),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, '1st Given By', givenByChoices, stGivenBy, (v) => setState(() => stGivenBy = v))),
          ],
        ),
        const SizedBox(height: 12),
        _buildDatePicker('1st TT Dt.', stDt, (v) => setState(() => stDt = v)),
        const Divider(height: 32),
        const Text('2nd TT Dose', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, '2nd Given Y/N', yesNoChoices, ndGivenYN, (v) => setState(() => ndGivenYN = v))),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, '2nd Given By', givenByChoices, ndGivenBy, (v) => setState(() => ndGivenBy = v))),
          ],
        ),
        const SizedBox(height: 12),
        _buildDatePicker('2nd TT Dt.', ndDt, (v) => setState(() => ndDt = v)),
      ],
    );
  }

  Widget _buildIFASection() {
    return buildSectionCard(
      context: context,
      title: 'IFA',
      icon: Icons.medication_outlined,
      children: [
        const Text('1st IFA', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, '1st Given Y/N', yesNoChoices, stGivenYN1, (v) => setState(() => stGivenYN1 = v))),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, '1st Given By', givenByChoices, stGivenBy1, (v) => setState(() => stGivenBy1 = v))),
          ],
        ),
        const SizedBox(height: 12),
        _buildDatePicker('1st IFA Dt.', stDt1, (v) => setState(() => stDt1 = v)),
        const Divider(height: 32),
        const Text('2nd IFA', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, '2nd Given Y/N', yesNoChoices, ndGivenYN1, (v) => setState(() => ndGivenYN1 = v))),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, '2nd Given By', givenByChoices, ndGivenBy1, (v) => setState(() => ndGivenBy1 = v))),
          ],
        ),
        const SizedBox(height: 12),
        _buildDatePicker('2nd IFA Dt.', ndDt1, (v) => setState(() => ndDt1 = v)),
        const Divider(height: 32),
        const Text('3rd IFA', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, '3rd Given Y/N', yesNoChoices, rdGivenYN, (v) => setState(() => rdGivenYN = v))),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, '3rd Given By', givenByChoices, rdGivenYN1, (v) => setState(() => rdGivenYN1 = v))),
          ],
        ),
        const SizedBox(height: 12),
        _buildDatePicker('3rd IFA Dt.', rdDt, (v) => setState(() => rdDt = v)),
        const Divider(height: 32),
        const Text('4th IFA', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, '4TH Given Y/N', yesNoChoices, THGivenYN, (v) => setState(() => THGivenYN = v))),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, '4th Given By', givenByChoices, THGivenYN1, (v) => setState(() => THGivenYN1 = v))),
          ],
        ),
        const SizedBox(height: 12),
        _buildDatePicker('4th IFA Dt.', thDt, (v) => setState(() => thDt = v)),
      ],
    );
  }

  Widget _buildDeliverySection() {
    return buildSectionCard(
      context: context,
      title: 'Delivery',
      icon: Icons.child_friendly_outlined,
      children: [
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, 'Delivery Type', deliveryTypeChoices, deliveryType, (v) => setState(() => deliveryType = v))),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Delivery Dt.', deliveryDt, (v) => setState(() => deliveryDt = v))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formSearchableDropdown(context, 'Delivery Place', deliveryPlaceChoices, deliveryPlace, (v) => setState(() => deliveryPlace = v))),
            const SizedBox(width: 12),
            Expanded(child: formSearchableDropdown(context, 'Delivery Outcome', deliveryOutcomeChoices, deliveryOutcome, (v) => setState(() => deliveryOutcome = v))),
          ],
        ),
        const SizedBox(height: 12),
        formTextField('Delivery Place Details', _deliveryPlaceDetails),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: formTextField('No.of Births', _noOfBirths, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: formTextField('No.of Birth of Female', _noOfBirthOfFemale, keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 12),
        formTextField('Total Live Births', _totalLiveBirths, keyboardType: TextInputType.number),
      ],
    );
  }

  Widget _buildRemarksSection() {
    return buildSectionCard(
      context: context,
      title: 'Remarks',
      icon: Icons.note_alt_outlined,
      children: [
        formTextField('Remarks', _remarks2, maxLines: 5),
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
            final picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now().add(const Duration(days: 365)));
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