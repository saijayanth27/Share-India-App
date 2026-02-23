import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';

class RefusedFormPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const RefusedFormPage({super.key, this.existingData, this.docId});

  @override
  State<RefusedFormPage> createState() => _RefusedFormPageState();
}

class _RefusedFormPageState extends State<RefusedFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Controllers
  final _registrationNumberController = TextEditingController();
  final _ageController = TextEditingController();
  final _otherReasonsController = TextEditingController();

  // Selected Values
  String? selectedFamilyCode;
  String? selectedName;
  String? selectedGender;
  DateTime? dateOfInterview;
  String? selectedInterviewer;
  String? selectedRespondent;
  String? selectedReason;
  DateTime? deathDate;
  TimeOfDay? createdTime;

  // Lists for Lookups
  List<String> allFamilyCodes = [];
  List<String> namesByFamily = [];
  bool _isLoadingFamily = false;
  bool _isLoadingNames = false;

  final List<String> interviewers = [
    "KIRANMAI K", "LAVANYA KASPOJU", "RAMADEVI Y", "REVATHI CH", "PUSHPA K", "KUSUMA",
    "CHV", "SHAKUNTHALA(CHV AT)", "ASHA", "HEMALATHA(CHV AT)", "LAXMI", "BHASKAR",
    "KUSUMA G", "KARUNAKAR", "KRISHNAVENI", "B JYOTHI", "MADHAVI(CHV GR)", "ANNAPURNA",
    "BALAMANI(CHV GR)", "SALOMI", "UDYASHREE", "JOHN", "BHASKAR K", "SUNITHA",
    "KOMARIAH", "MADAV"
  ];

  final List<String> respondents = [
    "Participant", "Family members", "Neighbors", "CHV", "TETRA Team"
  ];

  final List<String> withdrawalReasons = [
    "(1) Left the Village", "(2) Died", "(3) Double code", "(4) Not Interested / Refused"
  ];

  @override
  void initState() {
    super.initState();
    _fetchFamilyCodes();
    if (widget.existingData != null) {
      _loadExistingData();
    }
  }

  Future<void> _fetchFamilyCodes() async {
    setState(() => _isLoadingFamily = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('client').get();
      final codes = snapshot.docs
          .map((doc) => doc.data()['family_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      setState(() {
        allFamilyCodes = codes..sort();
        _isLoadingFamily = false;
      });
    } catch (e) {
      debugPrint('Error fetching family codes: $e');
      setState(() => _isLoadingFamily = false);
    }
  }

  Future<void> _fetchNamesByFamily(String familyCode) async {
    setState(() => _isLoadingNames = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyCode)
          .get();
      
      final names = snapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['Name']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      setState(() {
        namesByFamily = names..sort();
        _isLoadingNames = false;
      });
    } catch (e) {
      debugPrint('Error fetching names: $e');
      setState(() => _isLoadingNames = false);
    }
  }

  void _loadExistingData() {
    final d = widget.existingData!;
    setState(() {
      _registrationNumberController.text = d['Registration_Number'] ?? '';
      selectedFamilyCode = d['Family_code'];
      selectedName = d['Name'];
      selectedGender = d['Gender'];
      _ageController.text = d['Age']?.toString() ?? '';
      
      if (d['Date_of_Interview'] != null) {
        dateOfInterview = (d['Date_of_Interview'] as Timestamp).toDate();
      }
      
      selectedInterviewer = d['Interviewer_s_Name'];
      selectedRespondent = d['Respondent'];
      selectedReason = d['Reason_for_withdrawing_from_study'];
      
      if (d['Death_Date'] != null) {
        deathDate = (d['Death_Date'] as Timestamp).toDate();
      }

      if (d['Created_time'] != null) {
        // String format expected is HH:mm:ss, or it could be stored as a string
        final timeStr = d['Created_time'].toString();
        try {
          final parts = timeStr.split(':');
          if (parts.length >= 2) {
            createdTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        } catch (e) {
          debugPrint('Error parsing time: $e');
        }
      }

      _otherReasonsController.text = d['other_reasons_specified'] ?? '';
    });
    
    if (selectedFamilyCode != null) {
      _fetchNamesByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _registrationNumberController.clear();
      _ageController.clear();
      _otherReasonsController.clear();
      selectedFamilyCode = null;
      selectedName = null;
      selectedGender = null;
      dateOfInterview = null;
      selectedInterviewer = null;
      selectedRespondent = null;
      selectedReason = null;
      deathDate = null;
      createdTime = null;
      namesByFamily = [];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number': _registrationNumberController.text,
        'Family_code': selectedFamilyCode,
        'Name': selectedName,
        'Gender': selectedGender,
        'Age': int.tryParse(_ageController.text),
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'Interviewer_s_Name': selectedInterviewer,
        'Respondent': selectedRespondent,
        'Reason_for_withdrawing_from_study': selectedReason,
        'Death_Date': deathDate != null ? Timestamp.fromDate(deathDate!) : null,
        'Created_time': createdTime != null ? '${createdTime!.hour.toString().padLeft(2, '0')}:${createdTime!.minute.toString().padLeft(2, '0')}:00' : null,
        'other_reasons_specified': _otherReasonsController.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('refused_form').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('refused_form').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Refused form details saved successfully!'), backgroundColor: Colors.green),
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
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
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
        title: const Text('Refused Form'),
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
                    title: 'Participant Details',
                    children: [
                      TextFormField(
                        controller: _registrationNumberController,
                        decoration: const InputDecoration(labelText: 'Registration Number', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Family Code',
                          border: const OutlineInputBorder(),
                          suffixIcon: _isLoadingFamily ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                        ),
                        value: selectedFamilyCode,
                        items: allFamilyCodes.map((code) => DropdownMenuItem(value: code, child: Text(code))).toList(),
                        onChanged: (v) {
                          setState(() {
                            selectedFamilyCode = v;
                            selectedName = null;
                            namesByFamily = [];
                          });
                          if (v != null) _fetchNamesByFamily(v);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Name',
                          border: const OutlineInputBorder(),
                          suffixIcon: _isLoadingNames ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                        ),
                        value: selectedName,
                        items: namesByFamily.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                        onChanged: (v) => setState(() => selectedName = v),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                        value: selectedGender,
                        items: const [
                          DropdownMenuItem(value: '(1) Male', child: Text('(1) Male')),
                          DropdownMenuItem(value: '(0) Female', child: Text('(0) Female')),
                        ],
                        onChanged: (v) => setState(() => selectedGender = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ageController,
                        decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Interview Details',
                    children: [
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dateOfInterview ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => dateOfInterview = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date of Interview', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                          child: Text(dateOfInterview == null ? 'dd-MMM-yyyy' : DateFormat('dd-MMM-yyyy').format(dateOfInterview!)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Interviewer’s Name', border: OutlineInputBorder()),
                        value: selectedInterviewer,
                        items: interviewers.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                        onChanged: (v) => setState(() => selectedInterviewer = v),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Respondent', border: OutlineInputBorder()),
                        value: selectedRespondent,
                        items: respondents.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (v) => setState(() => selectedRespondent = v),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: createdTime ?? TimeOfDay.now(),
                          );
                          if (picked != null) setState(() => createdTime = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Created Time', border: OutlineInputBorder(), suffixIcon: Icon(Icons.access_time)),
                          child: Text(createdTime == null ? 'hh:mm' : createdTime!.format(context)),
                        ),
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Withdrawal Information',
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Reason for withdrawing from study?', border: OutlineInputBorder()),
                        value: selectedReason,
                        items: withdrawalReasons.map((reason) => DropdownMenuItem(value: reason, child: Text(reason))).toList(),
                        onChanged: (v) => setState(() => selectedReason = v),
                      ),
                      if (selectedReason?.contains('(2) Died') ?? false) ...[
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: deathDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => deathDate = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Death Date', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                            child: Text(deathDate == null ? 'dd-MMM-yyyy' : DateFormat('dd-MMM-yyyy').format(deathDate!)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _otherReasonsController,
                        decoration: const InputDecoration(labelText: 'Other reasons specified', border: OutlineInputBorder()),
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(widget.docId == null ? 'Save Form' : 'Update Form', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _resetForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
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
