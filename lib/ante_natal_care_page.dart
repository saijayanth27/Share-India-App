import "package:flutter/material.dart";import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'data_cache_service.dart';
import 'widget.dart';

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
  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];

  // --- Identity Fields ---
  String? selectedFamilyCode;
  final _nameController = TextEditingController();
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
  final _noOfBirths = TextEditingController();
  final _noOfBirthsFemale = TextEditingController();
  String? gender;
  List<String> selectedGenders = [];
  List<String> deliveryGenders = [];

  // Lookups
  List<String> allFamilyCodes = [];
  List<String> femaleMembers = [];
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

  Future<void> _fetchFemalesByFamily(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      // 1. Fetch from Firestore (Cache favored)
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyCode)
          .get(const GetOptions(source: Source.serverAndCache));

      // 2. Fetch from Local SQLite for offline support
      final localMembers = await DataCacheService().fetchMembersLocally(familyCode);

      // 3. Merge and Filter logic
      final Map<String, Map<String, dynamic>> memberMap = {};
      final List<String> females = [];
      
      void processMember(Map<String, dynamic> data) {
        final name = data['Name']?.toString() ?? '';
        if (name.isEmpty) return;
        memberMap[name] = data;

        final gender = data['Gender']?.toString() ?? '';
        final maritalStatus = data['Marital_Status']?.toString() ?? '';
        
        bool isFemale = gender.contains('(0) Female');
        bool isMarriedOrWidow = maritalStatus.contains('(1) Married') || maritalStatus.contains('(3) Widow');
        
        if (isFemale && isMarriedOrWidow) {
          females.add(name);
        }
      }

      for (var doc in snapshot.docs) {
        processMember(doc.data());
      }
      for (var member in localMembers) {
        processMember(member);
      }

      setState(() {
        _allMembersData = memberMap;
        femaleMembers = females..sort();
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
          .collection('ante_natal_care')
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

  void _onNameSelected(String? womanName) {
    setState(() {
      selectedName = womanName;
      _nameController.text = womanName ?? '';
      if (womanName != null) {
        // Auto-populate Uniq Reg No
        final womanData = _allMembersData[womanName];
        if (womanData != null) {
          _uniqRegNo.text = womanData['uniq_Registration_Number']?.toString() ?? '';
          _regNo.text = womanData['Registration_Number1']?.toString() ?? '';
        }

        // Find a male member where Name2 is the woman's name (Husband lookup)
        String? husband;
        _allMembersData.forEach((name, data) {
          final gender = data['Gender']?.toString() ?? '';
          final spouseName = data['Name2']?.toString() ?? '';
          if (spouseName == womanName && gender.contains('(0) Male')) {
            husband = name;
          }
        });

        if (husband != null) {
          _husbandName.text = husband!;
        }
      }
    });
  }

  void _loadExistingData([Map<String, dynamic>? data]) {
    final d = data ?? widget.existingData!;
    setState(() {
      selectedFamilyCode = d['Family_Code'];
      if (selectedFamilyCode != null && !_isEditMode) _fetchFemalesByFamily(selectedFamilyCode!);
      selectedName = d['Female'];
      _nameController.text = selectedName ?? '';
      _husbandName.text = d['Husband_Name'] ?? '';
      if (d['LMP_Date'] != null) {
        lmpDate = d['LMP_Date'] is Timestamp ? (d['LMP_Date'] as Timestamp).toDate() : DateTime.tryParse(d['LMP_Date'].toString());
      }
      selectEntryScreen = d['Select_Entry_Screen'];
      _uniqRegNo.text = d['uniq_Registration_Number'] ?? '';
      _regNo.text = d['Registration_Number'] ?? '';

      tt1Given = d['st_Given_Y_N'];
      tt1GivenBy = d['st_Given_By'];
      if (d['st_Dt'] != null) {
        tt1Date = d['st_Dt'] is Timestamp ? (d['st_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['st_Dt'].toString());
      }
      tt2Given = d['nd_Given_Y_N'];
      tt2GivenBy = d['nd_Given_By'];
      if (d['nd_Dt'] != null) {
        tt2Date = d['nd_Dt'] is Timestamp ? (d['nd_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['nd_Dt'].toString());
      }

      ifa1Given = d['st_Given_Y_N1'];
      if (d['st_Dt1'] != null) {
        ifa1Date = d['st_Dt1'] is Timestamp ? (d['st_Dt1'] as Timestamp).toDate() : DateTime.tryParse(d['st_Dt1'].toString());
      }
      ifa1GivenBy = d['st_Given_By1'];
      ifa2Given = d['nd_Given_Y_N1'];
      if (d['nd_Dt1'] != null) {
        ifa2Date = d['nd_Dt1'] is Timestamp ? (d['nd_Dt1'] as Timestamp).toDate() : DateTime.tryParse(d['nd_Dt1'].toString());
      }
      ifa2GivenBy = d['nd_Given_By1'];
      ifa3Given = d['rd_Given_Y_N'];
      if (d['rd_Dt'] != null) {
        ifa3Date = d['rd_Dt'] is Timestamp ? (d['rd_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['rd_Dt'].toString());
      }
      ifa3GivenBy = d['rd_Given_Y_N1'];
      ifa4Given = d['TH_Given_Y_N'];
      if (d['th_Dt'] != null) {
        ifa4Date = d['th_Dt'] is Timestamp ? (d['th_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['th_Dt'].toString());
      }
      ifa4GivenBy = d['TH_Given_Y_N1'];

      deliveryType = d['Delivery_Type'];
      if (d['Delivery_Dt'] != null) {
        deliveryDate = d['Delivery_Dt'] is Timestamp ? (d['Delivery_Dt'] as Timestamp).toDate() : DateTime.tryParse(d['Delivery_Dt'].toString());
      }
      deliveryPlace = d['Delivery_Place'];
      _deliveryPlaceDetails.text = d['Delivery_Place_Details'] ?? '';
      deliveryOutcome = d['Delivery'];
      _totalLiveBirths.text = d['Total_Live_Births'] ?? '';

      _remarks.text = d['Remarks2'] ?? '';
      selectedGenders = (d['Gender'] as String?)?.split(', ').where((s) => s.isNotEmpty).toList() ?? [];
      deliveryGenders = (d['Delivery_Gender'] as String?)?.split(', ').where((s) => s.isNotEmpty).toList() ?? [];
      _editDocId = d['id'];
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      if (!_isEditMode) {
        selectedFamilyCode = null;
      }
      _editDocId = null;
      selectedName = null;
      _nameController.clear();
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
      selectedGenders = [];
      deliveryGenders = [];
      femaleMembers = [];
      _existingRecords = [];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      // --- VALIDATIONS ---
      
      // 1. Abortion check (> 150 days)
      if (deliveryType == '(2) Abortion' && lmpDate != null && deliveryDate != null) {
        final diffDays = deliveryDate!.difference(lmpDate!).inDays;
        if (diffDays > 150) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The abortion date is greater than 150 days'), backgroundColor: Colors.orange));
          setState(() => _isSaving = false);
          return;
        }
      }

      // 2. Normal Delivery check (< 7 months)
      if (deliveryType == '(0) Normal' && lmpDate != null && deliveryDate != null) {
        int months = (deliveryDate!.year - lmpDate!.year) * 12 + deliveryDate!.month - lmpDate!.month;
        if (deliveryDate!.day < lmpDate!.day) months--;
        if (months < 7) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The delivery date and LMP date difference should be larger than 7 months'), backgroundColor: Colors.orange));
          setState(() => _isSaving = false);
          return;
        }
      }

      // 3. Open ANC Check
      if ((selectEntryScreen == 'Delivery' || selectEntryScreen == null) && deliveryDate == null) {
        final nameValue = _isEditMode ? selectedName : _nameController.text;
        final existingANC = await FirebaseFirestore.instance
            .collection('ante_natal_care')
            .where('Family_Code', isEqualTo: selectedFamilyCode)
            .where('Female', isEqualTo: nameValue)
            .get();
        
        bool hasOpenANC = false;
        for (var doc in existingANC.docs) {
          if (doc.data()['Delivery_Dt'] == null && doc.id != widget.docId) {
            hasOpenANC = true;
            break;
          }
        }

        if (hasOpenANC) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the delivery_date for the previous ANC record'), backgroundColor: Colors.orange));
          setState(() => _isSaving = false);
          return;
        }
      }
      final data = {
        'Family_Code': selectedFamilyCode,
        'Female': _isEditMode ? selectedName : _nameController.text,
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
        'Gender': selectedGenders.join(', '),
        'Delivery_Gender': deliveryGenders.join(', '),
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };

      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('ante_natal_care').doc(_editDocId).update(data);
      } else if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('ante_natal_care').doc(widget.docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('ante_natal_care').add(data);
      }

      // 4. Create child records if necessary
      if (deliveryOutcome == '(0) Live Birth') {
        await _createChildRecords();
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

  Future<void> _createChildRecords() async {
    final familyCode = selectedFamilyCode;
    if (familyCode == null) return;

    // Male births
    final maleCount = int.tryParse(_noOfBirths.text) ?? 0;
    if (maleCount > 1) {
      for (int i = 0; i < (maleCount - 1); i++) {
        await FirebaseFirestore.instance.collection('personal_details').add({
          'Family_Code': familyCode,
          'Name': 'Boy',
          'Gender': '(1) Male',
          'A_v_Status': '(1) Active', // Defaulting to Active
          'Marital_Status': '(0) Unmarried', // Defaulting to Unmarried
          'Added_User': 'AppUser', // Fallback or retrieve actual user
          'clientCreatedAt': DateTime.now().millisecondsSinceEpoch,
          'needs_zoho_sync': true,
        });
      }
    }

    // Female births
    final femaleCount = int.tryParse(_noOfBirthsFemale.text) ?? 0;
    if (femaleCount > 1) {
      for (int i = 0; i < (femaleCount - 1); i++) {
        await FirebaseFirestore.instance.collection('personal_details').add({
          'Family_Code': familyCode,
          'Name': 'Girl',
          'Gender': '(0) Female',
          'A_v_Status': '(1) Active',
          'Marital_Status': '(0) Unmarried',
          'Added_User': 'AppUser',
          'clientCreatedAt': DateTime.now().millisecondsSinceEpoch,
          'needs_zoho_sync': true,
        });
      }
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
  
  Widget _buildMultiSelectCheckboxes({required String label, required List<String> options, required List<String> selectedItems, required Function(List<String>) onSelectionChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          children: options.map((option) {
            final isSelected = selectedItems.contains(option);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (checked) {
                    final newSelection = List<String>.from(selectedItems);
                    if (checked == true) {
                      newSelection.add(option);
                    } else {
                      newSelection.remove(option);
                    }
                    onSelectionChanged(newSelection);
                  },
                ),
                Text(option),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ante Natal Care', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.pink.shade700, Colors.pink.shade400],
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
                    title: 'Ante Natal Care',
                    subtitle: 'Track maternity and prenatal health records',
                  ),

                  buildSectionCard(
                    context: context,
                    title: 'Basic Information',
                    icon: Icons.person_outline,
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
                              _fetchExistingRecords(v);
                            } else {
                              _fetchFemalesByFamily(v);
                            }
                          }
                        },
                      ),
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
                          items: _existingRecords.map((e) => DropdownMenuItem<String>(value: e['Female']?.toString(), child: Text(e['Female']?.toString() ?? ''))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              final record = _existingRecords.firstWhere((e) => e['Female'] == v);
                              _loadExistingData(record);
                            }
                          },
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Name (Female)', border: OutlineInputBorder(), hintText: 'Type name or pick from dropdown'),
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
                      TextFormField(controller: _husbandName, decoration: const InputDecoration(labelText: 'Husband Name', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                       _buildDatePicker(
                        label: 'LMP Date',
                        value: lmpDate,
                        onPicked: (v) {
                          setState(() {
                            lmpDate = v;
                            // Format: ddMMyy
                            final dateStr = DateFormat('ddMMyy').format(v);
                            final currentReg = _regNo.text;
                            // Append if not already there
                            if (!currentReg.endsWith(dateStr)) {
                              _regNo.text = currentReg + dateStr;
                            }
                          });
                        },
                      ),
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
                  if (selectEntryScreen == 'TT Dose')
                  buildSectionCard(
                    context: context,
                    title: 'TT Dose',
                    icon: Icons.vaccines_outlined,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDatePicker(label: 'TT1 Date', value: tt1Date, onPicked: (v) => setState(() => tt1Date = v))),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: '1st Given Y/N', border: OutlineInputBorder()),
                              value: tt1Given,
                              items: ['(1) Yes', '(0) No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (v) => setState(() => tt1Given = v),
                            ),
                          ),
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
                          Expanded(child: _buildDatePicker(label: 'TT2 Date', value: tt2Date, onPicked: (v) => setState(() => tt2Date = v))),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: '2nd Given Y/N', border: OutlineInputBorder()),
                              value: tt2Given,
                              items: ['(1) Yes', '(0) No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (v) => setState(() => tt2Given = v),
                            ),
                          ),
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
                  if (selectEntryScreen == 'IFA')
                  buildSectionCard(
                    context: context,
                    title: 'IFA (Iron Folic Acid)',
                    icon: Icons.medication_outlined,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDatePicker(label: 'IFA1 Date', value: ifa1Date, onPicked: (v) => setState(() => ifa1Date = v))),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: '1st Given Y/N', border: OutlineInputBorder()),
                              value: ifa1Given,
                              items: ['(1) Yes', '(0) No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (v) => setState(() => ifa1Given = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '1st Given By', border: OutlineInputBorder()),
                        value: ifa1GivenBy,
                        items: ['(0) RHC', '(1) PVT', '(2) GOVT'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => ifa1GivenBy = v),
                      ),
                      const SizedBox(height: 16),
                      _buildIFARow('2nd', ifa2Given, ifa2Date, ifa2GivenBy, (g) => ifa2Given = g, (d) => ifa2Date = d, (b) => ifa2GivenBy = b),
                      const SizedBox(height: 16),
                      _buildIFARow('3rd', ifa3Given, ifa3Date, ifa3GivenBy, (g) => ifa3Given = g, (d) => ifa3Date = d, (b) => ifa3GivenBy = b),
                      const SizedBox(height: 16),
                      _buildIFARow('4th', ifa4Given, ifa4Date, ifa4GivenBy, (g) => ifa4Given = g, (d) => ifa4Date = d, (b) => ifa4GivenBy = b),
                    ],
                  ),
                  if (selectEntryScreen == 'Delivery')
                  buildSectionCard(
                    context: context,
                    title: 'Delivery Details',
                    icon: Icons.child_friendly_outlined,
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Delivery Type'),
                        value: deliveryType,
                        items: ['(0) Normal', '(1) Caesarian', '(2) Abortion'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => deliveryType = v),
                      ),
                      if (deliveryType != '(2) Abortion') ...[
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
                      ],
                      const SizedBox(height: 16),
                      TextFormField(controller: _totalLiveBirths, decoration: const InputDecoration(labelText: 'Total Live Births', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                      if (deliveryOutcome == '(0) Live Birth') ...[
                        const SizedBox(height: 16),
                        _buildMultiSelectCheckboxes(
                          label: 'Gender',
                          options: ['Male', 'Female'],
                          selectedItems: deliveryGenders,
                          onSelectionChanged: (v) => setState(() => deliveryGenders = v),
                        ),
                      ],
                    ],
                  ),
                  if (selectEntryScreen == 'Remarks')
                  buildSectionCard(
                    context: context,
                    title: 'Extra Info & Remarks',
                    icon: Icons.notes_outlined,
                    children: [
                      _buildMultiSelectCheckboxes(
                        label: 'Gender',
                        options: ['Male', 'Female'],
                        selectedItems: selectedGenders,
                        onSelectionChanged: (v) => setState(() => selectedGenders = v),
                      ),
                      const SizedBox(height: 16),
                      if (deliveryOutcome == '(0) Live Birth') ...[
                        Row(
                          children: [
                            Expanded(
                             child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                                value: ['(1) Male', '(0) Female'].contains(gender) ? gender : null,
                                items: ['(1) Male', '(0) Female'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                onChanged: (v) => setState(() => gender = v),
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (gender == '(1) Male')
                              Expanded(child: TextFormField(controller: _noOfBirths, decoration: const InputDecoration(labelText: 'No. of Births', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                            if (gender == '(0) Female')
                              Expanded(child: TextFormField(controller: _noOfBirthsFemale, decoration: const InputDecoration(labelText: 'No. of Female Births', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(controller: _remarks, decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()), maxLines: 3),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (selectEntryScreen != null)
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: Text(_isEditMode ? 'Update ANC Record' : 'Save ANC Record', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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