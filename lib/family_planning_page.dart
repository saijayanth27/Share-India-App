import "package:flutter/material.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

class FamilyPlanningPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const FamilyPlanningPage({super.key, this.existingData, this.docId});

  @override
  State<FamilyPlanningPage> createState() => _FamilyPlanningPageState();
}

class _FamilyPlanningPageState extends State<FamilyPlanningPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // --- Identity Fields ---
  String? selectedFamilyCode;
  final _familyCodeOld = TextEditingController();
  final _finalFamilyCode = TextEditingController();
  String? selectedName;
  final _husbandName = TextEditingController();
  String? selectEntryScreen;
  final _regNo = TextEditingController();

  // --- Temporary Fields ---
  String? usedOral;
  final _howLongOral = TextEditingController();
  DateTime? lastUseOralDate;
  String? usedInjectable;
  String? howLongInjectable;
  DateTime? lastUseInjectableDate;
  String? usedCondoms;
  DateTime? condomsDate;
  String? usedCopperT;
  String? usedOther;
  final _otherIfYes = TextEditingController();

  // --- Permanent Fields ---
  String? usedPermanent;
  DateTime? permanentDate;
  String? permanentPlace;
  final _permanentRemarks = TextEditingController();

  // Lookups
  List<String> allFamilyCodes = [];
  List<String> femaleMembers = [];
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

  Future<void> _fetchFemalesByFamily(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyCode)
          .where('Gender', isEqualTo: '(0) Female')
          .get();

      final females = snapshot.docs
          .map((doc) => doc.data()['Name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      setState(() {
        femaleMembers = females..sort();
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
      if (selectedFamilyCode != null) _fetchFemalesByFamily(selectedFamilyCode!);
      _familyCodeOld.text = d['Family_Code_Old'] ?? '';
      _finalFamilyCode.text = d['Final_Family_Code'] ?? '';
      selectedName = d['Name'];
      _husbandName.text = d['Husband_Name'] ?? '';
      selectEntryScreen = d['Select_Entry_Screen'];
      _regNo.text = d['Registration_Number'] ?? '';

      usedOral = d['Used_Oral'];
      _howLongOral.text = d['How_Long_Oral'] ?? '';
      if (d['Last_Use_Oral_Date'] != null) lastUseOralDate = (d['Last_Use_Oral_Date'] as Timestamp).toDate();
      usedInjectable = d['Used_Injectable'];
      howLongInjectable = d['How_Long_Injectable'];
      if (d['Last_Use_Injectable_Date'] != null) lastUseInjectableDate = (d['Last_Use_Injectable_Date'] as Timestamp).toDate();
      usedCondoms = d['Used_Condoms'];
      if (d['Condoms_Date'] != null) condomsDate = (d['Condoms_Date'] as Timestamp).toDate();
      usedCopperT = d['Used_Copper_T'];
      usedOther = d['Used_Other'];
      _otherIfYes.text = d['Other_If_Yes'] ?? '';

      usedPermanent = d['Used_Permanent'];
      if (d['Permanent_Date'] != null) permanentDate = (d['Permanent_Date'] as Timestamp).toDate();
      permanentPlace = d['Permanent_Place'];
      _permanentRemarks.text = d['Permanent_Remarks'] ?? '';
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      selectedFamilyCode = null;
      _familyCodeOld.clear();
      _finalFamilyCode.clear();
      selectedName = null;
      _husbandName.clear();
      selectEntryScreen = null;
      _regNo.clear();

      usedOral = null;
      _howLongOral.clear();
      lastUseOralDate = null;
      usedInjectable = null;
      howLongInjectable = null;
      lastUseInjectableDate = null;
      usedCondoms = null;
      condomsDate = null;
      usedCopperT = null;
      usedOther = null;
      _otherIfYes.clear();

      usedPermanent = null;
      permanentDate = null;
      permanentPlace = null;
      _permanentRemarks.clear();
      femaleMembers = [];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Family_Code': selectedFamilyCode,
        'Family_Code_Old': _familyCodeOld.text,
        'Final_Family_Code': _finalFamilyCode.text,
        'Name': selectedName,
        'Husband_Name': _husbandName.text,
        'Select_Entry_Screen': selectEntryScreen,
        'Registration_Number': _regNo.text,

        'Used_Oral': usedOral,
        'How_Long_Oral': _howLongOral.text,
        'Last_Use_Oral_Date': lastUseOralDate != null ? Timestamp.fromDate(lastUseOralDate!) : null,
        'Used_Injectable': usedInjectable,
        'How_Long_Injectable': howLongInjectable,
        'Last_Use_Injectable_Date': lastUseInjectableDate != null ? Timestamp.fromDate(lastUseInjectableDate!) : null,
        'Used_Condoms': usedCondoms,
        'Condoms_Date': condomsDate != null ? Timestamp.fromDate(condomsDate!) : null,
        'Used_Copper_T': usedCopperT,
        'Used_Other': usedOther,
        'Other_If_Yes': _otherIfYes.text,

        'Used_Permanent': usedPermanent,
        'Permanent_Date': permanentDate != null ? Timestamp.fromDate(permanentDate!) : null,
        'Permanent_Place': permanentPlace,
        'Permanent_Remarks': _permanentRemarks.text,
        
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('family_planning').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('family_planning').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Family Planning record saved successfully!'), backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Family Planning', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    title: 'Family Planning',
                    subtitle: 'Manage contraceptive and family records',
                  ),
                  buildSectionCard(
                    context: context,
                    title: 'Basic Information',
                    icon: Icons.info_outline,
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Family Code', border: OutlineInputBorder()),
                        value: selectedFamilyCode,
                        items: allFamilyCodes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) {
                          setState(() { selectedFamilyCode = v; selectedName = null; });
                          if (v != null) _fetchFemalesByFamily(v);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _familyCodeOld, decoration: const InputDecoration(labelText: 'Family Code old', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextFormField(controller: _finalFamilyCode, decoration: const InputDecoration(labelText: 'Final family code', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          border: const OutlineInputBorder(),
                          suffixIcon: _isLoadingMembers ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                        ),
                        value: selectedName,
                        items: femaleMembers.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                        onChanged: (v) => setState(() => selectedName = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _husbandName, decoration: const InputDecoration(labelText: 'Husband Name', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Select Entry Screen', border: OutlineInputBorder()),
                        value: selectEntryScreen,
                        items: ['(0) Temporary', '(1) Permanent'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => selectEntryScreen = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _regNo, decoration: const InputDecoration(labelText: 'Registration Number', border: OutlineInputBorder())),
                    ],
                  ),

                  if (selectEntryScreen == '(0) Temporary')
                  buildSectionCard(
                    context: context,
                    title: 'Temporary Section',
                    icon: Icons.timer_outlined,
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Used oral contraceptives?'),
                        value: usedOral,
                        items: ['(1) Yes', '(0) No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => usedOral = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _howLongOral, decoration: const InputDecoration(labelText: 'How long use oral', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      _buildDatePicker(label: 'Last use oral contraceptives?', value: lastUseOralDate, onPicked: (v) => setState(() => lastUseOralDate = v)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Used injectable contraceptives?', border: OutlineInputBorder()),
                        value: usedInjectable,
                        items: ['(1) Yes', '(0) No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => usedInjectable = v),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'How long using injectable contraceptives?', border: OutlineInputBorder()),
                        value: howLongInjectable,
                        items: ['Choice 1', 'Choice 2'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => howLongInjectable = v),
                      ),
                      const SizedBox(height: 16),
                      _buildDatePicker(label: 'Last use injectable contraceptives?', value: lastUseInjectableDate, onPicked: (v) => setState(() => lastUseInjectableDate = v)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Used condoms?', border: OutlineInputBorder()),
                        value: usedCondoms,
                        items: ['(1) Yes', '(0) No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => usedCondoms = v),
                      ),
                      const SizedBox(height: 16),
                      _buildDatePicker(label: 'Date?', value: condomsDate, onPicked: (v) => setState(() => condomsDate = v)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Used an Copper-T?', border: OutlineInputBorder()),
                        value: usedCopperT,
                        items: ['(1) Yes', '(0) No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => usedCopperT = v),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Used other?', border: OutlineInputBorder()),
                        value: usedOther,
                        items: ['(1) Yes', '(0) No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => usedOther = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _otherIfYes, decoration: const InputDecoration(labelText: 'If yes,', border: OutlineInputBorder())),
                    ],
                  ),

                  if (selectEntryScreen == '(1) Permanent')
                  buildSectionCard(
                    context: context,
                    title: 'Permanent Section',
                    icon: Icons.check_circle_outline,
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Used?'),
                        value: usedPermanent,
                        items: ['(0) Tubectomy', '(1) Vasectomy' , '(2) Hysectomy'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => usedPermanent = v),
                      ),
                      const SizedBox(height: 16),
                      _buildDatePicker(label: 'Date?', value: permanentDate, onPicked: (v) => setState(() => permanentDate = v)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Place?', border: OutlineInputBorder()),
                        value: permanentPlace,
                        items: ['(0) RHC ', '(1) PVT', '(2) GOVT'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => permanentPlace = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _permanentRemarks, decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()), maxLines: 3),
                    ],
                  ),

                  const SizedBox(height: 16),
                  if (selectEntryScreen != null)
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Submit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
