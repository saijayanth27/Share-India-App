import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isLoading = false;

  // --- Controllers & State ---
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _familyCodeController = TextEditingController();
  final _otherRecommendedController = TextEditingController();
  final _otherPerformedController = TextEditingController();
  final _commentsController = TextEditingController();
  final _detailsController = TextEditingController();

  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectedGender;
  DateTime? interviewDate;
  String? selectedVisitNumber;
  String? selectedAdequacy;
  String? selectedSCJ;
  String? selectedImpression;
  String? selectedBiopsiesCount;
  String? selectedImagesCount;

  List<String> procedureRecommended = [];
  List<String> procedurePerformed = [];

  // Dropdowns
  List<String> allFamilyCodes = [];
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  bool _isLoadingMembers = false;

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
    _fetchFamilyCodes();
    if (widget.existingData != null) {
      _loadExistingData();
    } else {
      interviewDate = DateTime.now();
    }
  }

  Future<void> _fetchFamilyCodes() async {
    final codes = await DataCacheService().fetchFamilyCodes();
    setState(() {
      allFamilyCodes = codes;
    });
  }

  Future<void> _fetchMembersByFamily(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      // 1. Fetch from Firestore (Cache favored)
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyCode)
          .get(const GetOptions(source: Source.serverAndCache));

      // 2. Fetch from Local SQLite for offline support
      final localMembers = await DataCacheService().fetchMembersLocally(familyCode);

      // 3. Merge logic
      final Map<String, Map<String, dynamic>> memberMap = {};
      final Set<String> allNames = {};
      
      void processMember(Map<String, dynamic> data) {
        final name = data['Name']?.toString() ?? '';
        if (name.isEmpty) return;
        memberMap[name] = data;
        allNames.add(name);
      }

      for (var doc in snapshot.docs) {
        processMember(doc.data());
      }
      for (var local in localMembers) {
        processMember(local);
      }

      setState(() {
        _allMembersData = memberMap;
        familyMemberNames = allNames.toList()..sort();
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error fetching members: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _fetchExistingRecords(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('colposcopy')
          .where('Family_Code_Creation', isEqualTo: familyCode)
          .get();
      
      setState(() {
        _existingRecords = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error fetching existing records: $e');
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
          _regNoController.text = data['Registration_Number']?.toString() ?? '';
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
    _regNoController.text = d['Registration_Number'] ?? '';
    selectedFamilyCode = d['Family_Code_Creation'] ?? d['Family_code'] ?? d['Family_Code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    
    if (d['Interview_Date'] != null) {
      if (d['Interview_Date'] is Timestamp) {
        interviewDate = (d['Interview_Date'] as Timestamp).toDate();
      } else {
        try {
          interviewDate = DateFormat('dd-MMM-yyyy').parse(d['Interview_Date'].toString());
        } catch (_) {}
      }
    }
    
    selectedVisitNumber = d['Visit_Number'];
    selectedAdequacy = d['Colposcopy_adequacy1'];
    selectedSCJ = d['Level_of_new_squamo_columnar_junction_SCJ1'];
    selectedImpression = d['Colposcopic_impression'];
    
    if (d['Procedure_recommended'] != null) {
      procedureRecommended = List<String>.from(d['Procedure_recommended']);
    }
    if (d['Procedure_performed1'] != null) {
      procedurePerformed = List<String>.from(d['Procedure_performed1']);
    }
    
    _otherRecommendedController.text = d['If_Others_Please_Mention'] ?? '';
    _otherPerformedController.text = d['If_Others_Please_Mention1'] ?? '';
    _commentsController.text = d['a_Comments'] ?? '';
    _detailsController.text = d['Procedure_details_findings_and_comments'] ?? '';

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _regNoController.clear();
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
      _existingRecords = [];
      _editDocId = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number': _regNoController.text,
        'Family_Code_Creation': selectedFamilyCode,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Interview_Date': interviewDate != null ? Timestamp.fromDate(interviewDate!) : null,
        'Visit_Number': selectedVisitNumber,
        'Colposcopy_adequacy1': selectedAdequacy,
        'Level_of_new_squamo_columnar_junction_SCJ1': selectedSCJ,
        'Colposcopic_impression': selectedImpression,
        'Procedure_recommended': procedureRecommended,
        'If_Others_Please_Mention': _otherRecommendedController.text,
        'Procedure_performed1': procedurePerformed,
        'If_Others_Please_Mention1': _otherPerformedController.text,
        'Number_of_cervical_biopsies_taken': selectedBiopsiesCount,
        'How_many_colposcopy_images_were_taken1': selectedImagesCount,
        'a_Comments': _commentsController.text,
        'Procedure_details_findings_and_comments': _detailsController.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('colposcopy').doc(_editDocId).update(data);
      } else if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('colposcopy').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('colposcopy').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Colposcopy record saved successfully!'), backgroundColor: Colors.green),
        );
        if (widget.docId != null) {
          Navigator.pop(context);
        } else {
          _resetForm();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return buildSectionCard(
      context: context,
      title: title,
      children: children,
      icon: icon,
    );
  }

  Widget _buildRadioGroup(String title, List<String> options, String? groupValue, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: options.map((opt) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Radio<String>(value: opt, groupValue: groupValue, onChanged: onChanged),
              Text(opt),
            ],
          )).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildVerticalRadioGroup(String title, List<String> options, String? groupValue, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ...options.map((opt) => RadioListTile<String>(
          title: Text(opt),
          value: opt,
          groupValue: groupValue,
          onChanged: onChanged,
          contentPadding: EdgeInsets.zero,
          dense: true,
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Colposcopy', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade700, Colors.deepPurple.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  buildHeader(
                    context: context,
                    title: 'Colposcopy Examination',
                    subtitle: 'Cervical visualization and assessment',
                  ),
                  _buildSectionCard(
                    title: 'Identification',
                    icon: Icons.person_outline,
                    children: [
                      TextFormField(controller: _regNoController, decoration: const InputDecoration(labelText: 'Registration Number', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _familyCodeController,
                              decoration: const InputDecoration(labelText: 'Family code', border: OutlineInputBorder()),
                              onChanged: (v) {
                                setState(() {
                                  selectedFamilyCode = v;
                                  selectedMemberName = null;
                                  familyMemberNames = [];
                                });
                                if (v != null && v.isNotEmpty) {
                                  if (_isEditMode) {
                                    _fetchExistingRecords(v);
                                  } else {
                                    _fetchMembersByFamily(v);
                                  }
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _isEditMode
                                ? DropdownButtonFormField<String>(
                                    decoration: InputDecoration(
                                      labelText: 'Select Name to Edit',
                                      border: const OutlineInputBorder(),
                                      suffixIcon: _isLoadingMembers ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                                    ),
                                    value: selectedMemberName,
                                    items: _existingRecords.map((r) => DropdownMenuItem(value: r['Name']?.toString() ?? 'Unknown', child: Text(r['Name']?.toString() ?? 'Unknown'))).toList(),
                                    onChanged: _onNameSelected,
                                  )
                                : DropdownButtonFormField<String>(
                                    decoration: InputDecoration(
                                      labelText: 'Name',
                                      border: const OutlineInputBorder(),
                                      suffixIcon: _isLoadingMembers ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                                    ),
                                    value: selectedMemberName,
                                    items: familyMemberNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                                    onChanged: _onNameSelected,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRadioGroup('Gender', ['(1) Male', '(0) Female'], selectedGender, (v) => setState(() => selectedGender = v)),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(context: context, initialDate: interviewDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                                if (picked != null) setState(() => interviewDate = picked);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Interview Date', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                                child: Text(interviewDate == null ? 'Select Date' : DateFormat('dd-MMM-yyyy').format(interviewDate!)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'Visit Number', border: OutlineInputBorder()),
                              value: selectedVisitNumber,
                              items: visitChoices.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (v) => setState(() => selectedVisitNumber = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Assessment',
                    icon: Icons.assignment_outlined,
                    children: [
                      _buildRadioGroup('5 Colposcopy adequacy?', ['Satisfactory', 'Unsatisfactory'], selectedAdequacy, (v) => setState(() => selectedAdequacy = v)),
                      _buildVerticalRadioGroup('6 Level of new squamo-columnar junction (SCJ)', scjChoices, selectedSCJ, (v) => setState(() => selectedSCJ = v)),
                      _buildVerticalRadioGroup('7 Colposcopic impression?', impressionChoices, selectedImpression, (v) => setState(() => selectedImpression = v)),
                    ],
                  ),
                  _buildSectionCard(
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
                      const SizedBox(height: 16),
                      TextFormField(controller: _otherRecommendedController, decoration: const InputDecoration(labelText: 'If Others Please Mention', border: OutlineInputBorder())),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Procedure Performed',
                    icon: Icons.medical_services_outlined,
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
                      const SizedBox(height: 16),
                      TextFormField(controller: _otherPerformedController, decoration: const InputDecoration(labelText: 'If Others Please Mention', border: OutlineInputBorder())),
                      const SizedBox(height: 24),
                      _buildRadioGroup('10 Number of cervical biopsies taken', ['1', '2', '3', '4'], selectedBiopsiesCount, (v) => setState(() => selectedBiopsiesCount = v)),
                      _buildRadioGroup('12. How many colposcopy images were taken?', ['0', '1', '2'], selectedImagesCount, (v) => setState(() => selectedImagesCount = v)),
                      const SizedBox(height: 16),
                      TextFormField(controller: _commentsController, maxLines: 3, decoration: const InputDecoration(labelText: '12a. Comments', border: OutlineInputBorder())),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Findings',
                    icon: Icons.description_outlined,
                    children: [
                      TextFormField(controller: _detailsController, maxLines: 5, decoration: const InputDecoration(labelText: '13. Procedure details, findings and comments:', border: OutlineInputBorder())),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_isEditMode ? 'Update Colposcopy' : 'Save Colposcopy', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _resetForm,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Reset Form', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
