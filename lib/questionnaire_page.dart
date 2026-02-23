import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'app_drawer.dart';
import 'questionnaire_report_page.dart';

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

  // Family Members for Dropdowns (Mocked for now, should fetch from Firestore)
  List<String> allFamilyCodes = [];
  List<String> allNames = [];
  bool _isLoadingFamily = false;

  @override
  void initState() {
    super.initState();
    _fetchFamilyCodes();
    if (widget.existingData != null) {
      _loadExistingData();
    }
  }

  Future<void> _fetchFamilyCodes() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('client').get();
      final codes = snapshot.docs.map((doc) => doc.data()['family_id']?.toString()).whereType<String>().toSet().toList();
      setState(() {
        allFamilyCodes = codes..sort();
      });
    } catch (e) {
      debugPrint('Error fetching family codes: $e');
    }
  }

  Future<void> _fetchNamesByFamily(String familyCode) async {
    setState(() => _isLoadingFamily = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyCode)
          .get();

      final names = snapshot.docs.map((doc) => doc.data()['Name']?.toString() ?? '').where((name) => name.isNotEmpty).toList();

      setState(() {
        allNames = names..sort();
        _isLoadingFamily = false;
      });
    } catch (e) {
      debugPrint('Error fetching names: $e');
      setState(() => _isLoadingFamily = false);
    }
  }

  void _loadExistingData() {
    final d = widget.existingData!;
    setState(() {
      _registrationNumber.text = d['Registration_Number']?.toString() ?? '';
      selectedFamilyCode = d['Family_Code_Creation'];
      selectedName = d['Name'];
      selectedGender = d['Gender'];
      _age.text = d['Age']?.toString() ?? '';
      _contactTel.text = d['Contact_Tel']?.toString() ?? '';
      if (d['Date_of_Interview'] != null) {
        dateOfInterview = (d['Date_of_Interview'] as Timestamp).toDate();
      }
      interviewersName = d['Interviewer_s_Name'];
      
      _heightCm.text = d['Height_CM']?.toString() ?? '';
      _weightKg.text = d['Weight_Kg']?.toString() ?? '';
      generalHealthStatus = d['What_is_your_general_health_status'];

      hasHypertension = d['Have_you_ever_been_diagnosed_screened_with_hypertension'] ?? '(2) No';
      _hypertensionDays.text = d['No_of_days1']?.toString() ?? '';
      hypertensionDuration = d['Duration2'];
      hypertensionMedicine = d['b_Are_you_currently_using_any_medicine_s_Medicine_Name1'];
      _hypertensionDosage.text = d['Dosage']?.toString() ?? '';
      _hypertensionOtherMedicine.text = d['Any_other_Medicine_name1']?.toString() ?? '';

      hasDiabetes = d['Have_you_ever_been_diagnosed_screened_with_Diabetes'] ?? '(2) No';
      _diabetesDays.text = d['No_of_days']?.toString() ?? '';
      diabetesDuration = d['Duration1'];
      diabetesMedicine = d['b_Are_you_currently_using_any_medicine_s_Medicine_Name'];
      diabetesStrength = d['Strength1'];
      _diabetesOtherMedicine.text = d['Any_other_Medicine_name']?.toString() ?? '';

      smokesNow = d['Do_you_smoke_chew_tobacco_related_products_now'] ?? '(2) No';
      tobaccoProductsPresent = List<Map<String, dynamic>>.from(d['Products_List'] ?? []);

      smokedPast = d['Have_you_ever_smoke_chew_in_the_past'] ?? '(2) No';
      tobaccoProductsPast = List<Map<String, dynamic>>.from(d['Products_List_Past'] ?? []);

      drinksAlcohol = d['Do_you_drink_consume_Alcohol'] ?? '(2) No';
      _alcoholDuration.text = d['Duration']?.toString() ?? '';
      alcoholDurationUnit = d['Dropdown'];
      alcoholProducts = List<Map<String, dynamic>>.from(d['List_field'] ?? []);

      sufferGeneralHealth = d['Did_you_suffer_from_General_Health_problems'] ?? '(2) No';
      generalHealthStatusDetail = d['If_yes7'];
      _generalHealthOther.text = d['If_Others_Please_Mention7'] ?? '';

      sufferVision = d['Did_you_suffer_from_Vision_problems1'] ?? '(2) No';
      visionStatusDetail = d['If_yes'];
      _visionOther.text = d['If_Others_Please_Mention8'] ?? '';

      sufferEnt = d['Did_you_suffer_from_ENT_problems2'] ?? '(2) No';
      entStatusDetail = d['If_yes1'];
      _entOther.text = d['If_Others_Please_Mention9'] ?? '';

      sufferRespiratory = d['Did_you_suffer_from_Respiratory_problems'] ?? '(2) No';
      respiratoryStatusDetail = d['If_yes2'];
      _respiratoryOther.text = d['If_Others_Please_Mention10'] ?? '';

      sufferGastro = d['Did_you_suffer_from_Gastrointestinal_problems'] ?? '(2) No';
      gastroStatusDetail = d['If_yes3'];
      _gastroOther.text = d['If_Others_Please_Mention11'] ?? '';

      sufferGenitourinary = d['Did_you_suffer_from_Genitourinary_problems'] ?? '(2) No';
      genitourinaryStatusDetail = d['If_yes4'];
      _genitourinaryOther.text = d['If_Others_Please_Mention12'] ?? '';

      sufferMusclesBones = d['Did_you_suffer_from_Muscles_or_bones_problems'] ?? '(2) No';
      musclesBonesStatusDetail = d['If_yes5'];
      _musclesBonesOther.text = d['If_Others_Please_Mention13'] ?? '';

      sufferSkin = d['Did_you_suffer_from_Skin_problems'] ?? '(2) No';
      skinStatusDetail = d['If_yes6'];
      _skinOther.text = d['If_Others_Please_Mention14'] ?? '';

      sufferBlood = d['Did_you_suffer_from_blood_related_problems'] ?? '(2) No';
      bloodStatusDetail = d['If_yes8'];
      _bloodOther.text = d['If_Others_Please_Mention15'] ?? '';

      if (selectedFamilyCode != null) _fetchNamesByFamily(selectedFamilyCode!);
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
        'Registration_Number': _registrationNumber.text,
        'Family_Code_Creation': selectedFamilyCode,
        'Name': selectedName,
        'Gender': selectedGender,
        'Age': int.tryParse(_age.text),
        'Contact_Tel': _contactTel.text,
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'Interviewer_s_Name': interviewersName,
        'Height_CM': double.tryParse(_heightCm.text),
        'Weight_Kg': double.tryParse(_weightKg.text),
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
        'Entry_time': DateFormat('HH:mm:ss').format(DateTime.now()),
        'modified_time1': DateFormat('HH:mm:ss').format(DateTime.now()),
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('questionnaire').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('questionnaire').add(data);
      }

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
        TextFormField(controller: _registrationNumber, decoration: const InputDecoration(labelText: 'Registration Number', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Family Code', border: OutlineInputBorder()),
          value: selectedFamilyCode,
          items: allFamilyCodes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) {
            setState(() {
              selectedFamilyCode = v;
              selectedName = null;
            });
            if (v != null) _fetchNamesByFamily(v);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
          value: selectedName,
          items: allNames.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
          onChanged: (v) => setState(() => selectedName = v),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                value: selectedGender,
                items: ['(1) Male', '(0) Female'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => selectedGender = v),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: TextFormField(controller: _age, decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(controller: _contactTel, decoration: const InputDecoration(labelText: 'Contact Tel', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: dateOfInterview ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
                  if (picked != null) setState(() => dateOfInterview = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date of Interview', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                  child: Text(dateOfInterview == null ? 'Select Date' : DateFormat('dd-MMM-yyyy').format(dateOfInterview!)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Interviewer’s Name', border: OutlineInputBorder()),
          value: interviewersName,
          items: [
            'KUSUMA', 'CHV', 'SHAKUNTHALA (CHV AT)', 'HEMALATHA (CHV AT)', 'LAXMI', 'BHASKAR', 'KARUNAKAR', 'KRISHNAVENI', 'MADHAVI (CHV GR)', 'ANNAPURNA', 'BALAMANI (CHV GR)', 'SALOMI', 'UDYASHREE', 'JOHN', 'SUNITHA', 'KOMARIAH', 'MADAV', 'LAVANYA M', 'LAVANYA METTU', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'PUSHPA K', 'RAMADEVI G', 'RAMADEVI Y', 'REVATHI CH', 'ASHA', 'B JYOTHI', 'BHASKAR K', 'G RAMADEVI', 'K BHASKAR', 'KIRANMAI K', 'KUSUMA G', 'LAVANYA KASPOJU'
          ].map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
          onChanged: (v) => setState(() => interviewersName = v),
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
            Expanded(child: TextFormField(controller: _heightCm, decoration: const InputDecoration(labelText: 'Height(cm)', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
            const SizedBox(width: 16),
            Expanded(child: TextFormField(controller: _weightKg, decoration: const InputDecoration(labelText: 'Weight(Kg)', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: '1.What is your general health status?', border: OutlineInputBorder()),
          value: generalHealthStatus,
          items: ['(1) Excellent', '(2) Good', '(3) Fair', '(4) Poor'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => generalHealthStatus = v),
        ),
      ],
    );
  }

  Widget _buildHypertensionSection() {
    return _buildSectionCard(
      title: '2. Hypertension',
      children: [
        const Text('Have you ever been diagnosed/screened with hypertension?'),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '(1) Yes', groupValue: hasHypertension, onChanged: (v) => setState(() => hasHypertension = v))),
            Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '(2) No', groupValue: hasHypertension, onChanged: (v) => setState(() => hasHypertension = v))),
          ],
        ),
        if (hasHypertension == '(1) Yes') ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: TextFormField(controller: _hypertensionDays, decoration: const InputDecoration(labelText: '(2a)If Yes, since how many days you had?', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()),
                  value: hypertensionDuration,
                  items: ['(1) Years', '(2) Months', '(3) Days'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setState(() => hypertensionDuration = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: '(2b) Are you currently using any medicine\'s?', border: OutlineInputBorder()),
            value: hypertensionMedicine,
            items: [
              'AMLODIPINE', 'ATENOLOL', 'DILTIZEM SR', 'HYDROCHLOROTHIAZIDE', 'INDAPAMIDE', 'LOSARTAN', 'METOPROLOL', 'METOPROLOL-XL', 'MINIPRESS-XL', 'NIFEDIPINE SR', 'OLMESARTAN', 'S-AMLODIPINE', 'TELMISARTAN'
            ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) => setState(() => hypertensionMedicine = v),
          ),
          const SizedBox(height: 16),
          TextFormField(controller: _hypertensionDosage, decoration: const InputDecoration(labelText: 'Dosage', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextFormField(controller: _hypertensionOtherMedicine, decoration: const InputDecoration(labelText: 'Any other Medicine name', border: OutlineInputBorder())),
        ],
      ],
    );
  }

  Widget _buildDiabetesSection() {
    return _buildSectionCard(
      title: '3. Diabetes',
      children: [
        const Text('Have you ever been diagnosed/screened with Diabetes?'),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '(1) Yes', groupValue: hasDiabetes, onChanged: (v) => setState(() => hasDiabetes = v))),
            Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '(2) No', groupValue: hasDiabetes, onChanged: (v) => setState(() => hasDiabetes = v))),
          ],
        ),
        if (hasDiabetes == '(1) Yes') ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: TextFormField(controller: _diabetesDays, decoration: const InputDecoration(labelText: '(3a)If Yes, since how many days you had?', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()),
                  value: diabetesDuration,
                  items: ['(1) Years', '(2) Months', '(3) Days'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setState(() => diabetesDuration = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: '(3b) Are you currently using any medicine\'s?', border: OutlineInputBorder()),
            value: diabetesMedicine,
            items: [
              'ACARBOSE', 'GLIBENCLAMIDE', 'GLICLAZIDE', 'GLIMEPIRIDE', 'METFORMIN', 'METFORMIN SR', 'MIGITOL', 'PIOGLITAZONE', 'SITAGLIPTIN', 'VILDAGLIPTIN', 'VOGLIBOSE', 'INS-MIXTARD', 'INS-GLARGINE', 'INS-ASPART', 'INS-LISPRO'
            ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) => setState(() => diabetesMedicine = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Strength', border: OutlineInputBorder()),
            value: diabetesStrength,
            items: ['0.2', '0.3', '1', '2', '2.5', '5', '15', '25', '30', '45', '50', '80', '100', '150', '500', '1000', '250', '20', '60', '0.5'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => diabetesStrength = v),
          ),
          const SizedBox(height: 16),
          TextFormField(controller: _diabetesOtherMedicine, decoration: const InputDecoration(labelText: 'Any other Medicine name', border: OutlineInputBorder())),
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
                  Expanded(child: TextFormField(controller: _alcoholDuration, decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                      value: alcoholDurationUnit,
                      items: ['(1) Years', '(2) Months', '(3) Days'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (v) => setState(() => alcoholDurationUnit = v),
                    ),
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
            Expanded(child: RadioListTile<String>(title: const Text('(1) Yes'), value: '(1) Yes', groupValue: groupVal, onChanged: onGroupChanged)),
            Expanded(child: RadioListTile<String>(title: const Text('(2) No'), value: '(2) No', groupValue: groupVal, onChanged: onGroupChanged)),
          ],
        ),
        if (groupVal == '(1) Yes') ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'If yes', border: OutlineInputBorder()),
            value: detailVal,
            items: detailOptions.map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: onDetailChanged,
          ),
          const SizedBox(height: 16),
          TextFormField(controller: otherCtrl, decoration: const InputDecoration(labelText: 'If Others Please Mention', border: OutlineInputBorder())),
        ],
      ],
    );
  }
}
