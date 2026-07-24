import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'local_database_service.dart';
import 'sync_service.dart';
import 'widget.dart';

class EyeExaminationPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const EyeExaminationPage({super.key, this.existingData, this.docId});

  @override
  State<EyeExaminationPage> createState() => _EyeExaminationPageState();
}

class _EyeExaminationPageState extends State<EyeExaminationPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoading = false;
  bool _isActionActive = false; // Add this
  final FocusNode _familyCodeNode = FocusNode();
  bool _familyIdReadOnly = true;

  // --- Identification State ---
  final _nameController = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectedGender;
  final _ageController = TextEditingController();
  DateTime? examinationDate = DateTime.now();
  String? selectedInterviewer;

  // --- Right EYE (OD) State ---
  String? selectedFailedDistanceOD;
  String? selectedFailedPinholeOD;
  String? selectedSymptomsOD;
  final _othersSymptomsODController = TextEditingController();
  String? selectedEyeProblemsOD;
  final _othersEyeProblemsODController = TextEditingController();

  // --- Left EYE (OS) State ---
  String? selectedFailedDistanceOS;
  String? selectedFailedPinholeOS;
  String? selectedSymptomsOS;
  final _othersSymptomsOSController = TextEditingController();
  String? selectedEyeProblemsOS;
  final _othersEyeProblemsOSController = TextEditingController();

  // Dropdowns
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  // Location (auto-populated from Family Code)
  String? _locationVillage;
  String? _locationMandal;
  String? _locationDistrict;
  String? _locationState;

  bool _isLoadingMembers = false;

  final List<String> interviewers = ["KIRANMAI K", "LAVANYA KASPOJU", "RAMADEVI Y", "REVATHI CH"];
  final List<String> distanceChoices = ["6/12", "6/18", "6/60", "below 6/60"];
  final List<String> pinholeChoices = ["6/9", "6/12", "6/60", "equal or below 6/18"];
  final List<String> symptomsChoices = ["No Symptoms", "Headache", "Glare", "Double Vision", "Watering", "Redness", "Itching", "Burning", "Irritation", "Discharge", "Others"];
  final List<String> eyeProblemsChoices = ["No Problem", "Blurred/decreased Vision", "Refractive Error", "Presbyopia", "Cataract", "Pterygium", "Corneal Problem", "Squint", "Injury", "Bitot Spots", "Night Blindness", "Eyelid Problem", "Red Eye", "Others"];

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _isEditMode = true;
      _editDocId = widget.docId;
      _loadExistingData();
      final familyCode = (widget.existingData!['Family_Code'] ?? widget.existingData!['Family_code'] ?? '').toString();
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
    _registrationNumber.dispose();
    _familyCodeController.dispose();
    _ageController.dispose();
    _othersSymptomsODController.dispose();
    _othersEyeProblemsODController.dispose();
    _othersSymptomsOSController.dispose();
    _othersEyeProblemsOSController.dispose();
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
      final localMembers = await DataCacheService().fetchMembersLocally(familyCode);
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
          .collection('eye_examination')
          .where('Family_code', isEqualTo: familyCode)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 8));
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
      _registrationNumber.text = baseData['Registration_Number']?.toString() ?? '';
      selectedGender = baseData['Gender']?.toString();
      _ageController.text = baseData['Age']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        final snapshot = await FirebaseFirestore.instance
            .collection('eye_examination')
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
        debugPrint('Error fetching eye exam record: $e');
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
    _locationVillage  = (d['Village']  ?? d['village'])?.toString();
    _locationMandal   = (d['Mandal']   ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState    = (d['State']    ?? d['state'])?.toString();
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    _ageController.text = d['Age']?.toString() ?? '';
    
    final rawDate = d['Examination_Date'] ?? d['Date'];
    if (rawDate != null) {
      if (rawDate is Timestamp) {
        examinationDate = rawDate.toDate();
      } else {
        try {
          examinationDate = DateFormat('dd-MMM-yyyy').parse(rawDate.toString());
        } catch (_) {
          try {
            examinationDate = DateTime.parse(rawDate.toString());
          } catch (_) {}
        }
      }
    }
    
    selectedInterviewer = matchInterviewerName(d['Interviewer_s_Name'] ?? d['Interviewer_Name'] ?? d['INTNAME'], interviewers);
    selectedFailedDistanceOD = d['Failed_OD_Reflectancy_Vision_Distance'];
    selectedFailedPinholeOD = d['Failed_OD_Reflectancy_Vision_Pinhole'];
    selectedSymptomsOD = d['Signs_and_symptoms_OD'];
    _othersSymptomsODController.text = d['Any_Others_symptoms_OD'] ?? '';
    selectedEyeProblemsOD = d['Eye_Problems_suspected_OD'];
    _othersEyeProblemsODController.text = d['Any_Others_eye_problems_OD'] ?? '';
    
    selectedFailedDistanceOS = d['Failed_OS_Reflectancy_Vision_Distance'];
    selectedFailedPinholeOS = d['Failed_OS_Reflectancy_Vision_Pinhole'];
    selectedSymptomsOS = d['Signs_and_symptoms_OS'];
    _othersSymptomsOSController.text = d['Any_Others_symptoms_OS'] ?? '';
    selectedEyeProblemsOS = d['Eye_Problems_suspected_OS'];
    _othersEyeProblemsOSController.text = d['Any_Others_eye_problems_OS'] ?? '';

    if (!_isEditMode && selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _isActionActive = false;
      _registrationNumber.clear();
      // _familyCodeController.text = 'TSRRMED'; // Preserved
      _nameController.clear();
      // selectedFamilyCode = null; // Preserved
      selectedMemberName = null;
      selectedGender = null;
      _locationVillage = null;
      _locationMandal = null;
      _locationDistrict = null;
      _locationState = null;
      _ageController.clear();
      examinationDate = DateTime.now();
      selectedInterviewer = null;
      selectedFailedDistanceOD = null;
      selectedFailedPinholeOD = null;
      selectedSymptomsOD = null;
      _othersSymptomsODController.clear();
      selectedEyeProblemsOD = null;
      _othersEyeProblemsODController.clear();
      selectedFailedDistanceOS = null;
      selectedFailedPinholeOS = null;
      selectedSymptomsOS = null;
      _othersSymptomsOSController.clear();
      selectedEyeProblemsOS = null;
      _othersEyeProblemsOSController.clear();
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
        'Village': _locationVillage,
        'Mandal': _locationMandal,
        'District': _locationDistrict,
        'State': _locationState,
        'Age': int.tryParse(_ageController.text),
        'Examination_Date': examinationDate != null ? Timestamp.fromDate(examinationDate!) : null,
        'Interviewer_s_Name': selectedInterviewer,
        'Failed_OD_Reflectancy_Vision_Distance': selectedFailedDistanceOD,
        'Failed_OD_Reflectancy_Vision_Pinhole': selectedFailedPinholeOD,
        'Signs_and_symptoms_OD': selectedSymptomsOD,
        'Any_Others_symptoms_OD': _othersSymptomsODController.text,
        'Eye_Problems_suspected_OD': selectedEyeProblemsOD,
        'Any_Others_eye_problems_OD': _othersEyeProblemsODController.text,
        'Failed_OS_Reflectancy_Vision_Distance': selectedFailedDistanceOS,
        'Failed_OS_Reflectancy_Vision_Pinhole': selectedFailedPinholeOS,
        'Signs_and_symptoms_OS': selectedSymptomsOS,
        'Any_Others_symptoms_OS': _othersSymptomsOSController.text,
        'Eye_Problems_suspected_OS': selectedEyeProblemsOS,
        'Any_Others_eye_problems_OS': _othersEyeProblemsOSController.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('eye_examination', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Eye Examination updated! Syncing...' : 'Eye Examination saved! Syncing...'),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() {
        _isSaving = false;
        _isActionActive = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Eye Examination'), elevation: 0),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('eye_examination_scroll'),
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
                    title: 'Right EYE (OD)',
                    icon: Icons.remove_red_eye_outlined,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: formSearchableDropdown(
                                  context,
                                  'Distance',
                                  distanceChoices,
                                  selectedFailedDistanceOD,
                                  (v) =>
                                      setState(() => selectedFailedDistanceOD = v as String?),
                                  enabled: _isActionActive)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: formSearchableDropdown(
                                  context,
                                  'Pinhole',
                                  pinholeChoices,
                                  selectedFailedPinholeOD,
                                  (v) =>
                                      setState(() => selectedFailedPinholeOD = v as String?),
                                  enabled: _isActionActive)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: formSearchableDropdown(
                                  context,
                                  'Signs and symptoms',
                                  symptomsChoices,
                                  selectedSymptomsOD,
                                  (v) => setState(() => selectedSymptomsOD = v as String?),
                                  enabled: _isActionActive)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: formTextField('Any Others',
                                  _othersSymptomsODController, enabled: _isActionActive)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: formSearchableDropdown(
                                  context,
                                  'Eye Problems suspected',
                                  eyeProblemsChoices,
                                  selectedEyeProblemsOD,
                                  (v) =>
                                      setState(() => selectedEyeProblemsOD = v as String?),
                                  enabled: _isActionActive)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: formTextField('Any Others',
                                  _othersEyeProblemsODController, enabled: _isActionActive)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  buildSectionCard(
                    context: context,
                    title: 'Left EYE (OS)',
                    icon: Icons.remove_red_eye,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: formSearchableDropdown(
                                  context,
                                  'Distance',
                                  distanceChoices,
                                  selectedFailedDistanceOS,
                                  (v) =>
                                      setState(() => selectedFailedDistanceOS = v as String?),
                                  enabled: _isActionActive)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: formSearchableDropdown(
                                  context,
                                  'Pinhole',
                                  pinholeChoices,
                                  selectedFailedPinholeOS,
                                  (v) =>
                                      setState(() => selectedFailedPinholeOS = v as String?),
                                  enabled: _isActionActive)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: formSearchableDropdown(
                                  context,
                                  'Signs and symptoms',
                                  symptomsChoices,
                                  selectedSymptomsOS,
                                  (v) => setState(() => selectedSymptomsOS = v as String?),
                                  enabled: _isActionActive)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: formTextField('Any Others',
                                  _othersSymptomsOSController, enabled: _isActionActive)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: formSearchableDropdown(
                                  context,
                                  'Eye Problems suspected',
                                  eyeProblemsChoices,
                                  selectedEyeProblemsOS,
                                  (v) =>
                                      setState(() => selectedEyeProblemsOS = v as String?),
                                  enabled: _isActionActive)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: formTextField('Any Others',
                                  _othersEyeProblemsOSController, enabled: _isActionActive)),
                        ],
                      ),
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
      var detail = await LocalDatabaseService().getSingleFamilyDetail(familyCode.trim().toUpperCase());
      detail ??= await LocalDatabaseService().getSingleFamilyDetail(familyCode.trim());

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
          _locationVillage  = (detail!['village']  ?? detail['Village'])?.toString();
          _locationMandal   = (detail['mandal']    ?? detail['Mandal'])?.toString();
          _locationDistrict = (detail['district']  ?? detail['District'])?.toString();
          _locationState    = (detail['state']     ?? detail['State'])?.toString();
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
          SizedBox(width: 60, child: Text('$label:', style: const TextStyle(fontSize: 12, color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
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
        formTextField('Registration Number', _registrationNumber, enabled: _isActionActive),
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
        ),
        const SizedBox(height: 12),
        if (_locationVillage != null || _locationMandal != null || _locationDistrict != null)
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
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text('Location', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade700, fontSize: 12)),
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
          (<String>{...familyMemberNames, ..._existingRecords.map((r) => r['Name']?.toString() ?? '')}
              .where((n) => n.isNotEmpty)
              .toList()
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
            Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: '(1) Male', groupValue: selectedGender, onChanged: !_isActionActive ? null : (v) => setState(() => selectedGender = v as String?), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: '(0) Female', groupValue: selectedGender, onChanged: !_isActionActive ? null : (v) => setState(() => selectedGender = v as String?), contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
             Expanded(child: formTextField('Age', _ageController, enabled: _isActionActive, keyboardType: TextInputType.number, hint: 'e.g. 45')),
             const SizedBox(width: 12),
             Expanded(child: _buildDatePicker('Examination Date', examinationDate, (v) => setState(() => examinationDate = v), enabled: _isActionActive)),
          ],
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(context, 
          'Interviewer’s Name',
          ['KIRANMAI K', 'REVATHI CH', 'RAMADEVI Y', 'LAVANYA KASPOJU', 'PUSHPA K', 'G RAMADEVI', 'BHASKAR K', 'ASHA', 'KUSUMA G', 'B JYOTHI', 'RAMADEVI G', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU'],
          selectedInterviewer,
          (v) => setState(() => selectedInterviewer = v as String?),
          enabled: _isActionActive,
        ),
      ],
    );
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
              firstDate: DateTime(1900),
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
            child: Text(selectedDate == null ? 'dd-MMM-yyyy' : DateFormat('dd-MMM-yyyy').format(selectedDate)),
          ),
        ),
      ],
    );
  }
}
