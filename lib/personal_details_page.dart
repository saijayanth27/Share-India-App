import 'package:flutter/services.dart';
import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';
import 'language_provider.dart';

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
  final _familyCodeController = TextEditingController(text: 'TSRRMED');
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
  String? avStatus;
  String? selectedOccupation;
  String? maritalStatus;
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
      _familyCodeController.text = widget.initialFamilyCode!;
      _fetchMembersByFamily(widget.initialFamilyCode!);
    }
    if (widget.existingData != null) {
      _isEditMode = true;
      _editDocId = widget.docId;
      _loadExistingData();
    }
    _age.addListener(_onAgeChanged);
  }

  @override
  void dispose() {
    _age.dispose();
    _familyCodeController.dispose();
    _spouseNo.dispose();
    _mapNo.dispose();
    _newFamilyId.dispose();
    _serialNumber.dispose();
    _fatherRegNo.dispose();
    _parentsId.dispose();
    _relationCode.dispose();
    _firstName.dispose();
    _gen.dispose();
    _siNo.dispose();
    _birthWeight.dispose();
    _regNo.dispose();
    _income.dispose();
    _aadharNo.dispose();
    _deathCause.dispose();
    super.dispose();
  }

  void _onAgeChanged() {
    if (_age.text.isEmpty) {
      setState(() {}); 
      return;
    }
    final ageInt = int.tryParse(_age.text);
    if (ageInt != null && ageInt >= 0) {
      final now = DateTime.now();
      final birthYear = now.year - ageInt;
      final newDob = DateTime(birthYear, 1, 1);
      
      if (dateOfBirth == null || dateOfBirth!.year != birthYear) {
         setState(() {
           dateOfBirth = newDob;
         });
      } else {
        setState(() {}); 
      }
    }
  }

  void _onDOBChanged(DateTime picked) {
    setState(() {
      dateOfBirth = picked;
      final now = DateTime.now();
      int ageCount = now.year - picked.year;
      if (now.month < picked.month || (now.month == picked.month && now.day < picked.day)) {
        ageCount--;
      }
      _age.removeListener(_onAgeChanged);
      _age.text = ageCount.toString();
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

      // 1. Fetch from Family Code Creation for Head Name
      final familySnap = await FirebaseFirestore.instance
          .collection('Family Code Creation')
          .where('family_id', isEqualTo: fCode)
          .limit(1)
          .get();

      String? headNameFromFamily;
      if (familySnap.docs.isNotEmpty) {
        final data = familySnap.docs.first.data();
        headNameFromFamily = (data['head_of_family'] ?? data['Head_of_the_family'])?.toString();
      }

      // 2. Fetch Members
      final localMembers = await DataCacheService().fetchMembersLocally(fCode);
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: fCode)
          .get(const GetOptions(source: Source.serverAndCache));

      final Map<String, Map<String, dynamic>> merged = {};
      for (var m in localMembers) merged[m['Name'] ?? ''] = m;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id; // Capture Firestore document ID
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
        
        _headDoc = docs.firstWhere(
          (d) => d['Relation_with_Head'] == 'HEAD OF THE FAMILY',
          orElse: () => headNameFromFamily != null ? {'Name': headNameFromFamily, 'Relation_with_Head': 'HEAD OF THE FAMILY'} : {},
        );

        if (!_isEditMode) {
          _calculateNewFamilyID();
        }
      });
    } catch (e) {
      debugPrint('Error fetching members: $e');
      setState(() => _isLoadingFamily = false);
    }
  }

  void _calculateNewFamilyID() {
    if (_familyCodeController.text.isEmpty) return;
    
    final baseID = _familyCodeController.text;
    final distinctIDs = _allMembersList
        .map((m) => m['New_Family_ID']?.toString())
        .where((id) => id != null && id!.isNotEmpty)
        .toSet();
    
    const alphabets = "ABCDEFGHIJKMNOPQRSTUVWXYZ";
    final dupsize = distinctIDs.length; 
    if (dupsize < alphabets.length) {
      final letter = alphabets[dupsize];
      _newFamilyId.text = "$baseID$letter";
    }
  }

  void _onSpouseChanged(String? val) {
    if (val == null) return;
    
    // Check if spouse is already married or named as spouse elsewhere
    bool isAlreadyMarried = false;
    Map<String, dynamic>? spouseDoc;
    for (var member in _allMembersList) {
      if (member['Name'] == val) {
        spouseDoc = member;
        if (member['Marital_Status'] == '(1) Married') {
          isAlreadyMarried = true;
        }
      }
      if (member['Name2'] == val && member['Marital_Status'] == '(1) Married') {
        isAlreadyMarried = true;
      }
      if (isAlreadyMarried) break;
    }

    if (isAlreadyMarried) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('Duplicate Status')),
          content: Text(
            tr(
              "Selected Person '{name}' marital status in the database is Married. Please check.",
            ).replaceFirst('{name}', val.toString()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('OK')),
            ),
          ],
        ),
      );
    }

    setState(() {
      spouseNameLookup = val;
      maritalStatus = '(1) Married';
      avStatus = '(1) Active';
      showSpouseDetails = true;

      if (selectedGender == '(0) Female') {
        marriageType = 'Married In';
      }
      
      _updateAutoRelation();
      _calculateNewFamilyID();
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

    // 1. Spouse-based Logic (Highest Priority)
    if (spouseNameLookup != null) {
      if (spouseNameLookup == headName) {
        newRelation = (selectedGender == '(1) Male') ? 'HUSBAND' : 'WIFE';
      } else {
        final spouseDoc = _allMembersList.firstWhere((m) => m['Name'] == spouseNameLookup, orElse: () => {});
        if (spouseDoc.isNotEmpty) {
          final spouseRel = spouseDoc['Relation_with_Head']?.toString();
          if (spouseRel == 'SON') {
            if (selectedGender == '(0) Female') newRelation = 'DAUGHTER-IN-LAW';
          } else if (spouseRel == 'DAUGHTER') {
            if (selectedGender == '(1) Male') newRelation = 'SON-IN-LAW';
          } else if (spouseRel == 'BROTHER') {
            if (selectedGender == '(0) Female') newRelation = 'SISTER-IN-LAW (U)';
          } else if (spouseRel == 'SISTER') {
            if (selectedGender == '(1) Male') newRelation = 'BROTHER-IN-LAW';
          } else if (spouseRel == 'GRAND-SON(S)') {
            if (selectedGender == '(0) Female') newRelation = 'GRAND-DAUGHTER-IN-LAW';
          }
        }
      }
    }

    // 2. Parent-based Logic (if not already set by spouse logic)
    if (newRelation == null) {
      if ((fatherName != null && fatherName == headName) || (motherName != null && motherName == headName)) {
        newRelation = (selectedGender == '(1) Male') ? 'SON' : 'DAUGHTER';
      } else {
        if (fatherName != null) {
          final fatherDoc = _allMembersList.firstWhere((d) => d['Name'] == fatherName, orElse: () => {});
          final fatherRelation = fatherDoc['Relation_with_Head']?.toString();
          
          if (fatherRelation == 'SON' || fatherRelation == 'DAUGHTER-IN-LAW') {
            newRelation = (selectedGender == '(1) Male') ? 'GRAND-SON(S)' : 'GRAND-DAUGHTER(S)';
          } else if (fatherRelation == 'BROTHER' || fatherRelation == 'SISTER-IN-LAW(BW)') {
            newRelation = (selectedGender == '(1) Male') ? 'BROTHER SON' : 'BROTHER DAUGHTER';
          } else if (fatherRelation == 'BROTHER-IN-LAW' || fatherRelation == 'SISTER') {
            newRelation = (selectedGender == '(1) Male') ? 'NEPHEW' : 'NIECE';
          }
        }
        
        if (newRelation == null && motherName != null) {
          final motherDoc = _allMembersList.firstWhere((d) => d['Name'] == motherName, orElse: () => {});
          final motherRelation = motherDoc['Relation_with_Head']?.toString();
          
          if (motherRelation == 'DAUGHTER' || motherRelation == 'SON-IN-LAW') {
            newRelation = (selectedGender == '(1) Male') ? 'GRAND-SON (D)' : 'GRAND-DAUGHTER (D)';
          } else if (motherRelation == 'DAUGHTER-IN-LAW' || motherRelation == 'SON') {
            newRelation = (selectedGender == '(1) Male') ? 'GRAND-SON(S)' : 'GRAND-DAUGHTER(S)';
          }
        }
      }
    }

    if (newRelation != null && newRelation != relationWithHead) {
      _onRelationChanged(newRelation);
    }
  }

  void _onRelationChanged(String? val) {
    if (val == null) return;
    setState(() {
      relationWithHead = val;
      final Map<String, int> mapping = {
        'WIFE RELATIONS': 2, 'WIFE PARENT': 2, 'WIFE BROTHERS WIFE': 3, 'WIFE BROTHERS SON': 4,
        'WIFE BROTHERS DAUGHTER': 4, 'WIFE BROTHER': 3, 'DAUGHTER-IN-LAW': 4, 'GRAND-DAUGHTER-IN-LAW': 5,
        'GREAT GRAND SON (SS)': 6, 'GREAT GRAND DAUGHTER (SS)': 6, 'GRAND-SON(S)': 5, 'SINGLE': 3,
        'SISTER-IN-LAW (U)': 3, 'GREAT GRAND SON(SD)': 6, 'GRAND DAUGHTER HUSBAND(S)': 5,
        'GREAT GRAND DAUGTHER(SD)': 6, 'GRAND-DAUGHTER(S)': 5, 'ADOPTED SON': 4, 'ADOPTED GRAND DAUGHTER': 5,
        'OTHERS': 3, 'MOTHER RELATIONS': 3, 'MOTHERS-IN-LAW': 2, 'SISTER-SON-WIFE': 4, 'SISTER-GRAND-SON': 5,
        'SISTER-GRAND-DAUGHTER': 5, 'NEPHEW': 4, 'BROTHER-IN-LAW': 3, 'SISTER DAUGHTER HUSBAND': 4,
        'NIECE': 4, 'PARENT': 2, 'GRAND PARENT': 1, 'GREAT GRAND PARENT': 0, 'FATHER-IN-LAW': 2,
        'GRAND-DAUGHTER-IN-LAW (S)': 5, 'GREAT-GRAND-SON(DS)': 6, 'GREAT-GRAND-DAUGTHER(DS)': 6,
        'GRAND-SON (D)': 5, 'SON-IN-LAW': 4, 'GREAT GRAND SON (DD)': 6, 'GRAND DAUGHTER HUSBAND(D)': 5,
        'GREAT GRAND DAUGHTER (DD)': 6, 'GRAND-DAUGHTER (D)': 5, 'ADOPTED DAUGHTER': 4, 'SISTER-IN-LAW(BW)': 3,
        'BROTHERS SON WIFE': 4, 'BROTHERS SONS SON': 5, 'BROTHERS SONS DAUGHTER': 5, 'BROTHERS SON ADOPTED': 4,
        'BROTHER SON': 4, 'BROTHER-DAUGHTER-SON(DS)': 5, 'BROTHERS DAUGHTER HUSBAND': 4,
        'BROTHER-DAUGHTER-DAUGHTER(DD)': 5, 'BROTHER DAUGHTER': 4, 'GREAT GRAND DAUGHTER (ASD)': 6,
        'AUNTY': 2, 'ADOPTED GRAND SON': 5, 'ADOPTED GREAT GRAND DAUGHTER': 6, 'HEAD OF THE FAMILY': 3,
        'SISTER': 3, 'BROTHER': 3, 'DAUGHTER': 4, 'UNCLE': 2, 'SON': 4, 'WIFE': 3, 'HUSBAND': 3,
      };
      if (mapping.containsKey(val)) {
        _gen.text = mapping[val].toString();
      }
    });
  }

  void _resetForm({bool keepFamilyContext = false}) {
    _formKey.currentState?.reset();
    
    final String currentCode = _familyCodeController.text;
    final List<Map<String, dynamic>> currentMembers = _allMembersList;
    final List<String> currentMales = maleMembers;
    final List<String> currentFemales = femaleMembers;
    final Map<String, dynamic>? currentHead = _headDoc;

    setState(() {
      _firstName.clear(); _editDocId = null; _spouseNo.clear(); _mapNo.clear();
      _newFamilyId.clear(); _serialNumber.clear(); _fatherRegNo.clear(); _parentsId.clear();
      _relationCode.clear(); _gen.clear();       _siNo.clear(); selectedGender = null;
      _birthWeight.clear(); _regNo.clear(); dateOfBirth = null; _age.clear();
      liveStatus = '(1) Alive'; selectedEducation = null; avStatus = null;
      selectedOccupation = null; maritalStatus = null; _income.clear();
      _aadharNo.clear(); motherName = null; fatherName = null; relationWithHead = null;
      showSpouseDetails = false; spouseNameLookup = null; marriageType = null;
      selectedDeathPlace = null; _deathCause.clear();
      deathDate = null; diseases.updateAll((key, value) => '(2) No');

      if (keepFamilyContext) {
        _familyCodeController.text = currentCode;
        _allMembersList = currentMembers;
        _familyMemberDocs = currentMembers;
        maleMembers = currentMales;
        femaleMembers = currentFemales;
        _headDoc = currentHead;
        _calculateNewFamilyID();
      } else {
        _familyCodeController.clear();
        _allMembersList = [];
        _familyMemberDocs = [];
        maleMembers = [];
        femaleMembers = [];
        _headDoc = null;
      }
    });
  }

  void _loadExistingData([Map<String, dynamic>? data]) {
    final d = data ?? widget.existingData!;
    setState(() {
      _familyCodeController.text = d['Family_Code'] ?? '';
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
      
      // Temporarily remove listener to avoid DOB being overwritten by age calculation default (Jan 1st)
      _age.removeListener(_onAgeChanged);
      _age.text = d['Age']?.toString() ?? '';
      _age.addListener(_onAgeChanged);

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
      spouseNameLookup = d['Name2'] ?? d['Name1']; // Fallback for old records
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

  Future<void> _fetchAndLoadMember(String name) async {
    setState(() => _isLoadingFamily = true);
    try {
      // Fetch from Firestore to get the full, latest data and the correct doc ID
      final fCode = _familyCodeController.text.trim();
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: fCode)
          .where('Name', isEqualTo: name)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        setState(() {
          _editDocId = doc.id; // Use the actual Firestore document ID
          _loadExistingData(data);
        });
      } else {
        // Fallback to local cache if offline
        final localDoc = _allMembersList.firstWhere((m) => m['Name'] == name, orElse: () => {});
        if (localDoc.isNotEmpty) {
          setState(() {
            _editDocId = localDoc['firestoreDocId'] ?? localDoc['id'];
            _loadExistingData(localDoc);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching member: $e');
      // Fallback to local on error
      final localDoc = _allMembersList.firstWhere((m) => m['Name'] == name, orElse: () => {});
      if (localDoc.isNotEmpty) {
        setState(() {
          _editDocId = localDoc['firestoreDocId'] ?? localDoc['id'];
          _loadExistingData(localDoc);
        });
      }
    } finally {
      setState(() => _isLoadingFamily = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final data = {
        'Family_Code': _familyCodeController.text,
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
      // Capture state BEFORE reset so background sync uses the right values
      final bool wasEditing = _isEditMode && _editDocId != null;
      final String? capturedEditDocId = _editDocId;
      final String? capturedWidgetDocId = widget.docId;

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = capturedEditDocId ?? capturedWidgetDocId;

      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('personal_details', data);
      await DataCacheService().addMember(data); 

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Personal details saved locally! Syncing...')),
          backgroundColor: Colors.indigo,
          duration: const Duration(seconds: 1),
        ));

        // Post-Save Dialog for new records
        if (widget.docId != null || wasEditing) {
          if (widget.docId != null) Navigator.pop(context); else _resetForm();
        } else {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text(tr('Record Saved')),
              content: Text(tr('Do you want to add same members in same family code?')),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resetForm(keepFamilyContext: true);
                  },
                  child: Text(tr('Yes')),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: Text(tr('No')),
                ),
              ],
            ),
          );
        }
      }

      // 3. Optional: Reciprocal Spouse Update
      Map<String, dynamic>? spouseUpdate;
      if (spouseNameLookup != null) {
        final spouseRecord = _allMembersList.firstWhere((m) => m['Name'] == spouseNameLookup, orElse: () => {});
        if (spouseRecord.isNotEmpty) {
          spouseUpdate = {
            'Marital_Status': '(1) Married',
            'Spouse_Details1': true,
            'Name2': _firstName.text, // Current member is spouse's spouse
            'Name1': _firstName.text,
            'firestoreDocId': spouseRecord['id'] ?? spouseRecord['firestoreDocId'],
            'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
            'needs_zoho_sync': true,
          };
          await DataCacheService().saveOfflineSubmission('personal_details', spouseUpdate);
        }
      }

      // 2. Background Sync (Non-blocking)
      _performPersonalDetailsSync(
        data, 
        wasEditing: wasEditing, 
        editDocId: capturedEditDocId, 
        widgetDocId: capturedWidgetDocId,
        spouseData: spouseUpdate,
      );

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Error saving')}: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _performPersonalDetailsSync(Map<String, dynamic> data, {required bool wasEditing, String? editDocId, String? widgetDocId, Map<String, dynamic>? spouseData}) async {
    try {
      final String? docId = data['firestoreDocId'] as String? ?? editDocId ?? widgetDocId;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('personal_details').doc(docId).set(data, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
      } else {
        await FirebaseFirestore.instance.collection('personal_details').add(data).timeout(const Duration(seconds: 15));
      }
      
      // Sync Spouse if needed
      if (spouseData != null && spouseData['firestoreDocId'] != null) {
        await FirebaseFirestore.instance.collection('personal_details').doc(spouseData['firestoreDocId']).set(spouseData, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
      }
      
      // Sync Head Of Family if needed
      if (data['Relation_with_Head'] == 'HEAD OF THE FAMILY' && data['Family_Code'] != null) {
        final fCode = data['Family_Code'].toString();
        final hName = data['Name'].toString();
        
        await DataCacheService().updateHeadOfFamily(fCode, hName);

        final familyQuery = await FirebaseFirestore.instance
            .collection('Family Code Creation')
            .where('family_id', isEqualTo: fCode)
            .get();
        if (familyQuery.docs.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('Family Code Creation')
              .doc(familyQuery.docs.first.id)
              .update({
                'head_of_family': hName,
                'Head_of_the_family': hName, // Stay compatible with old code
              });
        }
      }
    } catch (e) {
      debugPrint('Background Sync Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageProvider.instance.isTeluguNotifier,
      builder: (context, isTelugu, _) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: Text(tr('Personal Details')), elevation: 0, actions: const [LanguageToggleButton()]),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('personal_details_scroll'),
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  formActionButtons(
                    context: context,
                    isEditMode: _isEditMode,
                    onNew: () { setState(() { _isEditMode = false; _resetForm(keepFamilyContext: true); }); },
                    onSave: _save,
                    onEdit: () {
                      setState(() {
                        _isEditMode = true;
                        final code = _familyCodeController.text.trim();
                        if (code.isNotEmpty) {
                          _fetchMembersByFamily(code);
                        }
                      });
                    },
                    onCancel: () => _resetForm(),
                    onExit: () => Navigator.pop(context),
                    isSaving: _isSaving,
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingFamily) // Show a small inline loader if fetching member data
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(),
                    )
                  else ...[
                    buildSectionCard(
                      context: context,
                      title: tr('Identity & Registration'),
                      icon: Icons.fingerprint_outlined,
                children: [
                  formSearchField(
                    tr('Family Code'),
                    _familyCodeController,
                    onSearch: () => _fetchMembersByFamily(_familyCodeController.text),
                    isLoading: _isLoadingFamily,
                    validator: (v) => (v == null || v.isEmpty) ? tr('Family Code is required') : null,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: formTextField(tr('Spouse'), _spouseNo, keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: formTextField(tr('Map No.'), _mapNo, keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 12),
                  _isEditMode
                      ? formSearchableDropdown(
                          context,
                          tr('Member to Edit'),
                          _allMembersList.map((m) => m['Name']?.toString() ?? '').where((n) => n.isNotEmpty).toList()..sort(),
                          _firstName.text.isEmpty ? null : _firstName.text,
                          (val) {
                            if (val != null) {
                              _fetchAndLoadMember(val);
                            }
                          },
                          isLoading: _isLoadingFamily,
                          validator: (v) => (v == null || v.isEmpty) ? tr('Please select a member') : null,
                        )
                      : formTextField(
                          tr('Name'),
                          _firstName,
                          validator: (v) => (v == null || v.isEmpty) ? tr('Name is required') : null,
                        ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: formTextField(tr('Gen'), _gen, keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: formTextField(tr('SI No'), _siNo, keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 12),
                  Text(tr('Gender'), style: const TextStyle(fontWeight: FontWeight.w500)),
                  Row(children: [
                    Expanded(child: RadioListTile<String>(title: Text(tr('(1) Male')), value: '(1) Male', groupValue: selectedGender, onChanged: (v) => setState(() { selectedGender = v; _updateAutoRelation(); }), contentPadding: EdgeInsets.zero, dense: true)),
                    Expanded(child: RadioListTile<String>(title: Text(tr('(0) Female')), value: '(0) Female', groupValue: selectedGender, onChanged: (v) => setState(() { selectedGender = v; _updateAutoRelation(); }), contentPadding: EdgeInsets.zero, dense: true)),
                  ]),
                  const SizedBox(height: 12),
                    formTextField(
                      tr('Registration Number'),
                      _regNo,
                      keyboardType: TextInputType.number,
                      readOnly: true,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              buildSectionCard(
                context: context,
                title: tr('Personal Info'),
                icon: Icons.person_outline,
                children: [
                  Row(children: [
                    Expanded(child: _buildDatePicker(tr('Date of Birth'), dateOfBirth, _onDOBChanged)),
                    const SizedBox(width: 12),
                    Expanded(child: formTextField(
                      tr('Age'),
                      _age,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return tr('Age is required');
                        if (int.tryParse(v) == null) return tr('Enter a valid age');
                        return null;
                      },
                    )),
                  ]),
                  const SizedBox(height: 12),
                  formSearchableDropdown(context, tr('Live Status'), ['(1) Alive', '(0) Dead'], liveStatus, (v) => setState(() => liveStatus = v)),
                  const SizedBox(height: 12),
                  formSearchableDropdown(context, tr('A/v Status'), ['(1) Active', '(0) Vacant'], avStatus, (v) => setState(() => avStatus = v)),
                  const SizedBox(height: 12),
                  formSearchableDropdown(context, tr('Marital Status'), ['(0) Unmarried', '(1) Married', '(2) Divorce', '(3) Widow', '(4) Not Eligible'], maritalStatus, (v) { setState(() { maritalStatus = v; if (v == '(0) Unmarried') showSpouseDetails = false; }); }),
                  if (liveStatus == '(0) Dead') ...[
                    const SizedBox(height: 12),
                    formSearchableDropdown(context, tr('Death Place'), ['(0) RHC', '(1) PVT', '(2) GOVT', '(3) HOME'], selectedDeathPlace, (v) => setState(() => selectedDeathPlace = v)),
                    const SizedBox(height: 12),
                    formTextField(tr('Death Cause'), _deathCause),
                    const SizedBox(height: 12),
                    _buildDatePicker(tr('Death Date'), deathDate, (picked) => setState(() => deathDate = picked)),
                  ],
                  const SizedBox(height: 12),
                  if ((int.tryParse(_age.text) ?? 0) > 3)
                    formSearchableDropdown(context, tr('Education'), ['(0) ILLITIRATE', '(1) CAN READ ONLY', '(2) CAN READ AND WRITE', '(3) PRIMARY SCHOOL', '(4) MIDDLE SCHOOL', '(5) HIGH SCHOOL', '(6) GRADUATE', '(7) POST GRADUATE'], selectedEducation, (v) => setState(() => selectedEducation = v)),
                  if ((int.tryParse(_age.text) ?? 0) > 3) const SizedBox(height: 12),
                  if ((int.tryParse(_age.text) ?? 0) > 3)
                    formSearchableDropdown(context, tr('Occupation'), ['(1) HOUSE WIFE', '(2) AGRICULTURE', '(3) UNEMPLOYED', '(4)LABOUR', '(5) SELF-EMPLOYED', '(6) PRIVATE EMPLOYEE', '(7) ANGANWADI TEACHER', '(8) C.H.V', '(9) PENSION', '(10) GOVT EMPLOYEE', '(99) DONT KNOW'], selectedOccupation, (v) => setState(() => selectedOccupation = v)),
                  if ((int.tryParse(_age.text) ?? 0) > 15) const SizedBox(height: 12),
                  if ((int.tryParse(_age.text) ?? 0) > 15) formTextField(tr('Income'), _income),
                  const SizedBox(height: 12),
                  formTextField(
                    tr('Aadhar No.'),
                    _aadharNo,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                    validator: (v) {
                      if (v != null && v.isNotEmpty && v.length != 12) return tr('Aadhar must be 12 digits');
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              buildSectionCard(
                context: context,
                title: tr('Relations'),
                icon: Icons.family_restroom_outlined,
                children: [
                  formSearchableDropdown(context, tr('Mother Name'), femaleMembers, motherName, _onMotherChanged, isLoading: _isLoadingFamily),
                  const SizedBox(height: 12),
                  formSearchableDropdown(context, tr('Father Name'), maleMembers, fatherName, _onFatherChanged, isLoading: _isLoadingFamily),
                  const SizedBox(height: 12),
                  formSearchableDropdown(
                    context,
                    tr('Relation with Head'),
                    ['ADOPTED DAUGHTER', 'ADOPTED GRAND DAUGHTER', 'ADOPTED GRAND SON', 'ADOPTED GREAT GRAND DAUGHTER', 'ADOPTED SON', 'AUNTY', 'BROTHER', 'BROTHER DAUGHTER', 'BROTHER SON', 'BROTHER-DAUGHTER-DAUGHTER(DD)', 'BROTHER-DAUGHTER-SON(DS)', 'BROTHER-IN-LAW', 'BROTHERS DAUGHTER HUSBAND', 'BROTHERS SON ADOPTED', 'BROTHERS SON WIFE', 'BROTHERS SONS DAUGHTER', 'BROTHERS SONS SON', 'BSW', 'DAUGHTER', 'DAUGHTER-IN-LAW', 'FATHER-IN-LAW', 'GRAND DAUGHTER HUSBAND(D)', 'GRAND DAUGHTER HUSBAND(S)', 'GRAND PARENT', 'GRAND-DAUGHTER (D)', 'GRAND-DAUGHTER(S)', 'GRAND-DAUGHTER-IN-LAW', 'GRAND-DAUGHTER-IN-LAW (S)', 'GRAND-SON (D)', 'GRAND-SON(S)', 'GREAT GRAND DAUGHTER (ASD)', 'GREAT GRAND DAUGHTER (DD)', 'GREAT GRAND DAUGHTER (SS)', 'GREAT GRAND DAUGTHER(SD)', 'GREAT GRAND PARENT', 'GREAT GRAND SON (DD)', 'GREAT GRAND SON (SS)', 'GREAT GRAND SON(SD)', 'GREAT-GRAND-DAUGTHER(DS)', 'GREAT-GRAND-SON(DS)', 'HEAD OF THE FAMILY', 'HUSBAND', 'MOTHER RELATIONS', 'MOTHERS-IN-LAW', 'NEPHEW', 'NIECE', 'OTHERS', 'PARENT', 'SINGLE', 'SISTER', 'SISTER DAUGHTER HUSBAND', 'SISTER-GRAND-DAUGHTER', 'SISTER-GRAND-SON', 'SISTER-IN-LAW (U)', 'SISTER-IN-LAW(BW)', 'SISTER-SON-WIFE', 'SON', 'SON-IN-LAW', 'UNCLE', 'WIFE', 'WIFE BROTHER', 'WIFE BROTHERS DAUGHTER', 'WIFE BROTHERS SON', 'WIFE BROTHERS WIFE', 'WIFE PARENT', 'WIFE RELATIONS'],
                    relationWithHead,
                    _onRelationChanged,
                    validator: (v) => (v == null || v.isEmpty) ? tr('Relation with Head is required') : null,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(title: Text(tr('Spouse Details')), value: showSpouseDetails, enabled: maritalStatus != '(0) Unmarried', onChanged: maritalStatus == '(0) Unmarried' ? null : (v) => setState(() => showSpouseDetails = v ?? false), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero),
                  if (showSpouseDetails) ...[
                    const SizedBox(height: 12),
                    formSearchableDropdown(context, tr('Select Spouse'), selectedGender == '(1) Male' ? femaleMembers : maleMembers, spouseNameLookup, _onSpouseChanged, isLoading: _isLoadingFamily),
                    const SizedBox(height: 12),
                    formSearchableDropdown(context, tr('Marriage Type'), ['Married In', 'Married Out'], marriageType, (v) => setState(() => marriageType = v)),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              buildSectionCard(
                context: context,
                title: tr('Health Status'),
                icon: Icons.health_and_safety_outlined,
                children: [
                  ...diseases.keys.map((d) => Column(children: [
                    ListTile(title: Text(tr(d), style: const TextStyle(fontSize: 13)), trailing: SizedBox(width: 150, child: Row(children: [
                      Expanded(child: RadioListTile<String>(title: Text(tr('Yes'), style: const TextStyle(fontSize: 11)), value: '(1) Yes', groupValue: diseases[d], onChanged: (v) => setState(() => diseases[d] = v), contentPadding: EdgeInsets.zero, dense: true)),
                      Expanded(child: RadioListTile<String>(title: Text(tr('No'), style: const TextStyle(fontSize: 11)), value: '(2) No', groupValue: diseases[d], onChanged: (v) => setState(() => diseases[d] = v), contentPadding: EdgeInsets.zero, dense: true)),
                    ]))),
                    const Divider(),
                  ])),
                ],
              ),
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onPicked) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      InkWell(
        onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
          if (picked != null) onPicked(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), suffixIcon: const Icon(Icons.calendar_today, size: 18)),
          child: Text(selectedDate == null ? 'dd-MMM-yyyy' : DateFormat('dd-MMM-yyyy').format(selectedDate)),
        ),
      ),
    ]);
  }
}
