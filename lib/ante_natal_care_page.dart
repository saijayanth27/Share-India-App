import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';

class AnteNatalCarePage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const AnteNatalCarePage({super.key, this.existingData, this.docId});

  @override
  State<AnteNatalCarePage> createState() => _AnteNatalCarePageState();
}

class _AnteNatalCarePageState extends State<AnteNatalCarePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // --- Identity Fields ---
  String? selectedFamilyCode;
  String? selectedName;
  final _husbandName = TextEditingController();
  DateTime? lmpDate;
  String? selectEntryScreen;
  final _uniqRegNo = TextEditingController();
  final _regNo = TextEditingController();

  // --- TT Dose Fields ---
  String? tt1Given;
  String? tt1GivenBy;
  DateTime? tt1Date;
  String? tt2Given;
  String? tt2GivenBy;
  DateTime? tt2Date;

  // --- IFA Fields ---
  String? ifa1Given;
  DateTime? ifa1Date;
  String? ifa1GivenBy;
  String? ifa2Given;
  DateTime? ifa2Date;
  String? ifa2GivenBy;
  String? ifa3Given;
  DateTime? ifa3Date;
  String? ifa3GivenBy;
  String? ifa4Given;
  DateTime? ifa4Date;
  String? ifa4GivenBy;

  // --- Delivery Fields ---
  String? deliveryType;
  DateTime? deliveryDate;
  String? deliveryPlace;
  final _deliveryPlaceDetails = TextEditingController();
  String? deliveryOutcome;
  final _totalLiveBirths = TextEditingController();

  // --- Remarks & Extra ---
  final _remarks = TextEditingController();
  String? gender;
  final _noOfBirths = TextEditingController();
  final _noOfBirthsFemale = TextEditingController();

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

      final females = snapshot.docs.map((doc) => doc.data()['Name']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
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
      selectedName = d['Female'];
      _husbandName.text = d['Husband_Name'] ?? '';
      if (d['LMP_Date'] != null) lmpDate = (d['LMP_Date'] as Timestamp).toDate();
      selectEntryScreen = d['Select_Entry_Screen'];
      _uniqRegNo.text = d['uniq_Registration_Number'] ?? '';
      _regNo.text = d['Registration_Number'] ?? '';

      tt1Given = d['st_Given_Y_N'];
      tt1GivenBy = d['st_Given_By'];
      if (d['st_Dt'] != null) tt1Date = (d['st_Dt'] as Timestamp).toDate();
      tt2Given = d['nd_Given_Y_N'];
      tt2GivenBy = d['nd_Given_By'];
      if (d['nd_Dt'] != null) tt2Date = (d['nd_Dt'] as Timestamp).toDate();

      ifa1Given = d['st_Given_Y_N1'];
      if (d['st_Dt1'] != null) ifa1Date = (d['st_Dt1'] as Timestamp).toDate();
      ifa1GivenBy = d['st_Given_By1'];
      ifa2Given = d['nd_Given_Y_N1'];
      if (d['nd_Dt1'] != null) ifa2Date = (d['nd_Dt1'] as Timestamp).toDate();
      ifa2GivenBy = d['nd_Given_By1'];
      ifa3Given = d['rd_Given_Y_N'];
      if (d['rd_Dt'] != null) ifa3Date = (d['rd_Dt'] as Timestamp).toDate();
      ifa3GivenBy = d['rd_Given_Y_N1'];
      ifa4Given = d['TH_Given_Y_N'];
      if (d['th_Dt'] != null) ifa4Date = (d['th_Dt'] as Timestamp).toDate();
      ifa4GivenBy = d['TH_Given_Y_N1'];

      deliveryType = d['Delivery_Type'];
      if (d['Delivery_Dt'] != null) deliveryDate = (d['Delivery_Dt'] as Timestamp).toDate();
      deliveryPlace = d['Delivery_Place'];
      _deliveryPlaceDetails.text = d['Delivery_Place_Details'] ?? '';
      deliveryOutcome = d['Delivery'];
      _totalLiveBirths.text = d['Total_Live_Births'] ?? '';

      _remarks.text = d['Remarks2'] ?? '';
      gender = d['Gender'];
      _noOfBirths.text = d['No_of_Births']?.toString() ?? '';
      _noOfBirthsFemale.text = d['No_of_Birth_of_Female1']?.toString() ?? '';
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      selectedFamilyCode = null;
      selectedName = null;
      _husbandName.clear();
      lmpDate = null;
      selectEntryScreen = null;
      _uniqRegNo.clear();
      _regNo.clear();
      tt1Given = null; tt1GivenBy = null; tt1Date = null;
      tt2Given = null; tt2GivenBy = null; tt2Date = null;
      ifa1Given = null; ifa1Date = null; ifa1GivenBy = null;
      ifa2Given = null; ifa2Date = null; ifa2GivenBy = null;
      ifa3Given = null; ifa3Date = null; ifa3GivenBy = null;
      ifa4Given = null; ifa4Date = null; ifa4GivenBy = null;
      deliveryType = null; deliveryDate = null; deliveryPlace = null;
      _deliveryPlaceDetails.clear();
      deliveryOutcome = null;
      _totalLiveBirths.clear();
      _remarks.clear();
      gender = null;
      _noOfBirths.clear();
      _noOfBirthsFemale.clear();
      femaleMembers = [];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Family_Code': selectedFamilyCode,
        'Female': selectedName,
        'Husband_Name': _husbandName.text,
        'LMP_Date': lmpDate != null ? Timestamp.fromDate(lmpDate!) : null,
        'Select_Entry_Screen': selectEntryScreen,
        'uniq_Registration_Number': _uniqRegNo.text,
        'Registration_Number': _regNo.text,
        'st_Given_Y_N': tt1Given,
        'st_Given_By': tt1GivenBy,
        'st_Dt': tt1Date != null ? Timestamp.fromDate(tt1Date!) : null,
        'nd_Given_Y_N': tt2Given,
        'nd_Given_By': tt2GivenBy,
        'nd_Dt': tt2Date != null ? Timestamp.fromDate(tt2Date!) : null,
        'st_Given_Y_N1': ifa1Given,
        'st_Dt1': ifa1Date != null ? Timestamp.fromDate(ifa1Date!) : null,
        'st_Given_By1': ifa1GivenBy,
        'nd_Given_Y_N1': ifa2Given,
        'nd_Dt1': ifa2Date != null ? Timestamp.fromDate(ifa2Date!) : null,
        'nd_Given_By1': ifa2GivenBy,
        'rd_Given_Y_N': ifa3Given,
        'rd_Dt': ifa3Date != null ? Timestamp.fromDate(ifa3Date!) : null,
        'rd_Given_Y_N1': ifa3GivenBy,
        'TH_Given_Y_N': ifa4Given,
        'th_Dt': ifa4Date != null ? Timestamp.fromDate(ifa4Date!) : null,
        'TH_Given_Y_N1': ifa4GivenBy,
        'Delivery_Type': deliveryType,
        'Delivery_Dt': deliveryDate != null ? Timestamp.fromDate(deliveryDate!) : null,
        'Delivery_Place': deliveryPlace,
        'Delivery_Place_Details': _deliveryPlaceDetails.text,
        'Delivery': deliveryOutcome,
        'Total_Live_Births': _totalLiveBirths.text,
        'Remarks2': _remarks.text,
        'Gender': gender,
        'No_of_Births': int.tryParse(_noOfBirths.text),
        'No_of_Birth_of_Female1': int.tryParse(_noOfBirthsFemale.text),
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('ante_natal_care').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('ante_natal_care').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ANC record saved successfully!'), backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('Ante Natal Care'), backgroundColor: Theme.of(context).colorScheme.primaryContainer),
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
                          if (v != null) _fetchFemalesByFamily(v);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Name (Female)',
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
                      _buildDatePicker(label: 'LMP Date', value: lmpDate, onPicked: (v) => setState(() => lmpDate = v)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Select Entry Screen', border: OutlineInputBorder()),
                        value: selectEntryScreen,
                        items: ['TT Dose', 'IFA', 'Delivery', 'Remarks'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => selectEntryScreen = v),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _regNo, decoration: const InputDecoration(labelText: 'Reg No.', border: OutlineInputBorder()))),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _uniqRegNo, decoration: const InputDecoration(labelText: 'Uniq Reg No.', border: OutlineInputBorder()))),
                        ],
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'TT Dose',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: '1st Given Y/N', border: OutlineInputBorder()),
                              value: tt1Given,
                              items: ['(1) Yes', '(0) No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (v) => setState(() => tt1Given = v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDatePicker(label: '1st TT Dt.', value: tt1Date, onPicked: (v) => setState(() => tt1Date = v))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '1st Given By', border: OutlineInputBorder()),
                        value: tt1GivenBy,
                        items: ['(0) RHC', '(1) PVT', '(2) GOVT'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => tt1GivenBy = v),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: '2nd Given Y/N', border: OutlineInputBorder()),
                              value: tt2Given,
                              items: ['(1) Yes', '(0) No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (v) => setState(() => tt2Given = v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDatePicker(label: '2nd TT Dt.', value: tt2Date, onPicked: (v) => setState(() => tt2Date = v))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '2nd Given By', border: OutlineInputBorder()),
                        value: tt2GivenBy,
                        items: ['(0) RHC', '(1) PVT', '(2) GOVT'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => tt2GivenBy = v),
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'IFA (Iron Folic Acid)',
                    children: [
                      _buildIFARow('1st', ifa1Given, ifa1Date, ifa1GivenBy, (g) => tt1Given = g, (d) => ifa1Date = d, (b) => ifa1GivenBy = b),
                      const SizedBox(height: 16),
                      _buildIFARow('2nd', ifa2Given, ifa2Date, ifa2GivenBy, (g) => ifa2Given = g, (d) => ifa2Date = d, (b) => ifa2GivenBy = b),
                      const SizedBox(height: 16),
                      _buildIFARow('3rd', ifa3Given, ifa3Date, ifa3GivenBy, (g) => ifa3Given = g, (d) => ifa3Date = d, (b) => ifa3GivenBy = b),
                      const SizedBox(height: 16),
                      _buildIFARow('4th', ifa4Given, ifa4Date, ifa4GivenBy, (g) => ifa4Given = g, (d) => ifa4Date = d, (b) => ifa4GivenBy = b),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Delivery Details',
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Delivery Type', border: OutlineInputBorder()),
                        value: deliveryType,
                        items: ['(0) Normal', '(1) Caesarian', '(2) Abortion'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => deliveryType = v),
                      ),
                      const SizedBox(height: 16),
                      _buildDatePicker(label: 'Delivery Dt.', value: deliveryDate, onPicked: (v) => setState(() => deliveryDate = v)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Delivery Place', border: OutlineInputBorder()),
                        value: deliveryPlace,
                        items: ['(0) RHC', '(1) PVT', '(2) GOVT', '(3) HOME'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => deliveryPlace = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _deliveryPlaceDetails, decoration: const InputDecoration(labelText: 'Place Details', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Outcome', border: OutlineInputBorder()),
                        value: deliveryOutcome,
                        items: ['(0) Live Birth', '(1) Still Birth', '(2) Premature'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => deliveryOutcome = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _totalLiveBirths, decoration: const InputDecoration(labelText: 'Total Live Births', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Extra Info & Remarks',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                              value: gender,
                              items: ['Male', 'Female'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (v) => setState(() => gender = v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _noOfBirths, decoration: const InputDecoration(labelText: 'No. of Births', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _noOfBirthsFemale, decoration: const InputDecoration(labelText: 'No. of Female Births', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                      const SizedBox(height: 16),
                      TextFormField(controller: _remarks, decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()), maxLines: 3),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Save ANC Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildIFARow(String step, String? given, DateTime? date, String? by, Function(String?) onGiven, Function(DateTime) onDate, Function(String?) onBy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(step, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Given Y/N', border: OutlineInputBorder()),
                value: given,
                items: ['(1) Yes', '(0) No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: onGiven,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _buildDatePicker(label: 'IFA Dt.', value: date, onPicked: onDate)),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Given By', border: OutlineInputBorder()),
          value: by,
          items: ['(0) RHC', '(1) PVT', '(2) GOVT'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onBy,
        ),
      ],
    );
  }
}
