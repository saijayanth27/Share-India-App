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

/// Enum to distinguish between BP and Sugar reading types
enum ReadingType { bp, sugar }

class HealthReadingsPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const HealthReadingsPage({super.key, this.existingData, this.docId});

  @override
  _HealthReadingsPageState createState() => _HealthReadingsPageState();
}

class _HealthReadingsPageState extends State<HealthReadingsPage> {
  // --- Existing Controllers & Images ---
  final List<TextEditingController> _sysControllers = List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> _diaControllers = List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> _pulseControllers = List.generate(3, (_) => TextEditingController());

  List<File?> _bpImages = [null, null, null];
  List<String?> _bpStoragePaths = [null, null, null];

  // --- Identity & Registration Controllers ---
  final _familyCodeController = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _age = TextEditingController();
  final _othersMention = TextEditingController();
  final _d1 = TextEditingController();
  final _d2 = TextEditingController();
  final _d3 = TextEditingController();
  
  String? selectedFamilyCode;
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

  List<String> allFamilyCodes = [];
  List<String> familyMembers = [];
  Map<String, Map<String, dynamic>> _allMembersData = {};
  bool _isLoadingMembers = false;

  bool _isEditMode = false;
  String? _editDocId;
  List<Map<String, dynamic>> _existingRecords = [];
  bool _isLoading = false;
  bool _isOnline = false; // CACHED connectivity state for zero-lag
  String _statusMessage = '';
  String _ocrRawText = ''; // For debugging
  StreamSubscription? _connectivitySubscription;

  // Image picker and text recognizer instances
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  // Gemini API Key (User should provide this)
  String _geminiApiKey = 'AIzaSyB4MBq0hMEx-UTB6eAr5FTDVR_kjOf-lUU'; 

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
    _fetchFamilyCodes();
    
    entryDate = DateTime.now();
    dateOfInterview = DateTime.now();

    if (widget.existingData != null) {
      _populateForm(widget.existingData!);
    }
    // Trigger background sync for any previous offline records immediately on launch
    HealthOCRService.processPendingReadings();
  }

  void _populateForm(Map<String, dynamic> d) {
    _registrationNumber.text = (d['Registration_Number'] ?? '').toString();
    selectedFamilyCode = d['Family_code'] ?? d['Family_Code'];
    _familyCodeController.text = selectedFamilyCode ?? '';
    if (selectedFamilyCode != null && familyMembers.isEmpty) _fetchMembersByFamily(selectedFamilyCode!);
    selectedName = d['Name'];
    selectedGender = d['Gender'];
    _age.text = (d['Age'] ?? '').toString();
    if (d['Date_of_Interview'] != null) {
      if (d['Date_of_Interview'] is Timestamp) {
        dateOfInterview = (d['Date_of_Interview'] as Timestamp).toDate();
      } else {
        try {
          dateOfInterview = DateFormat('dd-MMM-yyyy').parse(d['Date_of_Interview'].toString());
        } catch (_) {}
      }
    }
    interviewersName = d['Interviewer_s_Name'];
    ifNotDoneReason = d['If_not_done_reason'];
    _othersMention.text = d['If_Others_Please_Mention'] ?? '';
    
    _d1.text = d['/d1'] ?? d['Single_Line4'] ?? '';
    _d2.text = d['/d2'] ?? d['Single_Line3'] ?? '';
    _d3.text = d['/d3'] ?? d['Single_Line1'] ?? '';

    if (d['Date1'] != null) date1 = (d[ 'Date1'] as Timestamp).toDate();
    if (d['Date2'] != null) date2 = (d['Date2'] as Timestamp).toDate();
    if (d['Date3'] != null) date3 = (d['Date3'] as Timestamp).toDate();
    if (d['Entry_Date'] != null) entryDate = (d['Entry_Date'] as Timestamp).toDate();
    if (d['Modified_Date'] != null) modifiedDate = (d['Modified_Date'] as Timestamp).toDate();

    for (int i = 0; i < 3; i++) {
      final suffix = i == 0 ? '' : (i + 1).toString();
      _sysControllers[i].text = (d['systolic$suffix'] ?? '').toString();
      _diaControllers[i].text = (d['diastolic$suffix'] ?? '').toString();
      _pulseControllers[i].text = (d['pulse$suffix'] ?? d['Heart_Beat${i == 0 ? '1' : (i + 1).toString()}'] ?? '').toString();
      
      final pathKey = i == 0 ? 'bp_image_path' : 'bp_image_path${i + 1}';
      final storagePathKey = i == 0 ? 'bp_storage_path' : 'bp_storage_path${i + 1}';
      
      if (d[storagePathKey] != null) _bpStoragePaths[i] = d[storagePathKey] as String;
      if (d[pathKey] != null && File(d[pathKey]).existsSync()) _bpImages[i] = File(d[pathKey]);
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
      // 1. Fetch from Firestore (Cache favored)
      final snapshot = await FirebaseFirestore.instance
          .collection('personal_details')
          .where('Family_Code', isEqualTo: familyCode)
          .get(const GetOptions(source: Source.serverAndCache));

      // 2. Fetch from Local SQLite for offline support
      final localMembers = await DataCacheService().fetchMembersLocally(familyCode);

      // 3. Merge logic
      final Map<String, Map<String, dynamic>> memberMap = {};
      final Set<String> allNames = {};
      
      void processMember(Map<String, dynamic> data) {
        final name = data['Name']?.toString() ?? '';
        if (name.isEmpty) return;
        memberMap[name] = data;
        allNames.add(name);
      }

      for (var doc in snapshot.docs) {
        processMember(doc.data());
      }
      for (var local in localMembers) {
        processMember(local);
      }

      setState(() {
        _allMembersData = memberMap;
        familyMembers = allNames.toList()..sort();
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
          .collection('health_readings')
          .where('Family_code', isEqualTo: familyCode) // Note lower case 'code' in some forms
          .get();
      
      // Some forms use 'Family_Code', checking both if needed or sticking to one
      if (snapshot.docs.isEmpty) {
         final snapshot2 = await FirebaseFirestore.instance
            .collection('health_readings')
            .where('Family_Code', isEqualTo: familyCode)
            .get();
         setState(() {
           _existingRecords = snapshot2.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
         });
      } else {
        setState(() {
          _existingRecords = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
        });
      }
      setState(() => _isLoadingMembers = false);
    } catch (e) {
      debugPrint('Error fetching existing records: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  void _onNameSelected(String? name) async {
    setState(() {
      selectedName = name;
      if (name != null) {
        if (_isEditMode) {
          final record = _existingRecords.firstWhere((r) => r['Name'] == name, orElse: () => {});
          if (record.isNotEmpty) {
            _editDocId = record['id'];
            _populateForm(record);
          }
        } else if (_allMembersData.containsKey(name)) {
          final data = _allMembersData[name]!;
          _registrationNumber.text = data['Registration_Number']?.toString() ?? '';
          selectedGender = data['Gender']?.toString();
          _age.text = data['Age']?.toString() ?? '';
        }
      }
    });
  }

  void _setupConnectivityListener() {
    // Initial check
    Connectivity().checkConnectivity().then((dynamic result) {
      if (mounted) {
        setState(() {
          _isOnline = (result is List) 
              ? result.isNotEmpty && result.first != ConnectivityResult.none
              : result != ConnectivityResult.none;
        });
      }
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((dynamic result) {
      final connectivityResult = (result is List) 
          ? (result.isNotEmpty ? result.first : ConnectivityResult.none) 
          : result;
      
      final bool wasOnline = _isOnline;
      if (mounted) {
        setState(() {
          _isOnline = (connectivityResult != ConnectivityResult.none);
        });
      }
      
      if (_isOnline && !wasOnline) {
        debugPrint('🌐 Network restored to ${connectivityResult.name}. Waiting for stabilization...');
        // Wait 2 seconds for DNS/Socket to stabilize, reducing resolution errors
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            debugPrint('🚀 Stabilization complete. Triggering background sync...');
            // 1. Process all pending records in Firestore that were saved while offline
            HealthOCRService.processPendingReadings();
            
            // 2. Also trigger extraction for whatever is currently on screen
            _autoTriggerExtraction();
          }
        });
      }
    });
  }

  Future<void> _autoTriggerExtraction() async {
    // If we are already loading, skip
    if (_isLoading) return;
    
    // Check connectivity directly to avoid stale state
    final dynamic connectivity = await Connectivity().checkConnectivity();
    final bool currentlyOnline = (connectivity is List) 
        ? connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none
        : connectivity != ConnectivityResult.none;

    if (!currentlyOnline) return;

    final List<int> bpIndicesToExtract = [];
    for (int i = 0; i < 3; i++) {
      if (_bpImages[i] != null && _sysControllers[i].text.isEmpty) {
        bpIndicesToExtract.add(i);
      }
    }
    
    if (bpIndicesToExtract.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Network restored! Extraction background process started...';
    });

    try {
      // Process BP images
      for (int index in bpIndicesToExtract) {
        await _performOCR(_bpImages[index]!, ReadingType.bp, index: index);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
      }
    }
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return buildSectionCard(
      context: context,
      title: title,
      children: children,
      icon: icon,
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    for (var c in _sysControllers) c.dispose();
    for (var c in _diaControllers) c.dispose();
    for (var c in _pulseControllers) c.dispose();
    _registrationNumber.dispose();
    _age.dispose();
    _othersMention.dispose();
    _d1.dispose();
    _d2.dispose();
    _d3.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Widget _buildRecentReadingsHeader() {
    return const Row(
      children: [
        Icon(Icons.history, color: Colors.blue),
        SizedBox(width: 8),
        Text(
          'Recent Readings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRecentReadingsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('health_readings')
          .orderBy('clientUpdatedAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('No readings saved yet.', style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final type = data['type'] ?? '';
            final timestamp = data['timestamp'] ?? '';
            final isPending = data['needs_gemini_extraction'] == true;
            
            String title = '';
            String value = '';
            IconData icon = Icons.help_outline;
            Color color = Colors.grey;

            if (type == 'bp') {
              title = 'Blood Pressure';
              icon = Icons.monitor_heart;
              color = Colors.redAccent;
              if (isPending) {
                value = 'Processing...';
              } else {
                value = '${data['systolic'] ?? '--'}/${data['diastolic'] ?? '--'} (Pulse: ${data['pulse'] ?? '--'})';
              }
            } else {
              title = 'Sugar Reading';
              icon = Icons.water_drop;
              color = Colors.orange;
              if (isPending) {
                value = 'Processing...';
              } else {
                value = '${data['value'] ?? '--'} mg/dL';
              }
            }

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(timestamp, style: const TextStyle(fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isPending ? Colors.blue : Colors.black87,
                    ),
                  ),
                  if (isPending) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                  if (!isPending && data['extracted_at'] != null) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.auto_awesome, size: 14, color: Colors.blue),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Request camera permission
  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      _showSnackBar('Camera permission permanently denied. Please enable in settings.');
      openAppSettings();
      return false;
    } else {
      _showSnackBar('Camera permission denied.');
      return false;
    }
  }

  /// Open camera and capture image
  Future<void> _captureImage(ReadingType type, {int index = 0}) async {
    // Request permission first
    final hasPermission = await _requestCameraPermission();
    if (!hasPermission) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Opening camera...';
    });

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95, // High quality for better OCR
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Image capture cancelled.';
        });
        return;
      }

      final File imageFile = File(pickedFile.path);
      
      // Store in appropriate image slot
      setState(() {
        if (type == ReadingType.bp) {
          _bpImages[index] = imageFile;
        }
        _statusMessage = 'Processing image with OCR...';
      });

      // Process image (Bakes orientation, downscales, runs OCR)
      if (_isOnline) {
        await _performOCR(imageFile, type, index: index);
      } else {
        _statusMessage = 'Offline: Image saved. Reading will be extracted when online.';
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_isOnline) _statusMessage = '';
        });
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error capturing image: $e';
      });
      _showSnackBar('Error capturing image. Please try again.');
    }
  }

  /// Find bounding box for a label (SYS, DIA, PULSE, etc.)
  Rect? _findLabelBoundingBox(RecognizedText recognizedText, String label) {
    final labelUpper = label.toUpperCase();
    
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final lineText = line.text.toUpperCase();
        if (lineText.contains(labelUpper)) {
          debugPrint('Found label "$label" at: ${line.boundingBox}');
          return line.boundingBox;
        }
      }
    }
    
    debugPrint('Label "$label" not found');
    return null;
  }

  /// Crop a horizontal strip of the image containing a label
  Future<File?> _cropHorizontalStrip(File imageFile, Rect labelBox, String labelName) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) return null;
      
      image = img.bakeOrientation(image);
      
      final imgWidth = image.width;
      final imgHeight = image.height;
      
      final stripHeight = (labelBox.height * 7.0).toInt().clamp(20, imgHeight ~/ 2);
      final stripY = (labelBox.center.dy - stripHeight * 0.4).toInt().clamp(0, imgHeight - stripHeight);
      
      final strip = img.copyCrop(image,
        x: 0,
        y: stripY,
        width: imgWidth,
        height: stripHeight,
      );
      
      final tempDir = await getTemporaryDirectory();
      final stripFile = File('${tempDir.path}/strip_${labelName}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await stripFile.writeAsBytes(img.encodeJpg(strip, quality: 95));
      
      return stripFile;
    } catch (e) {
      debugPrint('❌ Error horizontal strip cropping: $e');
      return null;
    }
  }

  /// Preprocess image for ML Kit
  Future<File> _preprocessForMLKit(File cropFile) async {
    try {
      final bytes = await cropFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return cropFile;

      image = img.copyResize(image, 
        width: (image.width * 3).toInt(), 
        height: (image.height * 3).toInt(),
        interpolation: img.Interpolation.linear
      );

      image = img.adjustColor(image, contrast: 1.2);

      final tempDir = await getTemporaryDirectory();
      final processedFile = File('${tempDir.path}/ml_input_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await processedFile.writeAsBytes(img.encodeJpg(image, quality: 95));
      return processedFile;
    } catch (_) {
      return cropFile;
    }
  }

  /// Original preprocessor (for manual sampling fallback)
  Future<File> _preprocessDigitRegion(File cropFile, {double thresholdOffset = 0.0, bool invert = false}) async {
    try {
      final bytes = await cropFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return cropFile;
      
      image = img.grayscale(image);
      image = img.copyResize(image, 
        width: (image.width * 3.0).toInt(), 
        height: (image.height * 3.0).toInt(),
        interpolation: img.Interpolation.linear
      );
      
      double totalLuminance = 0;
      for (final p in image) totalLuminance += img.getLuminance(p);
      final double meanLuminance = totalLuminance / (image.width * image.height);
      final double targetThreshold = (meanLuminance + thresholdOffset).clamp(30.0, 220.0);
      
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final lum = img.getLuminance(pixel);
          bool isDigit = invert ? (lum > targetThreshold + 20) : (lum < targetThreshold - 15);
          image.setPixel(x, y, isDigit ? img.ColorRgb8(0, 0, 0) : img.ColorRgb8(255, 255, 255));
        }
      }
      
      final tempDir = await getTemporaryDirectory();
      final processedFile = File('${tempDir.path}/manual_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await processedFile.writeAsBytes(img.encodeJpg(image, quality: 95));
      return processedFile;
    } catch (e) {
      return cropFile;
    }
  }

  /// Extract digits from preprocessed region
  Future<String> _extractDigitsFromRegion(File regionFile) async {
    try {
      final mlInputFile = await _preprocessForMLKit(regionFile);
      final InputImage inputImage = InputImage.fromFile(mlInputFile);
      final RecognizedText result = await _textRecognizer.processImage(inputImage);
      
      String mlText = result.text.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (mlText.length >= 2 && mlText.length <= 4) {
        return mlText;
      }
      
      final processedFile = await _preprocessDigitRegion(regionFile, thresholdOffset: 0.0);
      final bytes = await processedFile.readAsBytes();
      img.Image? binaryImage = img.decodeImage(bytes);
      if (binaryImage == null) return '';

      final dilated = img.Image.from(binaryImage);
      for (int y = 1; y < binaryImage.height - 1; y++) {
        for (int x = 1; x < binaryImage.width - 1; x++) {
          if (img.getLuminance(binaryImage.getPixel(x, y)) < 128) {
            for (int dy = -1; dy <= 1; dy++) {
              for (int dx = -1; dx <= 1; dx++) {
                dilated.setPixel(x + dx, y + dy, img.ColorRgb8(0, 0, 0));
              }
            }
          }
        }
      }
      final image = dilated;

      List<int> darkCols = [];
      for (int x = 0; x < image.width; x++) {
        bool hasDark = false;
        for (int y = 0; y < image.height; y++) {
          if (img.getLuminance(image.getPixel(x, y)) < 128) {
            hasDark = true;
            break;
          }
        }
        if (hasDark) darkCols.add(x);
      }

      if (darkCols.isEmpty) return '';

      List<List<int>> digitIslands = [];
      if (darkCols.isNotEmpty) {
        List<int> currentIsland = [darkCols[0]];
        const int maxGap = 8;
        
        for (int i = 1; i < darkCols.length; i++) {
          if (darkCols[i] <= darkCols[i - 1] + maxGap) {
            currentIsland.add(darkCols[i]);
          } else {
            if (currentIsland.last - currentIsland.first > 10) {
              digitIslands.add(currentIsland);
            }
            currentIsland = [darkCols[i]];
          }
        }
        if (currentIsland.last - currentIsland.first > 10) {
          digitIslands.add(currentIsland);
        }
      }

      String finalBuffer = '';
      for (var island in digitIslands) {
        final xStart = island.first;
        final xEnd = island.last;
        final width = xEnd - xStart;

        if (xStart < image.width * 0.35) continue;

        final rawDigit = img.copyCrop(image, x: xStart, y: 0, width: width, height: image.height);
        final digit = _read7SegmentDigit(rawDigit);
        
        if (digit.isNotEmpty) {
          finalBuffer += digit;
        }
      }

      try { await processedFile.delete(); } catch (_) {}
      
      if (finalBuffer.length < 2) return '';
      return finalBuffer;

    } catch (e) {
      return '';
    }
  }

  String _read7SegmentDigit(img.Image digit) {
    int t = 0, b = digit.height - 1, l = 0, r = digit.width - 1;
    bool found = false;
    for (int y = 0; y < digit.height && !found; y++) {
      for (int x = 0; x < digit.width; x++) {
        if (img.getLuminance(digit.getPixel(x, y)) < 128) { t = y; found = true; break; }
      }
    }
    found = false;
    for (int y = digit.height - 1; y >= 0 && !found; y--) {
      for (int x = 0; x < digit.width; x++) {
        if (img.getLuminance(digit.getPixel(x, y)) < 128) { b = y; found = true; break; }
      }
    }
    found = false;
    for (int x = 0; x < digit.width && !found; x++) {
      for (int y = 0; y < digit.height; y++) {
        if (img.getLuminance(digit.getPixel(x, y)) < 128) { l = x; found = true; break; }
      }
    }
    found = false;
    for (int x = digit.width - 1; x >= 0 && !found; x--) {
      for (int y = 0; y < digit.height; y++) {
        if (img.getLuminance(digit.getPixel(x, y)) < 128) { r = x; found = true; break; }
      }
    }

    final h = b - t + 1;
    final w = r - l + 1;

    if (h < 15 || w < 2) return '';
    if (w > h * 1.5) return ''; 

    bool isDark(double pxPct, double pyPct) {
      final centerX = l + (w * pxPct).toInt();
      final centerY = t + (h * pyPct).toInt();
      int darkPoints = 0;
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          final px = centerX + dx;
          final py = centerY + dy;
          if (px >= 0 && px < digit.width && py >= 0 && py < digit.height) {
            if (img.getLuminance(digit.getPixel(px, py)) < 128) darkPoints++;
          }
        }
      }
      return darkPoints >= 3;
    }

    final sA = isDark(0.5, 0.1);
    final sB = isDark(0.9, 0.25);
    final sC = isDark(0.9, 0.75);
    final sD = isDark(0.5, 0.9);
    final sE = isDark(0.1, 0.75);
    final sF = isDark(0.1, 0.25);
    final sG = isDark(0.5, 0.5);

    final pattern = [sA, sB, sC, sD, sE, sF, sG].map((b) => b ? "1" : "0").join();

    const map = {
      "1111110": "0", "0110000": "1", "1101101": "2", "1111001": "3", "0110011": "4",
      "1011011": "5", "1011111": "6", "1110000": "7", "1111111": "8", "1111011": "9",
      "1110010": "7", "1111010": "3", "1011110": "6", "0011000": "1", 
      "0110001": "1", "0011111": "6",
    };

    if (map.containsKey(pattern)) return map[pattern]!;
    if (w < h * 0.4 && (sB || sC)) return "1";

    return ''; 
  }

  /// Extract values using Gemini AI Pro Vision
  Future<bool> _extractWithGemini(File imageFile, ReadingType type, {int index = 0}) async {
    if (!_isOnline) return false;
    if (_geminiApiKey.isEmpty) return false;

    try {
      final model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: _geminiApiKey);
      final imageBytes = await imageFile.readAsBytes();
      
      final String prompt = type == ReadingType.bp 
        ? "Extract the Systolic (SYS), Diastolic (DIA), and Pulse (PULSE/PUL) values from this blood pressure monitor image. Return ONLY a JSON object: {\"sys\": number, \"dia\": number, \"pulse\": number}. Use null if not found or unreadable."
        : "Extract values from this image. Return ONLY JSON.";

      final content = [Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)])];
      final response = await model.generateContent(content);
      final text = response.text;

      if (text != null && text.contains('{')) {
        final jsonStart = text.indexOf('{');
        final jsonEnd = text.lastIndexOf('}') + 1;
        final data = jsonDecode(text.substring(jsonStart, jsonEnd));

        if (type == ReadingType.bp) {
          if (data['sys'] != null) _sysControllers[index].text = data['sys'].toString();
          if (data['dia'] != null) _diaControllers[index].text = data['dia'].toString();
          if (data['pulse'] != null) _pulseControllers[index].text = data['pulse'].toString();
          return _sysControllers[index].text.isNotEmpty || _diaControllers[index].text.isNotEmpty;
        }
      }
    } catch (e) {
      debugPrint('❌ Gemini AI Error: $e');
    }
    return false;
  }

  Future<void> _performOCR(File imageFile, ReadingType type, {int index = 0}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final optimizedFile = File('${tempDir.path}/opt_${DateTime.now().microsecondsSinceEpoch}.jpg');
      
      final bytes = await imageFile.readAsBytes();
      final optimizedBytes = await compute(_optimizeImageForOCR, bytes);

      if (optimizedBytes == null) return;
      await optimizedFile.writeAsBytes(optimizedBytes);

      if (_geminiApiKey.isNotEmpty && _isOnline) {
        final success = await _extractWithGemini(optimizedFile, type, index: index);
        if (success) {
          if (optimizedFile.existsSync()) await optimizedFile.delete();
          return;
        }
      }

      final InputImage inputImage = InputImage.fromFile(optimizedFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      if (type == ReadingType.bp) {
        final sysBox = _findLabelBoundingBox(recognizedText, 'SYS');
        final diaBox = _findLabelBoundingBox(recognizedText, 'DIA');
        final pulseBox = _findLabelBoundingBox(recognizedText, 'PULSE') ?? _findLabelBoundingBox(recognizedText, 'PUL');
        
        if (sysBox != null) {
          final strip = await _cropHorizontalStrip(optimizedFile, sysBox, 'SYS');
          if (strip != null) {
            _sysControllers[index].text = await _extractDigitsFromRegion(strip);
            await strip.delete();
          }
        }
        if (diaBox != null) {
          final strip = await _cropHorizontalStrip(optimizedFile, diaBox, 'DIA');
          if (strip != null) {
            _diaControllers[index].text = await _extractDigitsFromRegion(strip);
            await strip.delete();
          }
        }
        if (pulseBox != null) {
          final strip = await _cropHorizontalStrip(optimizedFile, pulseBox, 'PULSE');
          if (strip != null) {
            _pulseControllers[index].text = await _extractDigitsFromRegion(strip);
            await strip.delete();
          }
        }
      }
      
      if (optimizedFile.existsSync()) await optimizedFile.delete();
    } catch (e) {
      debugPrint('❌ OCR Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  static Uint8List? _optimizeImageForOCR(Uint8List bytes) {
    try {
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;
      image = img.bakeOrientation(image);
      if (image.width > 1024 || image.height > 1024) {
        image = img.copyResize(image, width: image.width > image.height ? 1024 : null, height: image.height >= image.width ? 1024 : null);
      }
      return Uint8List.fromList(img.encodeJpg(image, quality: 85));
    } catch (e) {
      return null;
    }
  }

  Future<String?> _saveImageInternally(File imageFile, String prefix) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory imagesDir = Directory('${appDir.path}/readings_images');
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
      
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String filePath = '${imagesDir.path}/${prefix}_$timestamp.jpg';
      await imageFile.copy(filePath);
      return filePath;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _uploadImageToFirebase(String localPath, String folder, String filename) async {
    try {
      final File file = File(localPath);
      if (!file.existsSync()) return null;
      final storageRef = FirebaseStorage.instance.ref().child('$folder/$filename');
      final snapshot = await storageRef.putFile(file).whenComplete(() => {});
      return snapshot.ref.fullPath;
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveReadings() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving...';
    });

    try {
      final DateTime now = DateTime.now();
      modifiedDate = now;

      List<String?> bpImagePaths = [
        widget.existingData?['bp_image_path'],
        widget.existingData?['bp_image_path2'],
        widget.existingData?['bp_image_path3'],
      ];

      for (int i = 0; i < 3; i++) {
        if (_bpImages[i] != null) {
          if (_bpImages[i]!.path != bpImagePaths[i]) {
            bpImagePaths[i] = await _saveImageInternally(_bpImages[i]!, 'bp${i + 1}');
          }
        } else {
          bpImagePaths[i] = null;
        }
      }

      List<String?> bpStoragePaths = [_bpStoragePaths[0], _bpStoragePaths[1], _bpStoragePaths[2]];
      final String recordId = widget.docId ?? FirebaseFirestore.instance.collection('health_readings').doc().id;

      if (_isOnline) {
        for (int i = 0; i < 3; i++) {
          if (_bpImages[i] != null && _bpImages[i]!.path != widget.existingData?['bp_image_path${i == 0 ? '' : (i + 1).toString()}']) {
            final String filename = 'bp${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';
            bpStoragePaths[i] = await _uploadImageToFirebase(bpImagePaths[i]!, 'health_readings/$recordId', filename);
          }
        }
      }

      final healthData = {
        'Registration_Number': _registrationNumber.text,
        'Family_code': selectedFamilyCode,
        'Name': selectedName,
        'Gender': selectedGender,
        'Age': int.tryParse(_age.text),
        'Date_of_Interview': dateOfInterview != null ? Timestamp.fromDate(dateOfInterview!) : null,
        'Interviewer_s_Name': interviewersName,
        'If_not_done_reason': ifNotDoneReason,
        'If_Others_Please_Mention': _othersMention.text,

        'Blood_Pressure_1': '${_sysControllers[0].text}/${_diaControllers[0].text}',
        'Heart_Beat1': _pulseControllers[0].text,
        'Blood_Pressure_2': '${_sysControllers[1].text}/${_diaControllers[1].text}',
        'Heart_Beat_2': _pulseControllers[1].text,
        'Blood_Pressure_3': '${_sysControllers[2].text}/${_diaControllers[2].text}',
        'Heart_Beat_3': _pulseControllers[2].text,

        '/d1': _d1.text, 'Single_Line4': _d1.text,
        'Date1': date1 != null ? Timestamp.fromDate(date1!) : null,
        '/d2': _d2.text, 'Single_Line3': _d2.text,
        'Date2': date2 != null ? Timestamp.fromDate(date2!) : null,
        '/d3': _d3.text, 'Single_Line1': _d3.text,
        'Date3': date3 != null ? Timestamp.fromDate(date3!) : null,

        'Entry_Date': entryDate != null ? Timestamp.fromDate(entryDate!) : null,
        'Modified_Date': modifiedDate != null ? Timestamp.fromDate(modifiedDate!) : null,
        
        'systolic': int.tryParse(_sysControllers[0].text),
        'diastolic': int.tryParse(_diaControllers[0].text),
        'pulse': int.tryParse(_pulseControllers[0].text),
        'bp_image_path': bpImagePaths[0],
        'bp_storage_path': bpStoragePaths[0],
        
        'systolic2': int.tryParse(_sysControllers[1].text),
        'diastolic2': int.tryParse(_diaControllers[1].text),
        'pulse2': int.tryParse(_pulseControllers[1].text),
        'bp_image_path2': bpImagePaths[1],
        'bp_storage_path2': bpStoragePaths[1],

        'systolic3': int.tryParse(_sysControllers[2].text),
        'diastolic3': int.tryParse(_diaControllers[2].text),
        'pulse3': int.tryParse(_pulseControllers[2].text),
        'bp_image_path3': bpImagePaths[2],
        'bp_storage_path3': bpStoragePaths[2],

        'clientUpdatedAt': now.millisecondsSinceEpoch,
        'needs_zoho_sync': true,
        'zoho_form_code': 3000,
        'needs_gemini_extraction': _bpImages.any((img) => img != null && _sysControllers[_bpImages.indexOf(img)].text.isEmpty),
      };

      if (_isEditMode && _editDocId != null) {
        await FirebaseFirestore.instance.collection('health_readings').doc(_editDocId).update(healthData);
        _showSnackBar('BP Form updated successfully!', isSuccess: true);
        if (widget.existingData != null) {
          Navigator.pop(context);
        } else {
          _clearForm();
        }
      } else if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('health_readings').doc(widget.docId).update(healthData);
        _showSnackBar('BP Form updated successfully!', isSuccess: true);
        Navigator.pop(context);
      } else {
        await FirebaseFirestore.instance.collection('health_readings').doc(recordId).set(healthData);
        _showSnackBar('BP Form saved successfully!', isSuccess: true);
        _clearForm();
      }
      
      HealthOCRService.processPendingReadings();
    } catch (e) {
      _showSnackBar('Error saving: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    setState(() {
      for (var c in _sysControllers) c.clear();
      for (var c in _diaControllers) c.clear();
      for (var c in _pulseControllers) c.clear();
      _registrationNumber.clear();
      _age.clear();
      _othersMention.clear();
      _d1.clear(); _d2.clear(); _d3.clear();
      selectedFamilyCode = null;
      selectedName = null;
      selectedGender = null;
      dateOfInterview = DateTime.now();
      interviewersName = null;
      ifNotDoneReason = null;
      date1 = null; date2 = null; date3 = null;
      _bpImages = [null, null, null];
      _bpStoragePaths = [null, null, null];
      _statusMessage = '';
    });
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, String? hint, String? helper, Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            hintText: hint,
            helperText: helper,
          ),
          keyboardType: keyboardType,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? selectedValue, Function(String?) onChanged, {bool isLoading = false, String? hint = '-Select-'}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: selectedValue,
          isExpanded: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: isLoading ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
          ),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
          hint: hint != null ? Text(hint) : null,
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (picked != null) onPicked(picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(selectedDate == null ? 'Select Date' : DateFormat('dd-MMM-yyyy').format(selectedDate)),
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isSuccess ? Colors.green : Colors.red));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('BP & Glucose Form'), // Modified title
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700, Colors.pink.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _showSettingsDialog),
          IconButton(icon: const Icon(Icons.clear_all), onPressed: _clearForm),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  buildHeader(
                    context: context,
                    title: 'Health Readings',
                    subtitle: 'Monitor and track vital signs',
                  ),

                  if (_statusMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_statusMessage, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                  _buildIdentitySection(),
                  _buildReasonSection(),
                  _buildBPSection(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildRecentReadingsHeader(),
                  const SizedBox(height: 16),
                  _buildRecentReadingsList(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  void _showSettingsDialog() {
    final keyController = TextEditingController(text: _geminiApiKey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: TextField(controller: keyController, decoration: const InputDecoration(labelText: 'Gemini API Key')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () { setState(() => _geminiApiKey = keyController.text); Navigator.pop(context); }, child: const Text('Save')),
        ],
      ),
    );
  }

  Widget _buildIdentitySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField('Registration Number', _registrationNumber),
            const SizedBox(height: 12),
            _buildTextField('Family Code', _familyCodeController, onChanged: (v) {
              setState(() {
                selectedFamilyCode = v;
                selectedName = null;
                familyMembers = [];
              });
              if (v != null && v.isNotEmpty) {
                 if (_isEditMode) {
                   _fetchExistingRecords(v);
                 } else {
                   _fetchMembersByFamily(v);
                 }
              }
            }),
            const SizedBox(height: 12),
            if (_isEditMode)
              _buildDropdown('Select Name to Edit', _existingRecords.map((r) => r['Name']?.toString() ?? 'Unknown').toList(), selectedName, _onNameSelected, isLoading: _isLoadingMembers)
            else
              _buildDropdown('Name', familyMembers, selectedName, _onNameSelected, isLoading: _isLoadingMembers),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: RadioListTile<String>(title: const Text('Male'), value: '(1) Male', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), dense: true)),
                Expanded(child: RadioListTile<String>(title: const Text('Female'), value: '(0) Female', groupValue: selectedGender, onChanged: (v) => setState(() => selectedGender = v), dense: true)),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField('Age', _age, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _buildDatePicker('Date of Interview', dateOfInterview, (v) => setState(() => dateOfInterview = v)),
            const SizedBox(height: 12),
            _buildDropdown(
              'Interviewer’s Name',
              ['KIRANMAI K', 'REVATHI CH', 'RAMADEVI Y', 'LAVANYA KASPOJU', 'PUSHPA K', 'G RAMADEVI', 'BHASKAR K', 'ASHA', 'KUSUMA G', 'B JYOTHI', 'RAMADEVI G', 'LAVANYA METU', 'N POOJA', 'POOJA N', 'K BHASKAR', 'LAVANYA M', 'LAVANYA METTU'],
              interviewersName,
              (v) => setState(() => interviewersName = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Screening Status', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile<String>(title: const Text('Not available'), value: '(1) Not available', groupValue: ifNotDoneReason, onChanged: (v) => setState(() => ifNotDoneReason = v), dense: true),
            RadioListTile<String>(title: const Text('Refused'), value: '(2) Refused for current visit', groupValue: ifNotDoneReason, onChanged: (v) => setState(() => ifNotDoneReason = v), dense: true),
            RadioListTile<String>(title: const Text('Door Locked'), value: '(3) Door Locked', groupValue: ifNotDoneReason, onChanged: (v) => setState(() => ifNotDoneReason = v), dense: true),
            RadioListTile<String>(title: const Text('Other'), value: '(4) Other', groupValue: ifNotDoneReason, onChanged: (v) => setState(() => ifNotDoneReason = v), dense: true),
            if (ifNotDoneReason == '(4) Other') _buildTextField('Specify', _othersMention),
          ],
        ),
      ),
    );
  }

  Widget _buildBPSection() {
    return Column(children: List.generate(3, (i) => _buildBPSlot(i)));
  }

  Widget _buildBPSlot(int i) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('BP${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(child: _buildTextField('Sys', _sysControllers[i], keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _buildTextField('Dia', _diaControllers[i], keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _buildTextField('Pulse', _pulseControllers[i], keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildTextField('/d${i + 1}', (i == 0 ? _d1 : (i == 1 ? _d2 : _d3)))),
                const SizedBox(width: 8),
                Expanded(child: _buildDatePicker('Date', (i == 0 ? date1 : (i == 1 ? date2 : date3)), (v) => setState(() {
                  if (i == 0) date1 = v; else if (i == 1) date2 = v; else date3 = v;
                }))),
              ],
            ),
            const SizedBox(height: 12),
            if (_bpImages[i] != null) Image.file(_bpImages[i]!, height: 100),
            ElevatedButton(onPressed: () => _captureImage(ReadingType.bp, index: i), child: const Text('Capture Image')),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(onPressed: _saveReadings, child: Text(_isEditMode ? 'Update BP Readings' : 'Save BP Readings'));
  }
}