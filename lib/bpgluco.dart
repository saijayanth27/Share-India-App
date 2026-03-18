import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'app_drawer.dart';
import 'health_ocr_service.dart';
import 'data_cache_service.dart';
import 'widget.dart';

enum ReadingType { bp, sugar }

class HealthReadingsPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const HealthReadingsPage({super.key, this.existingData, this.docId});

  @override
  _HealthReadingsPageState createState() => _HealthReadingsPageState();
}

class _HealthReadingsPageState extends State<HealthReadingsPage> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _sysControllers = List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> _diaControllers = List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> _pulseControllers = List.generate(3, (_) => TextEditingController());

  List<File?> _bpImages = [null, null, null];
  List<String?> _bpStoragePaths = [null, null, null];

  final _familyCodeController = TextEditingController(text: 'TSRRMED');
  final _registrationNumber = TextEditingController();
  final _nameController = TextEditingController();
  final _age = TextEditingController();
  final _othersMention = TextEditingController();
  final _d1 = TextEditingController();
  final _d2 = TextEditingController();
  final _d3 = TextEditingController();
  
  String? selectedName;
  String? selectedGender;
  DateTime? dateOfInterview;
  String? interviewersName;
  String? ifNotDoneReason;
  DateTime? date1;
  DateTime? date2;
  DateTime? date3;
  DateTime? entryDate;
  DateTime? modifiedDate;

  List<String> familyMembers = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  bool _isLoadingMembers = false;

  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoading = false;
  bool _isOnline = false;
  String _statusMessage = '';
  StreamSubscription? _connectivitySubscription;

  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  String _geminiApiKey = 'AIzaSyB4MBq0hMEx-UTB6eAr5FTDVR_kjOf-lUU'; 

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
    entryDate = DateTime.now();
    dateOfInterview = DateTime.now();
    if (widget.existingData != null) {
      _isEditMode = true;
      _populateForm(widget.existingData!);
    }
    HealthOCRService.processPendingReadings();
  }

  void _populateForm(Map<String, dynamic> d) {
    _registrationNumber.text = (d['Registration_Number'] ?? '').toString();
    _familyCodeController.text = (d['Family_code'] ?? d['Family_Code'] ?? '').toString();
    if (_familyCodeController.text.isNotEmpty && familyMembers.isEmpty) _fetchMembersByFamily(_familyCodeController.text);
    selectedName = d['Name'];
    selectedGender = d['Gender'];
    _age.text = (d['Age'] ?? '').toString();
    final rawDate = d['Date_of_Interview'] ?? d['Interview_Date'];
    if (rawDate != null) {
      if (rawDate is Timestamp) {
        dateOfInterview = rawDate.toDate();
      } else {
        try {
          dateOfInterview = DateFormat('dd-MMM-yyyy').parse(rawDate.toString());
        } catch (_) {
          try {
            dateOfInterview = DateTime.parse(rawDate.toString());
          } catch (_) {}
        }
      }
    }
    interviewersName = d['Interviewer_s_Name'];
    ifNotDoneReason = d['If_not_done_reason'];
    _othersMention.text = d['If_Others_Please_Mention'] ?? '';
    _d1.text = d['/d1'] ?? d['Single_Line4'] ?? '';
    _d2.text = d['/d2'] ?? d['Single_Line3'] ?? '';
    _d3.text = d['/d3'] ?? d['Single_Line1'] ?? '';
    DateTime? _parseHealthDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      return DateTime.tryParse(val.toString()) ?? ((){
        try { return DateFormat('dd-MMM-yyyy').parse(val.toString()); } catch(_) { return null; }
      }());
    }

    if (d['Date1'] != null) date1 = _parseHealthDate(d['Date1']);
    if (d['Date2'] != null) date2 = _parseHealthDate(d['Date2']);
    if (d['Date3'] != null) date3 = _parseHealthDate(d['Date3']);
    if (d['Entry_Date'] != null) entryDate = _parseHealthDate(d['Entry_Date']);
    if (d['Modified_Date'] != null) modifiedDate = _parseHealthDate(d['Modified_Date']);
    for (int i = 0; i < 3; i++) {
      final suffix = i == 0 ? '' : (i + 1).toString();
      _sysControllers[i].text = (d['systolic$suffix'] ?? '').toString();
      _diaControllers[i].text = (d['diastolic$suffix'] ?? '').toString();
      _pulseControllers[i].text = (d['pulse$suffix'] ?? d['Heart_Beat${i == 0 ? '1' : (i + 1).toString()}'] ?? '').toString();
      final storagePathKey = i == 0 ? 'bp_storage_path' : 'bp_storage_path${i + 1}';
      if (d[storagePathKey] != null) _bpStoragePaths[i] = d[storagePathKey] as String;
    }
  }

  Future<void> _fetchMembersByFamily(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('personal_details').where('Family_Code', isEqualTo: familyCode).get(const GetOptions(source: Source.serverAndCache));
      final localMembers = await DataCacheService().fetchMembersLocally(familyCode);
      final Map<String, Map<String, dynamic>> memberMap = {};
      final Set<String> allNames = {};
      void processMember(Map<String, dynamic> data) {
        final name = data['Name']?.toString() ?? '';
        if (name.isEmpty) return;
        memberMap[name] = data;
        allNames.add(name);
      }
      for (var doc in snapshot.docs) processMember(doc.data());
      for (var local in localMembers) processMember(local);
      setState(() { _allMembersData = memberMap; familyMembers = allNames.toList()..sort(); });
    } catch (e) { debugPrint('Error fetching members: $e'); } finally { if (mounted) setState(() => _isLoadingMembers = false); }
  }

  Future<void> _fetchExistingRecords(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('health_readings').where('Family_code', isEqualTo: familyCode).get();
      if (snapshot.docs.isEmpty) {
         final snapshot2 = await FirebaseFirestore.instance.collection('health_readings').where('Family_Code', isEqualTo: familyCode).get();
         setState(() { _existingRecords = snapshot2.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList(); });
      } else {
        setState(() { _existingRecords = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList(); });
      }
    } catch (e) { debugPrint('Error fetching records: $e'); } finally { if (mounted) setState(() => _isLoadingMembers = false); }
  }

  void _onNameSelected(String? name) async {
    setState(() {
      selectedName = name;
      _nameController.text = name ?? '';
    });
    
    if (name == null) return;

    final baseData = _allMembersData[name];
    if (baseData != null && !_isEditMode) {
      _registrationNumber.text = (baseData['uniq_Registration_Number'] ?? baseData['Registration_Number'] ?? baseData['Registration_Number1'] ?? '').toString();
      selectedGender = baseData['Gender']?.toString();
      _age.text = baseData['Age']?.toString() ?? '';
    }

    if (_isEditMode) {
      setState(() => _isLoadingMembers = true);
      try {
        final fCode = _familyCodeController.text.trim();
        // health_readings uses "Family_code" or "Family_Code"
        var snapshot = await FirebaseFirestore.instance
            .collection('health_readings')
            .where('Family_code', isEqualTo: fCode)
            .where('Name', isEqualTo: name)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) {
          snapshot = await FirebaseFirestore.instance
              .collection('health_readings')
              .where('Family_Code', isEqualTo: fCode)
              .where('Name', isEqualTo: name)
              .orderBy('clientUpdatedAt', descending: true)
              .limit(1)
              .get();
        }

        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          setState(() {
            _editDocId = doc.id;
            final merged = {...?baseData, ...doc.data()};
            _populateForm(merged);
          });
        } else if (baseData != null) {
          _populateForm(baseData);
        }
      } catch (e) {
        debugPrint('Error fetching health readings record: $e');
        if (baseData != null) _populateForm(baseData);
      } finally {
        if (mounted) setState(() => _isLoadingMembers = false);
      }
    }
  }

  void _setupConnectivityListener() {
    Connectivity().checkConnectivity().then((dynamic result) {
      if (mounted) setState(() { _isOnline = (result is List) ? result.isNotEmpty && result.first != ConnectivityResult.none : result != ConnectivityResult.none; });
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((dynamic result) {
      final connectivityResult = (result is List) ? (result.isNotEmpty ? result.first : ConnectivityResult.none) : result;
      final bool wasOnline = _isOnline;
      if (mounted) setState(() { _isOnline = (connectivityResult != ConnectivityResult.none); });
      if (_isOnline && !wasOnline) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) { HealthOCRService.processPendingReadings(); _autoTriggerExtraction(); }
        });
      }
    });
  }

  Future<void> _autoTriggerExtraction() async {
    if (_isLoading) return;
    final List<int> bpIndicesToExtract = [];
    for (int i = 0; i < 3; i++) { if (_bpImages[i] != null && _sysControllers[i].text.isEmpty) bpIndicesToExtract.add(i); }
    if (bpIndicesToExtract.isEmpty) return;
    setState(() { _isLoading = true; _statusMessage = 'Network restored! Extraction background process started...'; });
    try {
      for (int index in bpIndicesToExtract) { await _performOCR(_bpImages[index]!, ReadingType.bp, index: index); }
    } finally { if (mounted) setState(() { _isLoading = false; _statusMessage = ''; }); }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    for (var c in _sysControllers) c.dispose();
    for (var c in _diaControllers) c.dispose();
    for (var c in _pulseControllers) c.dispose();
    _registrationNumber.dispose(); _familyCodeController.dispose(); _nameController.dispose();
    _age.dispose(); _othersMention.dispose(); _d1.dispose(); _d2.dispose(); _d3.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) openAppSettings();
    return false;
  }

  Future<void> _captureImage(ReadingType type, {int index = 0}) async {
    final hasPermission = await _requestCameraPermission();
    if (!hasPermission) return;
    setState(() { _isLoading = true; _statusMessage = 'Opening camera...'; });
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 95);
      if (pickedFile == null) { setState(() { _isLoading = false; _statusMessage = 'Image capture cancelled.'; }); return; }
      final File imageFile = File(pickedFile.path);
      setState(() { if (type == ReadingType.bp) _bpImages[index] = imageFile; _statusMessage = 'Processing image...'; });
      if (_isOnline) await _performOCR(imageFile, type, index: index); else _statusMessage = 'Offline: Saved. Will extract when online.';
    } catch (e) { setState(() => _statusMessage = 'Error: $e'); } finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _performOCR(File imageFile, ReadingType type, {int index = 0}) async {
    try {
      final model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: _geminiApiKey);
      final imageBytes = await imageFile.readAsBytes();
      final prompt = type == ReadingType.bp 
        ? "Extract SYS, DIA, and PULSE from this BP monitor image. Return ONLY JSON: {\"sys\": number, \"dia\": number, \"pulse\": number}."
        : "Extract values. Return ONLY JSON.";
      final content = [Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)])];
      final response = await model.generateContent(content);
      final text = response.text;
      if (text != null && text.contains('{')) {
        final data = jsonDecode(text.substring(text.indexOf('{'), text.lastIndexOf('}') + 1));
        if (type == ReadingType.bp) {
          if (data['sys'] != null) _sysControllers[index].text = data['sys'].toString();
          if (data['dia'] != null) _diaControllers[index].text = data['dia'].toString();
          if (data['pulse'] != null) _pulseControllers[index].text = data['pulse'].toString();
        }
      }
    } catch (e) { debugPrint('Gemini Error: $e'); }
  }

  Future<void> _saveReadings() async {
    setState(() { _isLoading = true; _statusMessage = 'Saving...'; });
    try {
      final DateTime now = DateTime.now();
      modifiedDate = now;
      List<String?> bpImagePaths = [null, null, null];
      for (int i = 0; i < 3; i++) {
        if (_bpImages[i] != null) {
          final Directory appDir = await getApplicationDocumentsDirectory();
          final String path = '${appDir.path}/bp${i+1}_${now.millisecondsSinceEpoch}.jpg';
          await _bpImages[i]!.copy(path);
          bpImagePaths[i] = path;
        }
      }
      final healthData = {
        'Registration_Number': _registrationNumber.text,
        'Family_code': _familyCodeController.text,
        'Name': selectedName ?? _nameController.text,
        'Gender': selectedGender,
        'Age': int.tryParse(_age.text),
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'Interviewer_s_Name': interviewersName,
        'If_not_done_reason': ifNotDoneReason,
        'If_Others_Please_Mention': _othersMention.text,
        'systolic': int.tryParse(_sysControllers[0].text),
        'diastolic': int.tryParse(_diaControllers[0].text),
        'pulse': int.tryParse(_pulseControllers[0].text),
        'systolic2': int.tryParse(_sysControllers[1].text),
        'diastolic2': int.tryParse(_diaControllers[1].text),
        'pulse2': int.tryParse(_pulseControllers[1].text),
        'systolic3': int.tryParse(_sysControllers[2].text),
        'diastolic3': int.tryParse(_diaControllers[2].text),
        'pulse3': int.tryParse(_pulseControllers[2].text),
        'clientUpdatedAt': now.millisecondsSinceEpoch,
        'needs_zoho_sync': true,
      };
      // Embed the Firestore doc ID so SyncService can route add vs update
      healthData['firestoreDocId'] = (_isEditMode && _editDocId != null) ? _editDocId : widget.docId;
      final bool wasEditing = _isEditMode;
      // 1. Save locally FIRST (Fast)
      await DataCacheService().saveOfflineSubmission('health_readings', healthData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasEditing ? 'Readings updated! Syncing...' : 'Readings saved! Syncing...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ));
        
        // Immediate UI Transition
        if (wasEditing) Navigator.pop(context); else _clearForm();
      }

      // 2. Background Sync (Non-blocking)
      _performHealthSync(healthData);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _performHealthSync(Map<String, dynamic> data) async {
    try {
      final String? docId = data['firestoreDocId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('health_readings').doc(docId).set(data, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('health_readings').add(data);
      }
    } catch (e) {
      debugPrint('Health Readings Background Sync Error: $e');
    }
  }

  void _clearForm() {
    setState(() {
      for (var c in _sysControllers) c.clear();
      for (var c in _diaControllers) c.clear();
      for (var c in _pulseControllers) c.clear();
      _registrationNumber.clear(); _familyCodeController.clear(); _nameController.clear();
      _age.clear(); _othersMention.clear(); _d1.clear(); _d2.clear(); _d3.clear();
      selectedName = null; selectedGender = null; interviewersName = null; ifNotDoneReason = null;
      _bpImages = [null, null, null]; _statusMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('BP & Glucose Form'), elevation: 0),
      drawer: const AppDrawer(),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              formActionButtons(
                context: context,
                isEditMode: _isEditMode,
                onNew: () { setState(() { _isEditMode = false; _clearForm(); }); },
                onSave: _saveReadings,
                onEdit: () { setState(() { _isEditMode = true; if (_familyCodeController.text.isNotEmpty) { _fetchMembersByFamily(_familyCodeController.text); _fetchExistingRecords(_familyCodeController.text); } }); },
                onCancel: _clearForm,
                onExit: () => Navigator.pop(context),
                isSaving: _isLoading,
              ),
              const SizedBox(height: 16),
              if (_statusMessage.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_statusMessage, style: const TextStyle(color: Colors.blue))),
              buildSectionCard(
                context: context,
                title: 'Identity & Registration',
                icon: Icons.fingerprint_outlined,
                children: [
                  formTextField(
                    'Registration Number',
                    _registrationNumber,
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  formSearchField(
                    'Family Code',
                    _familyCodeController,
                    onSearch: () => _fetchMembersByFamily(_familyCodeController.text),
                    isLoading: _isLoadingMembers,
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  formSearchableDropdown(
                    context,
                    'Name',
                    ({
                      ...familyMembers,
                      ..._existingRecords.map((r) => r['Name']?.toString() ?? '')
                    }.where((n) => n.isNotEmpty).map((n) => n.toString()).toList()..sort()),
                    selectedName,
                    _onNameSelected,
                    isLoading: _isLoadingMembers,
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
                  Row(children: [
                    Expanded(child: RadioListTile<String>(title: const Text('Male'), value: '(1) Male', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), dense: true)),
                    Expanded(child: RadioListTile<String>(title: const Text('Female'), value: '(0) Female', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), dense: true)),
                  ]),
                  const SizedBox(height: 12),
                  formTextField(
                    'Age',
                    _age,
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildDatePicker('Date of Interview', dateOfInterview, (v) => setState(() => dateOfInterview = v)),
                  const SizedBox(height: 12),
                  formSearchableDropdown(context, 
                    'Interviewer’s Name',
                    ['KIRANMAI K', 'REVATHI CH', 'RAMADEVI Y', 'LAVANYA KASPOJU', 'PUSHPA K', 'G RAMADEVI', 'BHASKAR K', 'ASHA', 'KUSUMA G', 'B JYOTHI', 'RAMADEVI G', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU'],
                    interviewersName,
                    (v) => setState(() => interviewersName = v),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              buildSectionCard(
                context: context,
                title: 'Screening Status',
                icon: Icons.help_outline,
                children: [
                  RadioListTile<String>(title: const Text('Not available'), value: '(1) Not available', groupValue: ifNotDoneReason, onChanged: (v) => setState(() => ifNotDoneReason = v), dense: true),
                  RadioListTile<String>(title: const Text('Refused'), value: '(2) Refused for current visit', groupValue: ifNotDoneReason, onChanged: (v) => setState(() => ifNotDoneReason = v), dense: true),
                  RadioListTile<String>(title: const Text('Door Locked'), value: '(3) Door Locked', groupValue: ifNotDoneReason, onChanged: (v) => setState(() => ifNotDoneReason = v), dense: true),
                  RadioListTile<String>(title: const Text('Other'), value: '(4) Other', groupValue: ifNotDoneReason, onChanged: (v) => setState(() => ifNotDoneReason = v), dense: true),
                  if (ifNotDoneReason == '(4) Other') formTextField('Specify', _othersMention),
                ],
              ),
              const SizedBox(height: 16),
              ...List.generate(3, (i) => Column(children: [
                buildSectionCard(
                  context: context,
                  title: 'BP Reading ${i + 1}',
                  icon: Icons.monitor_heart,
                  children: [
                    Row(children: [
                      Expanded(child: formTextField(
                        'Sys',
                        _sysControllers[i],
                        keyboardType: TextInputType.number,
                        validator: (v) => (ifNotDoneReason == null && (v == null || v.isEmpty)) ? 'Required' : null,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: formTextField(
                        'Dia',
                        _diaControllers[i],
                        keyboardType: TextInputType.number,
                        validator: (v) => (ifNotDoneReason == null && (v == null || v.isEmpty)) ? 'Required' : null,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: formTextField(
                        'Pulse',
                        _pulseControllers[i],
                        keyboardType: TextInputType.number,
                        validator: (v) => (ifNotDoneReason == null && (v == null || v.isEmpty)) ? 'Required' : null,
                      )),
                    ]),
                    const SizedBox(height: 12),
                    if (_bpImages[i] != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_bpImages[i]!, height: 120, width: double.infinity, fit: BoxFit.cover))),
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _captureImage(ReadingType.bp, index: i), icon: const Icon(Icons.camera_alt), label: const Text('Capture Reading'))),
                  ],
                ),
                const SizedBox(height: 16),
              ])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onPicked) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      InkWell(
        onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
          if (picked != null) onPicked(picked);
        },
        child: InputDecorator(
          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), suffixIcon: Icon(Icons.calendar_today, size: 18)),
          child: Text(selectedDate == null ? 'Select Date' : DateFormat('dd-MMM-yyyy').format(selectedDate)),
        ),
      ),
    ]);
  }
}