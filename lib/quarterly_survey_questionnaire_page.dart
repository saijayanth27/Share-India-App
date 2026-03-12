import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

class QuarterlySurveyPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const QuarterlySurveyPage({super.key, this.existingData, this.docId});

  @override
  State<QuarterlySurveyPage> createState() => _QuarterlySurveyPageState();
}

class _QuarterlySurveyPageState extends State<QuarterlySurveyPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoading = false;

  // Controllers
  final TextEditingController _regNoController = TextEditingController();
  final TextEditingController _familyIdController = TextEditingController();
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
  List<String> _familyIds = [];
  List<String> familyMembers = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  bool _isLoadingMembers = false;

  final List<String> _interviewerList = ['Interviewer 1', 'Interviewer 2', 'Staff A', 'Staff B'];
  final List<String> _medSourceList = ['Govt. hospital', 'Private hospital', 'Medical shop', 'NGO', 'Weekly clinic', 'Others'];

  @override
  void initState() {
    super.initState();
    _fetchFamilyIds();
    if (widget.existingData != null) {
      _loadExistingData();
    } else {
      _interviewDateController.text = DateFormat('dd-MMM-yyyy').format(DateTime.now());
    }
  }

  void _loadExistingData() {
    setState(() {
      _populateForm(widget.existingData!);
    });
  }

  void _populateForm(Map<String, dynamic> data) {
    _regNoController.text = data['Registration_Number']?.toString() ?? '';
    _selectedFamilyId = data['Family_Code'];
    _familyIdController.text = _selectedFamilyId ?? '';
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

    if (_selectedFamilyId != null && familyMembers.isEmpty) {
      _fetchMembersByFamily(_selectedFamilyId!);
    }
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
        familyMembers = allNames.toList()..sort();
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
          .collection('quarterly_survey')
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
      _selectedName = name;
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
          _selectedGender = data['Gender']?.toString();
          _ageController.text = data['Age']?.toString() ?? '';
        }
      }
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _regNoController.clear();
      _familyIdController.clear();
      _selectedFamilyId = null;
      _selectedName = null;
      _selectedGender = null;
      _ageController.clear();
      _interviewDateController.text = DateFormat('dd-MMM-yyyy').format(DateTime.now());
      _selectedInterviewer = null;
      _visitedFacility = null;
      _visitReasons.updateAll((key, value) => false);
      _visitOthersController.clear();
      _takingDmMed = null;
      _dmMedSource = null;
      _dmMedSourceOthersController.clear();
      _dmMedNamesController.clear();
      _dmForget = null;
      _dmNeglected = null;
      _dmStoppedBetter = null;
      _dmStoppedWorse = null;
      _takingHtnMed = null;
      _htnMedSource = null;
      _htnMedSourceOthersController.clear();
      _htnMedNamesController.clear();
      _htnForget = null;
      _htnNeglected = null;
      _htnStoppedBetter = null;
      _htnStoppedWorse = null;
      familyMembers = [];
      _existingRecords = [];
      _editDocId = null;
    });
  }

  Future<void> _fetchFamilyIds() async {
    final codes = await DataCacheService().fetchFamilyCodes();
    setState(() {
      _familyIds = codes;
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
      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('quarterly_survey').doc(_editDocId).update(formData);
      } else if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('quarterly_survey').doc(widget.docId).update(formData);
      } else {
        await FirebaseFirestore.instance.collection('quarterly_survey').add(formData);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Survey saved successfully!'), backgroundColor: Colors.green));
        if (widget.docId != null) {
          Navigator.pop(context);
        } else {
          _resetForm();
        }
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
      appBar: AppBar(
        title: const Text('Quarterly Survey', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade700, Colors.purple.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildHeader(
                context: context,
                title: 'Community Health Survey',
                subtitle: 'Quarterly health assessment and follow-up',
              ),

              _buildSectionCard(
                title: 'Identification',
                icon: Icons.person_outline,
                children: [
                  _buildTextField('Registration Number', _regNoController),
                  _buildTextField('Family Code', _familyIdController, onChanged: (val) {
                    setState(() {
                      _selectedFamilyId = val;
                      _selectedName = null;
                      familyMembers = [];
                    });
                    if (val.isNotEmpty) {
                      if (_isEditMode) {
                        _fetchExistingRecords(val);
                      } else {
                        _fetchMembersByFamily(val);
                      }
                    }
                  }),
                  _isEditMode
                      ? _buildDropdown('Select Name to Edit', _existingRecords.map((r) => r['Name']?.toString() ?? 'Unknown').toList(), _selectedName, _onNameSelected, isLoading: _isLoadingMembers)
                      : _buildDropdown('Name', familyMembers, _selectedName, _onNameSelected, isLoading: _isLoadingMembers),
                  _buildRadioGroup('Gender', ['Male', 'Female'], _selectedGender, (val) => setState(() => _selectedGender = val)),
                  _buildTextField('Age', _ageController, keyboardType: TextInputType.number),
                  _buildDatePicker('Date of Interview', _interviewDateController),
                  _buildDropdown('Interviewer\'s Name', _interviewerList, _selectedInterviewer, (val) => setState(() => _selectedInterviewer = val)),
                ],
              ),
              
              const SizedBox(height: 24),
              const SizedBox(height: 24),
              _buildSectionCard(
                title: 'Section 1: Health Facility Visits',
                icon: Icons.local_hospital_outlined,
                children: [
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
                ],
              ),

              const SizedBox(height: 24),
              const SizedBox(height: 24),
              _buildSectionCard(
                title: 'Section 2: Diabetes Medicines',
                icon: Icons.medical_services_outlined,
                children: [
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
                ],
              ),

              const SizedBox(height: 24),
              const SizedBox(height: 24),
              _buildSectionCard(
                title: 'Section 3: Hypertension Medicines',
                icon: Icons.bloodtype_outlined,
                children: [
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
                ],
              ),

              const SizedBox(height: 40),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_isEditMode ? 'Update Survey' : 'Submit Survey', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            ],
          ),
        ),
      ),
    );
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

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, int maxLines = 1, Function(String)? onChanged}) {
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
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? selectedValue, Function(String?) onChanged, {bool isLoading = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: selectedValue,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: isLoading ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
            ),
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
