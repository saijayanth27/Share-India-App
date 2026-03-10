import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';

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
    final codes = await DataCacheService().fetchFamilyCodes();
    setState(() {
      allFamilyCodes = codes;
    });
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
                child: Column(
                  children: [
                    _buildIdentitySection(),
                    _buildSectionCard(
                      title: 'Interview Details',
                      children: [
                        _buildDropdown('Respondent', respondents, selectedRespondent, (v) => setState(() => selectedRespondent = v)),
                        const SizedBox(height: 12),
                        _buildTimePicker('Created Time', createdTime, (v) => setState(() => createdTime = v)),
                      ],
                    ),
                    _buildSectionCard(
                      title: 'Withdrawal Information',
                      children: [
                        _buildDropdown('Reason for withdrawing from study?', withdrawalReasons, selectedReason, (v) => setState(() => selectedReason = v)),
                        if (selectedReason?.contains('(2) Died') ?? false) ...[
                          const SizedBox(height: 12),
                          _buildDatePicker('Death Date', deathDate, (v) => setState(() => deathDate = v)),
                        ],
                        const SizedBox(height: 12),
                        _buildTextField('Other reasons specified', _otherReasonsController, maxLines: 3),
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
                        child: Text(widget.docId == null ? 'Save Form' : 'Update Form', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Patient Identity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const Divider(),
            _buildTextField('Registration Number', _registrationNumberController),
            const SizedBox(height: 12),
            _buildDropdown('Family Code', allFamilyCodes, selectedFamilyCode, (v) {
              setState(() { selectedFamilyCode = v; selectedName = null; namesByFamily = []; });
              if (v != null) _fetchNamesByFamily(v);
            }),
            const SizedBox(height: 12),
            _buildDropdown('Name', namesByFamily, selectedName, (v) => setState(() => selectedName = v), isLoading: _isLoadingNames),
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
                Expanded(child: _buildTextField('Age', _ageController, keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _buildDatePicker('Date of Interview', dateOfInterview, (v) => setState(() => dateOfInterview = v))),
              ],
            ),
            const SizedBox(height: 12),
            _buildDropdown('Interviewer’s Name', interviewers, selectedInterviewer, (v) => setState(() => selectedInterviewer = v)),
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

  Widget _buildDropdown(String label, List<String> items, String? selectedValue, Function(String?) onChanged, {bool isLoading = false}) {
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
          hint: const Text('-Select-'),
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

  Widget _buildTimePicker(String label, TimeOfDay? selectedTime, Function(TimeOfDay) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: selectedTime ?? TimeOfDay.now(),
            );
            if (picked != null) onPicked(picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: Icon(Icons.access_time, size: 18),
            ),
            child: Text(selectedTime == null ? 'hh:mm' : selectedTime.format(context)),
          ),
        ),
      ],
    );
  }
}
