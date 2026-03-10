import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'app_drawer.dart';
import 'questionnaire_report_page.dart';
import 'maria_db_service.dart';
import 'data_cache_service.dart';

class QuestionnairePage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const QuestionnairePage({super.key, this.existingData, this.docId});

  @override
  State<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends State<QuestionnairePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;
  List<dynamic> _allQuestionnaires = [];
  Map<String, dynamic>? _selectedRecord;


  // --- Controllers & State Variables ---
  // Section 1: Identity & Registration
  final _registrationNumber = TextEditingController();
  String? selectedFamilyCode;
  String? selectedName;
  String? selectedGender;
  final _age = TextEditingController();
  final _contactTel = TextEditingController();
  DateTime? dateOfInterview = DateTime.now();
  String? interviewersName;
  File? _image;

  List<String> allFamilyCodes = [];
  List<String> familyMembers = [];
  bool _isLoadingMembers = false;

  // Section 2: Measurements
  final _heightCm = TextEditingController();
  final _weightKg = TextEditingController();
  String? generalHealthStatus;

  // Section 3: Medical History - Hypertension
  String? hasHypertension = '(2) No';
  final _hypertensionDays = TextEditingController();
  String? hypertensionDuration;
  String? hypertensionMedicine;
  final _hypertensionDosage = TextEditingController();
  final _hypertensionOtherMedicine = TextEditingController();

  // Section 4: Medical History - Diabetes
  String? hasDiabetes = '(2) No';
  final _diabetesDays = TextEditingController();
  String? diabetesDuration;
  String? diabetesMedicine;
  String? diabetesStrength;
  final _diabetesOtherMedicine = TextEditingController();

  // Section 5: Tobacco & Alcohol
  String? smokesNow = '(2) No';
  List<Map<String, dynamic>> tobaccoProductsPresent = [];
  
  String? smokedPast = '(2) No';
  List<Map<String, dynamic>> tobaccoProductsPast = [];

  String? drinksAlcohol = '(2) No';
  final _alcoholDuration = TextEditingController();
  String? alcoholDurationUnit;
  List<Map<String, dynamic>> alcoholProducts = [];

  // Section 6: Systemic Review (Q7 - Q15)
  String? sufferGeneralHealth = '(2) No';
  String? generalHealthStatusDetail;
  final _generalHealthOther = TextEditingController();

  String? sufferVision = '(2) No';
  String? visionStatusDetail;
  final _visionOther = TextEditingController();

  String? sufferEnt = '(2) No';
  String? entStatusDetail;
  final _entOther = TextEditingController();

  String? sufferRespiratory = '(2) No';
  String? respiratoryStatusDetail;
  final _respiratoryOther = TextEditingController();

  String? sufferGastro = '(2) No';
  String? gastroStatusDetail;
  final _gastroOther = TextEditingController();

  String? sufferGenitourinary = '(2) No';
  String? genitourinaryStatusDetail;
  final _genitourinaryOther = TextEditingController();

  String? sufferMusclesBones = '(2) No';
  String? musclesBonesStatusDetail;
  final _musclesBonesOther = TextEditingController();

  String? sufferSkin = '(2) No';
  String? skinStatusDetail;
  final _skinOther = TextEditingController();

  String? sufferBlood = '(2) No';
  String? bloodStatusDetail;
  final _bloodOther = TextEditingController();


  @override
  void initState() {
    super.initState();
    _fetchFamilyCodes();
    if (widget.existingData != null) {
      _loadExistingData();
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

      final members = <String>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data['Name']?.toString() ?? '';
        members.add(name);
      }

      setState(() {
        familyMembers = members..sort();
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error fetching members: $e');
      setState(() => _isLoadingMembers = false);
    }
  }


  void _loadExistingData() {
    final d = _selectedRecord ?? widget.existingData;
    if (d == null) return;
    
    setState(() {
      // Map MariaDB fields (Regno, INTDT, etc.) to your controllers
      _registrationNumber.text = (d['Regno'] ?? d['Registration_Number'])?.toString() ?? '';
      selectedFamilyCode = (d['Family_Code'] ?? d['Family_Code_Creation'])?.toString();
      if (selectedFamilyCode != null) _fetchMembersByFamily(selectedFamilyCode!);
      selectedName = (d['INTNAME'] ?? d['Name'])?.toString();
      _contactTel.text = (d['CONTACTNO'] ?? d['Contact_Tel'])?.toString() ?? '';
      selectedGender = d['Gender']?.toString();
      _age.text = d['Age']?.toString() ?? '';
      if (d['INTDT'] != null) {
        dateOfInterview = DateTime.tryParse(d['INTDT'].toString());
      } else if (d['Date_of_Interview'] != null) {
        dateOfInterview = (d['Date_of_Interview'] is String) ? DateTime.tryParse(d['Date_of_Interview']) : d['Date_of_Interview'];
      }

      _heightCm.text = (d['HT'] ?? d['Height_CM'])?.toString() ?? '';
      _weightKg.text = (d['WT'] ?? d['Weight_Kg'])?.toString() ?? '';
      
      // ... continue mapping the rest of the fields (Hypertension, Diabetes, etc.) ...
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        // --- Backend names for MariaDB ---
        'Regno': _registrationNumber.text,
        'INTDT': dateOfInterview?.toIso8601String(),
        'CONTACTNO': _contactTel.text,
        'INTNAME': selectedName,
        'HT': double.tryParse(_heightCm.text),
        'WT': double.tryParse(_weightKg.text),
        
        // --- Form logic fields ---
        'Age': int.tryParse(_age.text),
        'Gender': selectedGender,
        'Family_Code': selectedFamilyCode,
        'Name': selectedName,
        'What_is_your_general_health_status': generalHealthStatus,
        'Have_you_ever_been_diagnosed_screened_with_hypertension': hasHypertension,
        'No_of_days1': _hypertensionDays.text,
        'Duration2': hypertensionDuration,
        'b_Are_you_currently_using_any_medicine_s_Medicine_Name1': hypertensionMedicine,
        'Dosage': _hypertensionDosage.text,
        'Any_other_Medicine_name1': _hypertensionOtherMedicine.text,
        'Have_you_ever_been_diagnosed_screened_with_Diabetes': hasDiabetes,
        'No_of_days': int.tryParse(_diabetesDays.text),
        'Duration1': diabetesDuration,
        'b_Are_you_currently_using_any_medicine_s_Medicine_Name': diabetesMedicine,
        'Strength1': diabetesStrength,
        'Any_other_Medicine_name': _diabetesOtherMedicine.text,
        'Do_you_smoke_chew_tobacco_related_products_now': smokesNow,
        'Products_List': tobaccoProductsPresent,
        'Have_you_ever_smoke_chew_in_the_past': smokedPast,
        'Products_List_Past': tobaccoProductsPast,
        'Do_you_drink_consume_Alcohol': drinksAlcohol,
        'Duration': int.tryParse(_alcoholDuration.text),
        'Dropdown': alcoholDurationUnit,
        'List_field': alcoholProducts,
        'Did_you_suffer_from_General_Health_problems': sufferGeneralHealth,
        'If_yes7': generalHealthStatusDetail,
        'If_Others_Please_Mention7': _generalHealthOther.text,
        'Did_you_suffer_from_Vision_problems1': sufferVision,
        'If_yes': visionStatusDetail,
        'If_Others_Please_Mention8': _visionOther.text,
        'Did_you_suffer_from_ENT_problems2': sufferEnt,
        'If_yes1': entStatusDetail,
        'If_Others_Please_Mention9': _entOther.text,
        'Did_you_suffer_from_Respiratory_problems': sufferRespiratory,
        'If_yes2': respiratoryStatusDetail,
        'If_Others_Please_Mention10': _respiratoryOther.text,
        'Did_you_suffer_from_Gastrointestinal_problems': sufferGastro,
        'If_yes3': gastroStatusDetail,
        'If_Others_Please_Mention11': _gastroOther.text,
        'Did_you_suffer_from_Genitourinary_problems': sufferGenitourinary,
        'If_yes4': genitourinaryStatusDetail,
        'If_Others_Please_Mention12': _genitourinaryOther.text,
        'Did_you_suffer_from_Muscles_or_bones_problems': sufferMusclesBones,
        'If_yes5': musclesBonesStatusDetail,
        'If_Others_Please_Mention13': _musclesBonesOther.text,
        'Did_you_suffer_from_Skin_problems': sufferSkin,
        'If_yes6': skinStatusDetail,
        'If_Others_Please_Mention14': _skinOther.text,
        'Did_you_suffer_from_blood_related_problems': sufferBlood,
        'If_yes8': bloodStatusDetail,
        'If_Others_Please_Mention15': _bloodOther.text,
      };

      // Firestore logic REMOVED - Using only MariaDB
      await MariaDBService.syncQuestionnaire(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Questionnaire saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Health Questionnaire'),
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
                  _buildMeasurementSection(),
                  _buildHypertensionSection(),
                  _buildDiabetesSection(),
                  _buildHabitsSection(),
                  _buildSystemicReviewSection(),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Questionnaire', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                    onPressed: () async {
                      setState(() => _isSaving = true);
                      try {
                        // This pulls all raw data from MariaDB
                        final data = await MariaDBService.getQuestionnaires();
                        setState(() {
                          _allQuestionnaires = data;
                          _isEditMode = true;
                          _isSaving = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edit Mode Active. Enter Family Code to see names.')),
                        );
                      } catch (e) {
                        setState(() => _isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error fetching from MariaDB: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Edit Questionnaire Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }
  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
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

  Widget _buildIdentitySection() {
    return _buildSectionCard(
      title: 'Identity & Registration',
      children: [
        _buildTextField('Registration Number', _registrationNumber),
        const SizedBox(height: 12),
        _buildDropdown('Family Code', allFamilyCodes, selectedFamilyCode, (v) {
          setState(() { selectedFamilyCode = v; selectedName = null; });
          if (v != null) _fetchMembersByFamily(v);
        }),
        const SizedBox(height: 12),
        if (_isEditMode)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Name to Edit', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: _allQuestionnaires.where((rec) {
                  final recFamilyCode = (rec['Family_Code'] ?? rec['Family_Code_Creation'])?.toString() ?? '';
                  return recFamilyCode == selectedFamilyCode;
                }).map((rec) => DropdownMenuItem(
                      value: Map<String, dynamic>.from(rec),
                      child: Text(rec['INTNAME'] ?? rec['Name'] ?? 'Unknown'),
                    )).toList(),
                onChanged: (record) {
                  if (record != null) {
                    setState(() {
                      _selectedRecord = record;
                      _loadExistingData();
                    });
                  }
                },
              ),
            ],
          )
        else
          _buildDropdown('Name', familyMembers, selectedName, (v) => setState(() => selectedName = v), isLoading: _isLoadingMembers),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDropdown('Gender', ['(1) Male', '(0) Female'], selectedGender, (v) => setState(() => selectedGender = v)),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField('Age', _age, keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField('Contact Tel', _contactTel, keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        _buildDatePicker('Date of Interview', dateOfInterview, (v) => setState(() => dateOfInterview = v)),
        const SizedBox(height: 12),
        _buildDropdown(
          'Interviewer’s Name',
          [
            'KUSUMA', 'CHV', 'SHAKUNTHALA (CHV AT)', 'HEMALATHA (CHV AT)', 'LAXMI', 'BHASKAR', 'KARUNAKAR', 'KRISHNAVENI', 'MADHAVI (CHV GR)', 'ANNAPURNA', 'BALAMANI (CHV GR)', 'SALOMI', 'UDYASHREE', 'JOHN', 'SUNITHA', 'KOMARIAH', 'MADAV', 'LAVANYA M', 'LAVANYA METTU', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'PUSHPA K', 'RAMADEVI G', 'RAMADEVI Y', 'REVATHI CH', 'ASHA', 'B JYOTHI', 'BHASKAR K', 'G RAMADEVI', 'K BHASKAR', 'KIRANMAI K', 'KUSUMA G', 'LAVANYA KASPOJU'
          ],
          interviewersName,
          (v) => setState(() => interviewersName = v),
        ),
        const SizedBox(height: 16),
        _buildImagePicker(),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Image', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickImage,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
            child: _image == null
                ? const Center(child: Icon(Icons.camera_alt, size: 50, color: Colors.grey))
                : Image.file(_image!, fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementSection() {
    return _buildSectionCard(
      title: 'Measurements',
      children: [
        Row(
          children: [
            Expanded(child: _buildTextField('Height(cm)', _heightCm, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField('Weight(Kg)', _weightKg, keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          '1.What is your general health status?',
          ['(1) Excellent', '(2) Good', '(3) Fair', '(4) Poor'],
          generalHealthStatus,
          (v) => setState(() => generalHealthStatus = v),
        ),
      ],
    );
  }

  Widget _buildHypertensionSection() {
    return _buildSectionCard(
      title: '2. Hypertension',
      children: [
        const Text('Have you ever been diagnosed/screened with hypertension?', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '(1) Yes', groupValue: hasHypertension, onChanged: (v) => setState(() => hasHypertension = v), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '(2) No', groupValue: hasHypertension, onChanged: (v) => setState(() => hasHypertension = v), contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
        if (hasHypertension == '(1) Yes') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('(2a)Since how many days?', _hypertensionDays, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown('Duration', ['(1) Years', '(2) Months', '(3) Days'], hypertensionDuration, (v) => setState(() => hypertensionDuration = v)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            '(2b) Are you currently using any medicine\'s?',
            [
              'AMLODIPINE', 'ATENOLOL', 'DILTIZEM SR', 'HYDROCHLOROTHIAZIDE', 'INDAPAMIDE', 'LOSARTAN', 'METOPROLOL', 'METOPROLOL-XL', 'MINIPRESS-XL', 'NIFEDIPINE SR', 'OLMESARTAN', 'S-AMLODIPINE', 'TELMISARTAN'
            ],
            hypertensionMedicine,
            (v) => setState(() => hypertensionMedicine = v),
          ),
          const SizedBox(height: 12),
          _buildTextField('Dosage', _hypertensionDosage),
          const SizedBox(height: 12),
          _buildTextField('Any other Medicine name', _hypertensionOtherMedicine),
        ],
      ],
    );
  }

  Widget _buildDiabetesSection() {
    return _buildSectionCard(
      title: '3. Diabetes',
      children: [
        const Text('Have you ever been diagnosed/screened with Diabetes?', style: TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '(1) Yes', groupValue: hasDiabetes, onChanged: (v) => setState(() => hasDiabetes = v), contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '(2) No', groupValue: hasDiabetes, onChanged: (v) => setState(() => hasDiabetes = v), contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
        if (hasDiabetes == '(1) Yes') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('(3a)Since how many days?', _diabetesDays, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown('Duration', ['(1) Years', '(2) Months', '(3) Days'], diabetesDuration, (v) => setState(() => diabetesDuration = v)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            '(3b) Are you currently using any medicine\'s?',
            [
              'ACARBOSE', 'GLIBENCLAMIDE', 'GLICLAZIDE', 'GLIMEPIRIDE', 'METFORMIN', 'METFORMIN SR', 'MIGITOL', 'PIOGLITAZONE', 'SITAGLIPTIN', 'VILDAGLIPTIN', 'VOGLIBOSE', 'INS-MIXTARD', 'INS-GLARGINE', 'INS-ASPART', 'INS-LISPRO'
            ],
            diabetesMedicine,
            (v) => setState(() => diabetesMedicine = v),
          ),
          const SizedBox(height: 12),
          _buildDropdown('Strength', ['0.2', '0.3', '1', '2', '2.5', '5', '15', '25', '30', '45', '50', '80', '100', '150', '500', '1000', '250', '20', '60', '0.5'], diabetesStrength, (v) => setState(() => diabetesStrength = v)),
          const SizedBox(height: 12),
          _buildTextField('Any other Medicine name', _diabetesOtherMedicine),
        ],
      ],
    );
  }

  Widget _buildHabitsSection() {
    return Column(
      children: [
        _buildSectionCard(
          title: '4. Tobacco (Present)',
          children: [
            const Text('Do you smoke/chew tobacco related products now?'),
            Row(
              children: [
                Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '(1) Yes', groupValue: smokesNow, onChanged: (v) => setState(() => smokesNow = v))),
                Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '(2) No', groupValue: smokesNow, onChanged: (v) => setState(() => smokesNow = v))),
              ],
            ),
            if (smokesNow == '(1) Yes') ...[
              const Divider(),
              const Text('Products List', style: TextStyle(fontWeight: FontWeight.bold)),
              ...tobaccoProductsPresent.map((p) => ListTile(title: Text('${p['Tobacco_Name']} (${p['Quantity']} ${p['Type_field']})'))),
              ElevatedButton(onPressed: () => _addTobaccoProduct(tobaccoProductsPresent), child: const Text('Add Product')),
            ],
          ],
        ),
        _buildSectionCard(
          title: '5. Tobacco (Past)',
          children: [
            const Text('Have you ever smoke/chew in the past?'),
            Row(
              children: [
                Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '(1) Yes', groupValue: smokedPast, onChanged: (v) => setState(() => smokedPast = v))),
                Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '(2) No', groupValue: smokedPast, onChanged: (v) => setState(() => smokedPast = v))),
              ],
            ),
            if (smokedPast == '(1) Yes') ...[
              const Divider(),
              const Text('Products List (Past)', style: TextStyle(fontWeight: FontWeight.bold)),
              ...tobaccoProductsPast.map((p) => ListTile(title: Text('${p['Tobacco_Name']} (${p['Quantity']} ${p['Type_field']})'))),
              ElevatedButton(onPressed: () => _addTobaccoProduct(tobaccoProductsPast), child: const Text('Add Product')),
            ],
          ],
        ),
        _buildSectionCard(
          title: '6. Alcohol',
          children: [
            const Text('Do you drink/consume Alcohol?'),
            Row(
              children: [
                Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '(1) Yes', groupValue: drinksAlcohol, onChanged: (v) => setState(() => drinksAlcohol = v))),
                Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '(2) No', groupValue: drinksAlcohol, onChanged: (v) => setState(() => drinksAlcohol = v))),
              ],
            ),
            if (drinksAlcohol == '(1) Yes') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField('Duration', _alcoholDuration, keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown('Unit', ['(1) Years', '(2) Months', '(3) Days'], alcoholDurationUnit, (v) => setState(() => alcoholDurationUnit = v)),
                  ),
                ],
              ),
              const Divider(),
              const Text('Alcohol Products', style: TextStyle(fontWeight: FontWeight.bold)),
              ...alcoholProducts.map((a) => ListTile(title: Text('${a['Item']} (${a['Quantity']} ${a['Units']})'))),
              ElevatedButton(onPressed: _addAlcoholProduct, child: const Text('Add Item')),
            ],
          ],
        ),
      ],
    );
  }

  void _addTobaccoProduct(List<Map<String, dynamic>> products) {
    showDialog(
      context: context,
      builder: (context) {
        String? tobaccoName;
        String? habit = '(1) Yes';
        final days = TextEditingController();
        String? durationUnit;
        final quantity = TextEditingController();
        String? quantityType;

        return AlertDialog(
          title: const Text('Add Tobacco Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Tobacco Name'),
                  items: ['(1) Cigarette', '(2) Beedi', '(3) Pan Masala', '(4) Tobacco powder', '(5) Hooka', '(6) gutka'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => tobaccoName = v,
                ),
                TextFormField(controller: days, decoration: const InputDecoration(labelText: 'Days'), keyboardType: TextInputType.number),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: ['(1) Years', '(2) Months', '(3) Days'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) => durationUnit = v,
                ),
                TextFormField(controller: quantity, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: ['(1) Number', '(2) Packets'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => quantityType = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (tobaccoName != null) {
                  setState(() {
                    products.add({
                      'Tobacco_Name': tobaccoName,
                      'Product_Habit': habit,
                      'Days': int.tryParse(days.text),
                      'Months_years': durationUnit,
                      'Quantity': int.tryParse(quantity.text),
                      'Type_field': quantityType,
                    });
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addAlcoholProduct() {
     showDialog(
      context: context,
      builder: (context) {
        String? item;
        final other = TextEditingController();
        String? frequent;
        final quantity = TextEditingController();
        String? unit;

        return AlertDialog(
          title: const Text('Add Alcohol Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Item'),
                  items: ['(1)Beer', '(2)Wine', '(3)Toddy', '(4)Whisky', '(5)Arrack'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => item = v,
                ),
                TextFormField(controller: other, decoration: const InputDecoration(labelText: 'If Others Please Mention')),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Frequent'),
                  items: [
                    '(1) More than once in a day', '(2) Once a day', '(3) Few days in a week', '(4) Once in a week', '(5) Few times in a month', '(6) Once in a month', '(7) Rarely'
                  ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => frequent = v,
                ),
                TextFormField(controller: quantity, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Units'),
                  items: ['(1) ml', '(2) Peg', '(3) Glass', '(4) Packet', '(5) Bottle'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) => unit = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (item != null) {
                  setState(() {
                    alcoholProducts.add({
                      'Item': item,
                      'If_Others_Please_Mention': other.text,
                      'Frequent': frequent,
                      'Quantity': int.tryParse(quantity.text),
                      'Units': unit,
                    });
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSystemicReviewSection() {
    return Column(
      children: [
        _buildReviewItem('7. General Health', sufferGeneralHealth, (v) => setState(() => sufferGeneralHealth = v), generalHealthStatusDetail, (v) => setState(() => generalHealthStatusDetail = v), _generalHealthOther, ['(1) Weight gain', '(2) Weight loss']),
        _buildReviewItem('8. Vision', sufferVision, (v) => setState(() => sufferVision = v), visionStatusDetail, (v) => setState(() => visionStatusDetail = v), _visionOther, ['(1) Near sightedness', '(2) Far sightedness', '(3) Any Other']),
        _buildReviewItem('9. ENT', sufferEnt, (v) => setState(() => sufferEnt = v), entStatusDetail, (v) => setState(() => entStatusDetail = v), _entOther, ['(1) Ear', '(2) Nose', '(3) Throat', '(4) Any Other']),
        _buildReviewItem('10. Respiratory', sufferRespiratory, (v) => setState(() => sufferRespiratory = v), respiratoryStatusDetail, (v) => setState(() => respiratoryStatusDetail = v), _respiratoryOther, ['(1) Aasthma', '(2) COPD', '(3) Any Other']),
        _buildReviewItem('11. Gastrointestinal', sufferGastro, (v) => setState(() => sufferGastro = v), gastroStatusDetail, (v) => setState(() => gastroStatusDetail = v), _gastroOther, ['(1) Heart burn', '(2) Abdominal Pain', '(3) Any Other']),
        _buildReviewItem('12. Genitourinary', sufferGenitourinary, (v) => setState(() => sufferGenitourinary = v), genitourinaryStatusDetail, (v) => setState(() => genitourinaryStatusDetail = v), _genitourinaryOther, ['(1) Burning in urine', '(2) Increase frequency of urine', '(3) Any Other']),
        _buildReviewItem('13. Muscles/Bones', sufferMusclesBones, (v) => setState(() => sufferMusclesBones = v), musclesBonesStatusDetail, (v) => setState(() => musclesBonesStatusDetail = v), _musclesBonesOther, ['(1) Arthritis', '(2) Spondylitis', '(3) Any Other']),
        _buildReviewItem('14. Skin', sufferSkin, (v) => setState(() => sufferSkin = v), skinStatusDetail, (v) => setState(() => skinStatusDetail = v), _skinOther, ['(1) Skin rash', '(2) Skin dryness', '(3) Itching', '(4) Any Other']),
        _buildReviewItem('15. Blood related', sufferBlood, (v) => setState(() => sufferBlood = v), bloodStatusDetail, (v) => setState(() => bloodStatusDetail = v), _bloodOther, ['(1) Anemia', '(2) Bruising or excessive bleeding', '(3) Any Other']),
      ],
    );
  }

  Widget _buildReviewItem(String title, String? groupVal, Function(String?) onGroupChanged, String? detailVal, Function(String?) onDetailChanged, TextEditingController otherCtrl, List<String> detailOptions) {
    return _buildSectionCard(
      title: title,
      children: [
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '(1) Yes', groupValue: groupVal, onChanged: onGroupChanged, contentPadding: EdgeInsets.zero, dense: true)),
            Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '(2) No', groupValue: groupVal, onChanged: onGroupChanged, contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
        if (groupVal == '(1) Yes') ...[
          const SizedBox(height: 12),
          _buildDropdown('If yes', detailOptions, detailVal, onDetailChanged),
          const SizedBox(height: 12),
          _buildTextField('If Others Please Mention', otherCtrl),
        ],
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, int maxLines = 1, String? hint, String? helper}) {
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
              firstDate: DateTime(2000),
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
            child: Text(selectedDate == null ? 'Select Date' : DateFormat('dd-MMM-yyyy').format(selectedDate)),
          ),
        ),
      ],
    );
  }
}
