import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

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
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoadingMembers = false;

  // --- Identity Fields ---
  final _registrationNumber = TextEditingController();
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  final _nameController = TextEditingController();
  final _age = TextEditingController();
  final _finalFamilyCode = TextEditingController();
  final _relationCode = TextEditingController();

  String? selectedFamilyCode;
  String? selectedName;
  String? selectedGender;
  DateTime? dateOfInterview = DateTime.now();
  String? interviewersName;
  String? relationship;

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
  List<String> familyMemberNames = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};

  final List<String> interviewers = [
    'KIRANMAI K', 'REVATHI CH', 'RAMADEVI Y', 'LAVANYA KASPOJU', 'PUSHPA K', 'G RAMADEVI', 'BHASKAR K', 'ASHA', 'KUSUMA G', 'B JYOTHI', 'RAMADEVI G', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    setState(() {
      _populateForm(widget.existingData!);
    });
  }

  Future<void> _fetchMembersByFamily(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyCode)
          .get(const GetOptions(source: Source.serverAndCache));
      final localMembers = await DataCacheService().fetchMembersLocally(familyCode);
      final Map<String, Map<String, dynamic>> memberMap = {};
      final Set<String> allNames = {};
      void processMember(Map<String, dynamic> data) {
        final name = data['Name']?.toString() ?? '';
        if (name.isEmpty) return;
        memberMap[name] = data;
        allNames.add(name);
      }
      for (var doc in snapshot.docs) processMember(doc.data());
      for (var local in localMembers) processMember(local);
      setState(() {
        _allMembersData = memberMap;
        familyMemberNames = allNames.toList()..sort();
        selectedFamilyCode = familyCode;
      });
    } catch (e) {
      debugPrint('Error fetching members: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _fetchExistingRecords(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('aarogya')
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
      _nameController.text = name ?? '';
    });
    
    if (name == null) return;

    final baseData = _allMembersData[name];
    if (baseData != null && !_isEditMode) {
      _registrationNumber.text = (baseData['uniq_Registration_Number'] ?? baseData['Registration_Number'] ?? '').toString();
      selectedGender = baseData['Gender']?.toString();
      _age.text = baseData['Age']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        final snapshot = await FirebaseFirestore.instance
            .collection('aarogya')
            .where('Family_code', isEqualTo: fCode)
            .where('Name', isEqualTo: name)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          setState(() {
            _editDocId = doc.id;
            final merged = {...?baseData, ...doc.data()};
            _populateForm(merged);
          });
        } else if (baseData != null) {
          _populateForm(baseData);
        }
      } catch (e) {
        debugPrint('Error fetching aarogya record: $e');
        if (baseData != null) _populateForm(baseData);
      } finally {
        if (mounted) setState(() => _isLoadingMembers = false);
      }
    }
  }

  void _populateForm(Map<String, dynamic> d) {
    setState(() {
      _registrationNumber.text = (d['Registration_Number'] ?? '').toString();
      selectedFamilyCode = d['Family_code'] ?? d['Family_Code_Creation'];
      _familyCodeController.text = selectedFamilyCode ?? '';
      selectedName = d['Name'];
      _nameController.text = (d['Name'] ?? '').toString();
      selectedGender = d['Gender'];
      _age.text = (d['Age'] ?? '').toString();
      final rawDate = d['Date_of_Interview'] ?? d['Interview_Date'];
      if (rawDate != null) {
        if (rawDate is Timestamp) {
          dateOfInterview = rawDate.toDate();
        } else {
          try {
            dateOfInterview = DateFormat('dd-MMM-yyyy').parse(rawDate.toString());
          } catch (_) {
            try {
              dateOfInterview = DateTime.parse(rawDate.toString());
            } catch (_) {}
          }
        }
      }
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

      if (selectedFamilyCode != null && familyMemberNames.isEmpty) {
        _fetchMembersByFamily(selectedFamilyCode!);
      }
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _registrationNumber.clear();
      _familyCodeController.clear();
      _nameController.clear();
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
      familyMemberNames = [];
      _existingRecords = [];
      _editDocId = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number': _registrationNumber.text,
        'Family_code': selectedFamilyCode ?? _familyCodeController.text,
        'Name': _isEditMode ? selectedName : _nameController.text,
        'Gender': selectedGender,
        'Age': int.tryParse(_age.text),
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'Interviewer_s_Name': interviewersName,
        'Family_Code_Creation': selectedFamilyCode ?? _familyCodeController.text,
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

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('aarogya', data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Aarogya updated! Syncing...' : 'Aarogya saved! Syncing...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ));
        if (widget.docId != null) {
          Navigator.pop(context);
        } else if (!wasEditing) {
          _resetForm();
        }
      }

      // 2. Background Sync (Non-blocking)
      _performAarogyaSync(data);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _performAarogyaSync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('aarogya').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('aarogya').add(data);
      }
    } catch (e) {
      debugPrint('Aarogya Background Sync Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Aarogya Assessment'), elevation: 0),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    formActionButtons(
                      context: context,
                      isEditMode: _isEditMode,
                      onNew: () {
                        setState(() {
                          _isEditMode = false;
                          _resetForm();
                        });
                      },
                      onSave: _save,
                      onEdit: () {
                        setState(() {
                          _isEditMode = true;
                          final code = _familyCodeController.text.trim();
                          if (code.isNotEmpty) {
                            _fetchMembersByFamily(code);
                            _fetchExistingRecords(code);
                          }
                        });
                      },
                      onCancel: _resetForm,
                      onExit: () => Navigator.pop(context),
                      isSaving: _isSaving,
                    ),
                    const SizedBox(height: 16),
                    _buildIdentitySection(),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Aarogya Identity (Legacy)',
                      icon: Icons.badge_outlined,
                      children: [
                        formTextField('Final Family Code', _finalFamilyCode),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: InputDecorator(decoration: const InputDecoration(labelText: 'Relationship', border: OutlineInputBorder()), child: Text(relationship ?? 'Select Name first'))),
                            const SizedBox(width: 12),
                            Expanded(child: formTextField('Relation Code', _relationCode)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Income Information',
                      icon: Icons.attach_money_outlined,
                      children: [
                        formTextField('1. How many members in your family earn an income?', _earnersCount, keyboardType: TextInputType.number),
                        const SizedBox(height: 12),
                        formTextField('2. What is the total monthly income earning members?', _monthlyIncome, keyboardType: TextInputType.number),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Health Insurance',
                      icon: Icons.health_and_safety_outlined,
                      children: [
                        _buildRadioGroup('3. Do you have an Aarogyasri Card?', ['(1) Yes', '(2) No', '(3) Don’t Know', '(4) Did not answer'], hasAarogyasri, (v) => setState(() => hasAarogyasri = v)),
                        const SizedBox(height: 16),
                        _buildRadioGroup('4. Do you know about Health Insurance policies?', ['(1) Yes', '(2) No', '(3) Don’t Know', '(4) Did not answer'], knowsInsurance, (v) => setState(() => knowsInsurance = v)),
                        const SizedBox(height: 16),
                        _buildRadioGroup('5. Would you be willing to pay for a Health Insurance policy?', ['(1) Yes', '(2) No', '(3) Don’t Know', '(4) Did not answer'], willingToPay, (v) => setState(() => willingToPay = v)),
                        if (willingToPay == '(2) No') ...[
                          const SizedBox(height: 16),
                          const Text('5a. If answer is NO, Why?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ...['(a) Already have Aarogyasri card', '(b) Already have a health insurance policy', '(c) I don’t think I need it for my family', '(d) too expensive to afford', '(e)Any other reason'].map((opt) => CheckboxListTile(
                            title: Text(opt, style: const TextStyle(fontSize: 13)),
                            value: whyNoInsurance.contains(opt),
                            onChanged: (val) => setState(() => val == true ? whyNoInsurance.add(opt) : whyNoInsurance.remove(opt)),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          )),
                          if (whyNoInsurance.contains('(e)Any other reason')) formTextField('If Others Please Mention', _whyNoOthers, maxLines: 2),
                        ],
                        const SizedBox(height: 16),
                        _buildRadioGroup('6. Availing annual health insurance cover of Rs 2 lakhs per family?', ['(3) Don’t Know', '(4) Did not answer'], estimateAmount, (v) => setState(() => estimateAmount = v)),
                        const SizedBox(height: 16),
                        formTextField('PAY_2L', _pay2L),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Inpatient & Outpatient Needs',
                      icon: Icons.local_hospital_outlined,
                      children: [
                        const Text('7. Outpatient conditions usually not requiring admission:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ...['(a)HYPERTENSION', '(b)FEVER', '(c)DIABETIC', '(d)STROKE', '(e)PAIN ABDOMEN', '(f)Any other reason'].map((opt) => CheckboxListTile(
                          title: Text(opt, style: const TextStyle(fontSize: 13)),
                          value: outpatientConditions.contains(opt),
                          onChanged: (val) => setState(() => val == true ? outpatientConditions.add(opt) : outpatientConditions.remove(opt)),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        )),
                        if (outpatientConditions.contains('(f)Any other reason')) formTextField('If Others Mention', _outpatientOthers),
                        const SizedBox(height: 16),
                        const Text('8. Inpatient conditions usually requiring admission:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ...['(a)LOW BACK ACHE', '(b)Urinary tract infection', '(c)Neonatal jaundice', '(d)VIRAL PYREXIA', '(e)Osteoarthritis', '(f)Any other reason'].map((opt) => CheckboxListTile(
                          title: Text(opt, style: const TextStyle(fontSize: 13)),
                          value: inpatientConditions.contains(opt),
                          onChanged: (val) => setState(() => val == true ? inpatientConditions.add(opt) : inpatientConditions.remove(opt)),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        )),
                        if (inpatientConditions.contains('(f)Any other reason')) formTextField('If Others Mention', _inpatientOthers),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildIdentitySection() {
    return buildSectionCard(
      context: context,
      title: 'Patient Identity',
      icon: Icons.person_outline,
      children: [
        formTextField('Registration Number', _registrationNumber),
        const SizedBox(height: 12),
        formSearchField(
          'Family Code',
          _familyCodeController,
          onSearch: () {
            if (_familyCodeController.text.isNotEmpty) {
              _fetchMembersByFamily(_familyCodeController.text);
              _fetchExistingRecords(_familyCodeController.text);
            }
          },
          isLoading: _isLoadingMembers,
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(
          context,
          'Name',
          (<String>{...familyMemberNames, ..._existingRecords.map((r) => r['Name']?.toString() ?? '')}
              .where((n) => n.isNotEmpty)
              .toList()
            ..sort()),
          selectedName,
          _onNameSelected,
          isLoading: _isLoadingMembers,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
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
            Expanded(child: formTextField('Age', _age, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Date of Interview', dateOfInterview, (v) => setState(() => dateOfInterview = v))),
          ],
        ),
        const SizedBox(height: 12),
        formSearchableDropdown(context, 'Interviewer’s Name', interviewers, interviewersName, (v) => setState(() => interviewersName = v)),
      ],
    );
  }

  Widget _buildRadioGroup(String title, List<String> options, String? currentValue, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
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
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(selectedDate == null ? 'dd-MMM-yyyy' : DateFormat('dd-MMM-yyyy').format(selectedDate)),
          ),
        ),
      ],
    );
  }
}
