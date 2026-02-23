import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';

class AnthropometryPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const AnthropometryPage({super.key, this.existingData, this.docId});

  @override
  State<AnthropometryPage> createState() => _AnthropometryPageState();
}

class _AnthropometryPageState extends State<AnthropometryPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // --- Controllers & State Variables ---
  final _registrationNumber = TextEditingController();
  final _age = TextEditingController();
  final _waistMeasurement = TextEditingController();
  final _weight = TextEditingController();
  final _hipMeasurement = TextEditingController();
  final _height = TextEditingController();
  final _otherDetails = TextEditingController();
  final _notDoneOther = TextEditingController();

  String? selectedFamilyId;
  String? selectedName;
  String? selectedGender;
  String? interviewersName;
  DateTime? dateOfInterview = DateTime.now();
  String? notDoneReason;
  String? chvName;

  List<String> allFamilyIds = [];
  List<String> allNames = [];
  bool _isLoadingLookups = false;

  @override
  void initState() {
    super.initState();
    _fetchFamilyIds();
    if (widget.existingData != null) {
      _loadExistingData();
    }
  }

  Future<void> _fetchFamilyIds() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('client').get();
      final ids = snapshot.docs.map((doc) => doc.data()['family_id']?.toString()).whereType<String>().toSet().toList();
      setState(() {
        allFamilyIds = ids..sort();
      });
    } catch (e) {
      debugPrint('Error fetching family IDs: $e');
    }
  }

  Future<void> _fetchNamesByFamily(String familyId) async {
    setState(() => _isLoadingLookups = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyId)
          .get();

      final names = snapshot.docs.map((doc) => doc.data()['Name']?.toString() ?? '').where((name) => name.isNotEmpty).toList();

      setState(() {
        allNames = names..sort();
        _isLoadingLookups = false;
      });
    } catch (e) {
      debugPrint('Error fetching names: $e');
      setState(() => _isLoadingLookups = false);
    }
  }

  void _loadExistingData() {
    final d = widget.existingData!;
    setState(() {
      _registrationNumber.text = d['Registration_Number']?.toString() ?? '';
      selectedFamilyId = d['Family_ID'];
      selectedName = d['Name'];
      selectedGender = d['Gender'];
      _age.text = d['Age']?.toString() ?? '';
      interviewersName = d['Interviewer_s_Name'];
      if (d['Date_of_Interview'] != null) {
        dateOfInterview = (d['Date_of_Interview'] as Timestamp).toDate();
      }
      notDoneReason = d['If_not_done_reason'];
      _notDoneOther.text = d['If_Other_please_mention'] ?? '';
      chvName = d['CHV'];
      _waistMeasurement.text = d['Waist_Measurement']?.toString() ?? '';
      _weight.text = d['weight']?.toString() ?? '';
      _hipMeasurement.text = d['Hip_Measurement']?.toString() ?? '';
      _height.text = d['Height']?.toString() ?? '';
      _otherDetails.text = d['Other_Details'] ?? '';

      if (selectedFamilyId != null) _fetchNamesByFamily(selectedFamilyId!);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number': _registrationNumber.text,
        'Family_ID': selectedFamilyId,
        'Name': selectedName,
        'Gender': selectedGender,
        'Age': int.tryParse(_age.text),
        'Interviewer_s_Name': interviewersName,
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'If_not_done_reason': notDoneReason,
        'If_Other_please_mention': _notDoneOther.text,
        'CHV': chvName,
        'Waist_Measurement': double.tryParse(_waistMeasurement.text),
        'weight': double.tryParse(_weight.text),
        'Hip_Measurement': double.tryParse(_hipMeasurement.text),
        'Height': double.tryParse(_height.text),
        'Other_Details': _otherDetails.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('anthropometry').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('anthropometry').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anthropometry records saved successfully!'), backgroundColor: Colors.green),
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
        title: const Text('Anthropometry Measurement'),
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
                    title: 'Basic Information',
                    children: [
                      TextFormField(controller: _registrationNumber, decoration: const InputDecoration(labelText: 'Registration Number', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Family ID', border: OutlineInputBorder()),
                        value: selectedFamilyId,
                        items: allFamilyIds.map((id) => DropdownMenuItem(value: id, child: Text(id))).toList(),
                        onChanged: (v) {
                          setState(() {
                            selectedFamilyId = v;
                            selectedName = null;
                          });
                          if (v != null) _fetchNamesByFamily(v);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: 'Name', border: OutlineInputBorder(), suffixIcon: _isLoadingLookups ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null),
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
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Interview Details',
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Interviewer’s Name', border: OutlineInputBorder()),
                        value: interviewersName,
                        items: [
                          'KIRANMAI K', 'LAVANYA KASPOJU', 'RAMADEVI Y', 'REVATHI CH', 'PUSHPA K', 'KUSUMA', 'CHV', 'SHAKUNTHALA(CHV AT)', 'ASHA', 'HEMALATHA(CHV AT)', 'LAXMI', 'BHASKAR', 'KUSUMA G', 'KARUNAKAR', 'KRISHNAVENI', 'B JYOTHI', 'MADHAVI(CHV GR)', 'ANNAPURNA', 'BALAMANI(CHV GR)', 'SALOMI', 'UDYASHREE', 'JOHN', 'BHASKAR K', 'SUNITHA', 'KOMARIAH', 'MADAV', 'G RAMADEVI', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU', 'LAVANYA METU', 'MONAHOR REDDY', 'N POOJA', 'RAJAKUMARI', 'VENKAT'
                        ].map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                        onChanged: (v) => setState(() => interviewersName = v),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(context: context, initialDate: dateOfInterview ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
                          if (picked != null) setState(() => dateOfInterview = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date of Interview', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                          child: Text(dateOfInterview == null ? 'Select Date' : DateFormat('dd-MMM-yyyy').format(dateOfInterview!)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('If not done reason', style: TextStyle(fontWeight: FontWeight.bold)),
                      Column(
                        children: ['(1) Not available', '(2) Refused for current visit', '(3) Door Locked', '(4) Other'].map((r) => RadioListTile<String>(
                          title: Text(r),
                          value: r,
                          groupValue: notDoneReason,
                          onChanged: (v) => setState(() => notDoneReason = v),
                        )).toList(),
                      ),
                      if (notDoneReason == '(4) Other') ...[
                        const SizedBox(height: 8),
                        TextFormField(controller: _notDoneOther, decoration: const InputDecoration(labelText: 'If Other please mention', border: OutlineInputBorder())),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'CHV', border: OutlineInputBorder()),
                        value: chvName,
                        items: ['Choice 1', 'Choice 2', 'Choice 3'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => chvName = v),
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Measurements',
                    children: [
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _waistMeasurement, decoration: const InputDecoration(labelText: 'Waist Measurement', border: OutlineInputBorder(), suffixText: 'cm'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _weight, decoration: const InputDecoration(labelText: 'Weight', border: OutlineInputBorder(), suffixText: 'Kg'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _hipMeasurement, decoration: const InputDecoration(labelText: 'Hip Measurement', border: OutlineInputBorder(), suffixText: 'cm'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _height, decoration: const InputDecoration(labelText: 'Height', border: OutlineInputBorder(), suffixText: 'cm'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _otherDetails, decoration: const InputDecoration(labelText: 'Other Details', border: OutlineInputBorder()), maxLines: 3),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Measurements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
}
