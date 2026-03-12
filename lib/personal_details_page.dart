import 'package:flutter/services.dart';
import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

class PersonalDetailsPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;
  final String? initialFamilyCode;

  const PersonalDetailsPage({super.key, this.existingData, this.docId, this.initialFamilyCode});

  @override
  State<PersonalDetailsPage> createState() => _PersonalDetailsPageState();
}

class _PersonalDetailsPageState extends State<PersonalDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _allMembersList = [];

  // --- Identity & Registration Controllers ---
  final _familyCode = TextEditingController();
  final _spouseNo = TextEditingController();
  final _mapNo = TextEditingController();
  final _newFamilyId = TextEditingController();
  final _serialNumber = TextEditingController();
  final _fatherRegNo = TextEditingController();
  final _parentsId = TextEditingController();
  final _relationCode = TextEditingController();
  final _firstName = TextEditingController();
  final _gen = TextEditingController();
  final _siNo = TextEditingController();
  String? selectedGender;
  final _birthWeight = TextEditingController();
  final _regNo = TextEditingController();

  // --- Personal Info Controllers ---
  DateTime? dateOfBirth;
  final _age = TextEditingController();
  String? liveStatus = '(1) Alive';
  String? selectedEducation;
  String? avStatus = '(1) Active';
  String? selectedOccupation;
  String? maritalStatus = '(0) Unmarried';
  final _income = TextEditingController();
  final _aadharNo = TextEditingController();

  // --- Death Details (shown if liveStatus == '(0) Dead') ---
  String? selectedDeathPlace;
  final _deathCause = TextEditingController();
  DateTime? deathDate;

  // --- Relations Controllers ---
  String? motherName;
  String? fatherName;
  String? relationWithHead;
  bool showSpouseDetails = false;
  String? spouseNameLookup;
  Map<String, dynamic>? _headDoc;
  String? marriageType;

  // Family Members for Dropdowns
  List<String> maleMembers = [];
  List<String> femaleMembers = [];
  List<Map<String, dynamic>> _familyMemberDocs = []; // Cache for full docs
  bool _isLoadingFamily = false;

  // --- Diseases (1) Yes / (2) No ---
  Map<String, String?> diseases = {
    'Asthma?': '(2) No',
    'Diabetes?': '(2) No',
    'Hypertensive?': '(2) No',
    'Thyroid?': '(2) No',
    'Malaria(last 6m)': '(2) No',
    'jaundice(last 6m)': '(2) No',
    'Panmasala(currently)': '(2) No',
    'Drink alcohol(currently)?': '(2) No',
    'Smoke (currently)?': '(2) No',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialFamilyCode != null) {
      _familyCode.text = widget.initialFamilyCode!;
      _fetchMembersByFamily(widget.initialFamilyCode!);
    }
    if (widget.existingData != null) {
      _isEditMode = true;
      _editDocId = widget.docId;
      _loadExistingData();
    }
    
    // Add listener for Age to sync with DOB
    _age.addListener(_onAgeChanged);
  }

  @override
  void dispose() {
    _age.removeListener(_onAgeChanged);
    _age.dispose();
    super.dispose();
  }

  void _onAgeChanged() {
    if (_age.text.isEmpty) {
      setState(() {}); // Still rebuild for visibility
      return;
    }
    final ageInt = int.tryParse(_age.text);
    if (ageInt != null && ageInt >= 0) {
      final now = DateTime.now();
      // Set DOB to Jan 1st of the calculated birth year
      final birthYear = now.year - ageInt;
      final newDob = DateTime(birthYear, 1, 1);
      
      if (dateOfBirth == null || dateOfBirth!.year != birthYear) {
         setState(() {
           dateOfBirth = newDob;
         });
      } else {
        setState(() {}); // Rebuild for visibility
      }
    }
  }

  void _onDOBChanged(DateTime picked) {
    setState(() {
      dateOfBirth = picked;
      final now = DateTime.now();
      int age = now.year - picked.year;
      if (now.month < picked.month || (now.month == picked.month && now.day < picked.day)) {
        age--;
      }
      // Update Age controller without triggering infinite loop
      _age.removeListener(_onAgeChanged);
      _age.text = age.toString();
      _age.addListener(_onAgeChanged);
    });
  }


  Future<void> _fetchMembersByFamily(String familyCode) async {
    setState(() => _isLoadingFamily = true);
    try {
      final fCode = familyCode.trim();
      if (fCode.isEmpty) {
        setState(() => _isLoadingFamily = false);
        return;
      }

      // 1. Fetch from Local SQLite
      final localMembers = await DataCacheService().fetchMembersLocally(fCode);
      
      // 2. Fetch from Firestore Cache
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: fCode)
          .get(const GetOptions(source: Source.cache));

      // 3. Merge results (using Name as a key for unique members)
      final Map<String, Map<String, dynamic>> merged = {};
      for (var m in localMembers) merged[m['Name'] ?? ''] = m;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        merged[data['Name'] ?? ''] = data;
      }
      
      final docs = merged.values.toList();
      final males = <String>[];
      final females = <String>[];

      for (var data in docs) {
        final name = data['Name']?.toString() ?? '';
        final gender = data['Gender']?.toString() ?? '';
        if (gender.contains('(1) Male')) {
          males.add(name);
        } else if (gender.contains('(0) Female')) {
          females.add(name);
        }
      }

      setState(() {
        _familyMemberDocs = docs;
        _allMembersList = docs;
        maleMembers = males..sort();
        femaleMembers = females..sort();
        _isLoadingFamily = false;
        
        // Find Head of Family for auto-relation logic
        _headDoc = docs.firstWhere(
          (d) => d['Relation_with_Head'] == 'HEAD OF THE FAMILY',
          orElse: () => {},
        );

        if (docs.isEmpty && widget.existingData == null) {
          _onRelationChanged('HEAD OF THE FAMILY');
        }
      });
    } catch (e) {
      debugPrint('Error fetching members: $e');
      setState(() => _isLoadingFamily = false);
    }
  }

  void _onSpouseChanged(String? val) {
    if (val == null) return;

    // 1. Check for Duplicate Marriage (Deluge logic)
    bool isAlreadyMarried = false;
    for (var member in _familyMemberDocs) {
      if (member['Name2'] == val && member['Marital_Status'] == '(1) Married') {
        isAlreadyMarried = true;
        break;
      }
    }

    if (isAlreadyMarried) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Duplicate Status'),
          content: Text("Selected Person '$val' s Marital Status in the DataBase is Married,Please Check............."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    }

    setState(() {
      spouseNameLookup = val;
      // 2. Auto Marriage Type for Female (Deluge logic)
      if (selectedGender == '(0) Female') {
        marriageType = 'Married In';
      }
      
      _updateAutoRelation();
    });
  }

  void _onFatherChanged(String? val) {
    setState(() {
      fatherName = val;
      _updateAutoRelation();
    });
  }

  void _onMotherChanged(String? val) {
    setState(() {
      motherName = val;
      _updateAutoRelation();
    });
  }

  void _updateAutoRelation() {
    if (_headDoc == null || _headDoc!.isEmpty) return;
    
    final headName = _headDoc!['Name']?.toString();
    if (headName == null) return;

    String? newRelation;

    // 1. Check if Spouse is Head
    if (spouseNameLookup == headName) {
      newRelation = (selectedGender == '(1) Male') ? 'HUSBAND' : 'WIFE';
    }
    // 2. Check if Father or Mother is Head
    else if (fatherName == headName || motherName == headName) {
      newRelation = (selectedGender == '(1) Male') ? 'SON' : 'DAUGHTER';
    }
    // 3. Complex relations based on Father's relation to Head
    else if (fatherName != null) {
      final fatherDoc = _familyMemberDocs.firstWhere(
        (d) => d['Name'] == fatherName,
        orElse: () => {},
      );
      final fatherRelation = fatherDoc['Relation_with_Head']?.toString();

      if (fatherRelation == 'SON') {
        newRelation = (selectedGender == '(1) Male') ? 'GRAND-SON(S)' : 'GRAND-DAUGHTER(S)';
      } else if (fatherRelation == 'BROTHER') {
        newRelation = (selectedGender == '(1) Male') ? 'BROTHER SON' : 'BROTHER DAUGHTER';
      } else if (fatherRelation == 'BROTHER-IN-LAW') {
        newRelation = (selectedGender == '(1) Male') ? 'NEPHEW' : 'NIECE';
      }
    }
    // 4. Complex relations based on Mother's relation to Head
    else if (motherName != null) {
      final motherDoc = _familyMemberDocs.firstWhere(
        (d) => d['Name'] == motherName,
        orElse: () => {},
      );
      final motherRelation = motherDoc['Relation_with_Head']?.toString();

      if (motherRelation == 'DAUGHTER') {
        newRelation = (selectedGender == '(1) Male') ? 'GRAND-SON (D)' : 'GRAND-DAUGHTER (D)';
      }
    }

    if (newRelation != null) {
      _onRelationChanged(newRelation);
    }
  }

  void _onRelationChanged(String? val) {
    if (val == null) return;
    setState(() {
      relationWithHead = val;
      
      // Generation Mapping from "All Generations.xlsx"
      final Map<String, int> mapping = {
        'WIFE RELATIONS': 2,
        'WIFE PARENT': 2,
        'WIFE BROTHERS WIFE': 3,
        'WIFE BROTHERS SON': 4,
        'WIFE BROTHERS DAUGHTER': 4,
        'WIFE BROTHER': 3,
        'DAUGHTER-IN-LAW': 4,
        'GRAND-DAUGHTER-IN-LAW': 5,
        'GREAT GRAND SON (SS)': 6,
        'GREAT GRAND DAUGHTER (SS)': 6,
        'GRAND-SON(S)': 5,
        'SINGLE': 3,
        'SISTER-IN-LAW (U)': 3,
        'GREAT GRAND SON(SD)': 6,
        'GRAND DAUGHTER HUSBAND(S)': 5,
        'GREAT GRAND DAUGTHER(SD)': 6,
        'GRAND-DAUGHTER(S)': 5,
        'ADOPTED SON': 4,
        'ADOPTED GRAND DAUGHTER': 5,
        'OTHERS': 3,
        'MOTHER RELATIONS': 3,
        'MOTHERS-IN-LAW': 2,
        'SISTER-SON-WIFE': 4,
        'SISTER-GRAND-SON': 5,
        'SISTER-GRAND-DAUGHTER': 5,
        'NEPHEW': 4,
        'BROTHER-IN-LAW': 3,
        'SISTER DAUGHTER HUSBAND': 4,
        'NIECE': 4,
        'PARENT': 2,
        'GRAND PARENT': 1,
        'GREAT GRAND PARENT': 0,
        'FATHER-IN-LAW': 2,
        'GRAND-DAUGHTER-IN-LAW (S)': 5,
        'GREAT-GRAND-SON(DS)': 6,
        'GREAT-GRAND-DAUGTHER(DS)': 6,
        'GRAND-SON (D)': 5,
        'SON-IN-LAW': 4,
        'GREAT GRAND SON (DD)': 6,
        'GRAND DAUGHTER HUSBAND(D)': 5,
        'GREAT GRAND DAUGHTER (DD)': 6,
        'GRAND-DAUGHTER (D)': 5,
        'ADOPTED DAUGHTER': 4,
        'SISTER-IN-LAW(BW)': 3,
        'BROTHERS SON WIFE': 4,
        'BROTHERS SONS SON': 5,
        'BROTHERS SONS DAUGHTER': 5,
        'BROTHERS SON ADOPTED': 4,
        'BROTHER SON': 4,
        'BROTHER-DAUGHTER-SON(DS)': 5,
        'BROTHERS DAUGHTER HUSBAND': 4,
        'BROTHER-DAUGHTER-DAUGHTER(DD)': 5,
        'BROTHER DAUGHTER': 4,
        'GREAT GRAND DAUGHTER (ASD)': 6,
        'AUNTY': 2,
        'ADOPTED GRAND SON': 5,
        'ADOPTED GREAT GRAND DAUGHTER': 6,
        'HEAD OF THE FAMILY': 3,
        'SISTER': 3,
        'BROTHER': 3,
        'DAUGHTER': 4,
        'UNCLE': 2,
        'SON': 4,
        'WIFE': 3,
        'HUSBAND': 3,
      };

      if (mapping.containsKey(val)) {
        _gen.text = mapping[val].toString();
      }
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      if (!_isEditMode) {
        _familyCode.clear();
      }
      _firstName.clear();
      _editDocId = null;
      _spouseNo.clear();
      _mapNo.clear();
      _newFamilyId.clear();
      _serialNumber.clear();
      _fatherRegNo.clear();
      _parentsId.clear();
      _relationCode.clear();
      _gen.clear();
      _siNo.clear();
      selectedGender = null;
      _birthWeight.clear();
      _regNo.clear();
      dateOfBirth = null;
      _age.clear();
      liveStatus = '(1) Alive';
      selectedEducation = null;
      avStatus = '(1) Active';
      selectedOccupation = null;
      maritalStatus = '(0) Unmarried';
      _income.clear();
      _aadharNo.clear();
      motherName = null;
      fatherName = null;
      relationWithHead = null;
      showSpouseDetails = false;
      spouseNameLookup = null;
      marriageType = null;
      _familyMemberDocs = [];
      selectedDeathPlace = null;
      _deathCause.clear();
      deathDate = null;
      diseases.updateAll((key, value) => '(2) No');
    });
  }

  void _loadExistingData([Map<String, dynamic>? data]) {
    final d = data ?? widget.existingData!;
    setState(() {
      _familyCode.text = d['Family_Code'] ?? '';
      _spouseNo.text = d['Spouse']?.toString() ?? '';
      _mapNo.text = d['Map_No']?.toString() ?? '';
      _newFamilyId.text = d['New_Family_ID'] ?? '';
      _serialNumber.text = d['Registration_Number1'] ?? '';
      _fatherRegNo.text = d['Father_Registration_Number'] ?? '';
      _parentsId.text = d['Parents_ID'] ?? '';
      _relationCode.text = d['Relation_Code'] ?? '';
      _firstName.text = d['Name'] ?? '';
      _gen.text = d['Gen']?.toString() ?? '';
      _siNo.text = d['SI_No']?.toString() ?? '';
      selectedGender = d['Gender'];
      _birthWeight.text = d['Birth_weight']?.toString() ?? '';
      _regNo.text = d['uniq_Registration_Number']?.toString() ?? '';

      if (d['Date_of_Birth'] != null) {
        dateOfBirth = d['Date_of_Birth'] is Timestamp ? (d['Date_of_Birth'] as Timestamp).toDate() : DateTime.tryParse(d['Date_of_Birth'].toString());
      }
      _age.text = d['Age']?.toString() ?? '';
      liveStatus = d['Live_Status'] ?? '(1) Alive';
      selectedEducation = d['Education'];
      avStatus = d['A_v_Status'] ?? '(1) Active';
      selectedOccupation = d['Occupation'];
      maritalStatus = d['Marital_Status'] ?? '(0) Unmarried';
      _income.text = d['Income'] ?? '';
      _aadharNo.text = d['Aadhar_No1'] ?? '';

      motherName = d['Mother_Name'];
      fatherName = d['Father_Name'];
      relationWithHead = d['Relation_with_Head'];
      showSpouseDetails = d['Spouse_Details1'] ?? false;
      spouseNameLookup = d['Name2'];
      marriageType = d['Marriage_Type'];

      selectedDeathPlace = d['Death_Place'];
      _deathCause.text = d['Death_Cause'] ?? '';
      if (d['Death_Date'] != null) {
        deathDate = d['Death_Date'] is Timestamp ? (d['Death_Date'] as Timestamp).toDate() : DateTime.tryParse(d['Death_Date'].toString());
      }

      diseases['Asthma?'] = d['Asthma'] ?? '(2) No';
      diseases['Diabetes?'] = d['Diabetes'] ?? '(2) No';
      diseases['Hypertensive?'] = d['Hypertensive'] ?? '(2) No';
      diseases['Thyroid?'] = d['Thyroid'] ?? '(2) No';
      diseases['Malaria(last 6m)'] = d['Malaria_last_6m'] ?? '(2) No';
      diseases['jaundice(last 6m)'] = d['jaundice_last_6m'] ?? '(2) No';
      diseases['Panmasala(currently)'] = d['Panmasala_currently'] ?? '(2) No';
      diseases['Drink alcohol(currently)?'] = d['Drink_alcohol_currently'] ?? '(2) No';
      diseases['Smoke (currently)?'] = d['Smoke_currently'] ?? '(2) No';
    });
  }
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Family_Code': _familyCode.text,
        'Spouse': int.tryParse(_spouseNo.text),
        'Map_No': int.tryParse(_mapNo.text),
        'New_Family_ID': _newFamilyId.text,
        'Registration_Number1': _serialNumber.text,
        'Father_Registration_Number': _fatherRegNo.text,
        'Parents_ID': _parentsId.text,
        'Relation_Code': _relationCode.text,
        'Name': _firstName.text,
        'Gen': int.tryParse(_gen.text),
        'SI_No': int.tryParse(_siNo.text),
        'Gender': selectedGender,
        'Birth_weight': double.tryParse(_birthWeight.text),
        'uniq_Registration_Number': int.tryParse(_regNo.text),
        'Date_of_Birth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
        'Age': int.tryParse(_age.text),
        'Live_Status': liveStatus,
        'Education': selectedEducation,
        'A_v_Status': avStatus,
        'Occupation': selectedOccupation,
        'Marital_Status': maritalStatus,
        'Income': _income.text,
        'Aadhar_No1': _aadharNo.text,
        'Mother_Name': motherName,
        'Father_Name': fatherName,
        'Relation_with_Head': relationWithHead,
        'Spouse_Details1': showSpouseDetails,
        'Name2': spouseNameLookup,
        'Name1': spouseNameLookup,
        'Marriage_Type': marriageType,
        'Death_Place': selectedDeathPlace,
        'Death_Cause': _deathCause.text,
        'Death_Date': deathDate != null ? Timestamp.fromDate(deathDate!) : null,
        'Asthma': diseases['Asthma?'],
        'Diabetes': diseases['Diabetes?'],
        'Hypertensive': diseases['Hypertensive?'],
        'Thyroid': diseases['Thyroid?'],
        'Malaria_last_6m': diseases['Malaria(last 6m)'],
        'jaundice_last_6m': diseases['jaundice(last 6m)'],
        'Panmasala_currently': diseases['Panmasala(currently)'],
        'Drink_alcohol_currently': diseases['Drink_alcohol_currently?'],
        'Smoke_currently': diseases['Smoke (currently)?'],
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('personal_details').doc(_editDocId).update(data);
      } else if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('personal_details').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('personal_details').add(data);
      }

      // 3. Head of the Family Sync (Deluge logic)
      if (relationWithHead == 'HEAD OF THE FAMILY' && _familyCode.text.isNotEmpty) {
        // Update local lookup data for offline use
        await DataCacheService().updateHeadOfFamily(_familyCode.text, _firstName.text);
        
        try {
          final familyQuery = await FirebaseFirestore.instance
              .collection('Family Code Creation')
              .where('family_id', isEqualTo: _familyCode.text)
              .get();
          
          if (familyQuery.docs.isNotEmpty) {
            final familyDocId = familyQuery.docs.first.id;
            await FirebaseFirestore.instance
                .collection('Family Code Creation')
                .doc(familyDocId)
                .update({'Head_of_the_family': _firstName.text});
            debugPrint('DataSync: Updated Head of the Family for ${_familyCode.text}');
          }
        } catch (e) {
          debugPrint('Error syncing Head of the Family: $e');
        }
      }

      if (mounted) {
        // Update local offline storage
        DataCacheService().addMember(data);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Personal details saved successfully!'), backgroundColor: Colors.green),
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

  Widget _buildRadioGroup(String title, String key, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ...options.map((opt) => RadioListTile<String>(
              title: Text(opt),
              value: opt,
              groupValue: (key == 'Gender') ? selectedGender : (key == 'Live_Status' ? liveStatus : (key == 'A_v_Status' ? avStatus : maritalStatus)),
              onChanged: (val) {
                setState(() {
                  if (key == 'Gender') selectedGender = val;
                  else if (key == 'Live_Status') liveStatus = val;
                  else if (key == 'A_v_Status') avStatus = val;
                  else maritalStatus = val;
                });
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            )),
      ],
    );
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Personal Details', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade700, Colors.blue.shade600],
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
                padding: const EdgeInsets.all(20),
                children: [
                  buildHeader(
                    context: context,
                    title: 'Personal Details',
                    subtitle: 'Register and manage individual member health profiles',
                  ),
                  buildSectionCard(
                    context: context,
                    title: 'Identity & Registration',
                    icon: Icons.fingerprint_outlined,
                    children: [
                      const SizedBox(height: 12),

                      _buildTextField(
                        'Family Code',
                        _familyCode,
                        helper: 'Enter or auto-populated from creation form',
                      ),
                      const SizedBox(height: 12),
                      // If family code is entered manually, allow fetching members
                      if (_familyCode.text.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _fetchMembersByFamily(_familyCode.text.trim()),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Load Family Members'),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Spouse', _spouseNo, keyboardType: TextInputType.number, hint: '#######')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Map No.', _mapNo, keyboardType: TextInputType.number, hint: '#######')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _isEditMode
                          ? DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'Select Member to Edit', border: OutlineInputBorder()),
                              value: _firstName.text.isEmpty ? null : _firstName.text,
                              items: _allMembersList.map((m) => DropdownMenuItem<String>(value: m['Name']?.toString(), child: Text(m['Name']?.toString() ?? ''))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  final doc = _allMembersList.firstWhere((m) => m['Name'] == val);
                                  _editDocId = doc['id']; // Need to ensure id is present
                                  _loadExistingData(doc);
                                }
                              },
                            )
                          : _buildTextField('Name', _firstName, helper: 'First Name'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Gen', _gen, keyboardType: TextInputType.number, hint: '#######')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('SI No', _siNo, keyboardType: TextInputType.number, hint: '#######')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(child: RadioListTile<String>(title: const Text('(1) Male'), value: '(1) Male', groupValue: selectedGender, onChanged: (v) => setState(() { selectedGender = v; _updateAutoRelation(); }), contentPadding: EdgeInsets.zero, dense: true)),
                          Expanded(child: RadioListTile<String>(title: const Text('(0) Female'), value: '(0) Female', groupValue: selectedGender, onChanged: (v) => setState(() { selectedGender = v; _updateAutoRelation(); }), contentPadding: EdgeInsets.zero, dense: true)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField('Registration Number', _regNo, hint: '#######', helper: 'System will auto-generate or user input'),
                    ],
                  ),
                  buildSectionCard(
                    context: context,
                    title: 'Personal Info',
                    icon: Icons.person_outline,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDatePicker('Date of Birth', dateOfBirth, _onDOBChanged)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Age', _age, keyboardType: TextInputType.number, hint: 'yrs')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _buildDropdown('Live Status', ['(1) Alive', '(0) Dead'], liveStatus, (v) => setState(() => liveStatus = v)),
                                const SizedBox(height: 12),
                                _buildDropdown('A/v Status', ['(1) Active', '(0) Vacant'], avStatus, (v) => setState(() => avStatus = v)),
                                const SizedBox(height: 12),
                                _buildDropdown(
                                  'Marital Status',
                                  ['(0) Unmarried', '(1) Married', '(2) Divorce', '(3) Widow', '(4) Not Eligible'],
                                  maritalStatus,
                                  (v) {
                                    setState(() {
                                      maritalStatus = v;
                                      if (v == '(0) Unmarried') {
                                        showSpouseDetails = false;
                                      }
                                    });
                                  },
                                ),
                                if (liveStatus == '(0) Dead') ...[
                                  const SizedBox(height: 12),
                                  _buildDropdown(
                                    'Death Place',
                                    ['(0) RHC', '(1) PVT', '(2) GOVT', '(3) HOME'],
                                    selectedDeathPlace,
                                    (v) => setState(() => selectedDeathPlace = v),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTextField('Death Cause', _deathCause),
                                  const SizedBox(height: 12),
                                  _buildDatePicker('Death Date', deathDate, (picked) => setState(() => deathDate = picked)),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                  if ((int.tryParse(_age.text) ?? 0) > 3)
                                    _buildDropdown(
                                      'Education',
                                      [
                                        '(0) ILLITIRATE', '(1) CAN READ ONLY', '(2) CAN READ AND WRITE',
                                        '(3) PRIMARY SCHOOL', '(4) MIDDLE SCHOOL', '(5) HIGH SCHOOL',
                                        '(6) GRADUATE', '(7) POST GRADUATE'
                                      ],
                                      selectedEducation,
                                      (v) => setState(() => selectedEducation = v),
                                    ),
                                  if ((int.tryParse(_age.text) ?? 0) > 3) const SizedBox(height: 12),
                                  if ((int.tryParse(_age.text) ?? 0) > 3)
                                    _buildDropdown(
                                      'Occupation',
                                      [
                                        '(1) HOUSE WIFE', '(2) AGRICULTURE', '(3) UNEMPLOYED', '(4)LABOUR',
                                        '(5) SELF-EMPLOYED', '(6) PRIVATE EMPLOYEE', '(7) ANGANWADI TEACHER',
                                        '(8) C.H.V', '(9) PENSION', '(10) GOVT EMPLOYEE', '(99) DONT KNOW'
                                      ],
                                      selectedOccupation,
                                      (v) => setState(() => selectedOccupation = v),
                                    ),
                                  if ((int.tryParse(_age.text) ?? 0) > 15) const SizedBox(height: 12),
                                  if ((int.tryParse(_age.text) ?? 0) > 15)
                                    _buildTextField('Income', _income),
                                  const SizedBox(height: 12),
                                  _buildTextField(
                                    'Aadhar No.', 
                                    _aadharNo, 
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(12),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  buildSectionCard(
                    context: context,
                    title: 'Relations',
                    icon: Icons.family_restroom_outlined,
                    children: [
                      _buildDropdown('Mother Name', femaleMembers, motherName, _onMotherChanged, isLoading: _isLoadingFamily),
                      const SizedBox(height: 12),
                      _buildDropdown('Father Name', maleMembers, fatherName, _onFatherChanged, isLoading: _isLoadingFamily),
                      const SizedBox(height: 12),
                        _buildDropdown(
                          'Relation with Head',
                          [
                            'ADOPTED DAUGHTER', 'ADOPTED GRAND DAUGHTER', 'ADOPTED GRAND SON', 'ADOPTED GREAT GRAND DAUGHTER',
                            'ADOPTED SON', 'AUNTY', 'BROTHER', 'BROTHER DAUGHTER', 'BROTHER SON', 'BROTHER-DAUGHTER-DAUGHTER(DD)',
                            'BROTHER-DAUGHTER-SON(DS)', 'BROTHER-IN-LAW', 'BROTHERS DAUGHTER HUSBAND', 'BROTHERS SON ADOPTED',
                            'BROTHERS SON WIFE', 'BROTHERS SONS DAUGHTER', 'BROTHERS SONS SON', 'BSW', 'DAUGHTER', 'DAUGHTER-IN-LAW',
                            'FATHER-IN-LAW', 'GRAND DAUGHTER HUSBAND(D)', 'GRAND DAUGHTER HUSBAND(S)', 'GRAND PARENT', 'GRAND-DAUGHTER (D)',
                            'GRAND-DAUGHTER(S)', 'GRAND-DAUGHTER-IN-LAW', 'GRAND-DAUGHTER-IN-LAW (S)', 'GRAND-SON (D)', 'GRAND-SON(S)',
                            'GREAT GRAND DAUGHTER (ASD)', 'GREAT GRAND DAUGHTER (DD)', 'GREAT GRAND DAUGHTER (SS)', 'GREAT GRAND DAUGTHER(SD)',
                            'GREAT GRAND PARENT', 'GREAT GRAND SON (DD)', 'GREAT GRAND SON (SS)', 'GREAT GRAND SON(SD)', 'GREAT-GRAND-DAUGTHER(DS)',
                            'GREAT-GRAND-SON(DS)', 'HEAD OF THE FAMILY', 'HUSBAND', 'MOTHER RELATIONS', 'MOTHERS-IN-LAW', 'NEPHEW', 'NIECE',
                            'OTHERS', 'PARENT', 'SINGLE', 'SISTER', 'SISTER DAUGHTER HUSBAND', 'SISTER-GRAND-DAUGHTER', 'SISTER-GRAND-SON',
                            'SISTER-IN-LAW (U)', 'SISTER-IN-LAW(BW)', 'SISTER-SON-WIFE', 'SON', 'SON-IN-LAW', 'UNCLE', 'WIFE', 'WIFE BROTHER',
                            'WIFE BROTHERS DAUGHTER', 'WIFE BROTHERS SON', 'WIFE BROTHERS WIFE', 'WIFE PARENT', 'WIFE RELATIONS'
                          ],
                          relationWithHead,
                          _onRelationChanged,
                        ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text('Spouse Details'),
                        value: showSpouseDetails,
                        enabled: maritalStatus != '(0) Unmarried',
                        onChanged: maritalStatus == '(0) Unmarried' ? null : (v) => setState(() => showSpouseDetails = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (showSpouseDetails) ...[
                        const SizedBox(height: 12),
                        _buildDropdown(
                          'Select Spouse',
                          selectedGender == '(1) Male' ? femaleMembers : maleMembers,
                          spouseNameLookup,
                          _onSpouseChanged,
                          isLoading: _isLoadingFamily,
                        ),
                        const SizedBox(height: 12),
                        _buildDropdown(
                          'Marriage Type',
                          ['Married In', 'Arrange Marriage', 'Love Marriage', 'Other'],
                          marriageType,
                          (v) => setState(() => marriageType = v),
                        ),
                      ],
                    ],
                  ),
                  buildSectionCard(
                    context: context,
                    title: 'Diseases',
                    icon: Icons.health_and_safety_outlined,
                    children: [
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: diseases.keys.map((d) {
                          return SizedBox(
                            width: (MediaQuery.of(context).size.width - 64) / 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                RadioListTile<String>(
                                  title: const Text('(1) Yes', style: TextStyle(fontSize: 12)),
                                  value: '(1) Yes',
                                  groupValue: diseases[d],
                                  onChanged: (v) => setState(() => diseases[d] = v),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                                RadioListTile<String>(
                                  title: const Text('(2) No', style: TextStyle(fontSize: 12)),
                                  value: '(2) No',
                                  groupValue: diseases[d],
                                  onChanged: (v) => setState(() => diseases[d] = v),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
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
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(_isEditMode ? 'Update Family Member' : 'Add Family Member', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _resetForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, String? hint, String? helper, int maxLines = 1, List<TextInputFormatter>? inputFormatters}) {
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
          inputFormatters: inputFormatters,
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
}
