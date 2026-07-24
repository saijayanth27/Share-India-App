import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'local_database_service.dart';
import 'sync_service.dart';
import 'widget.dart';
import 'home_page.dart';

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
  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;
  bool _isDownloadingMembers = false;
  int _downloadProgress = 0;
  bool _membersAlreadyDownloaded = false;
  String? _membersDownloadedAt;
  bool _isActionActive = false; // Add this
  bool _isEditMode = false;
  String? _editDocId = null;
  List<Map<String, dynamic>> _allMembersList = [];
  final FocusNode _nameNode = FocusNode();
  final FocusNode _familyCodeNode = FocusNode();

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
  String? familyType;
  final _income = TextEditingController();
  final _aadharNo = TextEditingController();

  // --- Death Details (shown if liveStatus == '(0) Dead') ---
  String? selectedDeathPlace;
  final _deathCause = TextEditingController();
  DateTime? deathDate;

  // --- Relations Controllers ---
  String? motherName = 'No Mother';
  String? fatherName = 'No Father';
  String? relationWithHead;
  bool showSpouseDetails = false;
  String? spouseNameLookup;
  Map<String, dynamic>? _headDoc;
  String? marriageType;
  String? _familyMapNo;

  // Family Members for Dropdowns
  List<String> maleMembers = [];
  List<String> femaleMembers = [];
  List<String> eligibleMothers = [];
  List<String> eligibleFathers = [];
  List<Map<String, dynamic>> _familyMemberDocs = []; // Cache for full docs
  bool _isLoadingFamily = false;

  // --- Diseases (1) Yes / (2) No ---
  Map<String, String?> diseases = {
    'Asthma?': null,
    'Diabetes?': null,
    'Hypertension?': null,
    'Thyroid?': null,
    'Malaria (Last 6 Months)': null,
    'Jaundice (Last 6 Months)': null,
    'Panmasala (Currently)': null,
    'Drink Alcohol (Currently)?': null,
    'Smoke (Currently)?': null,
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialFamilyCode != null) {
      _familyCodeController.text = widget.initialFamilyCode!;
      _fetchMembersByFamily(widget.initialFamilyCode!);
      // Auto-enable "New" mode if we're coming from Family registration
      if (widget.existingData == null) {
        _isActionActive = true;
        _isEditMode = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _nameNode.requestFocus();
        });
      }
    }
    if (widget.existingData != null) {
      _isEditMode = true;
      _editDocId = widget.docId;
      _loadExistingData();
      // Fetch all family members so mother/father/spouse dropdowns are populated in edit mode
      final familyCode = (widget.existingData!['Family_Code'] ?? '').toString();
      if (familyCode.isNotEmpty) {
        _fetchMembersByFamily(familyCode);
      }
    }
    _mapNo.addListener(() {
      if (_mapNo.text.isNotEmpty) {
        _familyMapNo = _mapNo.text;
      }
    });
    _age.addListener(_onAgeChanged);
    _loadDownloadStatus();
  }

  Future<void> _loadDownloadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString('members_download_timestamp');
    if (ts != null && mounted) {
      setState(() {
        _membersAlreadyDownloaded = true;
        _membersDownloadedAt = ts;
      });
    }
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
    _nameNode.dispose();
    _familyCodeNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _getNormalizedGender(String? raw) {
    if (raw == null) return '';
    final l = raw.toLowerCase().trim();
    if (l == '1' || l == '(1) male' || l == 'male') return '(1) Male';
    if (l == '0' || l == '(0) female' || l == 'female') return '(0) Female';
    return raw;
  }

  void _onAgeChanged() {
    if (_age.text.isEmpty) {
      if (dateOfBirth != null) {
        setState(() {
          dateOfBirth = null;
        });
      }
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

      // Default Marital Status for individuals >= 15
      if (ageInt >= 15 && (maritalStatus == null || maritalStatus == '(4) Not Eligible' || maritalStatus!.isEmpty) && !_isEditMode) {
        setState(() {
          maritalStatus = '(0) Unmarried';
        });
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

      // Default Marital Status for individuals >= 15
      if (ageCount >= 15 && (maritalStatus == null || maritalStatus == '(4) Not Eligible' || (maritalStatus?.isEmpty ?? true)) && !_isEditMode) {
        maritalStatus = '(0) Unmarried';
      }
    });
  }

  Future<void> _fetchMembersByFamily(String familyCode) async {
    setState(() => _isLoadingFamily = true);
    try {
      final fCode = familyCode.trim().toUpperCase();
      if (fCode.isEmpty) {
        setState(() => _isLoadingFamily = false);
        return;
      }

      // 1. Fetch Members (Local First)
      final localMembers = await DataCacheService().fetchMembersLocally(fCode);
      final Map<String, Map<String, dynamic>> merged = {};
      for (var m in localMembers) merged[m['Name'] ?? ''] = m;

      // 2. Try to get Head Name from Local Cache
      String? headNameFromFamily;
      final details = await DataCacheService().fetchFamilyDetails();
      final detail = details.firstWhere((d) => (d['family_id']?.toString().toUpperCase() ?? '') == fCode, orElse: () => {});
      if (detail.isNotEmpty) {
        headNameFromFamily = (detail['head_of_family'] ?? detail['Head_of_the_family'])?.toString();
      }

      // Update state with local data immediately
      _updateMembersState(merged.values.toList(), headNameFromFamily);

      // 3. Background: Fetch from Firestore (Head & Members)
      try {
        final familySnap = await FirebaseFirestore.instance
            .collection('Family Code Creation')
            .where('family_id', isEqualTo: fCode)
            .limit(1)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 4));

        if (familySnap.docs.isNotEmpty) {
          final data = familySnap.docs.first.data();
          headNameFromFamily = (data['head_of_family'] ?? data['Head_of_the_family'])?.toString();
          // Cache the family header too while we're at it
          await DataCacheService().addGeneratedDetail({...data, 'family_id': fCode});
        }

        final snapshot = await FirebaseFirestore.instance
            .collection('personal_details')
            .where('Family_Code', isEqualTo: fCode)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 4));

        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['firestoreDocId'] = doc.id;
          merged[data['Name'] ?? ''] = data;
          
          // NEW: Persist to local cache for offline availability
          await DataCacheService().addMember(data);
        }
        
        // Final update with combined data
        _updateMembersState(merged.values.toList(), headNameFromFamily);

        // If a member is already displayed and their fresh data now has Father_Name/Mother_Name,
        // silently refresh the form so those fields show without requiring a re-selection.
        final displayedName = _firstName.text.trim();
        if (displayedName.isNotEmpty && merged.containsKey(displayedName)) {
          final fresh = merged[displayedName]!;
          final hasFresh = fresh.containsKey('Father_Name') || fresh.containsKey('Mother_Name');
          if (hasFresh && mounted) _loadExistingData(fresh);
        }
      } catch (e) {
        debugPrint('Firestore fetch failed/timed out, using local data: $e');
      }


      setState(() => _isLoadingFamily = false);
    } catch (e) {
      debugPrint('Error fetching members: $e');
      setState(() => _isLoadingFamily = false);
    }
  }

  void _updateMembersState(List<Map<String, dynamic>> docs, String? headNameFromFamily) {
    final marriedMales = <String>[];
    final marriedFemales = <String>[];
    final unmarriedAdultMales = <String>[];
    final unmarriedAdultFemales = <String>[];

    for (var data in docs) {
      final name = data['Name']?.toString() ?? '';
      final gender = data['Gender']?.toString() ?? '';
      final marital = data['Marital_Status']?.toString() ?? '';
      final ageStr = data['Age']?.toString() ?? '0';
      final age = int.tryParse(ageStr) ?? 0;
      
      // Broadened logic: Anyone 15+ can potentially be a parent dropdown option
      // even if not yet marked as Married (to handle cases where parents are added as children first)
      final isAdult = age >= 15;
      final isMarriedOrFormerly = !marital.contains('(0) Unmarried') && !marital.contains('(4) Not Eligible');
      final isUnmarriedAdult = marital.contains('(0) Unmarried') && age >= 18;

      final genderNormal = _getNormalizedGender(gender);
      if (genderNormal == '(0) Female') {
        if (isAdult || isMarriedOrFormerly) marriedFemales.add(name);
        if (isUnmarriedAdult) unmarriedAdultFemales.add(name);
      } else if (genderNormal == '(1) Male') {
        if (isAdult || isMarriedOrFormerly) marriedMales.add(name);
        if (isUnmarriedAdult) unmarriedAdultMales.add(name);
      }

      // Auto-detect Map No for the family if not already known
      if (_familyMapNo == null || _familyMapNo!.isEmpty) {
        final mNo = (data['Map_No'] ?? data['Map_No.'] ?? '').toString();
        if (mNo.isNotEmpty) {
          _familyMapNo = mNo;
        }
      }
    }

    if (_familyMapNo != null && _mapNo.text.isEmpty) {
      _mapNo.text = _familyMapNo!;
    }

    setState(() {
      _familyMemberDocs = docs;
      _allMembersList = docs;
      
      eligibleFathers = ['No Father', ...List<String>.from(marriedMales)..sort()];
      eligibleMothers = ['No Mother', ...List<String>.from(marriedFemales)..sort()];
      
      // Spouse selection includes both currently married (for editing) and unmarried adults (for new marriages)
      maleMembers = List<String>.from({...marriedMales, ...unmarriedAdultMales})..sort();
      femaleMembers = List<String>.from({...marriedFemales, ...unmarriedAdultFemales})..sort();


      _headDoc = docs.firstWhere(
        (d) {
          final rel = (d['Relation_with_Head'] ?? '').toString().toUpperCase().trim();
          return rel == 'HEAD OF THE FAMILY' || rel == 'HEAD OF FAMILY';
        },
        orElse: () => headNameFromFamily != null ? {'Name': headNameFromFamily, 'Relation_with_Head': 'HEAD OF THE FAMILY'} : {},
      );

      if (!_isEditMode) {
        _calculateNewFamilyID();
      }
    });
  }


  void _calculateNewFamilyID() {
    if (_familyCodeController.text.isEmpty) return;
    final baseID = _familyCodeController.text.trim().toUpperCase();
    // Matches Zoho alphabets (L intentionally excluded)
    const alphabets = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    // 1. Head of family always uses the base Family Code (no suffix)
    if (relationWithHead == 'HEAD OF THE FAMILY') {
      _newFamilyId.text = baseID;
      return;
    }

    // 2. Spouse-based logic — mirrors Zoho: only runs when Name2 is selected
    if (spouseNameLookup != null && spouseNameLookup!.isNotEmpty) {
      final spouseDoc = _allMembersList.firstWhere(
        (m) => (m['Name'] ?? '').toString().toUpperCase().trim() == spouseNameLookup!.toUpperCase().trim(),
        orElse: () => {},
      );

      if (spouseDoc.isNotEmpty) {
        final spouseRel = (spouseDoc['Relation_with_Head'] ?? '').toString().toUpperCase().trim();

        // Zoho: if spouse is HEAD OF THE FAMILY → empty block (do nothing / keep base)
        if (spouseRel == 'HEAD OF THE FAMILY') {
          _newFamilyId.text = baseID;
          return;
        }

        // Check a.Name2 — if already set, this spouse is already linked (existing marriage)
        final spouseName1 = (spouseDoc['Name2'] ?? '').toString().trim();
        if (spouseName1.isNotEmpty) {
          // Already married — inherit existing New_Family_ID without generating a new suffix
          final existingId = (spouseDoc['New_Family_ID'] ?? '').toString().toUpperCase().trim();
          _newFamilyId.text = existingId.isNotEmpty ? existingId : baseID;
          return;
        }

        // New marriage — generate next suffix letter
        // Zoho: distinct New_Family_IDs → real_data.size() - 1 → alphabets[dupsize]
        final distinctIds = _allMembersList
            .map((m) => (m['New_Family_ID'] ?? '').toString().toUpperCase().trim())
            .where((id) => id.isNotEmpty)
            .toSet();
        final int dupsize = distinctIds.isEmpty ? 0 : (distinctIds.length - 1);
        if (dupsize < alphabets.length) {
          _newFamilyId.text = baseID + alphabets[dupsize];
        }
        return;
      }
    }

    // 3. No spouse — inherit New_Family_ID from parent (father first, then mother)
    String? parentInheritedID;
    if (fatherName != null && fatherName != 'No Father') {
      final fDoc = _allMembersList.firstWhere(
        (m) => (m['Name'] ?? '').toString().toUpperCase().trim() == fatherName!.toUpperCase().trim(),
        orElse: () => {},
      );
      if (fDoc.isNotEmpty) parentInheritedID = (fDoc['New_Family_ID'] ?? '').toString().toUpperCase().trim();
    }
    if ((parentInheritedID == null || parentInheritedID.isEmpty) && motherName != null && motherName != 'No Mother') {
      final mDoc = _allMembersList.firstWhere(
        (m) => (m['Name'] ?? '').toString().toUpperCase().trim() == motherName!.toUpperCase().trim(),
        orElse: () => {},
      );
      if (mDoc.isNotEmpty) parentInheritedID = (mDoc['New_Family_ID'] ?? '').toString().toUpperCase().trim();
    }

    // 4. Fall back to parent's unit or base
    _newFamilyId.text = (parentInheritedID != null && parentInheritedID.isNotEmpty)
        ? parentInheritedID
        : baseID;
  }

  void _onSpouseChanged(String? val) {
    if (val == null || val.isEmpty) return;

    // Check if spouse is already married
    bool isAlreadyMarried = false;
    for (var member in _allMembersList) {
      final mName = (member['Name'] ?? '').toString().toUpperCase().trim();
      if (mName == val.toUpperCase().trim()) {
        if (member['Marital_Status'] == '(1) Married') {
          isAlreadyMarried = true;
          break;
        }
      }
    }

    if (isAlreadyMarried) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Duplicate Status'),
          content: Text("Selected Person '$val' is already marked as Married in the database."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    }

    // Exact string from dropdown items to ensure perfect match
    const String marriedString = '(1) Married';

    setState(() {
      print('DEBUG: Setting status to $marriedString for spouse $val');
      spouseNameLookup = val;
      maritalStatus = marriedString;
      showSpouseDetails = true;
      avStatus = '(1) Active';

      if (selectedGender == '(0) Female') {
        marriageType = 'Married In';
      }

      _updateAutoRelation();
      // Calculate New_Family_ID BEFORE modifying spouse's Name2 in _allMembersList.
      // If we set Name2 first, _calculateNewFamilyID would think the spouse is already
      // married (Name2 non-empty) and skip suffix generation.
      _calculateNewFamilyID();

      // Reciprocal update for target spouse (done after ID calculation)
      for (var i = 0; i < _allMembersList.length; i++) {
        final mName = (_allMembersList[i]['Name'] ?? '').toString().toUpperCase().trim();
        if (mName == val.toUpperCase().trim()) {
           _allMembersList[i]['Marital_Status'] = marriedString;
           _allMembersList[i]['Spouse_Details1'] = true;
           _allMembersList[i]['Name2'] = _firstName.text;
           break;
        }
      }
    });
  }

  void _onFatherChanged(String? val) {
    setState(() {
      fatherName = val;
      _updateAutoRelation();
      _calculateNewFamilyID();
    });
  }

  void _onMotherChanged(String? val) {
    setState(() {
      motherName = val;
      _updateAutoRelation();
      _calculateNewFamilyID();
    });
  }

  void _updateAutoRelation() {
    if (_headDoc == null || _headDoc!.isEmpty) return;
    final headName = (_headDoc!['Name'] ?? '').toString().toUpperCase().trim();
    if (headName.isEmpty) return;

    // Don't auto-assign until gender is known — avoids defaulting to wrong relation
    final gender = _getNormalizedGender(selectedGender);
    if (gender.isEmpty) return;
    final isMale = gender == '(1) Male';

    String? newRelation;

    // 1. Spouse-based Logic (Highest Priority)
    if (spouseNameLookup != null && spouseNameLookup!.isNotEmpty) {
      final sName = spouseNameLookup!.toUpperCase().trim();
      if (sName == headName) {
        // Spouse is head → HUSBAND or WIFE
        newRelation = isMale ? 'HUSBAND' : 'WIFE';
      } else {
        final spouseDoc = _allMembersList.firstWhere(
          (m) => (m['Name'] ?? '').toString().toUpperCase().trim() == sName,
          orElse: () => {},
        );
        if (spouseDoc.isNotEmpty) {
          // Normalize stored relation to uppercase for safe comparison
          final spouseRel = (spouseDoc['Relation_with_Head'] ?? '').toString().toUpperCase().trim();
          if (spouseRel == 'SON' || spouseRel == 'ADOPTED SON') {
            if (!isMale) newRelation = 'DAUGHTER-IN-LAW';
          } else if (spouseRel == 'DAUGHTER' || spouseRel == 'ADOPTED DAUGHTER') {
            if (isMale) newRelation = 'SON-IN-LAW';
          } else if (spouseRel == 'BROTHER') {
            if (!isMale) newRelation = 'SISTER-IN-LAW (U)';
          } else if (spouseRel == 'SISTER') {
            if (isMale) newRelation = 'BROTHER-IN-LAW';
          } else if (spouseRel == 'GRAND-SON(S)' || spouseRel == 'GRAND-SON (D)') {
            if (!isMale) newRelation = 'GRAND-DAUGHTER-IN-LAW';
          } else if (spouseRel == 'GRAND-DAUGHTER(S)' || spouseRel == 'GRAND-DAUGHTER (D)') {
            if (isMale) newRelation = 'GRAND DAUGHTER HUSBAND(S)';
          } else if (spouseRel == 'WIFE' || spouseRel == 'HUSBAND') {
            // Spouse of head's spouse (second marriage) — keep base relation
            newRelation = isMale ? 'HUSBAND' : 'WIFE';
          } else if (spouseRel == 'BROTHER SON') {
            if (!isMale) newRelation = 'BROTHERS SON WIFE';
          } else if (spouseRel == 'BROTHER DAUGHTER') {
            if (isMale) newRelation = 'BROTHERS DAUGHTER HUSBAND';
          }
        }
      }
    }

    // 2. Parent-based Logic (only when no spouse is set)
    if (newRelation == null) {
      final fName = (fatherName ?? '').toString().toUpperCase().trim();
      final mName = (motherName ?? '').toString().toUpperCase().trim();

      if ((fName.isNotEmpty && fName == headName) || (mName.isNotEmpty && mName == headName)) {
        // Direct child of head
        newRelation = isMale ? 'SON' : 'DAUGHTER';
      } else {
        // Derive from father's relation first
        if (fName.isNotEmpty && fName != 'NO FATHER') {
          final fatherDoc = _allMembersList.firstWhere(
            (d) => (d['Name'] ?? '').toString().toUpperCase().trim() == fName, orElse: () => {});
          final fRel = (fatherDoc['Relation_with_Head'] ?? '').toString().toUpperCase().trim();

          if (fRel == 'SON' || fRel == 'DAUGHTER-IN-LAW') {
            newRelation = isMale ? 'GRAND-SON(S)' : 'GRAND-DAUGHTER(S)';
          } else if (fRel == 'DAUGHTER' || fRel == 'SON-IN-LAW') {
            newRelation = isMale ? 'GRAND-SON (D)' : 'GRAND-DAUGHTER (D)';
          } else if (fRel == 'BROTHER' || fRel == 'SISTER-IN-LAW(BW)' || fRel == 'SISTER-IN-LAW (U)') {
            newRelation = isMale ? 'BROTHER SON' : 'BROTHER DAUGHTER';
          } else if (fRel == 'BROTHER-IN-LAW' || fRel == 'SISTER') {
            newRelation = isMale ? 'NEPHEW' : 'NIECE';
          } else if (fRel == 'GRAND-SON(S)' || fRel == 'GRAND-SON (D)' ||
                     fRel == 'GRAND-DAUGHTER(S)' || fRel == 'GRAND-DAUGHTER (D)' ||
                     fRel == 'GRAND-DAUGHTER-IN-LAW' || fRel == 'GRAND DAUGHTER HUSBAND(S)') {
            newRelation = isMale ? 'GREAT GRAND SON (SS)' : 'GREAT GRAND DAUGHTER (SS)';
          }
        }

        // Fall back to mother's relation if father gave nothing
        if (newRelation == null && mName.isNotEmpty && mName != 'NO MOTHER') {
          final motherDoc = _allMembersList.firstWhere(
            (d) => (d['Name'] ?? '').toString().toUpperCase().trim() == mName, orElse: () => {});
          final mRel = (motherDoc['Relation_with_Head'] ?? '').toString().toUpperCase().trim();

          if (mRel == 'DAUGHTER' || mRel == 'SON-IN-LAW') {
            newRelation = isMale ? 'GRAND-SON (D)' : 'GRAND-DAUGHTER (D)';
          } else if (mRel == 'DAUGHTER-IN-LAW' || mRel == 'SON') {
            newRelation = isMale ? 'GRAND-SON(S)' : 'GRAND-DAUGHTER(S)';
          } else if (mRel == 'WIFE' || mRel == 'HUSBAND') {
            // Child of head's spouse = head's child
            newRelation = isMale ? 'SON' : 'DAUGHTER';
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
      _calculateNewFamilyID();
    });
  }

  void _resetForm({bool keepFamilyContext = true, bool resetAction = true}) {
    setState(() {
      if (resetAction) _isActionActive = false;
      _isEditMode = false;
      // NOTE: _formKey.currentState?.reset() is intentionally NOT called here.
      // Calling reset() inside setState uses the OLD widget's initialValue (stale),
      // so FormField dropdowns (mother, father, etc.) would reset to the previous
      // selection rather than 'No Mother'/'No Father'. The post-frame callback below
      // runs AFTER the rebuild, when initialValues already reflect the new state.

      final String currentCode = _familyCodeController.text;
      final List<Map<String, dynamic>> currentMembers = _allMembersList;
      final List<String> currentMales = maleMembers;
      final List<String> currentFemales = femaleMembers;
      final List<String> currentMothers = eligibleMothers;
      final List<String> currentFathers = eligibleFathers;
      final Map<String, dynamic>? currentHead = _headDoc;

      _firstName.clear(); _editDocId = null; _spouseNo.clear(); _mapNo.clear();
      _newFamilyId.clear(); _serialNumber.clear(); _fatherRegNo.clear(); _parentsId.clear();
      _relationCode.clear(); _gen.clear();       _siNo.clear(); selectedGender = null;
      _birthWeight.clear(); _regNo.clear(); dateOfBirth = null; _age.clear();
      liveStatus = '(1) Alive'; selectedEducation = null; avStatus = null;
      selectedOccupation = null; maritalStatus = null; _income.clear();
      _aadharNo.clear(); motherName = 'No Mother'; fatherName = 'No Father'; relationWithHead = null;
      showSpouseDetails = false; spouseNameLookup = null; marriageType = null;
      selectedDeathPlace = null; _deathCause.clear();
      deathDate = null; 
      diseases.updateAll((key, value) => null); // Reset to null

      if (keepFamilyContext) {
        _familyCodeController.text = currentCode;
        _mapNo.text = _familyMapNo ?? '';
        _allMembersList = currentMembers;
        _familyMemberDocs = currentMembers;
        maleMembers = currentMales;
        femaleMembers = currentFemales;
        eligibleMothers = currentMothers;
        eligibleFathers = currentFathers;
        _headDoc = currentHead;
        
        // Ensure New Family ID is cleared so it re-calculates fresh
        _newFamilyId.clear();
        _calculateNewFamilyID();
      } else {
        _familyCodeController.text = 'TSRRMED';
        _newFamilyId.clear();
        _mapNo.clear();
        _allMembersList = [];
        _familyMemberDocs = [];
        maleMembers = [];
        femaleMembers = [];
        eligibleMothers = [];
        eligibleFathers = [];
        _headDoc = null;
      }
    });

    // Reset FormField widgets AFTER the rebuild so their initialValues
    // already reflect the reset state (e.g., 'No Mother', 'No Father').
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _formKey.currentState?.reset();
    });
  }

  void _loadExistingData([Map<String, dynamic>? data]) {
    final d = data ?? widget.existingData!;
    setState(() {
      _familyCodeController.text = d['Family_Code']?.toString() ?? '';
      _spouseNo.text = d['Spouse']?.toString() ?? '';
      final mNo = (d['Map_No'] ?? d['Map_No.'] ?? '').toString();
      _mapNo.text = mNo.isNotEmpty ? mNo : (_familyMapNo ?? '');
      _newFamilyId.text = d['New_Family_ID']?.toString() ?? '';
      _serialNumber.text = d['Registration_Number1']?.toString() ?? '';
      _fatherRegNo.text = d['Father_Registration_Number']?.toString() ?? '';
      _parentsId.text = d['Parents_ID']?.toString() ?? '';
      _relationCode.text = d['Relation_Code']?.toString() ?? '';
      _firstName.text = d['Name']?.toString() ?? '';
      _gen.text = d['Gen']?.toString() ?? '';
      _siNo.text = d['SI_No']?.toString() ?? '';
      selectedGender = _getNormalizedGender(d['Gender']?.toString());
      _birthWeight.text = d['Birth_weight']?.toString() ?? '';
      _regNo.text = d['uniq_Registration_Number']?.toString() ?? '';
      
      if (d['Date_of_Birth'] != null) {
        dateOfBirth = d['Date_of_Birth'] is Timestamp ? (d['Date_of_Birth'] as Timestamp).toDate() : DateTime.tryParse(d['Date_of_Birth'].toString());
      }
      
      // Temporarily remove listener to avoid DOB being overwritten by age calculation default (Jan 1st)
      _age.removeListener(_onAgeChanged);
      _age.text = d['Age']?.toString() ?? '';
      _age.addListener(_onAgeChanged);

      // Live status: app field → REACH REL_LIVE_ST (0=Died, 1=Alive)
      final rawLiveSt = d['Live_Status'] ?? d['REL_LIVE_ST'];
      if (rawLiveSt != null) {
        final s = rawLiveSt.toString().trim();
        liveStatus = (s == '1') ? '(1) Alive' : (s == '0') ? '(0) Dead' : s;
      } else {
        liveStatus = '(1) Alive';
      }
      // Normalize REACH integer codes → app string values
      final rawMarital = d['Marital_Status'];
      if (rawMarital != null) {
        final s = rawMarital.toString().trim();
        const maritalMap = {'0': '(0) Unmarried', '1': '(1) Married', '2': '(2) Divorce', '3': '(3) Widow', '4': '(4) Not Eligible'};
        maritalStatus = maritalMap[s] ?? (s.isEmpty ? '(0) Unmarried' : s);
      } else {
        maritalStatus = '(0) Unmarried';
      }

      final rawEdu = d['Education'];
      if (rawEdu != null) {
        final s = rawEdu.toString().trim();
        const eduMap = {'0': '(0) ILLITIRATE', '1': '(1) CAN READ ONLY', '2': '(2) CAN READ AND WRITE', '3': '(3) PRIMARY SCHOOL', '4': '(4) MIDDLE SCHOOL', '5': '(5) HIGH SCHOOL', '6': '(6) GRADUATE', '7': '(7) POST GRADUATE'};
        selectedEducation = eduMap[s] ?? (s.isEmpty ? null : s);
      } else {
        selectedEducation = null;
      }

      final rawOcc = d['Occupation'];
      if (rawOcc != null) {
        final s = rawOcc.toString().trim();
        const occMap = {'1': '(1) HOUSE WIFE', '2': '(2) AGRICULTURE', '3': '(3) UNEMPLOYED', '4': '(4)LABOUR', '5': '(5) SELF-EMPLOYED', '6': '(6) PRIVATE EMPLOYEE', '7': '(7) ANGANWADI TEACHER', '8': '(8) C.H.V', '9': '(9) PENSION', '10': '(10) GOVT EMPLOYEE', '99': '(99) DONT KNOW'};
        selectedOccupation = occMap[s] ?? (s.isEmpty ? null : s);
      } else {
        selectedOccupation = null;
      }

      final rawAv = d['A_v_Status'];
      if (rawAv != null) {
        final s = rawAv.toString().trim();
        avStatus = (s == '1') ? '(1) Active' : (s == '0') ? '(0) Vacant' : (s.isEmpty ? '(1) Active' : s);
      } else {
        avStatus = '(1) Active';
      }
      familyType = d['Family_Type'];
      _income.text = d['Income']?.toString() ?? '';
      _aadharNo.text = d['Aadhar_No1']?.toString() ?? '';
      final rawMother = d['Mother_Name']?.toString().trim() ?? '';
      motherName = rawMother.isNotEmpty ? rawMother : 'No Mother';
      final rawFather = d['Father_Name']?.toString().trim() ?? '';
      fatherName = rawFather.isNotEmpty ? rawFather : 'No Father';
      debugPrint('✅ _loadExistingData: name=${d['Name']}, fatherName=$fatherName, motherName=$motherName, rawFather="$rawFather", rawMother="$rawMother")');
      debugPrint('✅ eligibleFathers=$eligibleFathers');
      debugPrint('✅ eligibleMothers=$eligibleMothers');
      relationWithHead = d['Relation_with_Head'];
      showSpouseDetails = d['Spouse_Details1'] ?? false;
      spouseNameLookup = d['Name2'];
      marriageType = d['Marriage_Type'];
      // Death place: app field → REACH EXPR_AT (0=RHC,1=PVT,2=GOVT,3=HOME)
      final rawExprAt = d['Death_Place'] ?? d['EXPR_AT'];
      if (rawExprAt != null) {
        const dpMap = {'0': '(0) RHC', '1': '(1) PVT', '2': '(2) GOVT', '3': '(3) HOME'};
        final s = rawExprAt.toString().trim();
        selectedDeathPlace = dpMap[s] ?? (s.isEmpty ? null : s);
      }
      _deathCause.text = d['Death_Cause'] ?? '';

      // Death date: app field → REACH EXPR_DT fallback
      final rawDeathDate = d['Death_Date'] ?? d['EXPR_DT'];
      if (rawDeathDate != null) {
        if (rawDeathDate is Timestamp) {
          deathDate = rawDeathDate.toDate();
        } else if (rawDeathDate is Map) {
          final s = rawDeathDate['_seconds'] ?? rawDeathDate['seconds'];
          if (s != null) deathDate = DateTime.fromMillisecondsSinceEpoch((s as int) * 1000);
        } else {
          final s = rawDeathDate.toString();
          deathDate = DateTime.tryParse(s);
          if (deathDate == null) {
            try { deathDate = DateFormat('dd-MMM-yyyy').parse(s); } catch (_) {}
          }
        }
      }

      // Disease fields: app field → REACH RELATIONS field → normalize 1/2 → '(1) Yes'/'(2) No'
      String? normDis(dynamic appVal, dynamic reachVal) {
        final raw = appVal ?? reachVal;
        if (raw == null) return null;
        final s = raw.toString().trim();
        if (s == '1' || s == '(1) Yes') return '(1) Yes';
        if (s == '2' || s == '(2) No') return '(2) No';
        return s.isEmpty ? null : s;
      }
      diseases['Asthma?'] = normDis(d['Asthma'], d['ASTHMA']);
      diseases['Diabetes?'] = normDis(d['Diabetes'], d['DIABETES']);
      diseases['Hypertension?'] = normDis(d['Hypertensive'], d['HTN']);
      diseases['Thyroid?'] = normDis(d['Thyroid'], d['THYROID']);
      diseases['Malaria (Last 6 Months)'] = normDis(d['Malaria_last_6m'], d['MALARIA']);
      diseases['Jaundice (Last 6 Months)'] = normDis(d['jaundice_last_6m'], d['JAUNDICE']);
      diseases['Panmasala (Currently)'] = normDis(d['Panmasala_currently'], d['PANMASALA']);
      diseases['Drink Alcohol (Currently)?'] = normDis(d['Drink_alcohol_currently'], d['ALCOHOL']);
      diseases['Smoke (Currently)?'] = normDis(d['Smoke_currently'], d['SMOKE']);
    });
  }

  Future<void> _fetchAndLoadMember(String name) async {
    debugPrint('🔍 _fetchAndLoadMember: name="$name", _allMembersList.length=${_allMembersList.length}');
    // 1. Use already-loaded in-memory data first — instant, no network needed.
    final cached = _allMembersList.firstWhere(
      (m) => (m['Name']?.toString() ?? '') == name,
      orElse: () => {},
    );
    debugPrint('🔍 cached.isNotEmpty=${cached.isNotEmpty}, cached.keys=${cached.keys.toList()}');
    debugPrint('🔍 Father_Name=${cached['Father_Name']}, Mother_Name=${cached['Mother_Name']}');
    if (cached.isNotEmpty) {
      _editDocId = cached['firestoreDocId']?.toString() ?? cached['id']?.toString();
      _loadExistingData(cached);
      return;
    }

    // 2. Not in memory — fetch from Firestore (e.g. member added on another device).
    setState(() => _isLoadingFamily = true);
    try {
      final fCode = _familyCodeController.text.trim().toUpperCase();
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: fCode)
          .where('Name', isEqualTo: name)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 8));

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        data['firestoreDocId'] = doc.id;
        await DataCacheService().addMember(data);
        _editDocId = doc.id;
        _loadExistingData(data);
      }
    } catch (e) {
      debugPrint('_fetchAndLoadMember: Firestore fetch failed: $e');
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
        'Family_Type': familyType,
        'Income': _income.text,
        'Aadhar_No1': _aadharNo.text,
        'Mother_Name': motherName,
        'Father_Name': fatherName,
        'Relation_with_Head': relationWithHead,
        'Spouse_Details1': showSpouseDetails,
        'Name2': spouseNameLookup,
        'Marriage_Type': marriageType,
        'Death_Place': selectedDeathPlace,
        'Death_Cause': _deathCause.text,
        'Death_Date': deathDate != null ? Timestamp.fromDate(deathDate!) : null,
        'Asthma': diseases['Asthma?'],
        'Diabetes': diseases['Diabetes?'],
        'Hypertensive': diseases['Hypertension?'],
        'Thyroid': diseases['Thyroid?'],
        'Malaria_last_6m': diseases['Malaria (Last 6 Months)'],
        'jaundice_last_6m': diseases['Jaundice (Last 6 Months)'],
        'Panmasala_currently': diseases['Panmasala (Currently)'],
        'Drink_alcohol_currently': diseases['Drink Alcohol (Currently)?'],
        'Smoke_currently': diseases['Smoke (Currently)?'],
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };
      // Capture state BEFORE reset so background sync uses the right values
      final bool wasEditing = _isEditMode && _editDocId != null;
      final String? capturedEditDocId = _editDocId;
      final String? capturedWidgetDocId = widget.docId;

      // Embed the Firestore doc ID so SyncService can route add vs update
      data['firestoreDocId'] = capturedEditDocId ?? capturedWidgetDocId;

      // 1. Prepare Spouse Update (Reciprocal) if needed
      Map<String, dynamic>? spouseUpdate;
      if (spouseNameLookup != null) {
        final spouseRecord = _allMembersList.firstWhere((m) => m['Name'] == spouseNameLookup, orElse: () => {});
        if (spouseRecord.isNotEmpty) {
          spouseUpdate = {
            ...spouseRecord,
            'Marital_Status': '(1) Married',
            'Spouse_Details1': true,
            'Name2': _firstName.text,
            'New_Family_ID': _newFamilyId.text,
            'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
            'needs_zoho_sync': true,
          };
          // Explicitly set the doc ID for the spouse sync
          spouseUpdate!['firestoreDocId'] = spouseRecord['id'] ?? spouseRecord['firestoreDocId'];
        }
      }

      // 2. Save both locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('personal_details', data);
      await DataCacheService().addMember(data);

      if (spouseUpdate != null) {
        await DataCacheService().saveOfflineSubmission('personal_details', spouseUpdate!);
        await DataCacheService().addMember(spouseUpdate!);
      }

      // 3. Immediately update local state so next member sees this one in dropdowns
      final List<Map<String, dynamic>> updatedList = List.from(_allMembersList);

      // Update self in list
      final int selfIdx = updatedList.indexWhere((m) => m['Name'] == data['Name']);
      if (selfIdx != -1) updatedList[selfIdx] = data; else updatedList.add(data);

      // Update spouse in list
      if (spouseUpdate != null) {
        final int sIdx = updatedList.indexWhere((m) => m['Name'] == spouseUpdate!['Name']);
        if (sIdx != -1) updatedList[sIdx] = spouseUpdate!; else updatedList.add(spouseUpdate!);
      }

      // If Map No changed, propagate new Map No to ALL other family members
      final newMapNoStr = _mapNo.text.trim();
      if (newMapNoStr.isNotEmpty && newMapNoStr != (_familyMapNo ?? '').trim()) {
        final newMapNoInt = int.tryParse(newMapNoStr);
        for (int i = 0; i < updatedList.length; i++) {
          final member = updatedList[i];
          if (member['Name'] == data['Name']) continue; // already saved above
          final memberUpdate = {
            ...member,
            'Map_No': newMapNoInt,
            'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
            'needs_zoho_sync': true,
          };
          await DataCacheService().saveOfflineSubmission('personal_details', memberUpdate);
          await DataCacheService().addMember(memberUpdate);
          updatedList[i] = memberUpdate;
        }
        _familyMapNo = newMapNoStr;
      }

      _updateMembersState(updatedList, _headDoc?['Name']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Saved locally with spouse update! Syncing...'),
          backgroundColor: Colors.indigo,
          duration: Duration(seconds: 1),
        ));
        
        if (widget.docId != null || wasEditing) {
          if (widget.docId != null) Navigator.pop(context); else _resetForm();
        } else {
          _showAddAnotherDialog();
        }
      }

      // 4. Trigger Background Sync
      SyncService().syncPendingSubmissions();

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() {
        _isSaving = false;
        _isActionActive = false;
      });
    }
  }


  @override
  Future<void> _downloadMembersFromStorage() async {
    setState(() { _isDownloadingMembers = true; _downloadProgress = 0; });
    try {
      final ref = FirebaseStorage.instance.ref().child('exports/personal_details.json');
      final downloadUrl = await ref.getDownloadURL();

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);
      final totalBytes = response.contentLength ?? 0;
      final bytes = <int>[];
      int downloadedBytes = 0;

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(() => _downloadProgress = ((downloadedBytes / totalBytes) * 500).toInt());
        }
      }
      client.close();

      final List<dynamic> records = json.decode(String.fromCharCodes(bytes));

      final dbService = LocalDatabaseService();
      final List<Map<String, dynamic>> batch = [];
      int saved = 0;

      for (final record in records) {
        batch.add(Map<String, dynamic>.from(record as Map));
        if (batch.length == 500) {
          await dbService.saveMembers(batch, clearFirst: saved == 0);
          saved += batch.length;
          batch.clear();
          if (mounted) setState(() => _downloadProgress = 500 + ((saved / records.length) * 500).toInt());
        }
      }
      if (batch.isNotEmpty) {
        await dbService.saveMembers(batch, clearFirst: saved == 0);
        saved += batch.length;
      }

      // Save download completion timestamp
      final prefs = await SharedPreferences.getInstance();
      final downloadedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      await prefs.setString('members_download_timestamp', downloadedAt);

      if (mounted) {
        setState(() {
          _membersAlreadyDownloaded = true;
          _membersDownloadedAt = downloadedAt;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $saved members downloaded! All records are now available offline.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 8)),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingMembers = false);
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Personal Details'),
        elevation: 0,
        actions: [
          IconButton(
            icon: _isDownloadingMembers
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(
                    Icons.sync,
                    color: _membersAlreadyDownloaded ? Colors.greenAccent : Colors.white,
                  ),
            tooltip: _membersAlreadyDownloaded
                ? 'Downloaded on $_membersDownloadedAt'
                : 'Sync Members to Local Database',
            onPressed: _isDownloadingMembers ? null : () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(_membersAlreadyDownloaded ? 'Re-Sync Members' : 'Sync All Members'),
                  content: Text(
                    _membersAlreadyDownloaded
                        ? 'Members were last downloaded on $_membersDownloadedAt.\n\nDo you want to re-download? This will replace all existing local records.'
                        : 'This will download 97,000+ member records for offline use. This is a one-time download.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start')),
                  ],
                ),
              );
              if (confirm == true) _downloadMembersFromStorage();
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          SingleChildScrollView(
            key: const PageStorageKey('personal_details_scroll'),
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (_isLoadingFamily && _allMembersList.isEmpty) 
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    if (_isLoadingFamily) const LinearProgressIndicator(minHeight: 2), 
                    buildSectionCard(
                      context: context,
                      title: 'Identity & Registration',
                      icon: Icons.fingerprint_outlined,
                      children: [
                  formSearchField(
                    'Family Code',
                    _familyCodeController,
                    onSearch: () => _fetchMembersByFamily(_familyCodeController.text),
                    isLoading: _isLoadingFamily,
                    enabled: _isActionActive,
                    readOnly: false,
                    focusNode: _familyCodeNode,
                    isUpperCase: true, // Apply uppercase
                    validator: (v) => (v == null || v.isEmpty) ? 'Family Code is required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: formTextField('Spouse', _spouseNo, isNumericOnly: true, enabled: _isActionActive)),
                    const SizedBox(width: 12),
                    Expanded(child: formTextField('Map No.', _mapNo, isNumericOnly: true, enabled: true)),
                  ]),
                  const SizedBox(height: 12),
                  formTextField('New Family ID', _newFamilyId, isUpperCase: true, enabled: _isActionActive),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Name', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
                      const SizedBox(height: 6),
                      Builder(
                        builder: (btnContext) {
                          return TextFormField(
                            controller: _firstName,
                            enabled: _isActionActive,
                            focusNode: _nameNode,
                            validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')), UpperCaseTextFormatter()], // Strict text, uppercase
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade400),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.blue, width: 2),
                              ),
                              fillColor: Colors.white,
                              filled: true,
                              suffixIcon: _isEditMode
                                  ? IconButton(
                                      icon: _isLoadingFamily
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Icon(Icons.arrow_drop_down),
                                      onPressed: _isLoadingFamily ? null : () async {
                                        FocusScope.of(btnContext).unfocus();
                                        
                                        final names = _allMembersList
                                            .map((m) => m['Name']?.toString() ?? '')
                                            .where((n) => n.isNotEmpty)
                                            .toList()..sort();
                                            
                                        // Use contextual overlay instead of central dialog
                                        final RenderBox renderBox = btnContext.findRenderObject() as RenderBox;
                                        final offset = renderBox.localToGlobal(Offset.zero);
                                        final size = renderBox.size;
                                        
                                        final result = await showGeneralDialog<String>(
                                          context: context,
                                          barrierDismissible: true,
                                          barrierLabel: 'Dismiss',
                                          barrierColor: Colors.transparent,
                                          transitionDuration: const Duration(milliseconds: 150),
                                          pageBuilder: (context, anim1, anim2) {
                                            return Stack(
                                              children: [
                                                GestureDetector(
                                                  onTap: () => Navigator.pop(context),
                                                  behavior: HitTestBehavior.opaque,
                                                  child: Container(color: Colors.transparent),
                                                ),
                                                Positioned(
                                                  left: offset.dx,
                                                  top: offset.dy + size.height,
                                                  width: size.width,
                                                  child: FadeTransition(
                                                    opacity: anim1,
                                                    child: Material(
                                                      elevation: 8,
                                                      borderRadius: BorderRadius.circular(8),
                                                      clipBehavior: Clip.antiAlias,
                                                      child: ConstrainedBox(
                                                        constraints: const BoxConstraints(maxHeight: 300),
                                                        child: SearchableDropdownMenu(
                                                          items: names,
                                                          initialValue: _firstName.text,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                        if (result != null) {
                                          _fetchAndLoadMember(result);
                                        }
                                      },
                                    )
                                  : null,
                            ),
                          );
                        }
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      formRadioOption(
                        label: '(1) Male',
                        value: '(1) Male',
                        groupValue: selectedGender,
                        onChanged: !_isActionActive ? null : (v) => setState(() { selectedGender = v as String?; _updateAutoRelation(); }),
                      ),
                      const SizedBox(width: 16),
                      formRadioOption(
                        label: '(0) Female',
                        value: '(0) Female',
                        groupValue: selectedGender,
                        onChanged: !_isActionActive ? null : (v) => setState(() { selectedGender = v as String?; _updateAutoRelation(); }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                    formTextField(
                      'Serial Number of Individual',
                      _serialNumber,
                      isNumericOnly: true,
                      enabled: _isActionActive,
                    ),
                  const SizedBox(height: 12),
                    formTextField(
                      'Registration Number',
                      _regNo,
                      isNumericOnly: true,
                      enabled: false,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              buildSectionCard(
                context: context,
                title: 'Personal Info',
                icon: Icons.person_outline,
                children: [
                  Row(children: [
                    Expanded(child: _buildDatePicker('Date of Birth', dateOfBirth, _onDOBChanged, enabled: _isActionActive)),
                    const SizedBox(width: 12),
                    Expanded(child: formTextField(
                      'Age',
                      _age,
                      enabled: _isActionActive,
                      isNumericOnly: true,
                      inputFormatters: [LengthLimitingTextInputFormatter(3)],
                      onChanged: (v) {
                        final val = int.tryParse(v);
                        if (val != null && val > 100) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Age should not be more than 100'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          _age.text = '100';
                          _age.selection = TextSelection.fromPosition(TextPosition(offset: _age.text.length));
                        }
                      },
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Age is required';
                        final val = int.tryParse(v);
                        if (val == null) return 'Enter a valid age';
                        if (val > 100) return 'Age should not be more than 100';
                        return null;
                      },
                    )),
                  ]),
                  const SizedBox(height: 12),
                  formSearchableDropdown(context, 'Live Status', ['(1) Alive', '(0) Dead'], liveStatus, (v) => setState(() => liveStatus = v as String?), key: ValueKey('live_$liveStatus'), enabled: _isActionActive),
                  const SizedBox(height: 12),
                  formSearchableDropdown(context, 'A/v Status', ['(1) Active', '(0) Vacant'], avStatus, (v) => setState(() => avStatus = v as String?), key: ValueKey('av_$avStatus'), enabled: _isActionActive),
                  const SizedBox(height: 12),
                  formSearchableDropdown(
                    context,
                    'Marital Status',
                    ['(0) Unmarried', '(1) Married', '(2) Divorce', '(3) Widow', '(4) Not Eligible'],
                    maritalStatus,
                    (v) {
                      setState(() {
                        maritalStatus = v as String?;
                        if (v == '(0) Unmarried') showSpouseDetails = false;
                        _calculateNewFamilyID();
                      });
                    },
                    key: ValueKey('marital_$maritalStatus'),
                    enabled: _isActionActive
                  ),
                  if (liveStatus == '(0) Dead') ...[
                    const SizedBox(height: 12),
                    formSearchableDropdown(context, 'Death Place', ['(0) RHC', '(1) PVT', '(2) GOVT', '(3) HOME'], selectedDeathPlace, (v) => setState(() => selectedDeathPlace = v as String?), key: ValueKey('death_$selectedDeathPlace'), enabled: _isActionActive),
                    const SizedBox(height: 12),
                    formTextField('Death Cause', _deathCause, enabled: _isActionActive),
                    const SizedBox(height: 12),
                    _buildDatePicker('Death Date', deathDate, (picked) => setState(() => deathDate = picked), enabled: _isActionActive),
                  ],
                  const SizedBox(height: 12),
                  if ((int.tryParse(_age.text) ?? 0) > 3)
                    formSearchableDropdown(context, 'Education', ['(0) ILLITIRATE', '(1) CAN READ ONLY', '(2) CAN READ AND WRITE', '(3) PRIMARY SCHOOL', '(4) MIDDLE SCHOOL', '(5) HIGH SCHOOL', '(6) GRADUATE', '(7) POST GRADUATE'], selectedEducation, (v) => setState(() => selectedEducation = v), key: ValueKey('edu_$selectedEducation'), enabled: _isActionActive),
                  if ((int.tryParse(_age.text) ?? 0) > 3) const SizedBox(height: 12),
                  if ((int.tryParse(_age.text) ?? 0) > 3)
                    formSearchableDropdown(context, 'Occupation', ['(1) HOUSE WIFE', '(2) AGRICULTURE', '(3) UNEMPLOYED', '(4)LABOUR', '(5) SELF-EMPLOYED', '(6) PRIVATE EMPLOYEE', '(7) ANGANWADI TEACHER', '(8) C.H.V', '(9) PENSION', '(10) GOVT EMPLOYEE', '(99) DONT KNOW'], selectedOccupation, (v) => setState(() => selectedOccupation = v), key: ValueKey('occ_$selectedOccupation'), enabled: _isActionActive),
                  if ((int.tryParse(_age.text) ?? 0) > 15) const SizedBox(height: 12),
                  if ((int.tryParse(_age.text) ?? 0) > 15) formTextField('Income', _income, isNumericOnly: true, enabled: _isActionActive),
                  const SizedBox(height: 12),
                  formTextField(
                    'Aadhar No.',
                    _aadharNo,
                    enabled: _isActionActive,
                    isNumericOnly: true,
                    inputFormatters: [LengthLimitingTextInputFormatter(12)],
                    validator: (v) {
                      if (v != null && v.isNotEmpty && v.length != 12) return 'Aadhar must be 12 digits';
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              buildSectionCard(
                context: context,
                title: 'Relations',
                icon: Icons.family_restroom_outlined,
                children: [
                  formSearchableDropdown(
                    context, 'Mother Name',
                    {
                      ...eligibleMothers,
                      if (motherName != null && motherName!.isNotEmpty) motherName!,
                    }.toList(),
                    motherName, _onMotherChanged,
                    key: ValueKey('mother_$motherName'),
                    isLoading: _isLoadingFamily, enabled: _isActionActive,
                  ),
                  const SizedBox(height: 12),
                  formSearchableDropdown(
                    context, 'Father Name',
                    {
                      ...eligibleFathers,
                      if (fatherName != null && fatherName!.isNotEmpty) fatherName!,
                    }.toList(),
                    fatherName, _onFatherChanged,
                    key: ValueKey('father_$fatherName'),
                    isLoading: _isLoadingFamily, enabled: _isActionActive,
                  ),
                  const SizedBox(height: 12),
                  formSearchableDropdown(
                    context,
                    'Relation with Head',
                    ['ADOPTED DAUGHTER', 'ADOPTED GRAND DAUGHTER', 'ADOPTED GRAND SON', 'ADOPTED GREAT GRAND DAUGHTER', 'ADOPTED SON', 'AUNTY', 'BROTHER', 'BROTHER DAUGHTER', 'BROTHER SON', 'BROTHER-DAUGHTER-DAUGHTER(DD)', 'BROTHER-DAUGHTER-SON(DS)', 'BROTHER-IN-LAW', 'BROTHERS DAUGHTER HUSBAND', 'BROTHERS SON ADOPTED', 'BROTHERS SON WIFE', 'BROTHERS SONS DAUGHTER', 'BROTHERS SONS SON', 'BSW', 'DAUGHTER', 'DAUGHTER-IN-LAW', 'FATHER-IN-LAW', 'GRAND DAUGHTER HUSBAND(D)', 'GRAND DAUGHTER HUSBAND(S)', 'GRAND PARENT', 'GRAND-DAUGHTER (D)', 'GRAND-DAUGHTER(S)', 'GRAND-DAUGHTER-IN-LAW', 'GRAND-DAUGHTER-IN-LAW (S)', 'GRAND-SON (D)', 'GRAND-SON(S)', 'GREAT GRAND DAUGHTER (ASD)', 'GREAT GRAND DAUGHTER (DD)', 'GREAT GRAND DAUGHTER (SS)', 'GREAT GRAND DAUGTHER(SD)', 'GREAT GRAND PARENT', 'GREAT GRAND SON (DD)', 'GREAT GRAND SON (SS)', 'GREAT GRAND SON(SD)', 'GREAT-GRAND-DAUGTHER(DS)', 'GREAT-GRAND-SON(DS)', 'HEAD OF THE FAMILY', 'HUSBAND', 'MOTHER RELATIONS', 'MOTHERS-IN-LAW', 'NEPHEW', 'NIECE', 'OTHERS', 'PARENT', 'SINGLE', 'SISTER', 'SISTER DAUGHTER HUSBAND', 'SISTER-GRAND-DAUGHTER', 'SISTER-GRAND-SON', 'SISTER-IN-LAW (U)', 'SISTER-IN-LAW(BW)', 'SISTER-SON-WIFE', 'SON', 'SON-IN-LAW', 'UNCLE', 'WIFE', 'WIFE BROTHER', 'WIFE BROTHERS DAUGHTER', 'WIFE BROTHERS SON', 'WIFE BROTHERS WIFE', 'WIFE PARENT', 'WIFE RELATIONS'],
                    relationWithHead,
                    _onRelationChanged,
                    key: ValueKey('rel_$relationWithHead'),
                    enabled: _isActionActive,
                    validator: (v) => (v == null || v.isEmpty) ? 'Relation with Head is required' : null,
                  ),
                  const SizedBox(height: 8),
                  formCheckboxOption(
                    label: 'Spouse Details', 
                    value: showSpouseDetails, 
                    onChanged: !_isActionActive || maritalStatus == '(0) Unmarried' ? null : (v) => setState(() => showSpouseDetails = v ?? false)
                  ),
                  if (showSpouseDetails) ...[
                    const SizedBox(height: 12),
                    formSearchableDropdown(
                      context, 'Select Spouse',
                      {
                        ...(_getNormalizedGender(selectedGender) == '(1) Male' ? femaleMembers : maleMembers),
                        if (spouseNameLookup != null && spouseNameLookup!.isNotEmpty) spouseNameLookup!,
                      }.toList(),
                      spouseNameLookup, _onSpouseChanged,
                      isLoading: _isLoadingFamily, enabled: _isActionActive,
                    ),
                    const SizedBox(height: 12),
                    formSearchableDropdown(context, 'Marriage Type', ['Married In', 'Married Out'], marriageType, (v) => setState(() => marriageType = v), enabled: _isActionActive),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              buildSectionCard(
                context: context,
                title: 'Health Status',
                icon: Icons.health_and_safety_outlined,
                children: [
                  ...diseases.keys.map((d) => Column(children: [
                    ListTile(
                      title: Text(d, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)), 
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          formRadioOption(
                            label: '(1) Yes', 
                            value: '(1) Yes', 
                            groupValue: diseases[d], 
                            onChanged: !_isActionActive ? null : (v) => setState(() => diseases[d] = v as String?),
                          ),
                          const SizedBox(width: 12),
                          formRadioOption(
                            label: '(2) No', 
                            value: '(2) No', 
                            groupValue: diseases[d], 
                            onChanged: !_isActionActive ? null : (v) => setState(() => diseases[d] = v as String?),
                          ),
                        ],
                      ),
                    ),
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
      bottomNavigationBar: _isSaving
          ? null
          : formActionButtons(
              context: context,
              isEditMode: _isEditMode,
              onNew: () {
                setState(() {
                  _isEditMode = false;
                  _isActionActive = true;
                  _resetForm(keepFamilyContext: true, resetAction: false);
                  if (_familyCodeController.text.isEmpty) {
                    _familyCodeNode.requestFocus();
                  } else {
                    _nameNode.requestFocus();
                  }
                });
              },
              onSave: _save,
              onEdit: () {
                setState(() {
                  _isEditMode = true;
                  _isActionActive = true;
                  _nameNode.requestFocus();
                });
              },
              onCancel: () {
                setState(() {
                  _isActionActive = false;
                  _resetForm(keepFamilyContext: true);
                });
              },
              onExit: () => Navigator.pop(context),
              isSaving: _isSaving,
              isActionActive: _isActionActive,
            ),
    );
  }

  void _showAddAnotherDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Member Added Successfully', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
        content: const Text('Do you want to add another member to this family?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            },
            child: const Text('No (Dashboard)'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _resetForm(keepFamilyContext: true, resetAction: false);
                _isActionActive = true;
                _nameNode.requestFocus();
              });
            },
            child: const Text('Yes (Add More)'),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onPicked, {bool enabled = true}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      InkWell(
        onTap: !enabled ? null : () async {
          final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
          final picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
          if (picked != null) {
            onPicked(picked);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) _scrollController.jumpTo(offset);
            });
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), suffixIcon: const Icon(Icons.calendar_today, size: 18)),
          child: Text(selectedDate == null ? 'dd-MMM-yyyy' : DateFormat('dd-MMM-yyyy').format(selectedDate)),
        ),
      ),
    ]);
  }
}

class _MemberPickerDialog extends StatefulWidget {
  final List<String> items;
  final String? initialValue;

  const _MemberPickerDialog({required this.items, this.initialValue});

  @override
  State<_MemberPickerDialog> createState() => _MemberPickerDialogState();
}

class _MemberPickerDialogState extends State<_MemberPickerDialog> {
  late List<String> filtered;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    filtered = widget.items;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Name'),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: Column(
          children: [
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (val) {
                setState(() {
                  filtered = widget.items
                      .where((i) => i.toLowerCase().contains(val.toLowerCase()))
                      .toList();
                });
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No results'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final isSelected = filtered[i] == widget.initialValue;
                        return ListTile(
                          title: Text(filtered[i]),
                          selected: isSelected,
                          selectedTileColor: Colors.blue.shade50,
                          onTap: () => Navigator.pop(context, filtered[i]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}
