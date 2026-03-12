import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';

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
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];

  // --- Basic Information ---
  final _familyCodeController = TextEditingController();
  final _familyCodeOldController = TextEditingController();
  final _finalFamilyCodeController = TextEditingController();
  final _nameController = TextEditingController();
  String? selectedName;
  final _nameIdController = TextEditingController();
  final _husbandNameController = TextEditingController();
  String? selectEntryScreen;
  final _regNoController = TextEditingController();
  final _motherRegNoController = TextEditingController();
  final _fatherRegNoController = TextEditingController();
  final _familyNoController = TextEditingController();
  String? marriageType;

  // --- Used? Section ---
  String? used;
  DateTime? usedDate;
  String? usedPlace;
  final _remarksController = TextEditingController();

  // --- Contraceptives Section ---
  bool usedOralContraceptives = false;
  final _howLongOralController = TextEditingController();
  DateTime? lastUseOralDate;
  
  bool usedCondoms = false;
  DateTime? condomLastDate; // From image "Date?" associated with condoms

  bool usedCopperT = false;
  
  bool usedInjectable = false;
  final _howLongInjectableController = TextEditingController();
  DateTime? lastUseInjectableDate;

  bool usedOther = false;
  final _ifYesOtherController = TextEditingController();

  // Lookups
  List<String> allFamilyCodes = [];
  List<String> femaleMembers = [];
  bool _isLoadingMembers = false;
  Map<String, Map<String, dynamic>> _memberDataMap = {};

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
    setState(() {
      _isLoadingMembers = true;
      femaleMembers = [];
      _memberDataMap = {};
    });
    try {
      // 1. Fetch from Firestore (Personal Details)
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyCode)
          .where('Gender', isEqualTo: '(0) Female')
          .where('Marital_Status', isEqualTo: '(1) Married')
          .where('A_v_Status', isEqualTo: '(1) Active')
          .get(const GetOptions(source: Source.serverAndCache));

      // 2. Fetch exclusion list: Permanent Family Planning
      final fpExclusionSnapshot = await FirebaseFirestore.instance
          .collection('reproductive_health')
          .where('Family_Code', isEqualTo: familyCode)
          .where('Select_Entry_Screen', isEqualTo: '(1) Permanent')
          .get();
      final Set<String> excludedNames = fpExclusionSnapshot.docs
          .map((doc) => doc.data()['Name']?.toString() ?? '')
          .toSet();

      // 3. Fetch exclusion list: Ante Natal Care (ANC)
      final ancExclusionSnapshot = await FirebaseFirestore.instance
          .collection('ante_natal_care')
          .where('Family_Code', isEqualTo: familyCode)
          .get();
      excludedNames.addAll(ancExclusionSnapshot.docs
          .map((doc) => doc.data()['Female']?.toString() ?? '')
          .toSet());

      // 4. Fetch from Local SQLite
      final localMembers = await DataCacheService().fetchMembersLocally(familyCode);

      // 5. Merge and Filter logic
      final Map<String, Map<String, dynamic>> femaleMap = {};
      
      void processMember(Map<String, dynamic> data) {
        final name = data['Name'] ?? '';
        if (name.isEmpty || excludedNames.contains(name)) return;

        final gender = data['Gender']?.toString() ?? '';
        final maritalStatus = data['Marital_Status']?.toString() ?? '';
        final avStatus = data['A_v_Status']?.toString() ?? '';
        
        bool isFemale = gender.contains('(0) Female');
        bool isMarried = maritalStatus.contains('(1) Married');
        bool isActive = avStatus.contains('(1) Active');
        
        if (isFemale && isMarried && isActive) {
          femaleMap[name] = data;
        }
      }

      for (var doc in snapshot.docs) {
        processMember(doc.data());
      }
      for (var member in localMembers) {
        processMember(member);
      }

      setState(() {
        _memberDataMap = femaleMap;
        femaleMembers = femaleMap.keys.toList()..sort();
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error fetching members: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _fetchExistingRecords(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reproductive_health')
          .where('Family_Code', isEqualTo: familyCode)
          .get();
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
      if (name != null && _memberDataMap.containsKey(name)) {
        final data = _memberDataMap[name]!;
        _nameIdController.text = data['uniq_Registration_Number']?.toString() ?? '';
        _husbandNameController.text = data['Name2'] ?? data['Husband_Name'] ?? '';
        _regNoController.text = data['Registration_Number1'] ?? '';
        _motherRegNoController.text = data['Mother_Name'] ?? ''; // or specific ID field if exists
        _fatherRegNoController.text = data['Father_Name'] ?? '';
        _finalFamilyCodeController.text = data['Family_Code'] ?? '';
      } else {
        _nameIdController.clear();
        _husbandNameController.clear();
        _regNoController.clear();
        _motherRegNoController.clear();
        _fatherRegNoController.clear();
        _finalFamilyCodeController.clear();
      }
    });
  }

  void _loadExistingData([Map<String, dynamic>? data]) {
    final d = data ?? widget.existingData!;
    setState(() {
      _familyCodeController.text = d['Family_Code'] ?? '';
      _familyCodeOldController.text = d['Family_Code_Old'] ?? '';
      _finalFamilyCodeController.text = d['Final_Family_Code'] ?? '';
      selectedName = d['Name'];
      _nameController.text = d['Name'] ?? '';
      _nameIdController.text = d['Name_ID'] ?? '';
      _husbandNameController.text = d['Husband_Name'] ?? '';
      selectEntryScreen = d['Select_Entry_Screen'];
      _regNoController.text = d['Registration_Number'] ?? '';
      _motherRegNoController.text = d['Mother_Registration_Number'] ?? '';
      _fatherRegNoController.text = d['Father_Registration_Number'] ?? '';
      _familyNoController.text = d['Family_No'] ?? '';
      marriageType = d['Marriage_Type'];

      used = d['Used'];
      if (d['Used_Date'] != null) {
        usedDate = d['Used_Date'] is Timestamp ? (d['Used_Date'] as Timestamp).toDate() : DateTime.tryParse(d['Used_Date'].toString());
      }
      usedPlace = d['Used_Place'];
      _remarksController.text = d['Remarks'] ?? '';

      usedOralContraceptives = d['Used_Oral_Contraceptives'] ?? false;
      _howLongOralController.text = d['How_Long_Use_Oral'] ?? '';
      if (d['Last_Use_Oral_Date'] != null) {
        lastUseOralDate = d['Last_Use_Oral_Date'] is Timestamp ? (d['Last_Use_Oral_Date'] as Timestamp).toDate() : DateTime.tryParse(d['Last_Use_Oral_Date'].toString());
      }

      usedCondoms = d['Used_Condoms'] ?? false;
      if (d['Condom_Last_Date'] != null) {
        condomLastDate = d['Condom_Last_Date'] is Timestamp ? (d['Condom_Last_Date'] as Timestamp).toDate() : DateTime.tryParse(d['Condom_Last_Date'].toString());
      }

      usedCopperT = d['Used_CopperT'] ?? false;

      usedInjectable = d['Used_Injectable'] ?? false;
      _howLongInjectableController.text = d['How_Long_Using_Injectable'] ?? '';
      if (d['Last_Use_Injectable_Date'] != null) {
        lastUseInjectableDate = d['Last_Use_Injectable_Date'] is Timestamp ? (d['Last_Use_Injectable_Date'] as Timestamp).toDate() : DateTime.tryParse(d['Last_Use_Injectable_Date'].toString());
      }

      usedOther = d['Used_Other'] ?? false;
      _ifYesOtherController.text = d['If_Yes_Other'] ?? '';
      
      if (_familyCodeController.text.isNotEmpty && !_isEditMode) {
        _fetchFemalesByFamily(_familyCodeController.text);
      }
      _editDocId = d['id'];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'Family_Code': _familyCodeController.text,
        'Family_Code_Old': _familyCodeOldController.text,
        'Final_Family_Code': _finalFamilyCodeController.text,
        'Name': _isEditMode ? selectedName : _nameController.text,
        'Name_ID': _nameIdController.text,
        'Husband_Name': _husbandNameController.text,
        'Select_Entry_Screen': selectEntryScreen,
        'Registration_Number': _regNoController.text,
        'Mother_Registration_Number': _motherRegNoController.text,
        'Father_Registration_Number': _fatherRegNoController.text,
        'Family_No': _familyNoController.text,
        'Marriage_Type': marriageType,
        'Used': used,
        'Used_Date': usedDate != null ? Timestamp.fromDate(usedDate!) : null,
        'Used_Place': usedPlace,
        'Remarks': _remarksController.text,
        'Used_Oral_Contraceptives': usedOralContraceptives,
        'How_Long_Use_Oral': _howLongOralController.text,
        'Last_Use_Oral_Date': lastUseOralDate != null ? Timestamp.fromDate(lastUseOralDate!) : null,
        'Used_Condoms': usedCondoms,
        'Condom_Last_Date': condomLastDate != null ? Timestamp.fromDate(condomLastDate!) : null,
        'Used_CopperT': usedCopperT,
        'Used_Injectable': usedInjectable,
        'How_Long_Using_Injectable': _howLongInjectableController.text,
        'Last_Use_Injectable_Date': lastUseInjectableDate != null ? Timestamp.fromDate(lastUseInjectableDate!) : null,
        'Used_Other': usedOther,
        'If_Yes_Other': _ifYesOtherController.text,
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('reproductive_health').doc(_editDocId).update(data);
      } else if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('reproductive_health').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('reproductive_health').add(data);
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

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      if (!_isEditMode) {
        _familyCodeController.clear();
      }
      _editDocId = null;
      _familyCodeOldController.clear();
      _finalFamilyCodeController.clear();
      selectedName = null;
      _nameIdController.clear();
      _husbandNameController.clear();
      selectEntryScreen = null;
      _regNoController.clear();
      _motherRegNoController.clear();
      _fatherRegNoController.clear();
      _familyNoController.clear();
      _nameController.clear();
      marriageType = null;
      used = null;
      usedDate = null;
      usedPlace = null;
      _remarksController.clear();
      usedOralContraceptives = false;
      _howLongOralController.clear();
      lastUseOralDate = null;
      usedCondoms = false;
      condomLastDate = null;
      usedCopperT = false;
      usedInjectable = false;
      _howLongInjectableController.clear();
      lastUseInjectableDate = null;
      usedOther = false;
      _ifYesOtherController.clear();
      femaleMembers = [];
      _existingRecords = [];
    });
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        final picked = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101));
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
      appBar: AppBar(title: const Text('Family Planning'), backgroundColor: Theme.of(context).colorScheme.primaryContainer),
      drawer: const AppDrawer(),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [

                  _buildSectionCard(
                    title: 'Basic Details',
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Family Code', border: OutlineInputBorder()),
                        value: allFamilyCodes.contains(_familyCodeController.text) ? _familyCodeController.text : null,
                        items: allFamilyCodes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            _familyCodeController.text = v;
                            if (_isEditMode) {
                              _fetchExistingRecords(v);
                            } else {
                              _fetchFemalesByFamily(v);
                            }
                          }
                        },
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _familyCodeOldController, decoration: const InputDecoration(labelText: 'Family Code old', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextFormField(controller: _finalFamilyCodeController, readOnly: true, decoration: const InputDecoration(labelText: 'Final family code', border: OutlineInputBorder(), fillColor: Color(0xFFEEEEEE), filled: true)),
                      const SizedBox(height: 16),
                      if (_isEditMode)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Select Record to Edit',
                            border: const OutlineInputBorder(),
                            suffixIcon: _isLoadingMembers ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                          ),
                          value: selectedName,
                          items: _existingRecords.map((e) => DropdownMenuItem<String>(value: e['Name']?.toString(), child: Text(e['Name']?.toString() ?? ''))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              final record = _existingRecords.firstWhere((e) => e['Name'] == v);
                              _loadExistingData(record);
                            }
                          },
                          validator: (v) => v == null ? 'Required' : null,
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), hintText: 'Type name or pick from dropdown'),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                            if (femaleMembers.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Pick from Family Members',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: _isLoadingMembers ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                                ),
                                value: null,
                                items: femaleMembers.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                                onChanged: _onNameSelected,
                                hint: const Text('--Select Member--'),
                              ),
                            ],
                          ],
                        ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _nameIdController, readOnly: true, decoration: const InputDecoration(labelText: 'Name id', border: OutlineInputBorder(), fillColor: Color(0xFFEEEEEE), filled: true)),
                      const SizedBox(height: 16),
                      TextFormField(controller: _husbandNameController, readOnly: true, decoration: const InputDecoration(labelText: 'Husband Name', border: OutlineInputBorder(), fillColor: Color(0xFFEEEEEE), filled: true)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Select Entry Screen', border: OutlineInputBorder()),
                        value: selectEntryScreen,
                        onChanged: (v) => setState(() => selectEntryScreen = v),
                        items: ['Family Planning'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _regNoController, decoration: const InputDecoration(labelText: 'Registration Number', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextFormField(controller: _motherRegNoController, decoration: const InputDecoration(labelText: 'Mother Registration Number', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextFormField(controller: _fatherRegNoController, decoration: const InputDecoration(labelText: 'Father Registration Number', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextFormField(controller: _familyNoController, decoration: const InputDecoration(labelText: 'Family No', border: OutlineInputBorder())),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Marriage & Status',
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Marriage Type', border: OutlineInputBorder()),
                        value: marriageType,
                        items: ['Type 1', 'Type 2'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => marriageType = v),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Used?', border: OutlineInputBorder()),
                              value: used,
                              items: ['(1) Yes', '(0) No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (v) => setState(() => used = v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDatePicker(label: 'Date?', value: usedDate, onPicked: (v) => setState(() => usedDate = v))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _remarksController, decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()), maxLines: 2),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Contraceptive Methods',
                    children: [
                      CheckboxListTile(
                        title: const Text('Used oral contraceptives?'),
                        value: usedOralContraceptives,
                        onChanged: (v) => setState(() => usedOralContraceptives = v ?? false),
                      ),
                      if (usedOralContraceptives) ...[
                        TextFormField(controller: _howLongOralController, decoration: const InputDecoration(labelText: 'How long use oral', border: OutlineInputBorder())),
                        const SizedBox(height: 8),
                        _buildDatePicker(label: 'Last use oral contraceptives?', value: lastUseOralDate, onPicked: (v) => setState(() => lastUseOralDate = v)),
                        const SizedBox(height: 16),
                      ],
                      CheckboxListTile(
                        title: const Text('Used condoms?'),
                        value: usedCondoms,
                        onChanged: (v) => setState(() => usedCondoms = v ?? false),
                      ),
                      if (usedCondoms) ...[
                        _buildDatePicker(label: 'Date? (Last use Condoms)', value: condomLastDate, onPicked: (v) => setState(() => condomLastDate = v)),
                        const SizedBox(height: 16),
                      ],
                      CheckboxListTile(
                        title: const Text('Used an Copper-T?'),
                        value: usedCopperT,
                        onChanged: (v) => setState(() => usedCopperT = v ?? false),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text('Used injectable contraceptives?'),
                        value: usedInjectable,
                        onChanged: (v) => setState(() => usedInjectable = v ?? false),
                      ),
                      if (usedInjectable) ...[
                        TextFormField(controller: _howLongInjectableController, decoration: const InputDecoration(labelText: 'How long using injectable contraceptives?', border: OutlineInputBorder())),
                        const SizedBox(height: 8),
                        _buildDatePicker(label: 'Last use injectable contraceptives?', value: lastUseInjectableDate, onPicked: (v) => setState(() => lastUseInjectableDate = v)),
                        const SizedBox(height: 16),
                      ],
                      CheckboxListTile(
                        title: const Text('Used other?'),
                        value: usedOther,
                        onChanged: (v) => setState(() => usedOther = v ?? false),
                      ),
                      if (usedOther)
                        TextFormField(controller: _ifYesOtherController, decoration: const InputDecoration(labelText: 'If yes', border: OutlineInputBorder())),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: Text(_isEditMode ? 'Update Record' : 'Save Record', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }
}
