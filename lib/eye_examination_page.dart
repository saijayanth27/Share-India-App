import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';

class EyeExaminationPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const EyeExaminationPage({super.key, this.existingData, this.docId});

  @override
  State<EyeExaminationPage> createState() => _EyeExaminationPageState();
}

class _EyeExaminationPageState extends State<EyeExaminationPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoading = false;

  // --- Identification State ---
  final _nameController = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _familyCodeController = TextEditingController();
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
  List<String> allFamilyCodes = [];
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  bool _isLoadingMembers = false;

  final List<String> interviewers = ["KIRANMAI K", "LAVANYA KASPOJU", "RAMADEVI Y", "REVATHI CH"];
  final List<String> distanceChoices = ["6/12", "6/18", "6/60", "below 6/60"];
  final List<String> pinholeChoices = ["6/9", "6/12", "6/60", "equal or below 6/18"];
  final List<String> symptomsChoices = ["No Symptoms", "Headache", "Glare", "Double Vision", "Watering", "Redness", "Itching", "Burning", "Irritation", "Discharge", "Others"];
  final List<String> eyeProblemsChoices = ["No Problem", "Blurred/decreased Vision", "Refractive Error", "Presbyopia", "Cataract", "Pterygium", "Corneal Problem", "Squint", "Injury", "Bitot Spots", "Night Blindness", "Eyelid Problem", "Red Eye", "Others"];

  @override
  void initState() {
    super.initState();
    _fetchFamilyCodes();
    if (widget.existingData != null) {
      _loadExistingData();
    } else {
      examinationDate = DateTime.now();
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
          .collection('eye_examination')
          .where('Family_Code', isEqualTo: familyCode)
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
          _registrationNumber.text = data['Registration_Number']?.toString() ?? '';
          selectedGender = data['Gender']?.toString();
          _ageController.text = data['Age']?.toString() ?? '';
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
    _registrationNumber.text = d['Registration_Number']?.toString() ?? '';
    selectedFamilyCode = d['Family_Code'] ?? d['Family_code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    _ageController.text = d['Age']?.toString() ?? '';
    
    if (d['Examination_Date'] != null) {
      if (d['Examination_Date'] is Timestamp) {
        examinationDate = (d['Examination_Date'] as Timestamp).toDate();
      } else {
        try {
          examinationDate = DateFormat('dd-MMM-yyyy').parse(d['Examination_Date'].toString());
        } catch (_) {}
      }
    }
    
    selectedInterviewer = d['Interviewer_s_Name_ID'];
    
    selectedFailedDistanceOD = d['Did_you_fail_the_distance_visual_acuity_test_Right_Eye_OD'];
    selectedFailedPinholeOD = d['Did_you_fail_the_Pinhole_test_Right_Eye_OD'];
    selectedSymptomsOD = d['Symptoms_observed_during_the_Right_Eye_OD_Examination'];
    _othersSymptomsODController.text = d['Other_Symptoms_encountered_Right_Eye_OD'] ?? '';
    selectedEyeProblemsOD = d['Current_Eye_Problems_Right_Eye_OD'];
    _othersEyeProblemsODController.text = d['Other_Eye_Problems_encountered_Right_Eye_OD'] ?? '';

    selectedFailedDistanceOS = d['Did_you_fail_the_distance_visual_acuity_test_Left_Eye_OS'];
    selectedFailedPinholeOS = d['Did_you_fail_the_Pinhole_test_Left_Eye_OS'];
    selectedSymptomsOS = d['Symptoms_observed_during_the_Left_Eye_OS_Examination'];
    _othersSymptomsOSController.text = d['Other_Symptoms_encountered_Left_Eye_OS'] ?? '';
    selectedEyeProblemsOS = d['Current_Eye_Problems_Left_Eye_OS'];
    _othersEyeProblemsOSController.text = d['Other_Eye_Problems_encountered_Left_Eye_OS'] ?? '';

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _registrationNumber.clear();
      _nameController.clear();
      selectedFamilyCode = null;
      selectedMemberName = null;
      selectedGender = null;
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
      _editDocId = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number': _registrationNumber.text,
        'Family_Code': selectedFamilyCode,
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Age': int.tryParse(_ageController.text),
        'Examination_Date': examinationDate != null ? Timestamp.fromDate(examinationDate!) : null,
        'Interviewer_s_Name': selectedInterviewer,

        // OD
        'Failed_Distance': selectedFailedDistanceOD,
        'Failed_Pinhole': selectedFailedPinholeOD,
        'Signs_and_symptoms': selectedSymptomsOD,
        'Any_Others': _othersSymptomsODController.text,
        'Eye_Problems_suspected_by_Field_workers_Self_reported': selectedEyeProblemsOD,
        'Any_Others1': _othersEyeProblemsODController.text,

        // OS
        'Failed_Distance1': selectedFailedDistanceOS,
        'Failed_Pinhole1': selectedFailedPinholeOS,
        'Signs_and_symptoms2': selectedSymptomsOS,
        'Any_Others2': _othersSymptomsOSController.text,
        'Eye_Problems_suspected_by_Field_workers_Self_reported1': selectedEyeProblemsOS,
        'Any_Others3': _othersEyeProblemsOSController.text,

        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('eye_examination').doc(_editDocId).update(data);
      } else if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('eye_examination').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('eye_examination').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eye examination record saved successfully!'), backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Eye Examination Form'),
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
                _buildIdentitySection(),
                  _buildSectionCard(
                    title: 'Right EYE (OD)',
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDropdown('Failed Distance', distanceChoices, selectedFailedDistanceOD, (v) => setState(() => selectedFailedDistanceOD = v))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDropdown('Failed Pinhole', pinholeChoices, selectedFailedPinholeOD, (v) => setState(() => selectedFailedPinholeOD = v))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildDropdown('Signs and symptoms', symptomsChoices, selectedSymptomsOD, (v) => setState(() => selectedSymptomsOD = v))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Any Others', _othersSymptomsODController)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildDropdown('Eye Problems suspected', eyeProblemsChoices, selectedEyeProblemsOD, (v) => setState(() => selectedEyeProblemsOD = v))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Any Others', _othersEyeProblemsODController)),
                        ],
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Left EYE (OS)',
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDropdown('Failed Distance', distanceChoices, selectedFailedDistanceOS, (v) => setState(() => selectedFailedDistanceOS = v))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDropdown('Failed Pinhole', pinholeChoices, selectedFailedPinholeOS, (v) => setState(() => selectedFailedPinholeOS = v))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildDropdown('Signs and symptoms', symptomsChoices, selectedSymptomsOS, (v) => setState(() => selectedSymptomsOS = v))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Any Others', _othersSymptomsOSController)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildDropdown('Eye Problems suspected', eyeProblemsChoices, selectedEyeProblemsOS, (v) => setState(() => selectedEyeProblemsOS = v))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Any Others', _othersEyeProblemsOSController)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_isEditMode ? 'Update Examination' : 'Save Examination', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildIdentitySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Patient Identity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const Divider(),
            _buildTextField('Registration Number', _registrationNumber),
            const SizedBox(height: 12),

            _buildTextField('Family Code', _familyCodeController, onChanged: (v) {
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
            }),
            const SizedBox(height: 12),
            _isEditMode
                ? _buildDropdown('Select Name to Edit', _existingRecords.map((r) => r['Name']?.toString() ?? 'Unknown').toList(), selectedMemberName, _onNameSelected, isLoading: _isLoadingMembers)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField('Name', _nameController),
                      if (familyMemberNames.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildDropdown('Pick from Family Members', familyMemberNames, null, _onNameSelected, isLoading: _isLoadingMembers),
                      ],
                    ],
                  ),
            const SizedBox(height: 12),
            const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
            Row(
              children: [
                Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: '(1) Male', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
                Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: '(0) Female', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), contentPadding: EdgeInsets.zero, dense: true)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTextField('Age', _ageController, keyboardType: TextInputType.number, hint: 'e.g. 45')),
                const SizedBox(width: 12),
                Expanded(child: _buildDatePicker('Examination Date', examinationDate, (v) => setState(() => examinationDate = v))),
              ],
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              'Interviewer’s Name',
              ['KIRANMAI K', 'REVATHI CH', 'RAMADEVI Y', 'LAVANYA KASPOJU', 'PUSHPA K', 'G RAMADEVI', 'BHASKAR K', 'ASHA', 'KUSUMA G', 'B JYOTHI', 'RAMADEVI G', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU'],
              selectedInterviewer,
              (v) => setState(() => selectedInterviewer = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, String? hint, String? helper, int maxLines = 1, Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            hintText: hint,
            helperText: helper,
          ),
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? selectedValue, Function(String?) onChanged, {bool isLoading = false, String? hint = '-Select-'}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: selectedValue,
          isExpanded: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: isLoading ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
          ),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
          hint: hint != null ? Text(hint) : null,
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
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
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(selectedDate == null ? 'dd-MMM-yyyy' : DateFormat('dd-MMM-yyyy').format(selectedDate)),
          ),
        ),
      ],
    );
  }
}
