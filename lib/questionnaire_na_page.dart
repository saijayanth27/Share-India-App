import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'sync_service.dart';
import 'widget.dart';

class QuestionnaireNAPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const QuestionnaireNAPage({super.key, this.existingData, this.docId});

  @override
  State<QuestionnaireNAPage> createState() => _QuestionnaireNAPageState();
}

class _QuestionnaireNAPageState extends State<QuestionnaireNAPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;
  bool _isActionActive = false;
  bool _isEditMode = false;
  String? _editDocId;
  final FocusNode _familyCodeNode = FocusNode();
  bool _familyIdReadOnly = true;
  bool _isLoadingMembers = false;

  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  final _otherReasonController = TextEditingController();
  final _participantRegNoController = TextEditingController();

  String? selectedFamilyCode;
  String? selectedParticipantName;
  DateTime? visitDate = DateTime.now();
  String? selectedInterviewer;

  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};

  bool notAvailable = false;
  bool houseLocked = false;
  bool refusedCurrentVisit = false;
  bool otherReason = false;

  final List<String> interviewers = [
    "KIRANMAI K", "LAVANYA KASPOJU", "RAMADEVI Y", "REVATHI CH", "PUSHPA K",
    "KUSUMA", "CHV", "SHAKUNTHALA(CHV AT)", "ASHA", "HEMALATHA(CHV AT)",
    "LAXMI", "BHASKAR", "KUSUMA G", "KARUNAKAR", "KRISHNAVENI", "B JYOTHI",
    "MADHAVI(CHV GR)", "ANNAPURNA", "BALAMANI(CHV GR)", "SALOMI", "UDYASHREE",
    "JOHN", "BHASKAR K", "SUNITHA", "KOMARIAH", "MADAV"
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _isEditMode = true;
      _editDocId = widget.docId;
      _populateForm(widget.existingData!);
    }
  }

  @override
  void dispose() {
    _familyCodeNode.dispose();
    _familyCodeController.dispose();
    _otherReasonController.dispose();
    _participantRegNoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _populateForm(Map<String, dynamic> d) {
    selectedFamilyCode = d['Family_Code'] ?? d['Family_code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedParticipantName = d['Participant_Name']?.toString();
    _participantRegNoController.text = d['Registration_Number']?.toString() ?? '';
    final rawDate = d['Visit_Date'];
    if (rawDate != null) {
      if (rawDate is Timestamp) {
        visitDate = rawDate.toDate();
      } else {
        try { visitDate = DateFormat('dd-MMM-yyyy').parse(rawDate.toString()); } catch (_) {}
      }
    }
    selectedInterviewer = matchInterviewerName(d['Interviewer_s_Name'] ?? d['Interviewer_Name'] ?? d['INTNAME'], interviewers);
    notAvailable        = d['Not_Available'] == true;
    houseLocked         = d['House_Locked'] == true;
    refusedCurrentVisit = d['Refused_Current_Visit'] == true;
    otherReason         = d['Other_Reason'] == true;
    _otherReasonController.text = d['Other_Reason_Text']?.toString() ?? '';
  }

  void _resetForm() {
    setState(() {
      selectedFamilyCode = null;
      selectedParticipantName = null;
      familyMemberNames = [];
      _allMembersData = {};
      _participantRegNoController.clear();
      visitDate = DateTime.now();
      selectedInterviewer = null;
      notAvailable = false;
      houseLocked = false;
      refusedCurrentVisit = false;
      otherReason = false;
      _otherReasonController.clear();
    });
  }

  Future<void> _fetchMembersByFamily(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      final fCode = familyCode.trim().toUpperCase();
      if (fCode.isEmpty) return;

      final localMembers = await DataCacheService().fetchMembersLocally(fCode);

      List<Map<String, dynamic>> firestoreMembers = [];
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('personal_details')
            .where('Family_Code', isEqualTo: fCode)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 3));
        firestoreMembers = snapshot.docs.map((d) => d.data()).toList();
      } catch (e) {
        debugPrint('QST NA: Firestore timeout, using local: $e');
      }

      final Map<String, Map<String, dynamic>> memberMap = {};
      for (var data in [...firestoreMembers, ...localMembers]) {
        final name = data['Name']?.toString() ?? '';
        if (name.isEmpty) continue;
        memberMap[name] = data;
      }

      setState(() {
        _allMembersData = memberMap;
        familyMemberNames = memberMap.keys.toList()..sort();
        selectedFamilyCode = fCode;
      });
    } catch (e) {
      debugPrint('Error fetching members for QST NA: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  void _onParticipantSelected(String? name) {
    setState(() {
      selectedParticipantName = name;
      if (name != null && _allMembersData.containsKey(name)) {
        final member = _allMembersData[name]!;
        _participantRegNoController.text =
            member['Registration_Number1']?.toString() ??
            member['Registration_Number']?.toString() ?? '';
      } else {
        _participantRegNoController.clear();
      }
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
      final famCode = selectedFamilyCode ?? _familyCodeController.text.trim();
      final dateStr = visitDate != null ? DateFormat('dd-MMM-yyyy').format(visitDate!) : null;
      final data = {
        'Family_Code':           famCode,
        'Participant_Name':      selectedParticipantName,
        'Registration_Number':   int.tryParse(_participantRegNoController.text.trim()),
        'Visit_Date':            dateStr,
        'Interviewer_s_Name':    selectedInterviewer,
        'Not_Available':         notAvailable,
        'House_Locked':          houseLocked,
        'Refused_Current_Visit': refusedCurrentVisit,
        'Other_Reason':          otherReason,
        'Other_Reason_Text':     _otherReasonController.text,
        'clientUpdatedAt':       DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync':       true,
        'firestoreDocId':        _editDocId ?? 'qst_na_${famCode}_${dateStr?.replaceAll('-', '') ?? ''}',
      };

      final bool wasEditing = _isEditMode;
      await DataCacheService().saveOfflineSubmission('questionnaire_not_available', data);

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
      debugPrint('Error saving QST NA: $e');
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
        title: const Text('Questionnaire N/A',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade700, Colors.orange.shade400],
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
                    // Family Code
                    formSearchField(
                      'Family Code',
                      _familyCodeController,
                      onSearch: () {
                        final code = _familyCodeController.text.trim();
                        if (code.isNotEmpty) _fetchMembersByFamily(code);
                      },
                      enabled: _isActionActive,
                      readOnly: _familyIdReadOnly,
                      focusNode: _familyCodeNode,
                    ),
                    const SizedBox(height: 12),

                    // Participant Name
                    if (_isLoadingMembers)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      )
                    else
                      formSearchableDropdown(
                        context,
                        'Participant Name',
                        familyMemberNames,
                        selectedParticipantName,
                        (v) => _onParticipantSelected(v?.toString()),
                        enabled: _isActionActive,
                      ),
                    const SizedBox(height: 12),

                    // Participant Registration Number
                    formTextField(
                      'Participant Registration Number',
                      _participantRegNoController,
                      enabled: _isActionActive,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),

                    // Visit Date
                    _buildDatePicker(
                      'Visit Date', visitDate,
                      (d) => setState(() => visitDate = d),
                      enabled: _isActionActive,
                    ),
                    const SizedBox(height: 12),

                    // Interviewer
                    formSearchableDropdown(
                      context, 'Interviewer Name', interviewers,
                      selectedInterviewer,
                      (v) => setState(() => selectedInterviewer = v?.toString()),
                      enabled: _isActionActive,
                    ),

                    const SizedBox(height: 20),
                    const Divider(thickness: 1.5),
                    const SizedBox(height: 8),

                    const Text('Reason for Non-Availability',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),

                    formCheckboxOption(
                      label: '(1) Not Available',
                      value: notAvailable,
                      onChanged: (v) => setState(() => notAvailable = v ?? false),
                      enabled: _isActionActive,
                    ),
                    const SizedBox(height: 10),

                    formCheckboxOption(
                      label: '(2) House Locked',
                      value: houseLocked,
                      onChanged: (v) => setState(() => houseLocked = v ?? false),
                      enabled: _isActionActive,
                    ),
                    const SizedBox(height: 10),

                    formCheckboxOption(
                      label: '(3) Refused Current Visit',
                      value: refusedCurrentVisit,
                      onChanged: (v) => setState(() => refusedCurrentVisit = v ?? false),
                      enabled: _isActionActive,
                    ),
                    const SizedBox(height: 10),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        formCheckboxOption(
                          label: '(4) Other Reasons',
                          value: otherReason,
                          onChanged: (v) => setState(() => otherReason = v ?? false),
                          enabled: _isActionActive,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: formTextField(
                            'Specify', _otherReasonController,
                            enabled: _isActionActive && otherReason,
                          ),
                        ),
                      ],
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
