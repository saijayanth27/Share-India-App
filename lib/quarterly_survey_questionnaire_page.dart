import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';

class QuarterlySurveyPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const QuarterlySurveyPage({super.key, this.existingData, this.docId});

  @override
  State<QuarterlySurveyPage> createState() => _QuarterlySurveyPageState();
}

class _QuarterlySurveyPageState extends State<QuarterlySurveyPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final TextEditingController _regNoController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _interviewDateController = TextEditingController();
  final TextEditingController _visitOthersController = TextEditingController();
  final TextEditingController _dmMedSourceOthersController = TextEditingController();
  final TextEditingController _dmMedNamesController = TextEditingController();
  final TextEditingController _htnMedSourceOthersController = TextEditingController();
  final TextEditingController _htnMedNamesController = TextEditingController();

  // Selections
  String? _selectedFamilyId;
  String? _selectedName;
  String? _selectedGender;
  String? _selectedInterviewer;
  
  // Section 1: Health Facility
  String? _visitedFacility;
  final Map<String, bool> _visitReasons = {
    'Heart problem': false,
    'Kidney related': false,
    'Paralysis': false,
    'others': false,
  };

  // Section 2: Diabetes
  String? _takingDmMed;
  String? _dmMedSource;
  String? _dmForget;
  String? _dmNeglected;
  String? _dmStoppedBetter;
  String? _dmStoppedWorse;

  // Section 3: Hypertension
  String? _takingHtnMed;
  String? _htnMedSource;
  String? _htnForget;
  String? _htnNeglected;
  String? _htnStoppedBetter;
  String? _htnStoppedWorse;

  // Data for lookups
  List<Map<String, dynamic>> _familyMembers = [];
  List<String> _familyIds = [];
  List<String> _namesForSelectedFamily = [];

  final List<String> _interviewerList = ['Interviewer 1', 'Interviewer 2', 'Staff A', 'Staff B'];
  final List<String> _medSourceList = ['Govt. hospital', 'Private hospital', 'Medical shop', 'NGO', 'Weekly clinic', 'Others'];

  @override
  void initState() {
    super.initState();
    _fetchFamilyData();
    if (widget.existingData != null) {
      _loadExistingData();
    } else {
      _interviewDateController.text = DateFormat('dd-MMM-yyyy').format(DateTime.now());
    }
  }

  void _loadExistingData() {
    final data = widget.existingData!;
    _regNoController.text = data['Registration_Number']?.toString() ?? '';
    _selectedFamilyId = data['Family_Code'];
    _selectedName = data['Name'];
    _selectedGender = data['Gender'];
    _ageController.text = data['Age']?.toString() ?? '';
    _interviewDateController.text = data['Date_of_Interview'] ?? '';
    _selectedInterviewer = data['Interviewer_Name'];

    _visitedFacility = data['Visited_Facility'];
    if (data['Visit_Reasons'] is List) {
      for (var reason in data['Visit_Reasons']) {
        if (_visitReasons.containsKey(reason)) _visitReasons[reason] = true;
      }
    }
    _visitOthersController.text = data['Visit_Reasons_Others'] ?? '';

    _takingDmMed = data['Taking_DM_Med'];
    _dmMedSource = data['DM_Med_Source'];
    _dmMedSourceOthersController.text = data['DM_Med_Source_Others'] ?? '';
    _dmMedNamesController.text = data['DM_Med_Names'] ?? '';
    _dmForget = data['DM_Forget'];
    _dmNeglected = data['DM_Neglected'];
    _dmStoppedBetter = data['DM_Stopped_Better'];
    _dmStoppedWorse = data['DM_Stopped_Worse'];

    _takingHtnMed = data['Taking_HTN_Med'];
    _htnMedSource = data['HTN_Med_Source'];
    _htnMedSourceOthersController.text = data['HTN_Med_Source_Others'] ?? '';
    _htnMedNamesController.text = data['HTN_Med_Names'] ?? '';
    _htnForget = data['HTN_Forget'];
    _htnNeglected = data['HTN_Neglected'];
    _htnStoppedBetter = data['HTN_Stopped_Better'];
    _htnStoppedWorse = data['HTN_Stopped_Worse'];
  }

  Future<void> _fetchFamilyData() async {
    final members = await DataCacheService().fetchFamilyDetails();
    setState(() {
      _familyMembers = members;
      _familyIds = members.map((m) => m['Family_ID']?.toString() ?? '').toSet().toList();
      _familyIds.removeWhere((id) => id.isEmpty);
      if (_selectedFamilyId != null) _updateNamesForFamily(_selectedFamilyId!);
    });
  }

  void _updateNamesForFamily(String familyId) {
    setState(() {
      _namesForSelectedFamily = _familyMembers
          .where((m) => m['Family_ID'] == familyId)
          .map((m) => m['Name']?.toString() ?? '')
          .toList();
    });
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final List<String> selectedVisitReasons = [];
    _visitReasons.forEach((key, value) {
      if (value) selectedVisitReasons.add(key);
    });

    final formData = {
      'Registration_Number': _regNoController.text,
      'Family_Code': _selectedFamilyId,
      'Name': _selectedName,
      'Gender': _selectedGender,
      'Age': _ageController.text,
      'Date_of_Interview': _interviewDateController.text,
      'Interviewer_Name': _selectedInterviewer,

      'Visited_Facility': _visitedFacility,
      'Visit_Reasons': selectedVisitReasons,
      'Visit_Reasons_Others': _visitOthersController.text,

      'Taking_DM_Med': _takingDmMed,
      'DM_Med_Source': _dmMedSource,
      'DM_Med_Source_Others': _dmMedSourceOthersController.text,
      'DM_Med_Names': _dmMedNamesController.text,
      'DM_Forget': _dmForget,
      'DM_Neglected': _dmNeglected,
      'DM_Stopped_Better': _dmStoppedBetter,
      'DM_Stopped_Worse': _dmStoppedWorse,

      'Taking_HTN_Med': _takingHtnMed,
      'HTN_Med_Source': _htnMedSource,
      'HTN_Med_Source_Others': _htnMedSourceOthersController.text,
      'HTN_Med_Names': _htnMedNamesController.text,
      'HTN_Forget': _htnForget,
      'HTN_Neglected': _htnNeglected,
      'HTN_Stopped_Better': _htnStoppedBetter,
      'HTN_Stopped_Worse': _htnStoppedWorse,

      'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      'needs_zoho_sync': true,
    };

    try {
      if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('quarterly_survey').doc(widget.docId).update(formData);
      } else {
        await FirebaseFirestore.instance.collection('quarterly_survey').add(formData);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Survey saved successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quarterly Survey Questionnaire')),
      drawer: const AppDrawer(),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Identification'),
              _buildTextField('Registration Number', _regNoController),
              _buildDropdown('Family Code', _familyIds, _selectedFamilyId, (val) {
                setState(() {
                  _selectedFamilyId = val;
                  _selectedName = null;
                  _updateNamesForFamily(val!);
                });
              }),
              _buildDropdown('Name', _namesForSelectedFamily, _selectedName, (val) => setState(() => _selectedName = val)),
              _buildRadioGroup('Gender', ['Male', 'Female'], _selectedGender, (val) => setState(() => _selectedGender = val)),
              _buildTextField('Age', _ageController, keyboardType: TextInputType.number),
              _buildDatePicker('Date of Interview', _interviewDateController),
              _buildDropdown('Interviewer\'s Name', _interviewerList, _selectedInterviewer, (val) => setState(() => _selectedInterviewer = val)),
              
              const SizedBox(height: 24),
              _buildSectionTitle('Section 1: Health Facility Visits'),
              _buildRadioGroup('1. Past 3 months are you visited health care facility', ['Yes', 'No'], _visitedFacility, (val) => setState(() => _visitedFacility = val)),
              if (_visitedFacility == 'Yes') ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('If yes, specify reason:', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ..._visitReasons.keys.map((reason) => CheckboxListTile(
                  title: Text(reason),
                  value: _visitReasons[reason],
                  onChanged: (val) => setState(() => _visitReasons[reason] = val!),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                )),
                if (_visitReasons['others'] == true) _buildTextField('specify others', _visitOthersController),
              ],

              const SizedBox(height: 24),
              _buildSectionTitle('Section 2: Diabetes Medicines'),
              _buildRadioGroup('Are you currently taking medicines for Diabetes?', ['Yes', 'No'], _takingDmMed, (val) => setState(() => _takingDmMed = val)),
              if (_takingDmMed == 'Yes') ...[
                _buildDropdown('Where did you received medicines?', _medSourceList, _dmMedSource, (val) => setState(() => _dmMedSource = val)),
                if (_dmMedSource == 'Others') _buildTextField('specify others', _dmMedSourceOthersController),
                _buildTextField('Medicines Names (Diabetes)', _dmMedNamesController, maxLines: 3),
                _buildRadioGroup('1. Did you ever forget to take medicines?', ['Yes', 'No'], _dmForget, (val) => setState(() => _dmForget = val)),
                _buildRadioGroup('2. Do You ever neglected taking medicines', ['Yes', 'No'], _dmNeglected, (val) => setState(() => _dmNeglected = val)),
                _buildRadioGroup('3. Have you ever stopped taking medicines on feeling better?', ['Yes', 'No', 'Other'], _dmStoppedBetter, (val) => setState(() => _dmStoppedBetter = val)),
                _buildRadioGroup('4. Have you ever stopped taking medicines on feeling more worsening of your health', ['Yes', 'No'], _dmStoppedWorse, (val) => setState(() => _dmStoppedWorse = val)),
              ],

              const SizedBox(height: 24),
              _buildSectionTitle('Section 3: Hypertension Medicines'),
              _buildRadioGroup('Are you currently taking medicines for Blood Pressure?', ['Yes', 'No'], _takingHtnMed, (val) => setState(() => _takingHtnMed = val)),
              if (_takingHtnMed == 'Yes') ...[
                _buildDropdown('Where did you received medicines?', _medSourceList, _htnMedSource, (val) => setState(() => _htnMedSource = val)),
                if (_htnMedSource == 'Others') _buildTextField('specify others', _htnMedSourceOthersController),
                _buildTextField('Medicines Names (Hypertension)', _htnMedNamesController, maxLines: 3),
                _buildRadioGroup('1. Did you ever forget to take medicines?', ['Yes', 'No'], _htnForget, (val) => setState(() => _htnForget = val)),
                _buildRadioGroup('2. Do You ever neglected taking medicines', ['Yes', 'No'], _htnNeglected, (val) => setState(() => _htnNeglected = val)),
                _buildRadioGroup('3. Have you ever stopped taking medicines on feeling better?', ['Yes', 'No', 'Other'], _htnStoppedBetter, (val) => setState(() => _htnStoppedBetter = val)),
                _buildRadioGroup('4. Have you ever stopped taking medicines on feeling more worsening of your health', ['Yes', 'No'], _htnStoppedWorse, (val) => setState(() => _htnStoppedWorse = val)),
              ],

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue.shade700,
                  ),
                  child: const Text('Submit', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          const Divider(thickness: 2),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            keyboardType: keyboardType,
            maxLines: maxLines,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? selectedValue, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: selectedValue,
            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
            onChanged: onChanged,
            hint: const Text('-Select-'),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioGroup(String label, List<String> options, String? selectedValue, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 16,
            children: options.map((opt) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<String>(value: opt, groupValue: selectedValue, onChanged: onChanged),
                Text(opt),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            readOnly: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: Icon(Icons.calendar_today, size: 18),
            ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                setState(() => controller.text = DateFormat('dd-MMM-yyyy').format(date));
              }
            },
          ),
        ],
      ),
    );
  }
}
