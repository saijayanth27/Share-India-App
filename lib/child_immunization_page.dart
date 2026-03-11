import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';

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

  // --- Identity Fields ---
  String? selectedFamilyCode;
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

      final members = snapshot.docs.map((doc) => doc.data()['Name']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      setState(() {
        familyMembers = members..sort();
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
      selectedFamilyCode = d['Family_Code'];
      if (selectedFamilyCode != null) _fetchMembersByFamily(selectedFamilyCode!);
      selectedName = d['Name'];
      _motherName.text = d['Mother_Name'] ?? '';
      selectEntryScreen = d['Select_Entry_Screen'];
      if (d['Date_of_Birth'] != null) dob = (d['Date_of_Birth'] as Timestamp).toDate();
      _regNo.text = d['Registration_Number'] ?? '';

      bcgGiven = d['BCG_Given_Y_N'];
      if (d['BCG_Dt'] != null) bcgDate = (d['BCG_Dt'] as Timestamp).toDate();
      bcgGivenBy = d['BCG_Given_By'];

      dpt1Given = d['DPT1_Given_Y_N'];
      if (d['DPT1_Dt3'] != null) dpt1Date = (d['DPT1_Dt3'] as Timestamp).toDate();
      dpt1By = d['DPT1_Given_Y_N1'];
      dpt2Given = d['DPT2_Given_Y_N2'];
      if (d['DPT2_Dt'] != null) dpt2Date = (d['DPT2_Dt'] as Timestamp).toDate();
      dpt2By = d['DPT2_Given_By'];
      dpt3Given = d['DPT3_Given_Y_N3'];
      if (d['DPT3_Dt'] != null) dpt3Date = (d['DPT3_Dt'] as Timestamp).toDate();
      dpt3By = d['DPT3_Given_By'];
      dptBGiven = d['DPTB_Given_Y_N'];
      if (d['DPT_B_Dt'] != null) dptBDate = (d['DPT_B_Dt'] as Timestamp).toDate();
      dptBBy = d['DPTB_Given_Y_N1'];

      opv0Given = d['OPVO_Given_Y_N'];
      if (d['OPV0_Dt'] != null) opv0Date = (d['OPV0_Dt'] as Timestamp).toDate();
      opv0By = d['OPVO_Given_By'];
      opv1Given = d['OPVO_Given_By1'];
      if (d['OPV_1_Dt'] != null) opv1Date = (d['OPV_1_Dt'] as Timestamp).toDate();
      opv1By = d['OPV1_Given_By'];
      opv2Given = d['OPV2_Given_yes_no'];
      if (d['OPV2_Dt'] != null) opv2Date = (d['OPV2_Dt'] as Timestamp).toDate();
      opv2By = d['Drop_OPV2_Given_By'];
      opv3Given = d['OPV3_Given_by_Y_N'];
      if (d['OPV3_Dt'] != null) opv3Date = (d['OPV3_Dt'] as Timestamp).toDate();
      opv3By = d['OPV2_Given_By2'];
      opvBGiven = d['OPV_B_Given_Y_N'];
      if (d['OPV_B_Dt'] != null) opvBDate = (d['OPV_B_Dt'] as Timestamp).toDate();
      opvBBy = d['OPV2_Given_By1'];

      measlesGiven = d['Measles1'];
      if (d['Measles_Dt'] != null) measlesDate = (d['Measles_Dt'] as Timestamp).toDate();
      measlesBy = d['Measles_Given_Y_N'];

      hepB1Given = d['HepB1_Given_Y_N'];
      if (d['HepB1_Dt'] != null) hepB1Date = (d['HepB1_Dt'] as Timestamp).toDate();
      hepB1By = d['HepB1_Given_By'];
      hepB2Given = d['HepB2_Given_Y_N'];
      if (d['HepB2_Dt'] != null) hepB2Date = (d['HepB2_Dt'] as Timestamp).toDate();
      hepB2By = d['HepB2'];
      hepB3Given = d['HepB3_Given_Y_N'];
      if (d['HepB3_Dt'] != null) hepB3Date = (d['HepB3_Dt'] as Timestamp).toDate();
      hepB3By = d['HepB3_Given_By'];

      vitA1Given = d['VitA1_Given_Y_N'];
      if (d['VitA1_Dt'] != null) vitA1Date = (d['VitA1_Dt'] as Timestamp).toDate();
      vitA1By = d['VitA1_Given_By'];
      vitA2Given = d['VitA2_Given_Y_N'];
      if (d['VitA2_Dt'] != null) vitA2Date = (d['VitA2_Dt'] as Timestamp).toDate();
      vitA2By = d['VitA2_Given_By'];
      vitA3Given = d['VitA3_Given_Y_N1'];
      if (d['VitA3_Dt'] != null) vitA3Date = (d['VitA3_Dt'] as Timestamp).toDate();
      vitA3By = d['V'];
      vitA4Given = d['Vita4_Given_Y_N'];
      if (d['VitA4_Dt'] != null) vitA4Date = (d['VitA4_Dt'] as Timestamp).toDate();
      vitA4By = d['VitA4_Given_By'];
      vitABGiven = d['VitAB_Given_Y_N'];
      if (d['VitAB_Dt1'] != null) vitABDate = (d['VitAB_Dt1'] as Timestamp).toDate();
      vitABBy = d['VitAB_Given_By'];

      dtGiven = d['DT_Given_Y_N'];
      if (d['DT_Dt'] != null) dtDate = (d['DT_Dt'] as Timestamp).toDate();
      dtBy = d['DT_Given_By'];

      _remarks.text = d['Remarks1'] ?? '';
      _birthWeight.text = d['Birth_Weight']?.toString() ?? '';
      _birthHeight.text = d['Birth_Height'] ?? '';
      diarrhea = d['Diarrhea'];
      breastfeeding = d['Breastfeeding'];
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      selectedFamilyCode = null; selectedName = null; _motherName.clear(); selectEntryScreen = null; dob = null; _regNo.clear();
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
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Family_Code': selectedFamilyCode,
        'Name': selectedName,
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

      if (widget.docId != null) {
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('Child Immunization'), backgroundColor: Theme.of(context).colorScheme.primaryContainer),
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
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Family Code', border: OutlineInputBorder()),
                        value: selectedFamilyCode,
                        items: allFamilyCodes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) {
                          setState(() { selectedFamilyCode = v; selectedName = null; });
                          if (v != null) _fetchMembersByFamily(v);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          border: const OutlineInputBorder(),
                          suffixIcon: _isLoadingMembers ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                        ),
                        value: selectedName,
                        items: familyMembers.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                        onChanged: (v) => setState(() => selectedName = v),
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
                        onChanged: (v) => setState(() => selectEntryScreen = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _regNo, decoration: const InputDecoration(labelText: 'Registration Number', border: OutlineInputBorder())),
                    ],
                  ),

                  if (selectEntryScreen == 'BCG')
                  _buildSectionCard(
                    title: 'BCG',
                    children: [
                      _buildGivenRow(label: 'BCG', given: bcgGiven, date: bcgDate, by: bcgGivenBy, onGiven: (v) => setState(() => bcgGiven = v), onDate: (v) => setState(() => bcgDate = v), onBy: (v) => setState(() => bcgGivenBy = v)),
                    ],
                  ),

                  if (selectEntryScreen == 'DPT')
                  _buildSectionCard(
                    title: 'DPT',
                    children: [
                      _buildGivenRow(label: 'DPT 1', given: dpt1Given, date: dpt1Date, by: dpt1By, onGiven: (v) => setState(() => dpt1Given = v), onDate: (v) => setState(() => dpt1Date = v), onBy: (v) => setState(() => dpt1By = v)),
                      _buildGivenRow(label: 'DPT 2', given: dpt2Given, date: dpt2Date, by: dpt2By, onGiven: (v) => setState(() => dpt2Given = v), onDate: (v) => setState(() => dpt2Date = v), onBy: (v) => setState(() => dpt2By = v)),
                      _buildGivenRow(label: 'DPT 3', given: dpt3Given, date: dpt3Date, by: dpt3By, onGiven: (v) => setState(() => dpt3Given = v), onDate: (v) => setState(() => dpt3Date = v), onBy: (v) => setState(() => dpt3By = v)),
                      _buildGivenRow(label: 'DPT Booster', given: dptBGiven, date: dptBDate, by: dptBBy, onGiven: (v) => setState(() => dptBGiven = v), onDate: (v) => setState(() => dptBDate = v), onBy: (v) => setState(() => dptBBy = v)),
                    ],
                  ),

                  if (selectEntryScreen == 'OPV')
                  _buildSectionCard(
                    title: 'OPV',
                    children: [
                      _buildGivenRow(label: 'OPV 0', given: opv0Given, date: opv0Date, by: opv0By, onGiven: (v) => setState(() => opv0Given = v), onDate: (v) => setState(() => opv0Date = v), onBy: (v) => setState(() => opv0By = v)),
                      _buildGivenRow(label: 'OPV 1', given: opv1Given, date: opv1Date, by: opv1By, onGiven: (v) => setState(() => opv1Given = v), onDate: (v) => setState(() => opv1Date = v), onBy: (v) => setState(() => opv1By = v)),
                      _buildGivenRow(label: 'OPV 2', given: opv2Given, date: opv2Date, by: opv2By, onGiven: (v) => setState(() => opv2Given = v), onDate: (v) => setState(() => opv2Date = v), onBy: (v) => setState(() => opv2By = v)),
                      _buildGivenRow(label: 'OPV 3', given: opv3Given, date: opv3Date, by: opv3By, onGiven: (v) => setState(() => opv3Given = v), onDate: (v) => setState(() => opv3Date = v), onBy: (v) => setState(() => opv3By = v)),
                      _buildGivenRow(label: 'OPV Booster', given: opvBGiven, date: opvBDate, by: opvBBy, onGiven: (v) => setState(() => opvBGiven = v), onDate: (v) => setState(() => opvBDate = v), onBy: (v) => setState(() => opvBBy = v)),
                    ],
                  ),

                  if (selectEntryScreen == 'Measles')
                  _buildSectionCard(
                    title: 'Measles',
                    children: [
                      _buildGivenRow(label: 'Measles', given: measlesGiven, date: measlesDate, by: measlesBy, onGiven: (v) => setState(() => measlesGiven = v), onDate: (v) => setState(() => measlesDate = v), onBy: (v) => setState(() => measlesBy = v)),
                    ],
                  ),

                  if (selectEntryScreen == 'HepB')
                  _buildSectionCard(
                    title: 'HepB',
                    children: [
                      _buildGivenRow(label: 'HepB 1', given: hepB1Given, date: hepB1Date, by: hepB1By, onGiven: (v) => setState(() => hepB1Given = v), onDate: (v) => setState(() => hepB1Date = v), onBy: (v) => setState(() => hepB1By = v)),
                      _buildGivenRow(label: 'HepB 2', given: hepB2Given, date: hepB2Date, by: hepB2By, onGiven: (v) => setState(() => hepB2Given = v), onDate: (v) => setState(() => hepB2Date = v), onBy: (v) => setState(() => hepB2By = v)),
                      _buildGivenRow(label: 'HepB 3', given: hepB3Given, date: hepB3Date, by: hepB3By, onGiven: (v) => setState(() => hepB3Given = v), onDate: (v) => setState(() => hepB3Date = v), onBy: (v) => setState(() => hepB3By = v)),
                    ],
                  ),

                  if (selectEntryScreen == 'Vitamin A')
                  _buildSectionCard(
                    title: 'Vitamin A',
                    children: [
                      _buildGivenRow(label: 'VitA 1', given: vitA1Given, date: vitA1Date, by: vitA1By, onGiven: (v) => setState(() => vitA1Given = v), onDate: (v) => setState(() => vitA1Date = v), onBy: (v) => setState(() => vitA1By = v)),
                      _buildGivenRow(label: 'VitA 2', given: vitA2Given, date: vitA2Date, by: vitA2By, onGiven: (v) => setState(() => vitA2Given = v), onDate: (v) => setState(() => vitA2Date = v), onBy: (v) => setState(() => vitA2By = v)),
                      _buildGivenRow(label: 'VitA 3', given: vitA3Given, date: vitA3Date, by: vitA3By, onGiven: (v) => setState(() => vitA3Given = v), onDate: (v) => setState(() => vitA3Date = v), onBy: (v) => setState(() => vitA3By = v)),
                      _buildGivenRow(label: 'VitA 4', given: vitA4Given, date: vitA4Date, by: vitA4By, onGiven: (v) => setState(() => vitA4Given = v), onDate: (v) => setState(() => vitA4Date = v), onBy: (v) => setState(() => vitA4By = v)),
                      _buildGivenRow(label: 'VitA Booster', given: vitABGiven, date: vitABDate, by: vitABBy, onGiven: (v) => setState(() => vitABGiven = v), onDate: (v) => setState(() => vitABDate = v), onBy: (v) => setState(() => vitABBy = v)),
                    ],
                  ),

                  if (selectEntryScreen == 'DT')
                  _buildSectionCard(
                    title: 'DT',
                    children: [
                      _buildGivenRow(label: 'DT', given: dtGiven, date: dtDate, by: dtBy, onGiven: (v) => setState(() => dtGiven = v), onDate: (v) => setState(() => dtDate = v), onBy: (v) => setState(() => dtBy = v)),
                    ],
                  ),

                  if (selectEntryScreen == 'Remarks')
                  _buildSectionCard(
                    title: 'Other Information',
                    children: [
                      TextFormField(controller: _birthWeight, decoration: const InputDecoration(labelText: 'Birth Weight (kg)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                      const SizedBox(height: 16),
                      TextFormField(controller: _birthHeight, decoration: const InputDecoration(labelText: 'Birth Height', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Diarrhea', border: OutlineInputBorder()),
                        value: diarrhea,
                        items: ['Yes', 'No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => diarrhea = v),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Breastfeeding', border: OutlineInputBorder()),
                        value: breastfeeding,
                        items: ['Yes', 'No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => breastfeeding = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _remarks, decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()), maxLines: 3),
                    ],
                  ),
 
                  const SizedBox(height: 16),
                  if (selectEntryScreen != null)
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Save Immunization Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
