import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';

class DoctorPrescriptionsPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const DoctorPrescriptionsPage({super.key, this.existingData, this.docId});

  @override
  State<DoctorPrescriptionsPage> createState() => _DoctorPrescriptionsPageState();
}

class _DoctorPrescriptionsPageState extends State<DoctorPrescriptionsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // --- Controllers & State ---
  String? selectedFamilyCode;
  String? selectedMemberName;
  String? selectedGender;
  final _ageController = TextEditingController();
  String? selectedPrescriptionDate; // From JSON choices, though named 'Date'

  List<String> allFamilyCodes = [];
  List<String> familyMemberNames = [];
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

      final names = snapshot.docs.map((doc) => doc.data()['Name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();

      setState(() {
        familyMemberNames = names..sort();
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
      selectedFamilyCode = d['Family_code'];
      selectedMemberName = d['Name'];
      selectedGender = d['Gender'];
      _ageController.text = d['Age']?.toString() ?? '';
      selectedPrescriptionDate = d['Doctor_s_Prescription_date'];
    });
    if (selectedFamilyCode != null) {
      _fetchMembersByFamily(selectedFamilyCode!);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      selectedFamilyCode = null;
      selectedMemberName = null;
      selectedGender = null;
      _ageController.clear();
      selectedPrescriptionDate = null;
      familyMemberNames = [];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Family_code': selectedFamilyCode,
        'Name': selectedMemberName,
        'Gender': selectedGender,
        'Age': int.tryParse(_ageController.text),
        'Doctor_s_Prescription_date': selectedPrescriptionDate,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('doctor_prescriptions').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('doctor_prescriptions').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription saved successfully!'), backgroundColor: Colors.green),
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Doctor Prescriptions Form'),
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
                    title: 'Prescription Details',
                    children: [
                      // Family Code Lookup
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Family code', border: OutlineInputBorder()),
                        value: selectedFamilyCode,
                        items: allFamilyCodes.map((code) => DropdownMenuItem(value: code, child: Text(code))).toList(),
                        onChanged: (v) {
                          setState(() {
                            selectedFamilyCode = v;
                            selectedMemberName = null;
                            familyMemberNames = [];
                          });
                          if (v != null) _fetchMembersByFamily(v);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Name Lookup (Member of Family)
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Name',
                          border: const OutlineInputBorder(),
                          suffixIcon: _isLoadingMembers ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                        ),
                        value: selectedMemberName,
                        items: familyMemberNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                        onChanged: (v) => setState(() => selectedMemberName = v),
                      ),
                      const SizedBox(height: 16),

                      // Gender Radio
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600)),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('(1) Male'),
                                  value: '(1) Male',
                                  groupValue: selectedGender,
                                  onChanged: (v) => setState(() => selectedGender = v),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('(0) Female'),
                                  value: '(0) Female',
                                  groupValue: selectedGender,
                                  onChanged: (v) => setState(() => selectedGender = v),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Age
                      TextFormField(
                        controller: _ageController,
                        decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder(), hintText: '#######'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // Prescription Date (Choices from JSON)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: "Doctor's Prescription date", border: OutlineInputBorder()),
                        value: selectedPrescriptionDate,
                        items: const [
                          DropdownMenuItem(value: 'Choice 1', child: Text('Choice 1')),
                          DropdownMenuItem(value: 'Choice 2', child: Text('Choice 2')),
                          DropdownMenuItem(value: 'Choice 3', child: Text('Choice 3')),
                        ],
                        onChanged: (v) => setState(() => selectedPrescriptionDate = v),
                      ),
                    ],
                  ),

                  // Save Buttons
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
                          child: const Text('Save Prescription', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                ],
              ),
            ),
    );
  }
}
