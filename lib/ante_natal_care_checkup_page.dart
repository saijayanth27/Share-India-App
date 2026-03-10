import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';

class AnteNatalCareCheckupPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const AnteNatalCareCheckupPage({super.key, this.existingData, this.docId});

  @override
  State<AnteNatalCareCheckupPage> createState() => _AnteNatalCareCheckupPageState();
}

class _AnteNatalCareCheckupPageState extends State<AnteNatalCareCheckupPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // --- Identity Fields ---
  String? selectedFamilyCode;
  String? selectedName;
  final _visitNo = TextEditingController();
  DateTime? lmpDate;
  final _countOfCheckup = TextEditingController();

  // --- Checkup Details ---
  DateTime? checkupDt;
  String? checkupPlace;

  // --- Medical Test Fields ---
  String? hbsag;
  String? hb;
  String? ultraS;
  String? vdrl;
  String? urine;
  String? hiv;

  // --- Vitals & BP ---
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _bpStr = TextEditingController();
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();

  // --- Remarks ---
  final _remarks = TextEditingController();

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
      selectedName = d['Name'];
      _visitNo.text = d['Visit_No'] ?? '';
      if (d['LMP_date'] != null) lmpDate = (d['LMP_date'] as Timestamp).toDate();
      _countOfCheckup.text = d['Count_of_Checkup']?.toString() ?? '';

      if (d['Checkup_Dt'] != null) checkupDt = (d['Checkup_Dt'] as Timestamp).toDate();
      checkupPlace = d['Checkup_Place'];

      hbsag = d['HBSAG'];
      hb = d['HB'];
      ultraS = d['Ultra_S'];
      vdrl = d['VDRL'];
      urine = d['Urine'];
      hiv = d['HIV'];

      _weight.text = d['Weight'] ?? '';
      _height.text = d['Height'] ?? '';
      _bpStr.text = d['BP'] ?? '';
      _systolic.text = d['Systolic'] ?? '';
      _diastolic.text = d['Diastolic'] ?? '';

      _remarks.text = d['Remarks'] ?? '';
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      selectedFamilyCode = null; selectedName = null; _visitNo.clear(); lmpDate = null; _countOfCheckup.clear();
      checkupDt = null; checkupPlace = null;
      hbsag = null; hb = null; ultraS = null; vdrl = null; urine = null; hiv = null;
      _weight.clear(); _height.clear(); _bpStr.clear(); _systolic.clear(); _diastolic.clear();
      _remarks.clear();
      femaleMembers = [];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Family_Code': selectedFamilyCode,
        'Name': selectedName,
        'Visit_No': _visitNo.text,
        'LMP_date': lmpDate != null ? Timestamp.fromDate(lmpDate!) : null,
        'Count_of_Checkup': int.tryParse(_countOfCheckup.text),
        'Checkup_Dt': checkupDt != null ? Timestamp.fromDate(checkupDt!) : null,
        'Checkup_Place': checkupPlace,
        'HBSAG': hbsag,
        'HB': hb,
        'Ultra_S': ultraS,
        'VDRL': vdrl,
        'Urine': urine,
        'HIV': hiv,
        'Weight': _weight.text,
        'Height': _height.text,
        'BP': _bpStr.text,
        'Systolic': _systolic.text,
        'Diastolic': _diastolic.text,
        'Remarks': _remarks.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('ante_natal_care_checkup').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('ante_natal_care_checkup').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ANC Checkup saved successfully!'), backgroundColor: Colors.green),
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
      appBar: AppBar(title: const Text('ANC Checkup'), backgroundColor: Theme.of(context).colorScheme.primaryContainer),
      drawer: const AppDrawer(),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionCard(
                    title: 'Identity & Visit Info',
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
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _visitNo, decoration: const InputDecoration(labelText: 'Visit No', border: OutlineInputBorder()))),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _countOfCheckup, decoration: const InputDecoration(labelText: 'Count of Checkup', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDatePicker(label: 'LMP Date', value: lmpDate, onPicked: (v) => setState(() => lmpDate = v)),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Checkup Details',
                    children: [
                      _buildDatePicker(label: 'Checkup Date', value: checkupDt, onPicked: (v) => setState(() => checkupDt = v)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Checkup Place', border: OutlineInputBorder()),
                        value: checkupPlace,
                        items: ['RHC (MEDICITI)', 'PVT HOSPITAL', 'GOVT HOSPITAL'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => checkupPlace = v),
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Medical Test Results',
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildTestDropdown('HBSAG', hbsag, (v) => setState(() => hbsag = v))),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTestDropdown('HB', hb, (v) => setState(() => hb = v))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildTestDropdown('Ultra S', ultraS, (v) => setState(() => ultraS = v))),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTestDropdown('VDRL', vdrl, (v) => setState(() => vdrl = v))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildTestDropdown('Urine', urine, (v) => setState(() => urine = v))),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTestDropdown('HIV', hiv, (v) => setState(() => hiv = v))),
                        ],
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Physical & BP',
                    children: [
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _weight, decoration: const InputDecoration(labelText: 'Weight', border: OutlineInputBorder()))),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _height, decoration: const InputDecoration(labelText: 'Height', border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _bpStr, decoration: const InputDecoration(labelText: 'BP (Generic)', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _systolic, decoration: const InputDecoration(labelText: 'Systolic', border: OutlineInputBorder()))),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _diastolic, decoration: const InputDecoration(labelText: 'Diastolic', border: OutlineInputBorder()))),
                        ],
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Remarks',
                    children: [
                      TextFormField(controller: _remarks, decoration: const InputDecoration(labelText: 'Checkup Remarks', border: OutlineInputBorder()), maxLines: 3),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Save Checkup Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildTestDropdown(String label, String? value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      value: (value == 'Choice 1' || value == 'Choice 2' || value == 'Choice 3' || value == null) ? value : null,
      items: ['Choice 1', 'Choice 2', 'Choice 3'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}
