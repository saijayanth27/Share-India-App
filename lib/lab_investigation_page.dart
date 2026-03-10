import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';

class LabInvestigationPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const LabInvestigationPage({super.key, this.existingData, this.docId});

  @override
  State<LabInvestigationPage> createState() => _LabInvestigationPageState();
}

class _LabInvestigationPageState extends State<LabInvestigationPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // --- Controllers ---
  final _regNoController = TextEditingController();
  final _fastingSugarController = TextEditingController();
  final _hba1cController = TextEditingController();
  final _glycosylatedHbController = TextEditingController();
  final _meanGlucoseController = TextEditingController();
  final _creatinineController = TextEditingController();
  final _urineAlbuminController = TextEditingController();
  final _albuminRatioController = TextEditingController();
  final _proteinUrineSpotController = TextEditingController();
  final _creatinineUrineSpotController = TextEditingController();
  final _proteinCreatinineRatioController = TextEditingController();

  DateTime? investigationDate;

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _loadExistingData();
    } else {
      investigationDate = DateTime.now();
    }
  }

  void _loadExistingData() {
    final d = widget.existingData!;
    setState(() {
      _regNoController.text = d['Registration_Number_of'] ?? '';
      if (d['Date_of_Lab_Investigation'] != null) {
        investigationDate = (d['Date_of_Lab_Investigation'] as Timestamp).toDate();
      }
      _fastingSugarController.text = d['Fasting_blood_sugar']?.toString() ?? '';
      _hba1cController.text = d['hemoglobin_A1c']?.toString() ?? '';
      _glycosylatedHbController.text = d['Glycosylated_Hemoglobin']?.toString() ?? '';
      _meanGlucoseController.text = d['Mean_Blood_Glucose']?.toString() ?? '';
      _creatinineController.text = d['Creatinine']?.toString() ?? '';
      _urineAlbuminController.text = d['urine_albumin']?.toString() ?? '';
      _albuminRatioController.text = d['albumin_ratio']?.toString() ?? '';
      _proteinUrineSpotController.text = d['protein_urine_spot']?.toString() ?? '';
      _creatinineUrineSpotController.text = d['Creatinine_urine_spot']?.toString() ?? '';
      _proteinCreatinineRatioController.text = d['protein_Creatinine_ratio']?.toString() ?? '';
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _regNoController.clear();
      investigationDate = DateTime.now();
      _fastingSugarController.clear();
      _hba1cController.clear();
      _glycosylatedHbController.clear();
      _meanGlucoseController.clear();
      _creatinineController.clear();
      _urineAlbuminController.clear();
      _albuminRatioController.clear();
      _proteinUrineSpotController.clear();
      _creatinineUrineSpotController.clear();
      _proteinCreatinineRatioController.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Registration_Number_of': _regNoController.text,
        'Date_of_Lab_Investigation': investigationDate != null ? Timestamp.fromDate(investigationDate!) : null,
        'Fasting_blood_sugar': double.tryParse(_fastingSugarController.text),
        'hemoglobin_A1c': double.tryParse(_hba1cController.text),
        'Glycosylated_Hemoglobin': double.tryParse(_glycosylatedHbController.text),
        'Mean_Blood_Glucose': double.tryParse(_meanGlucoseController.text),
        'Creatinine': double.tryParse(_creatinineController.text),
        'urine_albumin': double.tryParse(_urineAlbuminController.text),
        'albumin_ratio': double.tryParse(_albuminRatioController.text),
        'protein_urine_spot': double.tryParse(_proteinUrineSpotController.text),
        'Creatinine_urine_spot': double.tryParse(_creatinineUrineSpotController.text),
        'protein_Creatinine_ratio': double.tryParse(_proteinCreatinineRatioController.text),
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('lab_investigation').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('lab_investigation').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lab Investigation record saved successfully!'), backgroundColor: Colors.green),
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

  Widget _buildNumericField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Lab Investigation Form'),
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
                  _buildSectionCard(
                    title: 'Identification',
                    children: [
                      TextFormField(
                        controller: _regNoController,
                        decoration: const InputDecoration(
                          labelText: 'Registration Number of the participant',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: investigationDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => investigationDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date of Lab Investigation',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(investigationDate == null ? 'Select Date' : DateFormat('dd-MMM-yyyy').format(investigationDate!)),
                        ),
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Investigations',
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildNumericField('Fasting blood sugar', _fastingSugarController)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildNumericField('urine albumin', _urineAlbuminController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildNumericField('hemoglobin A1c', _hba1cController)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildNumericField('albumin ratio', _albuminRatioController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildNumericField('Glycosylated Hemoglobin', _glycosylatedHbController)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildNumericField('protein urine spot', _proteinUrineSpotController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildNumericField('Mean Blood Glucose', _meanGlucoseController)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildNumericField('Creatinine urine spot', _creatinineUrineSpotController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildNumericField('Creatinine', _creatinineController)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildNumericField('protein Creatinine ratio', _proteinCreatinineRatioController)),
                        ],
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
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Save Lab Results', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _resetForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
}
