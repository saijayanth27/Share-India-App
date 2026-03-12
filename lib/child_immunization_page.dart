import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

class ChildImmunizationPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const ChildImmunizationPage({super.key, this.existingData, this.docId});

  @override
  State<ChildImmunizationPage> createState() => _ChildImmunizationPageState();
}

class _ChildImmunizationPageState extends State<ChildImmunizationPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];

  // --- Identity Fields ---
  String? selectedFamilyCode;
  final _nameController = TextEditingController();
  String? selectedName;
  final _motherName = TextEditingController();
  String? selectEntryScreen;
  DateTime? dob;
  final _regNo = TextEditingController();

  // --- BCG ---
  String? bcgGiven;
  DateTime? bcgDate;
  String? bcgGivenBy;

  // --- DPT ---
  String? dpt1Given; DateTime? dpt1Date; String? dpt1By;
  String? dpt2Given; DateTime? dpt2Date; String? dpt2By;
  String? dpt3Given; DateTime? dpt3Date; String? dpt3By;
  String? dptBGiven; DateTime? dptBDate; String? dptBBy;

  // --- OPV ---
  String? opv0Given; DateTime? opv0Date; String? opv0By;
  String? opv1Given; DateTime? opv1Date; String? opv1By;
  String? opv2Given; DateTime? opv2Date; String? opv2By;
  String? opv3Given; DateTime? opv3Date; String? opv3By;
  String? opvBGiven; DateTime? opvBDate; String? opvBBy;

  // --- Measles ---
  String? measlesGiven; DateTime? measlesDate; String? measlesBy;

  // --- HepB ---
  String? hepB1Given; DateTime? hepB1Date; String? hepB1By;
  String? hepB2Given; DateTime? hepB2Date; String? hepB2By;
  String? hepB3Given; DateTime? hepB3Date; String? hepB3By;

  // --- Vitamin A ---
  String? vitA1Given; DateTime? vitA1Date; String? vitA1By;
  String? vitA2Given; DateTime? vitA2Date; String? vitA2By;
  String? vitA3Given; DateTime? vitA3Date; String? vitA3By;
  String? vitA4Given; DateTime? vitA4Date; String? vitA4By;
  String? vitABGiven; DateTime? vitABDate; String? vitABBy;

  // --- DT ---
  String? dtGiven; DateTime? dtDate; String? dtBy;

  // --- General/Others ---
  final _remarks = TextEditingController();
  final _birthWeight = TextEditingController();
  final _birthHeight = TextEditingController();
  String? diarrhea;
  String? breastfeeding;

  // Lookups
  List<String> allFamilyCodes = [];
  List<String> familyMembers = [];
  bool _isLoadingMembers = false;
  Map<String, Map<String, dynamic>> _allMembersData = {};

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

  Future<void> _fetchMembersByFamily(String familyCode, {String? entryScreen}) async {
    setState(() => _isLoadingMembers = true);
    try {
      // 1. Fetch from Firestore (Cache favored)
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyCode)
          .get(const GetOptions(source: Source.serverAndCache));

      // 2. Fetch from Local SQLite for offline support
      final localMembers = await DataCacheService().fetchMembersLocally(familyCode);

      // 3. Fetch existing immunization records to exclude
      Set<String> alreadyRegistered = {};
      if (entryScreen != null) {
        final existingRecords = await FirebaseFirestore.instance
            .collection('child_immunization')
            .where('Family_Code', isEqualTo: familyCode)
            .where('Select_Entry_Screen', isEqualTo: entryScreen)
            .get(const GetOptions(source: Source.serverAndCache));
        alreadyRegistered = existingRecords.docs.map((doc) => doc.data()['Name']?.toString() ?? '').toSet();
      }

      // 4. Merge and Filter logic
      final Map<String, Map<String, dynamic>> memberMap = {};
      final Set<String> filteredNames = {};
      
      void processMember(Map<String, dynamic> data) {
        final name = data['Name']?.toString() ?? '';
        if (name.isEmpty) return;
        memberMap[name] = data;

        if (alreadyRegistered.contains(name)) return;

        final mother = data['Mother_Name']?.toString() ?? '';
        final father = data['Father_Name']?.toString() ?? '';
        final weight = data['Birth_Weight'] ?? data['Birth_weight'];

        bool hasMother = mother.isNotEmpty && mother != 'No Mother';
        bool hasFather = father.isNotEmpty && father != 'No Father';
        bool hasWeight = weight != null && weight.toString().isNotEmpty;

        if (hasMother || hasFather || hasWeight) {
          filteredNames.add(name);
        }
      }

      for (var doc in snapshot.docs) {
        processMember(doc.data());
      }
      for (var local in localMembers) {
        processMember(local);
      }

      setState(() {
        _allMembersData = memberMap;
        familyMembers = filteredNames.toList()..sort();
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error fetching members: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _fetchExistingRecords(String familyCode, {String? entryScreen}) async {
    setState(() => _isLoadingMembers = true);
    try {
      var query = FirebaseFirestore.instance
          .collection('child_immunization')
          .where('Family_Code', isEqualTo: familyCode);
      
      if (entryScreen != null) {
        query = query.where('Select_Entry_Screen', isEqualTo: entryScreen);
      }

      final snapshot = await query.get();
      
      setState(() {
        _existingRecords = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error fetching existing records: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  void _onNameSelected(String? name) {
    setState(() {
      selectedName = name;
      _nameController.text = name ?? '';
      if (name != null) {
        if (_isEditMode) {
          final record = _existingRecords.firstWhere((r) => r['Name'] == name, orElse: () => {});
          if (record.isNotEmpty) {
            _editDocId = record['id'];
            _populateForm(record);
          }
        } else if (_allMembersData.containsKey(name)) {
          final data = _allMembersData[name]!;
        
        // Auto-populate DOB
        if (data['Date_of_Birth'] != null) {
          if (data['Date_of_Birth'] is Timestamp) {
            dob = (data['Date_of_Birth'] as Timestamp).toDate();
          } else if (data['Date_of_Birth'] is String) {
            dob = DateTime.tryParse(data['Date_of_Birth']);
          }
        }

        // Auto-populate Registration Number
        _regNo.text = data['Registration_Number1'] ?? data['Registration_Number'] ?? '';

        // Auto-populate Birth Weight
        final weight = data['Birth_Weight'] ?? data['Birth_weight'];
        if (weight != null) {
          _birthWeight.text = weight.toString();
        }

        // Auto-populate Mother Name
        final motherId = data['Mother_Name']?.toString();
        if (motherId != null && motherId != 'No Mother') {
          // Look through cached members for a member with this ID or Name
          String? foundMotherName;
          _allMembersData.forEach((key, value) {
            if (value['ID'].toString() == motherId || key == motherId) {
              foundMotherName = key;
            }
          });
          _motherName.text = foundMotherName ?? motherId;
        } else {
          _motherName.clear();
        }
        }
      }
    });
  }

  void _populateForm(Map<String, dynamic> d) {
    setState(() {
      selectedName = d['Name'];
      _nameController.text = selectedName ?? '';
      _editDocId = d['id'];
      selectedFamilyCode = d['Family_Code'];
      selectEntryScreen = d['Select_Entry_Screen'];
      if (selectedFamilyCode != null) _fetchMembersByFamily(selectedFamilyCode!, entryScreen: selectEntryScreen);
      if (d['Date_of_Birth'] != null) {
        if (d['Date_of_Birth'] is Timestamp) {
          dob = (d['Date_of_Birth'] as Timestamp).toDate();
        } else if (d['Date_of_Birth'] is String) {
          dob = DateTime.tryParse(d['Date_of_Birth']);
        }
      }
      _regNo.text = (d['Registration_Number'] ?? d['Registration_Number1'] ?? '').toString();
      _motherName.text = d['Mother_Name'] ?? '';

      bcgGiven = d['BCG_Given_Y_N'];
      if (d['BCG_Dt'] != null) bcgDate = (d['BCG_Dt'] is Timestamp) ? (d['BCG_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['BCG_Dt']?.toString() ?? '');
      bcgGivenBy = d['BCG_Given_By'];

      dpt1Given = d['DPT1_Given_Y_N'];
      if (d['DPT1_Dt3'] != null) dpt1Date = (d['DPT1_Dt3'] is Timestamp) ? (d['DPT1_Dt3'] as Timestamp).toDate() : DateTime.tryParse(d['DPT1_Dt3']?.toString() ?? '');
      dpt1By = d['DPT1_Given_Y_N1'];
      dpt2Given = d['DPT2_Given_Y_N2'];
      if (d['DPT2_Dt'] != null) dpt2Date = (d['DPT2_Dt'] is Timestamp) ? (d['DPT2_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['DPT2_Dt']?.toString() ?? '');
      dpt2By = d['DPT2_Given_By'];
      dpt3Given = d['DPT3_Given_Y_N3'];
      if (d['DPT3_Dt'] != null) dpt3Date = (d['DPT3_Dt'] is Timestamp) ? (d['DPT3_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['DPT3_Dt']?.toString() ?? '');
      dpt3By = d['DPT3_Given_By'];
      dptBGiven = d['DPTB_Given_Y_N'];
      if (d['DPT_B_Dt'] != null) dptBDate = (d['DPT_B_Dt'] is Timestamp) ? (d['DPT_B_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['DPT_B_Dt']?.toString() ?? '');
      dptBBy = d['DPTB_Given_Y_N1'];

      opv0Given = d['OPVO_Given_Y_N'];
      if (d['OPV0_Dt'] != null) opv0Date = (d['OPV0_Dt'] is Timestamp) ? (d['OPV0_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['OPV0_Dt']?.toString() ?? '');
      opv0By = d['OPVO_Given_By'];
      opv1Given = d['OPVO_Given_By1'];
      if (d['OPV_1_Dt'] != null) opv1Date = (d['OPV_1_Dt'] is Timestamp) ? (d['OPV_1_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['OPV_1_Dt']?.toString() ?? '');
      opv1By = d['OPV1_Given_By'];
      opv2Given = d['OPV2_Given_yes_no'];
      if (d['OPV2_Dt'] != null) opv2Date = (d['OPV2_Dt'] is Timestamp) ? (d['OPV2_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['OPV2_Dt']?.toString() ?? '');
      opv2By = d['Drop_OPV2_Given_By'];
      opv3Given = d['OPV3_Given_by_Y_N'];
      if (d['OPV3_Dt'] != null) opv3Date = (d['OPV3_Dt'] is Timestamp) ? (d['OPV3_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['OPV3_Dt']?.toString() ?? '');
      opv3By = d['OPV2_Given_By2'];
      opvBGiven = d['OPV_B_Given_Y_N'];
      if (d['OPV_B_Dt'] != null) opvBDate = (d['OPV_B_Dt'] is Timestamp) ? (d['OPV_B_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['OPV_B_Dt']?.toString() ?? '');
      opvBBy = d['OPV2_Given_By1'];

      measlesGiven = d['Measles1'];
      if (d['Measles_Dt'] != null) measlesDate = (d['Measles_Dt'] is Timestamp) ? (d['Measles_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['Measles_Dt']?.toString() ?? '');
      measlesBy = d['Measles_Given_Y_N'];

      hepB1Given = d['HepB1_Given_Y_N'];
      if (d['HepB1_Dt'] != null) hepB1Date = (d['HepB1_Dt'] is Timestamp) ? (d['HepB1_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['HepB1_Dt']?.toString() ?? '');
      hepB1By = d['HepB1_Given_By'];
      hepB2Given = d['HepB2_Given_Y_N'];
      if (d['HepB2_Dt'] != null) hepB2Date = (d['HepB2_Dt'] is Timestamp) ? (d['HepB2_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['HepB2_Dt']?.toString() ?? '');
      hepB2By = d['HepB2'];
      hepB3Given = d['HepB3_Given_Y_N'];
      if (d['HepB3_Dt'] != null) hepB3Date = (d['HepB3_Dt'] is Timestamp) ? (d['HepB3_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['HepB3_Dt']?.toString() ?? '');
      hepB3By = d['HepB3_Given_By'];

      vitA1Given = d['VitA1_Given_Y_N'];
      if (d['VitA1_Dt'] != null) vitA1Date = (d['VitA1_Dt'] is Timestamp) ? (d['VitA1_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['VitA1_Dt']?.toString() ?? '');
      vitA1By = d['VitA1_Given_By'];
      vitA2Given = d['VitA2_Given_Y_N'];
      if (d['VitA2_Dt'] != null) vitA2Date = (d['VitA2_Dt'] is Timestamp) ? (d['VitA2_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['VitA2_Dt']?.toString() ?? '');
      vitA2By = d['VitA2_Given_By'];
      vitA3Given = d['VitA3_Given_Y_N1'];
      if (d['VitA3_Dt'] != null) vitA3Date = (d['VitA3_Dt'] is Timestamp) ? (d['VitA3_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['VitA3_Dt']?.toString() ?? '');
      vitA3By = d['V'];
      vitA4Given = d['Vita4_Given_Y_N'];
      if (d['VitA4_Dt'] != null) vitA4Date = (d['VitA4_Dt'] is Timestamp) ? (d['VitA4_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['VitA4_Dt']?.toString() ?? '');
      vitA4By = d['VitA4_Given_By'];
      vitABGiven = d['VitAB_Given_Y_N'];
      if (d['VitAB_Dt1'] != null) vitABDate = (d['VitAB_Dt1'] is Timestamp) ? (d['VitAB_Dt1'] as Timestamp).toDate() : DateTime.tryParse(d['VitAB_Dt1']?.toString() ?? '');
      vitABBy = d['VitAB_Given_By'];

      dtGiven = d['DT_Given_Y_N'];
      if (d['DT_Dt'] != null) dtDate = (d['DT_Dt'] is Timestamp) ? (d['DT_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['DT_Dt']?.toString() ?? '');
      dtBy = d['DT_Given_By'];

      _remarks.text = d['Remarks1'] ?? '';
      _birthWeight.text = d['Birth_Weight']?.toString() ?? '';
      _birthHeight.text = d['Birth_Height'] ?? '';
      diarrhea = d['Diarrhea'];
      breastfeeding = d['Breastfeeding'];
    });
  }

  void _loadExistingData() {
    _populateForm(widget.existingData!);
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      selectedFamilyCode = null; selectedName = null; _nameController.clear(); _motherName.clear(); selectEntryScreen = null; dob = null; _regNo.clear();
      bcgGiven = null; bcgDate = null; bcgGivenBy = null;
      dpt1Given = null; dpt1Date = null; dpt1By = null;
      dpt2Given = null; dpt2Date = null; dpt2By = null;
      dpt3Given = null; dpt3Date = null; dpt3By = null;
      dptBGiven = null; dptBDate = null; dptBBy = null;
      opv0Given = null; opv0Date = null; opv0By = null;
      opv1Given = null; opv1Date = null; opv1By = null;
      opv2Given = null; opv2Date = null; opv2By = null;
      opv3Given = null; opv3Date = null; opv3By = null;
      opvBGiven = null; opvBDate = null; opvBBy = null;
      measlesGiven = null; measlesDate = null; measlesBy = null;
      hepB1Given = null; hepB1Date = null; hepB1By = null;
      hepB2Given = null; hepB2Date = null; hepB2By = null;
      hepB3Given = null; hepB3Date = null; hepB3By = null;
      vitA1Given = null; vitA1Date = null; vitA1By = null;
      vitA2Given = null; vitA2Date = null; vitA2By = null;
      vitA3Given = null; vitA3Date = null; vitA3By = null;
      vitA4Given = null; vitA4Date = null; vitA4By = null;
      vitABGiven = null; vitABDate = null; vitABBy = null;
      dtGiven = null; dtDate = null; dtBy = null;
      _remarks.clear(); _birthWeight.clear(); _birthHeight.clear(); diarrhea = null; breastfeeding = null;
      familyMembers = [];
      _existingRecords = [];
      _editDocId = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Family_Code': selectedFamilyCode,
        'Name': _isEditMode ? selectedName : _nameController.text,
        'Mother_Name': _motherName.text,
        'Select_Entry_Screen': selectEntryScreen,
        'Date_of_Birth': dob != null ? Timestamp.fromDate(dob!) : null,
        'Registration_Number': _regNo.text,

        'BCG_Given_Y_N': bcgGiven,
        'BCG_Dt': bcgDate != null ? Timestamp.fromDate(bcgDate!) : null,
        'BCG_Given_By': bcgGivenBy,

        'DPT1_Given_Y_N': dpt1Given,
        'DPT1_Dt3': dpt1Date != null ? Timestamp.fromDate(dpt1Date!) : null,
        'DPT1_Given_Y_N1': dpt1By,
        'DPT2_Given_Y_N2': dpt2Given,
        'DPT2_Dt': dpt2Date != null ? Timestamp.fromDate(dpt2Date!) : null,
        'DPT2_Given_By': dpt2By,
        'DPT3_Given_Y_N3': dpt3Given,
        'DPT3_Dt': dpt3Date != null ? Timestamp.fromDate(dpt3Date!) : null,
        'DPT3_Given_By': dpt3By,
        'DPTB_Given_Y_N': dptBGiven,
        'DPT_B_Dt': dptBDate != null ? Timestamp.fromDate(dptBDate!) : null,
        'DPTB_Given_Y_N1': dptBBy,

        'OPVO_Given_Y_N': opv0Given,
        'OPV0_Dt': opv0Date != null ? Timestamp.fromDate(opv0Date!) : null,
        'OPVO_Given_By': opv0By,
        'OPVO_Given_By1': opv1Given,
        'OPV_1_Dt': opv1Date != null ? Timestamp.fromDate(opv1Date!) : null,
        'OPV1_Given_By': opv1By,
        'OPV2_Given_yes_no': opv2Given,
        'OPV2_Dt': opv2Date != null ? Timestamp.fromDate(opv2Date!) : null,
        'Drop_OPV2_Given_By': opv2By,
        'OPV3_Given_by_Y_N': opv3Given,
        'OPV3_Dt': opv3Date != null ? Timestamp.fromDate(opv3Date!) : null,
        'OPV2_Given_By2': opv3By,
        'OPV_B_Given_Y_N': opvBGiven,
        'OPV_B_Dt': opvBDate != null ? Timestamp.fromDate(opvBDate!) : null,
        'OPV2_Given_By1': opvBBy,

        'Measles1': measlesGiven,
        'Measles_Dt': measlesDate != null ? Timestamp.fromDate(measlesDate!) : null,
        'Measles_Given_Y_N': measlesBy,

        'HepB1_Given_Y_N': hepB1Given,
        'HepB1_Dt': hepB1Date != null ? Timestamp.fromDate(hepB1Date!) : null,
        'HepB1_Given_By': hepB1By,
        'HepB2_Given_Y_N': hepB2Given,
        'HepB2_Dt': hepB2Date != null ? Timestamp.fromDate(hepB2Date!) : null,
        'HepB2': hepB2By,
        'HepB3_Given_Y_N': hepB3Given,
        'HepB3_Dt': hepB3Date != null ? Timestamp.fromDate(hepB3Date!) : null,
        'HepB3_Given_By': hepB3By,

        'VitA1_Given_Y_N': vitA1Given,
        'VitA1_Dt': vitA1Date != null ? Timestamp.fromDate(vitA1Date!) : null,
        'VitA1_Given_By': vitA1By,
        'VitA2_Given_Y_N': vitA2Given,
        'VitA2_Dt': vitA2Date != null ? Timestamp.fromDate(vitA2Date!) : null,
        'VitA2_Given_By': vitA2By,
        'VitA3_Given_Y_N1': vitA3Given,
        'VitA3_Dt': vitA3Date != null ? Timestamp.fromDate(vitA3Date!) : null,
        'V': vitA3By,
        'Vita4_Given_Y_N': vitA4Given,
        'VitA4_Dt': vitA4Date != null ? Timestamp.fromDate(vitA4Date!) : null,
        'VitA4_Given_By': vitA4By,
        'VitAB_Given_Y_N': vitABGiven,
        'VitAB_Dt1': vitABDate != null ? Timestamp.fromDate(vitABDate!) : null,
        'VitAB_Given_By': vitABBy,

        'DT_Given_Y_N': dtGiven,
        'DT_Dt': dtDate != null ? Timestamp.fromDate(dtDate!) : null,
        'DT_Given_By': dtBy,

        'Remarks1': _remarks.text,
        'Birth_Weight': double.tryParse(_birthWeight.text),
        'Birth_Height': _birthHeight.text,
        'Diarrhea': diarrhea,
        'Breastfeeding': breastfeeding,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('child_immunization').doc(_editDocId).update(data);
      } else if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('child_immunization').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('child_immunization').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Immunization record saved successfully!'), backgroundColor: Colors.green),
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

  Widget _buildDatePicker({required String label, required DateTime? value, required Function(DateTime) onPicked}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.calendar_today)),
        child: Text(value == null ? 'Select Date' : DateFormat('dd-MMM-yyyy').format(value)),
      ),
    );
  }

  Widget _buildGivenRow({
    required String label,
    required String? given,
    required DateTime? date,
    required String? by,
    required Function(String?) onGiven,
    required Function(DateTime) onDate,
    required Function(String?) onBy,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Given Y/N', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  value: given,
                  items: ['(1) Yes', '(0) No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: onGiven,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _buildDatePicker(label: 'Date', value: date, onPicked: onDate)),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Given By', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            value: by,
            items: ['(0) RHC', '(1) PVT', '(2) GOVT'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onBy,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Child Immunization', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade800, Colors.orange.shade500],
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
                    title: 'Child Immunization',
                    subtitle: 'Manage childhood vaccines and health records',
                  ),
                  buildSectionCard(
                    context: context,
                    title: 'Basic Information',
                    icon: Icons.baby_changing_station_outlined,
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Family Code', border: OutlineInputBorder()),
                        value: selectedFamilyCode,
                        items: allFamilyCodes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                         onChanged: (v) {
                           setState(() { selectedFamilyCode = v; selectedName = null; });
                           if (v != null) {
                             if (_isEditMode) {
                               _fetchExistingRecords(v, entryScreen: selectEntryScreen);
                             } else {
                               _fetchMembersByFamily(v, entryScreen: selectEntryScreen);
                             }
                           }
                         },
                      ),
                      const SizedBox(height: 16),
                        if (_isEditMode)
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Select Name to Edit',
                              border: const OutlineInputBorder(),
                              suffixIcon: _isLoadingMembers ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                            ),
                            value: selectedName,
                            items: _existingRecords.map((r) => DropdownMenuItem(value: r['Name']?.toString() ?? 'Unknown', child: Text(r['Name']?.toString() ?? 'Unknown'))).toList(),
                            onChanged: _onNameSelected,
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(labelText: 'Name (Child)', border: OutlineInputBorder(), hintText: 'Type name or pick from dropdown'),
                              ),
                              if (familyMembers.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Pick from Family Members',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: _isLoadingMembers ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                                  ),
                                  value: null,
                                  items: familyMembers.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                                  onChanged: _onNameSelected,
                                  hint: const Text('--Select Member--'),
                                ),
                              ],
                            ],
                          ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _motherName, decoration: const InputDecoration(labelText: 'Mother Name', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      _buildDatePicker(label: 'Date of Birth', value: dob, onPicked: (v) => setState(() => dob = v)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Select Entry Screen', border: OutlineInputBorder()),
                        value: selectEntryScreen,
                        items: ['BCG', 'DPT', 'OPV', 'Measles', 'HepB', 'Vitamin A', 'DT', 'Remarks'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                         onChanged: (v) {
                           setState(() {
                             selectEntryScreen = v;
                             selectedName = null;
                           });
                           if (selectedFamilyCode != null) {
                             if (_isEditMode) {
                               _fetchExistingRecords(selectedFamilyCode!, entryScreen: v);
                             } else {
                               _fetchMembersByFamily(selectedFamilyCode!, entryScreen: v);
                             }
                           }
                         },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _regNo, decoration: const InputDecoration(labelText: 'Registration Number', border: OutlineInputBorder())),
                    ],
                  ),

                  if (selectEntryScreen == 'BCG')
                  buildSectionCard(
                    context: context,
                    title: 'BCG',
                    icon: Icons.vaccines_outlined,
                    children: [
                      _buildGivenRow(label: 'BCG', given: bcgGiven, date: bcgDate, by: bcgGivenBy, onGiven: (v) => setState(() => bcgGiven = v), onDate: (v) => setState(() => bcgDate = v), onBy: (v) => setState(() => bcgGivenBy = v)),
                    ],
                  ),

                  if (selectEntryScreen == 'DPT')
                  buildSectionCard(
                    context: context,
                    title: 'DPT',
                    icon: Icons.vaccines_outlined,
                    children: [
                      _buildGivenRow(label: 'DPT 1', given: dpt1Given, date: dpt1Date, by: dpt1By, onGiven: (v) => setState(() => dpt1Given = v), onDate: (v) => setState(() => dpt1Date = v), onBy: (v) => setState(() => dpt1By = v)),
                      _buildGivenRow(label: 'DPT 2', given: dpt2Given, date: dpt2Date, by: dpt2By, onGiven: (v) => setState(() => dpt2Given = v), onDate: (v) => setState(() => dpt2Date = v), onBy: (v) => setState(() => dpt2By = v)),
                      _buildGivenRow(label: 'DPT 3', given: dpt3Given, date: dpt3Date, by: dpt3By, onGiven: (v) => setState(() => dpt3Given = v), onDate: (v) => setState(() => dpt3Date = v), onBy: (v) => setState(() => dpt3By = v)),
                      _buildGivenRow(label: 'DPT Booster', given: dptBGiven, date: dptBDate, by: dptBBy, onGiven: (v) => setState(() => dptBGiven = v), onDate: (v) => setState(() => dptBDate = v), onBy: (v) => setState(() => dptBBy = v)),
                    ],
                  ),

                  if (selectEntryScreen == 'OPV')
                  buildSectionCard(
                    context: context,
                    title: 'OPV',
                    icon: Icons.vaccines_outlined,
                    children: [
                      _buildGivenRow(label: 'OPV 0', given: opv0Given, date: opv0Date, by: opv0By, onGiven: (v) => setState(() => opv0Given = v), onDate: (v) => setState(() => opv0Date = v), onBy: (v) => setState(() => opv0By = v)),
                      _buildGivenRow(label: 'OPV 1', given: opv1Given, date: opv1Date, by: opv1By, onGiven: (v) => setState(() => opv1Given = v), onDate: (v) => setState(() => opv1Date = v), onBy: (v) => setState(() => opv1By = v)),
                      _buildGivenRow(label: 'OPV 2', given: opv2Given, date: opv2Date, by: opv2By, onGiven: (v) => setState(() => opv2Given = v), onDate: (v) => setState(() => opv2Date = v), onBy: (v) => setState(() => opv2By = v)),
                      _buildGivenRow(label: 'OPV 3', given: opv3Given, date: opv3Date, by: opv3By, onGiven: (v) => setState(() => opv3Given = v), onDate: (v) => setState(() => opv3Date = v), onBy: (v) => setState(() => opv3By = v)),
                      _buildGivenRow(label: 'OPV Booster', given: opvBGiven, date: opvBDate, by: opvBBy, onGiven: (v) => setState(() => opvBGiven = v), onDate: (v) => setState(() => opvBDate = v), onBy: (v) => setState(() => opvBBy = v)),
                    ],
                  ),

                  if (selectEntryScreen == 'Measles')
                  buildSectionCard(
                    context: context,
                    title: 'Measles',
                    icon: Icons.vaccines_outlined,
                    children: [
                      _buildGivenRow(label: 'Measles', given: measlesGiven, date: measlesDate, by: measlesBy, onGiven: (v) => setState(() => measlesGiven = v), onDate: (v) => setState(() => measlesDate = v), onBy: (v) => setState(() => measlesBy = v)),
                    ],
                  ),

                  if (selectEntryScreen == 'HepB')
                  buildSectionCard(
                    context: context,
                    title: 'HepB',
                    icon: Icons.vaccines_outlined,
                    children: [
                      _buildGivenRow(label: 'HepB 1', given: hepB1Given, date: hepB1Date, by: hepB1By, onGiven: (v) => setState(() => hepB1Given = v), onDate: (v) => setState(() => hepB1Date = v), onBy: (v) => setState(() => hepB1By = v)),
                      _buildGivenRow(label: 'HepB 2', given: hepB2Given, date: hepB2Date, by: hepB2By, onGiven: (v) => setState(() => hepB2Given = v), onDate: (v) => setState(() => hepB2Date = v), onBy: (v) => setState(() => hepB2By = v)),
                      _buildGivenRow(label: 'HepB 3', given: hepB3Given, date: hepB3Date, by: hepB3By, onGiven: (v) => setState(() => hepB3Given = v), onDate: (v) => setState(() => hepB3Date = v), onBy: (v) => setState(() => hepB3By = v)),
                    ],
                  ),

                  if (selectEntryScreen == 'Vitamin A')
                  buildSectionCard(
                    context: context,
                    title: 'Vitamin A',
                    icon: Icons.vaccines_outlined,
                    children: [
                      _buildGivenRow(label: 'VitA 1', given: vitA1Given, date: vitA1Date, by: vitA1By, onGiven: (v) => setState(() => vitA1Given = v), onDate: (v) => setState(() => vitA1Date = v), onBy: (v) => setState(() => vitA1By = v)),
                      _buildGivenRow(label: 'VitA 2', given: vitA2Given, date: vitA2Date, by: vitA2By, onGiven: (v) => setState(() => vitA2Given = v), onDate: (v) => setState(() => vitA2Date = v), onBy: (v) => setState(() => vitA2By = v)),
                      _buildGivenRow(label: 'VitA 3', given: vitA3Given, date: vitA3Date, by: vitA3By, onGiven: (v) => setState(() => vitA3Given = v), onDate: (v) => setState(() => vitA3Date = v), onBy: (v) => setState(() => vitA3By = v)),
                      _buildGivenRow(label: 'VitA 4', given: vitA4Given, date: vitA4Date, by: vitA4By, onGiven: (v) => setState(() => vitA4Given = v), onDate: (v) => setState(() => vitA4Date = v), onBy: (v) => setState(() => vitA4By = v)),
                      _buildGivenRow(label: 'VitA Booster', given: vitABGiven, date: vitABDate, by: vitABBy, onGiven: (v) => setState(() => vitABGiven = v), onDate: (v) => setState(() => vitABDate = v), onBy: (v) => setState(() => vitABBy = v)),
                    ],
                  ),

                  if (selectEntryScreen == 'DT')
                  buildSectionCard(
                    context: context,
                    title: 'DT',
                    icon: Icons.vaccines_outlined,
                    children: [
                      _buildGivenRow(label: 'DT', given: dtGiven, date: dtDate, by: dtBy, onGiven: (v) => setState(() => dtGiven = v), onDate: (v) => setState(() => dtDate = v), onBy: (v) => setState(() => dtBy = v)),
                    ],
                  ),

                  if (selectEntryScreen == 'Remarks')
                  buildSectionCard(
                    context: context,
                    title: 'Other Information',
                    icon: Icons.notes_outlined,
                    children: [
                      TextFormField(controller: _birthWeight, decoration: const InputDecoration(labelText: 'Birth Weight (kg)'), keyboardType: TextInputType.number),
                      const SizedBox(height: 16),
                      TextFormField(controller: _birthHeight, decoration: const InputDecoration(labelText: 'Birth Height')),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Diarrhea'),
                        value: diarrhea,
                        items: ['Yes', 'No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => diarrhea = v),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Breastfeeding'),
                        value: breastfeeding,
                        items: ['Yes', 'No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => breastfeeding = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _remarks, decoration: const InputDecoration(labelText: 'Remarks'), maxLines: 3),
                    ],
                  ),
 
                  const SizedBox(height: 16),
                  if (selectEntryScreen != null)
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: Text(_isEditMode ? 'Update Immunization Record' : 'Save Immunization Record', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
