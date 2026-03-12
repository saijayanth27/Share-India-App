import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';

class TBQuestionnairePage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const TBQuestionnairePage({super.key, this.existingData, this.docId});

  @override
  State<TBQuestionnairePage> createState() => _TBQuestionnairePageState();
}

class _TBQuestionnairePageState extends State<TBQuestionnairePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoading = false;

  // --- Main Form Controllers & State ---
  final _nameController = TextEditingController();
  final _registrationNumber = TextEditingController();
  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectedGender;
  final _ageController = TextEditingController();
  DateTime? interviewDate = DateTime.now();
  String? selectedInterviewer;
  String? selectedReason;
  final _familyCodeController = TextEditingController();
  final _singleLineController = TextEditingController();

  // Questions State (Yes/No)
  Map<String, String?> answers = {
    'cough_2wks': '(2) No',
    'fever_2wks': '(2) No',
    'weight_loss': '(2) No',
    'night_sweats': '(2) No',
    'haemoptysis': '(2) No',
    'tb_before': '(2) No',
    'tb_exposure': '(2) No',
    'respiratory_history': '(2) No',
    'recent_infection': '(2) No',
    'crowded_places': '(2) No',
    'tb_household': '(2) No',
    'healthcare_work': '(2) No',
    'high_risk_env': '(2) No',
    'smoking': '(2) No',
    'alcohol': '(2) No',
    'recent_tests': '(2) No',
  };

  final _tbDetailsController = TextEditingController();
  final _respiratoryDetailsController = TextEditingController();

  // Dropdown Options
  List<String> allFamilyCodes = [];
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  bool _isLoadingMembers = false;

  final List<String> interviewers = [
    "KIRANMAI K", "REVATHI CH", "RAMADEVI Y", "LAVANYA KASPOJU", "PUSHPA K",
    "G RAMADEVI", "BHASKAR K", "ASHA", "KUSUMA G", "B JYOTHI", "RAMADEVI G",
    "LAVANYA METU", "N POOJA", "POOJA N", "K BHASKAR", "LAVANYA M", "LAVANYA METTU"
  ];

  final List<String> reasons = [
    "(1) Not available", "(2) Refused for current visit", "(3) Door Locked", "(4) Other"
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
          .collection('tb_questionnaire')
          .where('Family_code', isEqualTo: familyCode)
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
    selectedFamilyCode = d['Family_code'] ?? d['Family_Code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    _registrationNumber.text = d['Registration_Number']?.toString() ?? '';
    selectedMemberName = d['Name'];
    _nameController.text = selectedMemberName ?? '';
    selectedGender = d['Gender'];
    _ageController.text = d['Age']?.toString() ?? '';
    
    if (d['Date_of_Interview'] != null) {
      if (d['Date_of_Interview'] is Timestamp) {
        interviewDate = (d['Date_of_Interview'] as Timestamp).toDate();
      } else {
        try {
          interviewDate = DateFormat('dd-MMM-yyyy').parse(d['Date_of_Interview'].toString());
        } catch (_) {}
      }
    }
    
    selectedInterviewer = d['Interviewer_s_Name'];
    selectedReason = d['If_not_done_reason'];
    _singleLineController.text = d['Single_Line'] ?? '';

    answers['cough_2wks'] = d['Have_you_had_a_cough_for_more_than_2_weeks'] ?? '(2) No';
    answers['fever_2wks'] = d['Have_you_had_a_fever_for_more_than_2_weeks'] ?? '(2) No';
    answers['weight_loss'] = d['Do_you_feel_like_you_have_lost_weight'] ?? '(2) No';
    answers['night_sweats'] = d['Are_you_experiencing_excessive_sweating_at_night_Night_sweats'] ?? '(2) No';
    answers['haemoptysis'] = d['Haemoptysis_coughing_up_blood'] ?? '(2) No';
    answers['tb_before'] = d['Medical_History1'] ?? '(2) No';
    _tbDetailsController.text = d['If_yes_provide_details'] ?? '';
    answers['tb_exposure'] = d['Medical_History2'] ?? '(2) No';
    answers['respiratory_history'] = d['Respiratory_and_General_Health1'] ?? '(2) No';
    _respiratoryDetailsController.text = d['If_yes_please_provide_details'] ?? '';
    answers['recent_infection'] = d['Respiratory_and_General_Health2'] ?? '(2) No';
    answers['crowded_places'] = d['Social_and_Environmental_Factors1'] ?? '(2) No';
    answers['tb_household'] = d['Social_and_Environmental_Factors2'] ?? '(2) No';
    answers['healthcare_work'] = d['Occupational_History1'] ?? '(2) No';
    answers['high_risk_env'] = d['Occupational_History2'] ?? '(2) No';
    answers['smoking'] = d['Behavioural_Risk_Factors1'] ?? '(2) No';
    answers['alcohol'] = d['Behavioural_Risk_Factors2'] ?? '(2) No';
    answers['recent_tests'] = d['Diagnostic_Tests1'] ?? '(2) No';

    if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      selectedFamilyCode = null;
      _registrationNumber.clear();
      _nameController.clear();
      selectedMemberName = null;
      selectedGender = null;
      _ageController.clear();
      interviewDate = DateTime.now();
      selectedInterviewer = null;
      selectedReason = null;
      _singleLineController.clear();
      answers.updateAll((key, value) => '(2) No');
      _tbDetailsController.clear();
      _respiratoryDetailsController.clear();
      familyMemberNames = [];
      _existingRecords = [];
      _editDocId = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final data = {
        'Family_code': selectedFamilyCode,
        'Registration_Number': int.tryParse(_registrationNumber.text),
        'Name': _isEditMode ? selectedMemberName : _nameController.text,
        'Gender': selectedGender,
        'Age': int.tryParse(_ageController.text),
        'Date_of_Interview': interviewDate != null ? Timestamp.fromDate(interviewDate!) : null,
        'Interviewer_s_Name': selectedInterviewer,
        'If_not_done_reason': selectedReason,
        'Single_Line': _singleLineController.text,
        'Have_you_had_a_cough_for_more_than_2_weeks': answers['cough_2wks'],
        'Have_you_had_a_fever_for_more_than_2_weeks': answers['fever_2wks'],
        'Do_you_feel_like_you_have_lost_weight': answers['weight_loss'],
        'Are_you_experiencing_excessive_sweating_at_night_Night_sweats': answers['night_sweats'],
        'Haemoptysis_coughing_up_blood': answers['haemoptysis'],
        'Medical_History1': answers['tb_before'],
        'If_yes_provide_details': _tbDetailsController.text,
        'Medical_History2': answers['tb_exposure'],
        'Respiratory_and_General_Health1': answers['respiratory_history'],
        'If_yes_please_provide_details': _respiratoryDetailsController.text,
        'Respiratory_and_General_Health2': answers['recent_infection'],
        'Social_and_Environmental_Factors1': answers['crowded_places'],
        'Social_and_Environmental_Factors2': answers['tb_household'],
        'Occupational_History1': answers['healthcare_work'],
        'Occupational_History2': answers['high_risk_env'],
        'Behavioural_Risk_Factors1': answers['smoking'],
        'Behavioural_Risk_Factors2': answers['alcohol'],
        'Diagnostic_Tests1': answers['recent_tests'],
        'Entry_Date': widget.docId == null ? DateFormat('HH:mm:ss').format(now) : widget.existingData?['Entry_Date'],
        'Modified_Date': DateFormat('HH:mm:ss').format(now),
        'clientUpdatedAt': now.millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('tb_questionnaire').doc(_editDocId).update(data);
      } else if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('tb_questionnaire').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('tb_questionnaire').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TB Questionnaire saved successfully!'), backgroundColor: Colors.green),
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

  Widget _buildYesNoQuestion(String title, String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('(1) Yes'),
                  value: '(1) Yes',
                  groupValue: answers[key],
                  onChanged: (v) => setState(() => answers[key] = v),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('(2) No'),
                  value: '(2) No',
                  groupValue: answers[key],
                  onChanged: (v) => setState(() => answers[key] = v),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('TB Questionnaire'),
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
                    title: 'Status Info',
                    children: [
                      _buildDropdown("If not done, reason", reasons, selectedReason, (v) => setState(() => selectedReason = v)),
                      const SizedBox(height: 12),
                      _buildTextField('Single Line', _singleLineController),
                    ],
                  ),
                  _buildSectionCard(
                    title: '(1) Current Symptoms',
                    children: [
                      _buildYesNoQuestion('Have you had a cough for more than 2 weeks?', 'cough_2wks'),
                      _buildYesNoQuestion('Have you had a fever for more than 2 weeks?', 'fever_2wks'),
                      _buildYesNoQuestion('Do you feel like you have lost weight?', 'weight_loss'),
                      _buildYesNoQuestion('Are you experiencing excessive sweating at night (Night sweats)?', 'night_sweats'),
                      _buildYesNoQuestion('Haemoptysis (coughing up blood):', 'haemoptysis'),
                    ],
                  ),
                  _buildSectionCard(
                    title: '(2) Medical History',
                    children: [
                      _buildYesNoQuestion('Have you been diagnosed with tuberculosis before?', 'tb_before'),
                      if (answers['tb_before'] == '(1) Yes') ...[
                        const SizedBox(height: 12),
                        _buildTextField('If yes, provide details', _tbDetailsController),
                      ],
                      const SizedBox(height: 16),
                      _buildYesNoQuestion('Do you have a history of exposure to someone with confirmed TB?', 'tb_exposure'),
                    ],
                  ),
                  _buildSectionCard(
                    title: '(3) Respiratory and General Health',
                    children: [
                      _buildYesNoQuestion('Any history of chronic respiratory conditions (e.g., asthma, chronic bronchitis)?', 'respiratory_history'),
                      if (answers['respiratory_history'] == '(1) Yes') ...[
                        const SizedBox(height: 12),
                        _buildTextField('If yes, please provide details.', _respiratoryDetailsController),
                      ],
                      const SizedBox(height: 16),
                      _buildYesNoQuestion('Any recent respiratory infections or illnesses?', 'recent_infection'),
                    ],
                  ),
                  _buildSectionCard(
                    title: '(4) Social and Environmental Factors',
                    children: [
                      _buildYesNoQuestion('Are you living or working in crowded places?', 'crowded_places'),
                      _buildYesNoQuestion('Is there a history of TB in your household or close contacts?', 'tb_household'),
                    ],
                  ),
                  _buildSectionCard(
                    title: '(5) Occupational History',
                    children: [
                      _buildYesNoQuestion('Do you work in healthcare, correctional facilities, or others?', 'healthcare_work'),
                      _buildYesNoQuestion('environments with an increased risk of TB exposure?', 'high_risk_env'),
                    ],
                  ),
                  _buildSectionCard(
                    title: '(6) Behavioural Risk Factors',
                    children: [
                      _buildYesNoQuestion('Do you smoke or have a history of smoking?', 'smoking'),
                      _buildYesNoQuestion('Do you consume alcohol regularly?', 'alcohol'),
                    ],
                  ),
                  _buildSectionCard(
                    title: '(7) Diagnostic Tests',
                    children: [
                      _buildYesNoQuestion('Have you had any recent chest X-rays or other respiratory tests?', 'recent_tests'),
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
                      child: Text(_isEditMode ? 'Update Questionnaire' : 'Save Questionnaire', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              if (v != null && v.isNotEmpty) {
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
                Expanded(child: _buildDatePicker('Date of Interview', interviewDate, (v) => setState(() => interviewDate = v))),
              ],
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              'Interviewer’s Name',
              interviewers,
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
