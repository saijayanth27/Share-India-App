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

  // --- Identification State ---
  final _registrationNumber = TextEditingController();
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
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyCode)
          .get();

      final names = snapshot.docs.map((doc) => doc.data()['Name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();

      setState(() {
        familyMemberNames = names..sort();
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error fetching members: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  void _loadExistingData() {
    final d = widget.existingData!;
    setState(() {
      _registrationNumber.text = d['Registration_Number']?.toString() ?? '';
      selectedFamilyCode = d['Family_Code'];
      selectedMemberName = d['Name'];
      selectedGender = d['Gender'];
      _ageController.text = d['Age']?.toString() ?? '';
      if (d['Examination_Date'] != null) {
        examinationDate = (d['Examination_Date'] as Timestamp).toDate();
      }
      selectedInterviewer = d['Interviewer_s_Name'];

      // OD
      selectedFailedDistanceOD = d['Failed_Distance'];
      selectedFailedPinholeOD = d['Failed_Pinhole'];
      selectedSymptomsOD = d['Signs_and_symptoms'];
      _othersSymptomsODController.text = d['Any_Others'] ?? '';
      selectedEyeProblemsOD = d['Eye_Problems_suspected_by_Field_workers_Self_reported'];
      _othersEyeProblemsODController.text = d['Any_Others1'] ?? '';

      // OS
      selectedFailedDistanceOS = d['Failed_Distance1'];
      selectedFailedPinholeOS = d['Failed_Pinhole1'];
      selectedSymptomsOS = d['Signs_and_symptoms2'];
      _othersSymptomsOSController.text = d['Any_Others2'] ?? '';
      selectedEyeProblemsOS = d['Eye_Problems_suspected_by_Field_workers_Self_reported1'];
      _othersEyeProblemsOSController.text = d['Any_Others3'] ?? '';
    });
    if (selectedFamilyCode != null) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _registrationNumber.clear();
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
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number': _registrationNumber.text,
        'Family_Code': selectedFamilyCode,
        'Name': selectedMemberName,
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

      if (widget.docId != null) {
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
                      child: Text(widget.docId == null ? 'Save Examination' : 'Update Examination', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            _buildDropdown('Family Code', allFamilyCodes, selectedFamilyCode, (v) {
              setState(() { selectedFamilyCode = v; selectedMemberName = null; familyMemberNames = []; });
              if (v != null) _fetchMembersByFamily(v);
            }),
            const SizedBox(height: 12),
            _buildDropdown('Name', familyMemberNames, selectedMemberName, (v) => setState(() => selectedMemberName = v), isLoading: _isLoadingMembers),
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

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, String? hint, String? helper, int maxLines = 1}) {
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
