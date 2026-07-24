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
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_drawer.dart';
import 'health_ocr_service.dart';
import 'data_cache_service.dart';
import 'local_database_service.dart';
import 'sync_service.dart';
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
  final ScrollController _scrollController = ScrollController();
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
  List<Map<String, dynamic>> _allPersonRecords = [];
  List<String> _availableVisitDates = [];
  String? _selectedVisitDate;
  String? ifNotDoneReason;
  DateTime? date1;
  DateTime? date2;
  DateTime? date3;
  DateTime? entryDate;
  DateTime? modifiedDate;

  List<String> familyMembers = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  // Location (auto-populated from Family Code)
  String? _locationVillage;
  String? _locationMandal;
  String? _locationDistrict;
  String? _locationState;

  bool _isLoadingMembers = false;

  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoading = false;
  bool _isOnline = false;
  String _statusMessage = '';
  bool _isActionActive = false;
  final FocusNode _familyCodeNode = FocusNode();
  bool _familyIdReadOnly = true;
  StreamSubscription? _connectivitySubscription;

  bool _isDownloadingBP = false;
  bool _bpAlreadyDownloaded = false;
  String? _bpDownloadedAt;

  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  String _geminiApiKey = 'AIzaSyB4MBq0hMEx-UTB6eAr5FTDVR_kjOf-lUU'; 

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
    _loadBPDownloadStatus();
    entryDate = DateTime.now();
    dateOfInterview = DateTime.now();
    if (widget.existingData != null) {
      _isEditMode = true;
      _populateForm(widget.existingData!);
    }
    HealthOCRService.processPendingReadings();
  }

  void _populateForm(Map<String, dynamic> d) {
    // Registration: current field OR old TETRA REGNO/Regno
    _registrationNumber.text = (d['Registration_Number'] ?? d['REGNO'] ?? d['Regno'] ?? '').toString();
    _familyCodeController.text = (d['Family_code'] ?? d['Family_Code'] ?? d['FAM_ID'] ?? '').toString();
    if (_familyCodeController.text.isNotEmpty && familyMembers.isEmpty) _fetchMembersByFamily(_familyCodeController.text);
    selectedName = d['Name'];
    _locationVillage  = (d['Village']  ?? d['village'])?.toString();
    _locationMandal   = (d['Mandal']   ?? d['mandal'])?.toString();
    _locationDistrict = (d['District'] ?? d['district'])?.toString();
    _locationState    = (d['State']    ?? d['state'])?.toString();
    // Gender: handles raw '1'/'0' from old TETRA data
    selectedGender = normalizeGender(d['Gender']);
    _age.text = (d['Age'] ?? '').toString();
    // Interview date: current field OR old TETRA INTDT
    final rawDate = d['Date_of_Interview'] ?? d['Interview_Date'] ?? d['INTDT'];
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
    interviewersName = matchInterviewerName(d['Interviewer_s_Name'] ?? d['interviewer_name'] ?? d['interviewer'] ?? d['Interviewer_Name'] ?? d['INTNAME'], ['KIRANMAI K', 'REVATHI CH', 'RAMADEVI Y', 'LAVANYA KASPOJU', 'PUSHPA K', 'G RAMADEVI', 'BHASKAR K', 'ASHA', 'KUSUMA G', 'B JYOTHI', 'RAMADEVI G', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU']);
    // Not done reason: current field OR old TETRA NA_DL (1=Not available, 2=Refused, 3=Door Locked, 4=Other)
    final _naCode = d['NA_DL']?.toString().trim();
    ifNotDoneReason = d['If_not_done_reason'] ?? const {
      '1': '(1) Not available',
      '2': '(2) Refused for current visit',
      '3': '(3) Door Locked',
      '4': '(4) Other',
    }[_naCode];
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
    // Reading dates: current field OR old TETRA BP1DT/BP2DT/BP3DT
    date1 = _parseHealthDate(d['Date1'] ?? d['BP1DT']);
    date2 = _parseHealthDate(d['Date2'] ?? d['BP2DT']);
    date3 = _parseHealthDate(d['Date3'] ?? d['BP3DT']);
    if (d['Entry_Date'] != null) entryDate = _parseHealthDate(d['Entry_Date']);
    if (d['Modified_Date'] != null) modifiedDate = _parseHealthDate(d['Modified_Date']);
    for (int i = 0; i < 3; i++) {
      final suffix = i == 0 ? '' : (i + 1).toString();
      final bpNum = (i + 1).toString();
      // BP readings: current field OR old TETRA BP1S/BP2S/BP3S (systolic), BP1D/BP2D/BP3D (diastolic), HR1/HR2/HR3 (pulse)
      _sysControllers[i].text = (d['systolic$suffix'] ?? d['BP${bpNum}S'] ?? '').toString();
      _diaControllers[i].text = (d['diastolic$suffix'] ?? d['BP${bpNum}D'] ?? '').toString();
      _pulseControllers[i].text = (d['pulse$suffix'] ?? d['Heart_Beat${i == 0 ? '1' : (i + 1).toString()}'] ?? d['HR$bpNum'] ?? '').toString();
      final storagePathKey = i == 0 ? 'bp_storage_path' : 'bp_storage_path${i + 1}';
      if (d[storagePathKey] != null) _bpStoragePaths[i] = d[storagePathKey] as String;
    }
  }

  Future<void> _loadBPDownloadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString('bp_download_timestamp');
    if (mounted) setState(() { _bpAlreadyDownloaded = ts != null; _bpDownloadedAt = ts; });
  }

  Future<void> _downloadBPFromStorage() async {
    if (_isDownloadingBP) return;
    final prefs = await SharedPreferences.getInstance();

    if (_bpAlreadyDownloaded) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Already Downloaded'),
          content: Text('BP data was downloaded on $_bpDownloadedAt.\n\nDownload again to refresh?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Re-download')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isDownloadingBP = true);
    try {
      final ref = FirebaseStorage.instance.ref('exports/bp_readings.json');
      final url = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final List<dynamic> jsonList = jsonDecode(response.body);
      final records = jsonList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await LocalDatabaseService().saveBpRecords(records, clearFirst: true);
      final downloadedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      await prefs.setString('bp_download_timestamp', downloadedAt);
      if (mounted) {
        setState(() { _bpAlreadyDownloaded = true; _bpDownloadedAt = downloadedAt; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('BP data downloaded (${records.length} records)'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Download failed: $e'), backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isDownloadingBP = false);
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
        
        // Filter: only members aged 18 or older
        final age = int.tryParse(data['Age']?.toString() ?? '0') ?? 0;
        if (age < 18) return;

        memberMap[name] = data;
        allNames.add(name);
      }
      for (var doc in snapshot.docs) processMember(doc.data());
      for (var local in localMembers) processMember(local);
      setState(() { _allMembersData = memberMap; familyMembers = allNames.toList()..sort(); });
    _fetchFamilyLocation(familyCode);
    } catch (e) { debugPrint('Error fetching members: $e'); } finally { if (mounted) setState(() => _isLoadingMembers = false); }
  }

  Future<void> _fetchExistingRecords(String familyCode) async {
    setState(() => _isLoadingMembers = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('health_readings').where('Family_code', isEqualTo: familyCode).get(const GetOptions(source: Source.serverAndCache)).timeout(const Duration(seconds: 8));
      if (snapshot.docs.isEmpty) {
         final snapshot2 = await FirebaseFirestore.instance.collection('health_readings').where('Family_Code', isEqualTo: familyCode).get(const GetOptions(source: Source.serverAndCache)).timeout(const Duration(seconds: 8));
         setState(() { _existingRecords = snapshot2.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList(); });
      } else {
        setState(() { _existingRecords = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList(); });
      }
    } catch (e) { debugPrint('Error fetching records: $e'); } finally { if (mounted) setState(() => _isLoadingMembers = false); }
  }

  String? _dateStringFromRecord(Map<String, dynamic> r) {
    final raw = r['Date_of_Interview'] ?? r['Interview_Date'];
    if (raw == null) return null;
    if (raw is Timestamp) return DateFormat('dd-MMM-yyyy').format(raw.toDate());
    try { return DateFormat('dd-MMM-yyyy').format(DateFormat('dd-MMM-yyyy').parse(raw.toString())); } catch (_) {}
    try { return DateFormat('dd-MMM-yyyy').format(DateTime.parse(raw.toString())); } catch (_) {}
    return raw.toString();
  }

  void _onVisitDateSelected(String? dateStr) {
    if (dateStr == null) return;
    setState(() => _selectedVisitDate = dateStr);
    final rec = _allPersonRecords.firstWhere(
      (r) => _dateStringFromRecord(r) == dateStr,
      orElse: () => _allPersonRecords.first,
    );
    _editDocId = rec['firestoreDocId']?.toString();
    setState(() => _populateForm(rec));
  }

  void _onNameSelected(String? name) async {
    setState(() {
      selectedName = name;
      _nameController.text = name ?? '';
      _allPersonRecords = [];
      _availableVisitDates = [];
      _selectedVisitDate = null;
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
        List<Map<String, dynamic>> records = [];

        try {
          var snapshot = await FirebaseFirestore.instance
              .collection('health_readings')
              .where('Family_code', isEqualTo: fCode)
              .where('Name', isEqualTo: name)
              .orderBy('clientUpdatedAt', descending: true)
              .get()
              .timeout(const Duration(seconds: 5));

          if (snapshot.docs.isEmpty) {
            snapshot = await FirebaseFirestore.instance
                .collection('health_readings')
                .where('Family_Code', isEqualTo: fCode)
                .where('Name', isEqualTo: name)
                .orderBy('clientUpdatedAt', descending: true)
                .get()
                .timeout(const Duration(seconds: 5));
          }

          for (final doc in snapshot.docs) {
            records.add({...?baseData, ...doc.data(), 'firestoreDocId': doc.id});
          }
        } catch (e) {
          debugPrint('BP: Firestore lookup failed: $e');
        }

        if (records.isEmpty) {
          final localRecord = await LocalDatabaseService().getBpRecordByName(fCode, name);
          if (localRecord != null) records.add({...?baseData, ...localRecord});
        }
        if (records.isEmpty && baseData != null) records.add(baseData);

        final dates = records
            .map((r) => _dateStringFromRecord(r))
            .where((d) => d != null)
            .cast<String>()
            .toList();

        if (mounted) {
          setState(() {
            _allPersonRecords = records;
            _availableVisitDates = dates;
          });
          if (records.length == 1) {
            _editDocId = records.first['firestoreDocId']?.toString();
            setState(() => _populateForm(records.first));
          }
        }
      } catch (e) {
        debugPrint('Error in BP _onNameSelected: $e');
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
    _familyCodeNode.dispose();
    _connectivitySubscription?.cancel();
    for (var c in _sysControllers) c.dispose();
    for (var c in _diaControllers) c.dispose();
    for (var c in _pulseControllers) c.dispose();
    _registrationNumber.dispose(); _familyCodeController.dispose(); _nameController.dispose();
    _age.dispose(); _othersMention.dispose(); _d1.dispose(); _d2.dispose(); _d3.dispose();
    _textRecognizer.close();
    _scrollController.dispose();
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

  void _checkBpAlert(String val, String type) {
    if (val.isEmpty) return;
    final value = int.tryParse(val);
    if (value == null) return;

    bool isHigh = false;
    if (type == 'SYS' && value >= 140) isHigh = true;
    if (type == 'DIA' && value >= 90) isHigh = true;

    if (isHigh) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ALERT: High $type Detected ($value)!', 
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveReadings() async {
    // Pre-save validation for High BP
    List<int> validSys = _sysControllers.map((c) => int.tryParse(c.text)).whereType<int>().toList();
    List<int> validDia = _diaControllers.map((c) => int.tryParse(c.text)).whereType<int>().toList();
    
    bool hasHighBp = validSys.any((v) => v >= 140) || validDia.any((v) => v >= 90);
    
    if (hasHighBp) {
      bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('High Blood Pressure Detected', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text('One or more of the entered blood pressure readings (Systolic > 140 or Diastolic > 90) indicates High BP.\n\nAre you sure you want to save these readings?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Acknowledge & Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      
      if (proceed != true) return;
    }

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
        'Village': _locationVillage,
        'Mandal': _locationMandal,
        'District': _locationDistrict,
        'State': _locationState,
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

      // 2. Trigger Background Sync (Handles Firestore push)
      SyncService().syncPendingSubmissions();

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() {
        _isLoading = false;
        _isActionActive = false; // Add this
      });
    }
  }


  void _clearForm() {
    setState(() {
      _isActionActive = false;
      for (var c in _sysControllers) c.clear();
      for (var c in _diaControllers) c.clear();
      for (var c in _pulseControllers) c.clear();
      _registrationNumber.clear();
      // _familyCodeController.text = 'TSRRMED'; // Preserved
      _nameController.clear();
      _age.clear(); _othersMention.clear(); _d1.clear(); _d2.clear(); _d3.clear();
      selectedName = null; selectedGender = null; interviewersName = null; ifNotDoneReason = null;
      _locationVillage = null; _locationMandal = null; _locationDistrict = null; _locationState = null;
      _bpImages = [null, null, null]; _statusMessage = '';
      _allPersonRecords = []; _availableVisitDates = []; _selectedVisitDate = null;
    });
  }


  Future<void> _fetchFamilyLocation(String familyCode) async {
    try {
      var detail = await LocalDatabaseService().getSingleFamilyDetail(familyCode.trim().toUpperCase());
      detail ??= await LocalDatabaseService().getSingleFamilyDetail(familyCode.trim());

      if (detail == null) {
        final snap = await FirebaseFirestore.instance
            .collection('Family Code Creation')
            .doc(familyCode.trim().toUpperCase())
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 6));
        if (snap.exists) detail = snap.data();
      }

      if (detail != null && mounted) {
        setState(() {
          _locationVillage  = (detail!['village']  ?? detail['Village'])?.toString();
          _locationMandal   = (detail['mandal']    ?? detail['Mandal'])?.toString();
          _locationDistrict = (detail['district']  ?? detail['District'])?.toString();
          _locationState    = (detail['state']     ?? detail['State'])?.toString();
        });
      }
    } catch (e) {
      debugPrint('_fetchFamilyLocation: $e');
    }
  }

  Widget _buildLocationRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text('$label:', style: const TextStyle(fontSize: 12, color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('BP & Glucose Form'),
        elevation: 0,
        actions: [
          _isDownloadingBP
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : IconButton(
                  icon: Icon(Icons.cloud_download_outlined, color: _bpAlreadyDownloaded ? Colors.greenAccent : Colors.white),
                  tooltip: _bpAlreadyDownloaded ? 'Downloaded: $_bpDownloadedAt' : 'Download for offline',
                  onPressed: _downloadBPFromStorage,
                ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_statusMessage.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(_statusMessage,
                              style: const TextStyle(color: Colors.blue))),
                    buildSectionCard(
                      context: context,
                      title: 'Identity & Registration',
                      icon: Icons.fingerprint_outlined,
                      children: [
                        formTextField(
                          'Registration Number',
                          _registrationNumber,
                          enabled: _isActionActive,
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        formSearchField(
                          'Family Code',
                          _familyCodeController,
                          onSearch: () =>
                              _fetchMembersByFamily(_familyCodeController.text),
                          isLoading: _isLoadingMembers,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                          readOnly: _familyIdReadOnly,
                          focusNode: _familyCodeNode,
                        ),
                        const SizedBox(height: 12),
                        if (_locationVillage != null || _locationMandal != null || _locationDistrict != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Icon(Icons.location_on_outlined, size: 16, color: Colors.blue.shade700),
                                    const SizedBox(width: 4),
                                    Text('Location', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade700, fontSize: 12)),
                                  ]),
                                  const SizedBox(height: 6),
                                  _buildLocationRow('Village', _locationVillage),
                                  _buildLocationRow('Mandal', _locationMandal),
                                  _buildLocationRow('District', _locationDistrict),
                                  _buildLocationRow('State', _locationState),
                                ],
                              ),
                            ),
                          ),
                        formSearchableDropdown(
                          context,
                          'Name',
                          ({
                            ...familyMembers,
                            ..._existingRecords
                                .map((r) => r['Name']?.toString() ?? '')
                          }
                              .where((n) => n.isNotEmpty)
                              .map((n) => n.toString())
                              .toList()
                            ..sort()),
                          selectedName,
                          _onNameSelected,
                          isLoading: _isLoadingMembers,
                          enabled: _isActionActive,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        if (_isEditMode && _availableVisitDates.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          formSearchableDropdown(
                            context,
                            'Visit Date',
                            _availableVisitDates,
                            _selectedVisitDate,
                            _onVisitDateSelected,
                            enabled: _isActionActive,
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text('Gender',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        Row(children: [
                          Expanded(
                              child: RadioListTile<String>(
                                  title: const Text('Male'),
                                  value: '(1) Male',
                                  groupValue: selectedGender,
                                  onChanged: !_isActionActive ? null : (v) =>
                                      setState(() => selectedGender = v),
                                  dense: true)),
                          Expanded(
                              child: RadioListTile<String>(
                                  title: const Text('Female'),
                                  value: '(0) Female',
                                  groupValue: selectedGender,
                                  onChanged: !_isActionActive ? null : (v) =>
                                      setState(() => selectedGender = v),
                                  dense: true)),
                        ]),
                        const SizedBox(height: 12),
                        formTextField(
                          'Age',
                          _age,
                          enabled: _isActionActive,
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        _buildDatePicker('Date of Interview', dateOfInterview,
                            (v) => setState(() => dateOfInterview = v)),
                        const SizedBox(height: 12),
                        formSearchableDropdown(
                          context,
                          'Interviewer’s Name',
                          [
                            'KIRANMAI K',
                            'REVATHI CH',
                            'RAMADEVI Y',
                            'LAVANYA KASPOJU',
                            'PUSHPA K',
                            'G RAMADEVI',
                            'BHASKAR K',
                            'ASHA',
                            'KUSUMA G',
                            'B JYOTHI',
                            'RAMADEVI G',
                            'LAVANYA METU',
                            'N POOJA',
                            'POOJA N',
                            'K BHASKAR',
                            'LAVANYA M',
                            'LAVANYA METTU'
                          ],
                          interviewersName,
                          (v) => setState(() => interviewersName = v),
                          enabled: _isActionActive,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildSectionCard(
                      context: context,
                      title: 'Screening Status',
                      icon: Icons.help_outline,
                      children: [
                        RadioListTile<String>(
                            title: const Text('Not available'),
                            value: '(1) Not available',
                            groupValue: ifNotDoneReason,
                            onChanged: !_isActionActive ? null : (v) =>
                                setState(() => ifNotDoneReason = v),
                            dense: true),
                        RadioListTile<String>(
                            title: const Text('Refused'),
                            value: '(2) Refused for current visit',
                            groupValue: ifNotDoneReason,
                            onChanged: !_isActionActive ? null : (v) =>
                                setState(() => ifNotDoneReason = v),
                            dense: true),
                        RadioListTile<String>(
                            title: const Text('Door Locked'),
                            value: '(3) Door Locked',
                            groupValue: ifNotDoneReason,
                            onChanged: !_isActionActive ? null : (v) =>
                                setState(() => ifNotDoneReason = v),
                            dense: true),
                        RadioListTile<String>(
                            title: const Text('Other'),
                            value: '(4) Other',
                            groupValue: ifNotDoneReason,
                            onChanged: !_isActionActive ? null : (v) =>
                                setState(() => ifNotDoneReason = v),
                            dense: true),
                        if (ifNotDoneReason == '(4) Other')
                          formTextField('Specify', _othersMention, enabled: _isActionActive),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(
                        3,
                        (i) => Column(children: [
                              buildSectionCard(
                                context: context,
                                title: 'BP Reading ${i + 1}',
                                icon: Icons.monitor_heart,
                                children: [
                                  Row(children: [
                                    Expanded(
                                        child: formTextField(
                                      'Sys',
                                      _sysControllers[i],
                                      enabled: _isActionActive,
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => _checkBpAlert(v, 'SYS'),
                                      validator: (v) => (ifNotDoneReason ==
                                                  null &&
                                              (v == null || v.isEmpty))
                                          ? 'Required'
                                          : null,
                                    )),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: formTextField(
                                      'Dia',
                                      _diaControllers[i],
                                      enabled: _isActionActive,
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => _checkBpAlert(v, 'DIA'),
                                      validator: (v) => (ifNotDoneReason ==
                                                  null &&
                                              (v == null || v.isEmpty))
                                          ? 'Required'
                                          : null,
                                    )),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: formTextField(
                                      'Pulse',
                                      _pulseControllers[i],
                                      enabled: _isActionActive,
                                      keyboardType: TextInputType.number,
                                      validator: (v) => (ifNotDoneReason ==
                                                  null &&
                                              (v == null || v.isEmpty))
                                          ? 'Required'
                                          : null,
                                    )),
                                  ]),
                                  const SizedBox(height: 12),
                                  if (_bpImages[i] != null)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.file(_bpImages[i]!,
                                                height: 120,
                                                width: double.infinity,
                                                fit: BoxFit.cover))),
                                  SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                          onPressed: !_isActionActive ? null : () => _captureImage(
                                              ReadingType.bp,
                                              index: i),
                                          icon: const Icon(Icons.camera_alt),
                                          label:
                                              const Text('Capture Reading'))),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ])),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _isLoading
          ? null
          : formActionButtons(
              context: context,
              isEditMode: _isEditMode,
              onNew: () {
                setState(() {
                  _isEditMode = false;
                  _clearForm();
                  _isActionActive = true;
                  _familyIdReadOnly = false;
                  _familyCodeNode.requestFocus();
                });
              },
              onSave: _saveReadings,
              onEdit: () {
                setState(() {
                  _isEditMode = true;
                  _isActionActive = true;
                  _familyIdReadOnly = false;
                  _familyCodeNode.requestFocus();
                  if (_familyCodeController.text.isNotEmpty) {
                    _fetchMembersByFamily(_familyCodeController.text);
                    _fetchExistingRecords(_familyCodeController.text);
                  }
                });
              },
              onCancel: () {
                setState(() {
                  _isActionActive = false;
                  _clearForm();
                });
              },
              onExit: () => Navigator.pop(context),
              isSaving: _isLoading,
              isActionActive: _isActionActive,
            ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onPicked) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      InkWell(
        onTap: !_isActionActive ? null : () async {
          final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
          final picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
          if (picked != null) {
            onPicked(picked);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) _scrollController.jumpTo(offset);
            });
          }
        },
        child: InputDecorator(
          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), suffixIcon: Icon(Icons.calendar_today, size: 18)),
          child: Text(selectedDate == null ? 'Select Date' : DateFormat('dd-MMM-yyyy').format(selectedDate)),
        ),
      ),
    ]);
  }
}