import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';

class AarogyaPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const AarogyaPage({super.key, this.existingData, this.docId});

  @override
  State<AarogyaPage> createState() => _AarogyaPageState();
}

class _AarogyaPageState extends State<AarogyaPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // --- Identity Fields ---
  final _registrationNumber = TextEditingController();
  String? selectedFamilyCode;
  String? selectedName;
  String? selectedGender;
  final _age = TextEditingController();
  DateTime? dateOfInterview = DateTime.now();
  String? interviewersName;
  String? relationship;
  final _finalFamilyCode = TextEditingController();
  final _relationCode = TextEditingController();

  // --- Income Information ---
  final _earnersCount = TextEditingController();
  final _monthlyIncome = TextEditingController();

  // --- Health Insurance Questions ---
  String? hasAarogyasri;
  String? knowsInsurance;
  String? willingToPay;
  List<String> whyNoInsurance = [];
  final _whyNoOthers = TextEditingController();
  
  String? estimateAmount; // Question 6
  final _pay2L = TextEditingController();

  // --- Conditions Preferences (Multiselect) ---
  List<String> outpatientConditions = [];
  final _outpatientOthers = TextEditingController();
  
  List<String> inpatientConditions = [];
  final _inpatientOthers = TextEditingController();

  // Lookups
  List<String> allFamilyCodes = [];
  List<Map<String, dynamic>> memberDetails = [];
  bool _isLoadingMembers = false;

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

      final details = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      setState(() {
        memberDetails = details;
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
      _registrationNumber.text = (d['Registration_Number'] ?? '').toString();
      selectedFamilyCode = d['Family_code'] ?? d['Family_Code_Creation'];
      if (selectedFamilyCode != null) _fetchMembersByFamily(selectedFamilyCode!);
      selectedName = d['Name'];
      selectedGender = d['Gender'];
      _age.text = (d['Age'] ?? '').toString();
      if (d['Date_of_Interview'] != null) dateOfInterview = (d['Date_of_Interview'] as Timestamp).toDate();
      interviewersName = d['Interviewer_s_Name'];
      relationship = d['Relations'];
      _finalFamilyCode.text = d['Final_family_code'] ?? '';
      _relationCode.text = d['Relation_Code'] ?? '';

      _earnersCount.text = d['reach_aarogya_1'] ?? '';
      _monthlyIncome.text = d['reach_aarogya_2'] ?? '';

      hasAarogyasri = d['reach_aarogya_3'];
      knowsInsurance = d['reach_aarogya_4'];
      willingToPay = d['reach_aarogya_5'];
      
      if (d['a_If_answer_is_NO_Why1'] is List) {
        whyNoInsurance = List<String>.from(d['a_If_answer_is_NO_Why1']);
      }
      _whyNoOthers.text = d['If_Others_Please_Mention3'] ?? '';
      
      estimateAmount = d['reach_aarogya_6'];
      _pay2L.text = d['PAY_2L1'] ?? '';

      if (d['For_which_of_the_following_conditions_usually_not_requiring_admission_to_a_hospital_you_would_like'] is List) {
        outpatientConditions = List<String>.from(d['For_which_of_the_following_conditions_usually_not_requiring_admission_to_a_hospital_you_would_like']);
      }
      _outpatientOthers.text = d['If_Others_Please_Mention1'] ?? '';

      if (d['For_which_of_the_following_conditions_usually_requiring_admission_to_a_hospital_you_would_like_to'] is List) {
        inpatientConditions = List<String>.from(d['For_which_of_the_following_conditions_usually_requiring_admission_to_a_hospital_you_would_like_to']);
      }
      _inpatientOthers.text = d['If_Others_Please_Mention2'] ?? '';
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _registrationNumber.clear();
      selectedFamilyCode = null; selectedName = null;
      selectedGender = null; _age.clear();
      dateOfInterview = DateTime.now(); interviewersName = null;
      relationship = null;
      _finalFamilyCode.clear(); _relationCode.clear();
      _earnersCount.clear(); _monthlyIncome.clear();
      hasAarogyasri = null; knowsInsurance = null; willingToPay = null; whyNoInsurance = []; _whyNoOthers.clear();
      estimateAmount = null; _pay2L.clear();
      outpatientConditions = []; _outpatientOthers.clear();
      inpatientConditions = []; _inpatientOthers.clear();
      memberDetails = [];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number': _registrationNumber.text,
        'Family_code': selectedFamilyCode,
        'Name': selectedName,
        'Gender': selectedGender,
        'Age': int.tryParse(_age.text),
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'Interviewer_s_Name': interviewersName,
        'Family_Code_Creation': selectedFamilyCode,
        'Final_family_code': _finalFamilyCode.text,
        'Relations': relationship,
        'Relation_Code': _relationCode.text,
        'reach_aarogya_1': _earnersCount.text,
        'reach_aarogya_2': _monthlyIncome.text,
        'reach_aarogya_3': hasAarogyasri,
        'reach_aarogya_4': knowsInsurance,
        'reach_aarogya_5': willingToPay,
        'a_If_answer_is_NO_Why1': whyNoInsurance,
        'If_Others_Please_Mention3': _whyNoOthers.text,
        'reach_aarogya_6': estimateAmount,
        'PAY_2L1': _pay2L.text,
        'For_which_of_the_following_conditions_usually_not_requiring_admission_to_a_hospital_you_would_like': outpatientConditions,
        'If_Others_Please_Mention1': _outpatientOthers.text,
        'For_which_of_the_following_conditions_usually_requiring_admission_to_a_hospital_you_would_like_to': inpatientConditions,
        'If_Others_Please_Mention2': _inpatientOthers.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('aarogya').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('aarogya').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aarogya assessment saved successfully!'), backgroundColor: Colors.green),
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

  Widget _buildMultiSelect({
    required String title,
    required List<String> options,
    required List<String> selectedValues,
    required Function(String, bool) onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((opt) {
            final isSelected = selectedValues.contains(opt);
            return FilterChip(
              label: Text(opt, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
              selected: isSelected,
              selectedColor: Colors.blue,
              checkmarkColor: Colors.white,
              onSelected: (val) => onToggle(opt, val),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('Aarogya Assessment'), backgroundColor: Theme.of(context).colorScheme.primaryContainer),
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
                    title: 'Aarogya Identity (Legacy)',
                    children: [
                      _buildTextField('Final Family Code', _finalFamilyCode),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: InputDecorator(decoration: const InputDecoration(labelText: 'Relationship', border: OutlineInputBorder()), child: Text(relationship ?? 'Select Name first'))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Relation Code', _relationCode)),
                        ],
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Income Information',
                    children: [
                      _buildTextField('1. How many members in your family earn an income?', _earnersCount),
                      const SizedBox(height: 12),
                      _buildTextField('2. What is the total monthly income earning members?', _monthlyIncome),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Health Insurance',
                    children: [
                      _buildRadioGroup(
                        '3. Do you have an Aarogyasri Card?',
                        ['(1) Yes', '(2) No', '(3) Don’t Know', '(4) Did not answer'],
                        hasAarogyasri,
                        (v) => setState(() => hasAarogyasri = v),
                      ),
                      const SizedBox(height: 16),
                      _buildRadioGroup(
                        '4. Do you know about Health Insurance policies?',
                        ['(1) Yes', '(2) No', '(3) Don’t Know', '(4) Did not answer'],
                        knowsInsurance,
                        (v) => setState(() => knowsInsurance = v),
                      ),
                      const SizedBox(height: 16),
                      _buildRadioGroup(
                        '5. Would you be willing to pay for a Health Insurance policy?',
                        ['(1) Yes', '(2) No', '(3) Don’t Know', '(4) Did not answer'],
                        willingToPay,
                        (v) => setState(() => willingToPay = v),
                      ),
                      if (willingToPay == '(2) No') ...[
                        const SizedBox(height: 16),
                        _buildMultiSelect(
                          title: '5a. If answer is NO, Why?',
                          options: [
                            '(a) Already have Aarogyasri card',
                            '(b) Already have a health insurance policy',
                            '(c) I don’t think I need it for my family',
                            '(d) too expensive to afford',
                            '(e)Any other reason'
                          ],
                          selectedValues: whyNoInsurance,
                          onToggle: (val, add) => setState(() => add ? whyNoInsurance.add(val) : whyNoInsurance.remove(val)),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField('If Others Please Mention', _whyNoOthers, maxLines: 2),
                      ],
                      const SizedBox(height: 16),
                      _buildRadioGroup(
                        '6. Availing annual health insurance cover of Rs 2 lakhs per family?',
                        ['(3) Don’t Know', '(4) Did not answer'],
                        estimateAmount,
                        (v) => setState(() => estimateAmount = v),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField('PAY_2L', _pay2L),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Inpatient & Outpatient Needs',
                    children: [
                      _buildMultiSelect(
                        title: '7. Outpatient conditions usually not requiring admission:',
                        options: ['(a)HYPERTENSION', '(b)FEVER', '(c)DIABETIC', '(d)STROKE', '(e)PAIN ABDOMEN', '(f)Any other reason'],
                        selectedValues: outpatientConditions,
                        onToggle: (val, add) => setState(() => add ? outpatientConditions.add(val) : outpatientConditions.remove(val)),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField('If Others Mention', _outpatientOthers),
                      const SizedBox(height: 16),
                      _buildMultiSelect(
                        title: '8. Inpatient conditions usually requiring admission:',
                        options: ['(a)LOW BACK ACHE', '(b)Urinary tract infection', '(c)Neonatal jaundice', '(d)VIRAL PYREXIA', '(e)Osteoarthritis', '(f)Any other reason'],
                        selectedValues: inpatientConditions,
                        onToggle: (val, add) => setState(() => add ? inpatientConditions.add(val) : inpatientConditions.remove(val)),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField('If Others Mention', _inpatientOthers),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Save Aarogya Assessment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              setState(() { selectedFamilyCode = v; selectedName = null; relationship = null; });
              if (v != null) _fetchMembersByFamily(v);
            }),
            const SizedBox(height: 12),
            _buildDropdown('Name', memberDetails.map((m) => m['Name'].toString()).toList(), selectedName, (v) {
              final m = memberDetails.firstWhere((element) => element['Name'] == v);
              setState(() {
                selectedName = v;
                relationship = m['Relationship'];
                _relationCode.text = m['Relation_Code'] ?? '';
              });
            }, isLoading: _isLoadingMembers),
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
                Expanded(child: _buildTextField('Age', _age, keyboardType: TextInputType.number, hint: 'e.g. 45')),
                const SizedBox(width: 12),
                Expanded(child: _buildDatePicker('Date of Interview', dateOfInterview, (v) => setState(() => dateOfInterview = v))),
              ],
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              'Interviewer’s Name',
              ['KIRANMAI K', 'REVATHI CH', 'RAMADEVI Y', 'LAVANYA KASPOJU', 'PUSHPA K', 'G RAMADEVI', 'BHASKAR K', 'ASHA', 'KUSUMA G', 'B JYOTHI', 'RAMADEVI G', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU'],
              interviewersName,
              (v) => setState(() => interviewersName = v),
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

  Widget _buildRadioGroup(String title, List<String> options, String? currentValue, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ...options.map((opt) => RadioListTile<String>(
          title: Text(opt, style: const TextStyle(fontSize: 13)),
          value: opt,
          groupValue: currentValue,
          onChanged: (val) => val != null ? onChanged(val) : null,
          contentPadding: EdgeInsets.zero,
          dense: true,
        )),
      ],
    );
  }
}
