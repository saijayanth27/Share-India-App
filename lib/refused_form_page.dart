import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

class RefusedFormPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const RefusedFormPage({super.key, this.existingData, this.docId});

  @override
  State<RefusedFormPage> createState() => _RefusedFormPageState();
}

class _RefusedFormPageState extends State<RefusedFormPage> {
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoading = false;

  // Controllers
  // Controllers
  final _registrationNumberController = TextEditingController();
  final _familyCodeController = TextEditingController();
  final _ageController = TextEditingController();
  final _otherReasonsController = TextEditingController();
  final _specifyOtherController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

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
  List<String> familyMembers = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  bool _isLoadingMembers = false;

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
          .collection('refused_form')
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
      selectedName = name;
      if (name != null) {
        if (_isEditMode) {
          final record = _existingRecords.firstWhere((r) => r['Name'] == name, orElse: () => {});
          if (record.isNotEmpty) {
            _editDocId = record['id'];
            _populateForm(record);
          }
        } else if (_allMembersData.containsKey(name)) {
          final data = _allMembersData[name]!;
          _registrationNumberController.text = data['Registration_Number']?.toString() ?? '';
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
    _registrationNumberController.text = d['Registration_Number'] ?? '';
    selectedFamilyCode = d['Family_code'] ?? d['Family_Code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    selectedName = d['Name'];
    selectedGender = d['Gender'];
    _ageController.text = d['Age']?.toString() ?? '';
    
    if (d['Date_of_Interview'] != null) {
      if (d['Date_of_Interview'] is Timestamp) {
        dateOfInterview = (d['Date_of_Interview'] as Timestamp).toDate();
      } else {
        try {
          dateOfInterview = DateFormat('dd-MMM-yyyy').parse(d['Date_of_Interview'].toString());
        } catch (_) {}
      }
    }
    
    selectedInterviewer = d['Interviewer_s_Name'];
    selectedRespondent = d['Respondent'];
    selectedReason = d['Reason_for_withdrawing_from_study'];
    
    if (d['Death_Date'] != null) {
      if (d['Death_Date'] is Timestamp) {
        deathDate = (d['Death_Date'] as Timestamp).toDate();
      } else {
        try {
          deathDate = DateFormat('dd-MMM-yyyy').parse(d['Death_Date'].toString());
        } catch (_) {}
      }
    }
    
    _specifyOtherController.text = d['Specify_Reason'] ?? ''; // Using the new controller

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
    
    if (selectedFamilyCode != null && familyMembers.isEmpty) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    // _formKey.currentState?.reset(); // _formKey is not defined in this snippet, assuming it's elsewhere or will be added.
    setState(() {
      _registrationNumberController.clear();
      _ageController.clear();
      _otherReasonsController.clear();
      _specifyOtherController.clear(); // Clear new controller
      selectedFamilyCode = null;
      selectedName = null;
      selectedGender = null;
      dateOfInterview = null;
      selectedInterviewer = null;
      selectedRespondent = null;
      selectedReason = null;
      deathDate = null;
      createdTime = null;
      familyMembers = [];
      _existingRecords = [];
      _editDocId = null;
    });
  }

  Future<void> _save() async {
    // if (!_formKey.currentState!.validate()) return; // _formKey is not defined in this snippet, assuming it's elsewhere or will be added.
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
        'Specify_Reason': _specifyOtherController.text, // Added this field
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('refused_form').doc(_editDocId).update(data);
      } else if (widget.docId != null) {
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Withdrawal Consent Form', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700, Colors.red.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    buildHeader(
                      context: context,
                      title: 'Withdrawal Consent',
                      subtitle: 'Process participant withdrawal from the study',
                    ),
                    _buildIdentitySection(),
                    _buildSectionCard(
                      title: 'Interview Details',
                      icon: Icons.assignment_outlined,
                      children: [
                        _buildDropdown('Respondent', respondents, selectedRespondent, (v) => setState(() => selectedRespondent = v)),
                        const SizedBox(height: 12),
                        _buildTimePicker('Created Time', createdTime, (v) => setState(() => createdTime = v)),
                      ],
                    ),
                    _buildSectionCard(
                      title: 'Withdrawal Information',
                      icon: Icons.cancel_outlined,
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
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(_isEditMode ? 'Update Form' : 'Save Form', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
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



  Widget _buildIdentitySection() {
    return _buildSectionCard(
      title: 'Patient Identity',
      icon: Icons.person_outline,
      children: [
        _buildTextField('Registration Number', _registrationNumberController),
        const SizedBox(height: 12),
        _buildTextField('Family Code', _familyCodeController, onChanged: (v) {
          setState(() {
            selectedFamilyCode = v;
            selectedName = null;
            familyMembers = [];
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
            ? _buildDropdown('Select Name to Edit', _existingRecords.map((r) => r['Name']?.toString() ?? 'Unknown').toList(), selectedName, _onNameSelected, isLoading: _isLoadingMembers)
            : _buildDropdown('Name', familyMembers, selectedName, _onNameSelected, isLoading: _isLoadingMembers),
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
