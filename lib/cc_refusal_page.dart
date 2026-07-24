import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'sync_service.dart';
import 'widget.dart';

class CcRefusalPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const CcRefusalPage({super.key, this.existingData, this.docId});

  @override
  State<CcRefusalPage> createState() => _CcRefusalPageState();
}

class _CcRefusalPageState extends State<CcRefusalPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;
  bool _isActionActive = false;
  bool _isEditMode = false;
  String? _editDocId;
  bool _isLoadingMembers = false;
  final FocusNode _familyCodeNode = FocusNode();
  bool _familyIdReadOnly = true;

  final _registrationNumberController = TextEditingController();
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  final _ageController = TextEditingController();
  final _notInterestedTextController = TextEditingController();

  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectedGender;
  String? selectedInterviewer;
  String? selectedRespondent;
  DateTime? menstruationDate;

  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};

  bool currentlyPregnant = false;
  bool uterusRemoved = false;
  bool notInterested = false;
  bool currentlyMenstruating = false;
  bool notAvailable = false;

  final List<String> interviewers = [
    "KIRANMAI K", "LAVANYA KASPOJU", "RAMADEVI Y", "REVATHI CH", "PUSHPA K",
    "KUSUMA", "CHV", "SHAKUNTHALA(CHV AT)", "ASHA", "HEMALATHA(CHV AT)",
    "LAXMI", "BHASKAR", "KUSUMA G", "KARUNAKAR", "KRISHNAVENI", "B JYOTHI",
    "MADHAVI(CHV GR)", "ANNAPURNA", "BALAMANI(CHV GR)", "SALOMI", "UDYASHREE",
    "JOHN", "BHASKAR K", "SUNITHA", "KOMARIAH", "MADAV"
  ];

  final List<String> respondents = [
    "Participant", "Family members", "Neighbors", "CHV", "TETRA Team"
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _isEditMode = true;
      _editDocId = widget.docId;
      _populateForm(widget.existingData!);
      final famCode = (widget.existingData!['Family_Code'] ?? widget.existingData!['Family_code'] ?? '').toString();
      if (famCode.isNotEmpty) _fetchMembersByFamily(famCode);
    }
  }

  @override
  void dispose() {
    _familyCodeNode.dispose();
    _registrationNumberController.dispose();
    _familyCodeController.dispose();
    _ageController.dispose();
    _notInterestedTextController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembersByFamily(String famCode) async {
    final fCode = famCode.trim().toUpperCase();
    if (fCode.isEmpty) return;
    setState(() => _isLoadingMembers = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: fCode)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 8));
      final Map<String, Map<String, dynamic>> members = {};
      for (final doc in snap.docs) {
        final d = doc.data();
        final name = d['Name']?.toString() ?? '';
        if (name.isNotEmpty) members[name] = d;
      }
      if (mounted) {
        setState(() {
          _allMembersData = members;
          familyMemberNames = members.keys.toList()..sort();
        });
      }
    } catch (e) {
      debugPrint('Error fetching members: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  void _onNameSelected(String? name) {
    if (name == null) return;
    setState(() => selectedMemberName = name);
    final member = _allMembersData[name];
    if (member == null) return;
    setState(() {
      _registrationNumberController.text =
          member['uniq_Registration_Number']?.toString() ??
          member['Registration_Number']?.toString() ?? '';
      selectedGender = member['Gender'];
      _ageController.text = member['Age']?.toString() ?? '';
    });
  }

  void _populateForm(Map<String, dynamic> d) {
    _registrationNumberController.text = d['Registration_Number']?.toString() ?? '';
    selectedFamilyCode = d['Family_Code'] ?? d['Family_code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName    = d['Name'];
    selectedGender        = d['Gender'];
    _ageController.text   = d['Age']?.toString() ?? '';
    selectedInterviewer   = matchInterviewerName(d['Interviewer_s_Name'] ?? d['Interviewer_Name'] ?? d['INTNAME'], interviewers);
    selectedRespondent    = d['Respondent'];
    currentlyPregnant     = d['Currently_Pregnant'] == true;
    uterusRemoved         = d['Uterus_Removed'] == true;
    notInterested         = d['Not_Interested'] == true;
    _notInterestedTextController.text = d['Not_Interested_Text'] ?? '';
    currentlyMenstruating = d['Currently_Menstruating'] == true;
    notAvailable          = d['Not_Available'] == true;
    final rawMensDate = d['Menstruation_Date'];
    if (rawMensDate != null) {
      if (rawMensDate is Timestamp) {
        menstruationDate = rawMensDate.toDate();
      } else {
        try { menstruationDate = DateFormat('dd-MMM-yyyy').parse(rawMensDate.toString()); } catch (_) {}
      }
    }
  }

  void _resetForm() {
    setState(() {
      _registrationNumberController.clear();
      _ageController.clear();
      _notInterestedTextController.clear();
      selectedMemberName = null;
      selectedGender = null;
      selectedInterviewer = null;
      selectedRespondent = null;
      familyMemberNames = [];
      _allMembersData = {};
      currentlyPregnant = false;
      uterusRemoved = false;
      notInterested = false;
      currentlyMenstruating = false;
      notAvailable = false;
      menstruationDate = null;
    });
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
              firstDate: DateTime(2000),
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
            child: Text(
              selectedDate != null ? DateFormat('dd-MMM-yyyy').format(selectedDate) : 'Select date',
              style: TextStyle(color: selectedDate != null ? Colors.black87 : Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final regNo = _registrationNumberController.text.trim();
      final famCode = selectedFamilyCode ?? _familyCodeController.text.trim();
      final data = {
        'Registration_Number':    regNo,
        'Family_Code':            famCode,
        'Name':                   selectedMemberName,
        'Gender':                 selectedGender,
        'Age':                    int.tryParse(_ageController.text),
        'Interviewer_s_Name':     selectedInterviewer,
        'Respondent':             selectedRespondent,
        'Currently_Pregnant':     currentlyPregnant,
        'Uterus_Removed':         uterusRemoved,
        'Not_Interested':         notInterested,
        'Not_Interested_Text':    _notInterestedTextController.text,
        'Currently_Menstruating': currentlyMenstruating,
        'Menstruation_Date':      menstruationDate != null ? DateFormat('dd-MMM-yyyy').format(menstruationDate!) : null,
        'Not_Available':          notAvailable,
        'clientUpdatedAt':        DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync':        true,
        'firestoreDocId':         _editDocId ?? 'cc_ref_$regNo',
      };

      final bool wasEditing = _isEditMode;
      await DataCacheService().saveOfflineSubmission('cc_refusal', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Updated! Syncing...' : 'Saved! Syncing...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ));
        if (widget.docId != null) {
          Navigator.pop(context);
        } else if (!wasEditing) {
          _resetForm();
        }
      }
      SyncService().syncPendingSubmissions();
    } catch (e) {
      debugPrint('Error saving CC Refusal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save.'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Cervical Screening Refusal',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    formTextField('Registration Number', _registrationNumberController,
                        enabled: false, keyboardType: TextInputType.number),
                    const SizedBox(height: 12),

                    formSearchField(
                      'Family Code', _familyCodeController,
                      onSearch: () {
                        final v = _familyCodeController.text.trim();
                        setState(() {
                          selectedFamilyCode = v;
                          selectedMemberName = null;
                          familyMemberNames = [];
                        });
                        if (v.isNotEmpty) _fetchMembersByFamily(v);
                      },
                      enabled: _isActionActive,
                      readOnly: _familyIdReadOnly,
                      focusNode: _familyCodeNode,
                    ),
                    const SizedBox(height: 12),

                    formSearchableDropdown(
                      context, 'Name', familyMemberNames, selectedMemberName,
                      (v) => _onNameSelected(v as String?),
                      isLoading: _isLoadingMembers,
                      enabled: _isActionActive,
                    ),
                    const SizedBox(height: 12),

                    // Gender + Age row
                    Row(
                      children: [
                        const Text('Gender:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Male'),
                            value: '(1) Male',
                            groupValue: selectedGender,
                            onChanged: !_isActionActive ? null : (v) => setState(() => selectedGender = v),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Female'),
                            value: '(0) Female',
                            groupValue: selectedGender,
                            onChanged: !_isActionActive ? null : (v) => setState(() => selectedGender = v),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: formTextField('Age', _ageController,
                              enabled: _isActionActive, keyboardType: TextInputType.number),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    formSearchableDropdown(context, 'Interviewer Name', interviewers,
                        selectedInterviewer, (v) => setState(() => selectedInterviewer = v as String?),
                        enabled: _isActionActive),
                    const SizedBox(height: 20),
                    const Divider(thickness: 1.5),
                    const SizedBox(height: 8),

                    formSearchableDropdown(context, 'Respondent', respondents,
                        selectedRespondent, (v) => setState(() => selectedRespondent = v as String?),
                        enabled: _isActionActive),
                    const SizedBox(height: 20),

                    const Text('Reason for Withdrawing from Study',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),

                    formCheckboxOption(
                      label: '(5) Currently Pregnant',
                      value: currentlyPregnant,
                      onChanged: (v) => setState(() => currentlyPregnant = v ?? false),
                      enabled: _isActionActive,
                    ),
                    const SizedBox(height: 10),

                    formCheckboxOption(
                      label: '(6) Uterus Removed',
                      value: uterusRemoved,
                      onChanged: (v) => setState(() => uterusRemoved = v ?? false),
                      enabled: _isActionActive,
                    ),
                    const SizedBox(height: 10),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: formCheckboxOption(
                            label: '(7) Not Interested / Refused',
                            value: notInterested,
                            onChanged: (v) => setState(() => notInterested = v ?? false),
                            enabled: _isActionActive,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: formTextField('Specify', _notInterestedTextController,
                              enabled: _isActionActive && notInterested),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Divider(thickness: 1.5),
                    const SizedBox(height: 8),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: formCheckboxOption(
                            label: '(1) Currently Menstruating',
                            value: currentlyMenstruating,
                            onChanged: (v) => setState(() => currentlyMenstruating = v ?? false),
                            enabled: _isActionActive,
                          ),
                        ),
                        if (currentlyMenstruating) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDatePicker(
                              'Date', menstruationDate,
                              (d) => setState(() => menstruationDate = d),
                              enabled: _isActionActive,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),

                    formCheckboxOption(
                      label: '(2) Not Available',
                      value: notAvailable,
                      onChanged: (v) => setState(() => notAvailable = v ?? false),
                      enabled: _isActionActive,
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _isSaving
          ? null
          : formActionButtons(
              context: context,
              isEditMode: _isEditMode,
              isActionActive: _isActionActive,
              onNew: () {
                setState(() {
                  _isEditMode = false;
                  _resetForm();
                  _isActionActive = true;
                  _familyIdReadOnly = false;
                });
                _familyCodeNode.requestFocus();
              },
              onEdit: () => setState(() {
                _isEditMode = true;
                _isActionActive = true;
                _familyIdReadOnly = false;
              }),
              onSave: _save,
              onCancel: () => setState(() {
                _isActionActive = false;
                _familyIdReadOnly = true;
              }),
              onExit: () => Navigator.pop(context),
              isSaving: _isSaving,
            ),
    );
  }
}
