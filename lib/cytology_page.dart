import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';

class CytologyPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const CytologyPage({super.key, this.existingData, this.docId});

  @override
  State<CytologyPage> createState() => _CytologyPageState();
}

class _CytologyPageState extends State<CytologyPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoading = false;

  // --- Main Form Controllers ---
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _familyCodeController = TextEditingController();
  final _otherAdequacyReasonController = TextEditingController();
  final _otherNeoplasticController = TextEditingController();
  final _otherNonNeoplasticController = TextEditingController();
  final _commentController = TextEditingController();

  // --- State Variables ---
  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectedGender;
  DateTime? dateReceived;
  DateTime? dateRead;
  String? selectedAdequacy;
  List<String> selectedAdequacyReasons = [];
  List<String> selectedInfections = [];
  String? selectedEpithelialDiagnosis;
  List<String> selectedSquamousCells = [];
  List<String> selectedGlandularCells = [];

  // --- Options ---
  List<String> allFamilyCodes = [];
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  bool _isLoadingMembers = false;

  final List<String> adequacyChoices = [
    "(1) Satisfactory",
    "(2)Satisfactory, but limited by",
    "(3)Unsatisfactory for evaluation"
  ];
  final List<String> adequacyReasonChoices = [
    "1) Transformation zone component absent",
    "(2) Scant squamous epithelial component",
    "(3) Partially/totally obscuring inflammation",
    "(4) Obscuring blood",
    "(5) Air-drying artifact",
    "(6) Other"
  ];
  final List<String> infectionChoices = [
    "9a HSV",
    "9b Trichomonas",
    "09c Candida",
    "09d Coccobacilli shift in vaginal flora",
    "09e Other"
  ];
  final List<String> epithelialDiagnosisChoices = [
    "(1) Negative",
    "(2) Reactive cellular changes"
  ];
  final List<String> squamousCellChoices = [
    "(1) ASCUS, NOS",
    "(2) ASCUS, favor reactive",
    "(3) | ASCUS, rule out LSIL",
    "(4) ASCUS, metaplastic",
    "(5) LSIL, NOS",
    "(6) LSIL, cellular changes of HPV",
    "(7) LSIL, CIN 1"
  ];
  final List<String> glandularCellChoices = [
    "(1) Benign endometrial cells in a peri/postmenopausal woman",
    "(2) AGUS, NOS",
    "(3) Atypical endometrial cells, NOS",
    "(4) Atypical endocervical cells, favor reactive",
    "(5) Atypical endocervical cells, favor neoplasia",
    "(6) Adenocarcinoma in situ (AIS)",
    "(7) Adenocarcinoma, NOS",
    "(8) Endocervical adenocarcinoma",
    "(9) Endometrial adenocarcinoma"
  ];

  @override
  void initState() {
    super.initState();
    _fetchFamilyCodes();
    if (widget.existingData != null) {
      _loadExistingData();
    } else {
      dateReceived = DateTime.now();
      dateRead = DateTime.now();
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
          .collection('cytology')
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
    selectedFamilyCode = d['Family_Code_Creation'] ?? d['Family_Code'] ?? d['Family_code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    
    if (d['Date_received'] != null) {
      if (d['Date_received'] is Timestamp) {
        dateReceived = (d['Date_received'] as Timestamp).toDate();
      } else {
        try {
          dateReceived = DateFormat('dd-MMM-yyyy').parse(d['Date_received'].toString());
        } catch (_) {}
      }
    }
    if (d['Date_read'] != null) {
      if (d['Date_read'] is Timestamp) {
        dateRead = (d['Date_read'] as Timestamp).toDate();
      } else {
        try {
          dateRead = DateFormat('dd-MMM-yyyy').parse(d['Date_read'].toString());
        } catch (_) {}
      }
    }
    
    selectedAdequacy = d['Specimen_adequacy'];
    if (d['a_Specify_reason'] != null) selectedAdequacyReasons = List<String>.from(d['a_Specify_reason']);
    _otherAdequacyReasonController.text = d['If_any_other_please_mention'] ?? '';
    
    if (d['Infection'] != null) selectedInfections = List<String>.from(d['Infection']);
    selectedEpithelialDiagnosis = d['Epithelial_cell_diagnosis'];
    
    if (d['Squamous_cell'] != null) selectedSquamousCells = List<String>.from(d['Squamous_cell']);
    if (d['Glandular_cell'] != null) selectedGlandularCells = List<String>.from(d['Glandular_cell']);
    
    _otherNonNeoplasticController.text = d['Other_Non_Neoplastic_Findings'] ?? '';
    _otherNeoplasticController.text = d['Specify_Others'] ?? '';
    _commentController.text = d['Other_comments'] ?? '';

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }
  void _resetForm() {
    // _formKey.currentState?.reset(); // This line is commented out as _formKey is not defined in the provided context.
    setState(() {
      _regNoController.clear();
      _nameController.clear();
      selectedFamilyCode = null;
      selectedMemberName = null;
      selectedGender = null;
      dateReceived = DateTime.now();
      dateRead = DateTime.now();
      selectedAdequacy = null;
      selectedAdequacyReasons = [];
      _otherAdequacyReasonController.clear();
      selectedInfections = [];
      selectedEpithelialDiagnosis = null;
      selectedSquamousCells = [];
      selectedGlandularCells = [];
      _otherNeoplasticController.clear();
      _otherNonNeoplasticController.clear();
      _commentController.clear();
      familyMemberNames = [];
      _existingRecords = [];
      _editDocId = null;
    });
  }

  Future<void> _save() async {
    // if (!_formKey.currentState!.validate()) return; // This line is commented out as _formKey is not defined in the provided context.
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final data = {
        'Registration_Number': _regNoController.text,
        'Family_Code_Creation': selectedFamilyCode,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Date_received': dateReceived != null ? Timestamp.fromDate(dateReceived!) : null,
        'Date_read': dateRead != null ? Timestamp.fromDate(dateRead!) : null,
        'Specimen_adequacy': selectedAdequacy,
        'a_Specify_reason': selectedAdequacyReasons,
        'If_any_other_please_mention': _otherAdequacyReasonController.text,
        'Infection': selectedInfections,
        'Epithelial_cell_diagnosis': selectedEpithelialDiagnosis,
        'a_Squamous_cells': selectedSquamousCells,
        'Glandular_Cells': selectedGlandularCells,
        'Other_neoplastic': _otherNeoplasticController.text,
        'Other_non_neoplastic': _otherNonNeoplasticController.text,
        'Comment': _commentController.text,
        'clientUpdatedAt': now.millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('cytology').doc(_editDocId).update(data);
      } else if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('cytology').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('cytology').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cytology record saved successfully!'), backgroundColor: Colors.green),
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

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRadioGroup(String title, List<String> options, String? groupValue, Function(String?) onChanged) {
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

  Widget _buildCheckboxGroup(String title, List<String> options, List<String> selectedValues, Function(String, bool) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ...options.map((opt) => CheckboxListTile(
          title: Text(opt),
          value: selectedValues.contains(opt),
          onChanged: (val) => onChanged(opt, val ?? false),
          controlAffinity: ListTileControlAffinity.leading,
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
        title: const Text('Cytology Form'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      drawer: const AppDrawer(),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [

                  _buildSectionCard(
                    title: 'Identification',
                    children: [
                      TextFormField(
                        controller: _regNoController,
                        decoration: const InputDecoration(labelText: 'Registration Number', border: OutlineInputBorder()),
                      ),
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
                                if (v.isNotEmpty) {
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
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextFormField(
                                        controller: _nameController,
                                        decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), hintText: 'Type name or pick from dropdown'),
                                      ),
                                      if (familyMemberNames.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelText: 'Pick from Family Members',
                                            border: const OutlineInputBorder(),
                                            suffixIcon: _isLoadingMembers ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                                          ),
                                          value: null,
                                          items: familyMemberNames.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                                          onChanged: _onNameSelected,
                                          hint: const Text('--Select Member--'),
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600)),
                          Row(
                            children: [
                              Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: '(1) Male', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
                              Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: '(0) Female', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(context: context, initialDate: dateReceived ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                                if (picked != null) setState(() => dateReceived = picked);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Date received', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                                child: Text(dateReceived == null ? 'Select Date' : DateFormat('dd-MMM-yyyy').format(dateReceived!)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(context: context, initialDate: dateRead ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                                if (picked != null) setState(() => dateRead = picked);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Date read', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                                child: Text(dateRead == null ? 'Select Date' : DateFormat('dd-MMM-yyyy').format(dateRead!)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Specimen Assessment',
                    children: [
                      _buildRadioGroup('8. Specimen adequacy', adequacyChoices, selectedAdequacy, (v) => setState(() => selectedAdequacy = v)),
                      _buildCheckboxGroup('8a. Specify reason', adequacyReasonChoices, selectedAdequacyReasons, (opt, val) {
                        setState(() => val ? selectedAdequacyReasons.add(opt) : selectedAdequacyReasons.remove(opt));
                      }),
                      TextFormField(
                        controller: _otherAdequacyReasonController,
                        decoration: const InputDecoration(labelText: 'If any other please mention', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Diagnosis & Findings',
                    children: [
                      _buildCheckboxGroup('9. Infection', infectionChoices, selectedInfections, (opt, val) {
                        setState(() => val ? selectedInfections.add(opt) : selectedInfections.remove(opt));
                      }),
                      _buildRadioGroup('10 Epithelial cell diagnosis', epithelialDiagnosisChoices, selectedEpithelialDiagnosis, (v) => setState(() => selectedEpithelialDiagnosis = v)),
                      _buildCheckboxGroup('11a. Squamous cells', squamousCellChoices, selectedSquamousCells, (opt, val) {
                        setState(() => val ? selectedSquamousCells.add(opt) : selectedSquamousCells.remove(opt));
                      }),
                      _buildCheckboxGroup('11b. Glandular Cells', glandularCellChoices, selectedGlandularCells, (opt, val) {
                        setState(() => val ? selectedGlandularCells.add(opt) : selectedGlandularCells.remove(opt));
                      }),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Other Results',
                    children: [
                      TextFormField(
                        controller: _otherNeoplasticController,
                        decoration: const InputDecoration(labelText: '(10) Other neoplastic', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _otherNonNeoplasticController,
                        decoration: const InputDecoration(labelText: '(11) Other non-neoplastic', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _commentController,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: '12 Comment', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: Text(_isEditMode ? 'Update Cytology' : 'Save Cytology', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _resetForm,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
