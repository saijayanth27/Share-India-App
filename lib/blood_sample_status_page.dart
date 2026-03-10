import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';

class BloodSampleStatusPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const BloodSampleStatusPage({super.key, this.existingData, this.docId});

  @override
  State<BloodSampleStatusPage> createState() => _BloodSampleStatusPageState();
}

class _BloodSampleStatusPageState extends State<BloodSampleStatusPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // --- Controllers & State Variables ---
  final _registrationNumber = TextEditingController();
  final _age = TextEditingController();
  
  String? selectedFamilyCode;
  String? selectedName;
  String? selectedGender;
  DateTime? dateOfInterview = DateTime.now();
  String? interviewersName;
  String? notDoneReason;

  // Status Fields
  String? collectBloodSample;
  String? collectHBA1C;
  String? collectThyroid;
  String? collectCRE;
  String? collectSputumTB;
  String? collectVaginalSwabHPV;
  String? collectUrine;

  // Date Fields
  DateTime? dateCBP;
  DateTime? dateHBA1C;
  DateTime? dateThyroid;
  DateTime? dateCRE;
  DateTime? dateSputumTB;
  DateTime? dateVaginalSwabHPV;
  DateTime? dateUrine;
  DateTime? entryDate = DateTime.now();
  DateTime? modifiedDate = DateTime.now();

  List<String> allFamilyCodes = [];
  List<String> allNames = [];
  bool _isLoadingLookups = false;

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

  Future<void> _fetchNamesByFamily(String familyCode) async {
    setState(() => _isLoadingLookups = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyCode)
          .get();

      final names = snapshot.docs.map((doc) => doc.data()['Name']?.toString() ?? '').where((name) => name.isNotEmpty).toList();

      setState(() {
        allNames = names..sort();
        _isLoadingLookups = false;
      });
    } catch (e) {
      debugPrint('Error fetching names: $e');
      setState(() => _isLoadingLookups = false);
    }
  }

  void _loadExistingData() {
    final d = widget.existingData!;
    setState(() {
      _registrationNumber.text = d['Registration_Number']?.toString() ?? '';
      selectedFamilyCode = d['Family_code'];
      selectedName = d['Name'];
      selectedGender = d['Gender'];
      _age.text = d['Age']?.toString() ?? '';
      if (d['Date_of_Interview'] != null) dateOfInterview = (d['Date_of_Interview'] as Timestamp).toDate();
      interviewersName = d['Interviewer_s_Name'];
      notDoneReason = d['If_not_done_reason'];

      collectBloodSample = d['Did_you_collect_Blood_Sample1'];
      collectHBA1C = d['Did_you_collected_Blood_sample_for_HBA1C'];
      collectThyroid = d['Did_you_collected_Blood_sample_for_THYROID'];
      collectCRE = d['Did_you_collected_Blood_sample_for_CRE'];
      collectSputumTB = d['Did_you_collected_SPUTUM_sample_for_TB_Test'];
      collectVaginalSwabHPV = d['Did_you_collected_Vaginal_Swab_sample_for_HPV'];
      collectUrine = d['Did_you_collected_Urine_sample'];

      if (d['Date_of_Blood_sample_collection_for_CBP'] != null) dateCBP = (d['Date_of_Blood_sample_collection_for_CBP'] as Timestamp).toDate();
      if (d['Date_of_Blood_sample_collection_for_HBA1C'] != null) dateHBA1C = (d['Date_of_Blood_sample_collection_for_HBA1C'] as Timestamp).toDate();
      if (d['Date_of_Blood_sample_collection_for_THYROID'] != null) dateThyroid = (d['Date_of_Blood_sample_collection_for_THYROID'] as Timestamp).toDate();
      if (d['Date_of_Blood_sample_collection_for_CRE'] != null) dateCRE = (d['Date_of_Blood_sample_collection_for_CRE'] as Timestamp).toDate();
      if (d['Date_of_Sputum_sample_collection_for_TB_Test'] != null) dateSputumTB = (d['Date_of_Sputum_sample_collection_for_TB_Test'] as Timestamp).toDate();
      if (d['Date_of_V_Swab_sample_collection_for_HPV'] != null) dateVaginalSwabHPV = (d['Date_of_V_Swab_sample_collection_for_HPV'] as Timestamp).toDate();
      if (d['Date_of_Urine_sample_collection'] != null) dateUrine = (d['Date_of_Urine_sample_collection'] as Timestamp).toDate();
      
      if (d['Entry_Date'] != null) entryDate = (d['Entry_Date'] as Timestamp).toDate();
      if (d['Modified_Date'] != null) modifiedDate = (d['Modified_Date'] as Timestamp).toDate();

      if (selectedFamilyCode != null) _fetchNamesByFamily(selectedFamilyCode!);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number': _registrationNumber.text,
        'Family_code': selectedFamilyCode,
        'Name': selectedName,
        'Gender': selectedGender,
        'Age': int.tryParse(_age.text),
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'Interviewer_s_Name': interviewersName,
        'If_not_done_reason': notDoneReason,
        'Did_you_collect_Blood_Sample1': collectBloodSample,
        'Did_you_collected_Blood_sample_for_HBA1C': collectHBA1C,
        'Did_you_collected_Blood_sample_for_THYROID': collectThyroid,
        'Did_you_collected_Blood_sample_for_CRE': collectCRE,
        'Did_you_collected_SPUTUM_sample_for_TB_Test': collectSputumTB,
        'Did_you_collected_Vaginal_Swab_sample_for_HPV': collectVaginalSwabHPV,
        'Did_you_collected_Urine_sample': collectUrine,
        'Date_of_Blood_sample_collection_for_CBP': dateCBP != null ? Timestamp.fromDate(dateCBP!) : null,
        'Date_of_Blood_sample_collection_for_HBA1C': dateHBA1C != null ? Timestamp.fromDate(dateHBA1C!) : null,
        'Date_of_Blood_sample_collection_for_THYROID': dateThyroid != null ? Timestamp.fromDate(dateThyroid!) : null,
        'Date_of_Blood_sample_collection_for_CRE': dateCRE != null ? Timestamp.fromDate(dateCRE!) : null,
        'Date_of_Sputum_sample_collection_for_TB_Test': dateSputumTB != null ? Timestamp.fromDate(dateSputumTB!) : null,
        'Date_of_V_Swab_sample_collection_for_HPV': dateVaginalSwabHPV != null ? Timestamp.fromDate(dateVaginalSwabHPV!) : null,
        'Date_of_Urine_sample_collection': dateUrine != null ? Timestamp.fromDate(dateUrine!) : null,
        'Entry_Date': entryDate != null ? Timestamp.fromDate(entryDate!) : null,
        'Modified_Date': Timestamp.now(),
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('blood_sample_status').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('blood_sample_status').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blood sample status saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
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
        title: const Text('Blood Sample Status'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      drawer: const AppDrawer(),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildIdentitySection(),
                  _buildSampleStatusSection(),
                  _buildCollectionDatesSection(),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildIdentitySection() {
    return _buildSectionCard(
      title: 'Identity & Interview',
      children: [
        TextFormField(controller: _registrationNumber, decoration: const InputDecoration(labelText: 'Registration Number', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Family code', border: OutlineInputBorder()),
          value: selectedFamilyCode,
          items: allFamilyCodes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) {
            setState(() {
              selectedFamilyCode = v;
              selectedName = null;
            });
            if (v != null) _fetchNamesByFamily(v);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: 'Name', border: OutlineInputBorder(), suffixIcon: _isLoadingLookups ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null),
          value: selectedName,
          items: allNames.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
          onChanged: (v) => setState(() => selectedName = v),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                value: selectedGender,
                items: ['(1) Male', '(0) Female'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => selectedGender = v),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: TextFormField(controller: _age, decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: dateOfInterview ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
            if (picked != null) setState(() => dateOfInterview = picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date of Interview', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
            child: Text(dateOfInterview == null ? 'Select Date' : DateFormat('dd-MMM-yyyy').format(dateOfInterview!)),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Interviewer’s Name', border: OutlineInputBorder()),
          value: interviewersName,
          items: ['KIRANMAI K', 'LAVANYA KASPOJU', 'RAMADEVI Y', 'REVATHI CH'].map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
          onChanged: (v) => setState(() => interviewersName = v),
        ),
        const SizedBox(height: 16),
        const Text('If not done, reason', style: TextStyle(fontWeight: FontWeight.bold)),
        Column(
          children: ['Not available', 'Refused for current visit', 'Door Locked'].map((r) => RadioListTile<String>(
            title: Text(r),
            value: r,
            groupValue: notDoneReason,
            onChanged: (v) => setState(() => notDoneReason = v),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildSampleStatusSection() {
    return _buildSectionCard(
      title: 'Sample Collection Status',
      children: [
        _buildRadioRow('Did you collect Blood Sample?', collectBloodSample, (v) => setState(() => collectBloodSample = v), ['Yes']),
        _buildDropdownRow('HBA1C', collectHBA1C, (v) => setState(() => collectHBA1C = v)),
        _buildDropdownRow('THYROID', collectThyroid, (v) => setState(() => collectThyroid = v)),
        _buildDropdownRow('CRE', collectCRE, (v) => setState(() => collectCRE = v)),
        _buildDropdownRow('TB Test (SPUTUM)', collectSputumTB, (v) => setState(() => collectSputumTB = v)),
        _buildDropdownRow('HPV (Vaginal Swab)', collectVaginalSwabHPV, (v) => setState(() => collectVaginalSwabHPV = v)),
        _buildDropdownRow('Urine', collectUrine, (v) => setState(() => collectUrine = v)),
      ],
    );
  }

  Widget _buildRadioRow(String label, String? value, Function(String?) onChanged, List<String> choices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: choices.map((c) => Expanded(
            child: RadioListTile<String>(
              title: Text(c),
              value: c,
              groupValue: value,
              onChanged: onChanged,
            ),
          )).toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDropdownRow(String sample, String? value, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: 'Did you collect sample for $sample', border: const OutlineInputBorder()),
        value: value,
        items: ['Yes', 'No', 'Refused'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCollectionDatesSection() {
    return _buildSectionCard(
      title: 'Collection Dates',
      children: [
        _buildDatePicker('Date of Blood sample collection for CBP', dateCBP, (v) => setState(() => dateCBP = v)),
        _buildDatePicker('Date of Blood sample collection for HBA1C', dateHBA1C, (v) => setState(() => dateHBA1C = v)),
        _buildDatePicker('Date of Blood sample collection for THYROID', dateThyroid, (v) => setState(() => dateThyroid = v)),
        _buildDatePicker('Date of Blood sample collection for CRE', dateCRE, (v) => setState(() => dateCRE = v)),
        _buildDatePicker('Date of Sputum sample collection for TB Test', dateSputumTB, (v) => setState(() => dateSputumTB = v)),
        _buildDatePicker('Date of V.Swab sample collection for HPV', dateVaginalSwabHPV, (v) => setState(() => dateVaginalSwabHPV = v)),
        _buildDatePicker('Date of Urine sample collection', dateUrine, (v) => setState(() => dateUrine = v)),
        const Divider(),
        _buildDatePicker('Entry Date', entryDate, (v) => setState(() => entryDate = v)),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? value, Function(DateTime?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.calendar_today)),
          child: Text(value == null ? 'Select Date' : DateFormat('dd-MMM-yyyy').format(value)),
        ),
      ),
    );
  }
}
