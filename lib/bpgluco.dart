import 'dart:convert';
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
import 'app_drawer.dart';
import 'health_ocr_service.dart';

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
  // Text editing controllers for form fields
  final TextEditingController _sysController = TextEditingController();
  final TextEditingController _diaController = TextEditingController();
  final TextEditingController _pulseController = TextEditingController();
  final TextEditingController _sugarController = TextEditingController();

  // SEPARATE images for BP and Sugar
  File? _bpImage;
  File? _sugarImage;
  
  bool _isLoading = false;
  bool _isOnline = false; // CACHED connectivity state for zero-lag
  String _statusMessage = '';
  String _ocrRawText = ''; // For debugging
  StreamSubscription? _connectivitySubscription;
  
  // Storage location info
  String? _storageDirectory;

  // Image picker and text recognizer instances
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  // Gemini API Key (User should provide this)
  String _geminiApiKey = 'AIzaSyA7DhZc6K8uPdjsh3toKYTwdzvS_-hv_R0'; 

  @override
  void initState() {
    super.initState();
    _initStorageDirectory();
    _setupConnectivityListener();
    // Trigger background sync for any previous offline records immediately on launch
    HealthOCRService.processPendingReadings();
    if (widget.existingData != null) {
      _sysController.text = (widget.existingData!['systolic'] ?? '').toString();
      _diaController.text = (widget.existingData!['diastolic'] ?? '').toString();
      _pulseController.text = (widget.existingData!['pulse'] ?? '').toString();
      _sugarController.text = (widget.existingData!['sugar_value'] ?? '').toString();

      // Load existing images if paths are provided and files exist
      if (widget.existingData!['bp_image_path'] != null) {
        final file = File(widget.existingData!['bp_image_path']);
        if (file.existsSync()) {
          _bpImage = file;
        }
      }
      if (widget.existingData!['sugar_image_path'] != null) {
        final file = File(widget.existingData!['sugar_image_path']);
        if (file.existsSync()) {
          _sugarImage = file;
        }
      }
    }
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
    // If we have a BP image but no BP text data, run extraction
    if (_bpImage != null && _sysController.text.isEmpty && !_isLoading) {
      _extractWithGemini(_bpImage!, ReadingType.bp);
    }
    // If we have a Sugar image but no Sugar data, run extraction
    if (_sugarImage != null && _sugarController.text.isEmpty && !_isLoading) {
      _extractWithGemini(_sugarImage!, ReadingType.sugar);
    }
  }

  Future<void> _initStorageDirectory() async {
    setState(() {
      _storageDirectory = '/storage/emulated/0/Download';
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _sysController.dispose();
    _diaController.dispose();
    _pulseController.dispose();
    _sugarController.dispose();
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
  Future<void> _captureImage(ReadingType type) async {
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
          _bpImage = imageFile;
        } else {
          _sugarImage = imageFile;
        }
        _statusMessage = 'Processing image with OCR...';
      });

      // Perform OCR as a non-blocking background task
      _performOCR(imageFile, type);
      
      // Stop the instant spinner because OCR is now backgrounded
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });

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
  /// This captures the digits regardless of their horizontal position (LEFT or RIGHT)
  Future<File?> _cropHorizontalStrip(File imageFile, Rect labelBox, String labelName) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) {
        debugPrint('❌ Failed to decode image for strip cropping');
        return null;
      }
      
      // Ensure proper orientation
      image = img.bakeOrientation(image);
      
      final imgWidth = image.width;
      final imgHeight = image.height;
      
      // Calculate strip bounds
      // Full width (0 to imgWidth)
      // Vertical: centered on the label with generous padding
      final stripHeight = (labelBox.height * 7.0).toInt().clamp(20, imgHeight ~/ 2);
      // Offset Y so the label center is at 40% of the strip height, leaving 60% below (more "bottom")
      final stripY = (labelBox.center.dy - stripHeight * 0.4).toInt().clamp(0, imgHeight - stripHeight);
      
      debugPrint('✂️ Strip Cropping [$labelName]: y=$stripY, height=$stripHeight, width=$imgWidth');
      
      // Crop full width strip
      final strip = img.copyCrop(image,
        x: 0,
        y: stripY,
        width: imgWidth,
        height: stripHeight,
      );
      
      // Save debug strip to Download
      try {
        const String downloadPath = '/storage/emulated/0/Download';
        final String debugFilename = 'DEBUG_strip_${labelName}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final File debugFile = File('$downloadPath/$debugFilename');
        await debugFile.writeAsBytes(img.encodeJpg(strip, quality: 95));
        debugPrint('🔍 DEBUG: Horizontal strip saved: $debugFilename');
      } catch (e) {
        debugPrint('Could not save debug strip: $e');
      }
      
      final tempDir = await getTemporaryDirectory();
      final stripFile = File('${tempDir.path}/strip_${labelName}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await stripFile.writeAsBytes(img.encodeJpg(strip, quality: 95));
      
      return stripFile;
    } catch (e) {
      debugPrint('❌ Error horizontal strip cropping: $e');
      return null;
    }
  }

  /// Aggressive preprocessing for LCD digit region
  /// Optimized for 7-segment displays to join broken segments
  /// Now uses MEAN luminance to determine the best threshold dynamically
  /// Preprocess image for ML Kit (Upscale + Contrast only)
  /// NO grayscale/thresholding to avoid merging shadows
  Future<File> _preprocessForMLKit(File cropFile) async {
    try {
      final bytes = await cropFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return cropFile;

      // 1. Upscale for better recognition
      image = img.copyResize(image, 
        width: (image.width * 3).toInt(), 
        height: (image.height * 3).toInt(),
        interpolation: img.Interpolation.linear
      );

      // 2. Simple Contrast Boost (Contrast 20%)
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
      
      // 1. Grayscale
      image = img.grayscale(image);
      
      // 2. Upscale
      image = img.copyResize(image, 
        width: (image.width * 3.0).toInt(), 
        height: (image.height * 3.0).toInt(),
        interpolation: img.Interpolation.linear
      );
      
      // 3. Adaptive Thresholding
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

  /// Extract digits from preprocessed region using Tesseract
  /// DIGIT-ONLY configuration (whitelist: 0-9)
  /// Multi-Pass Brute Force OCR extraction
  /// Tries 6 different preprocessing combinations for maximum robustness
  /// Extract digits from strip using custom 7-segment pattern sampling
  /// 100% Offline, No ML/Tesseract
  Future<String> _extractDigitsFromRegion(File regionFile) async {
    try {
      // --- PASS 1: Direct ML Kit Extraction (User Request) ---
      final mlInputFile = await _preprocessForMLKit(regionFile);
      final InputImage inputImage = InputImage.fromFile(mlInputFile);
      final RecognizedText result = await _textRecognizer.processImage(inputImage);
      
      String mlText = result.text.replaceAll(RegExp(r'[^0-9]'), '');
      
      // If we got 2-3 digits, trust it!
      if (mlText.length >= 2 && mlText.length <= 4) {
        debugPrint('🎯 ML Kit Direct Success: "$mlText"');
        return mlText;
      }
      
      debugPrint('⚠️ ML Kit Direct failed or returned junk: "${result.text}". Falling back to custom sampler...');

      // --- PASS 2: Custom 7-Segment Sampler (Fallback) ---
      final processedFile = await _preprocessDigitRegion(regionFile, thresholdOffset: 0.0);
      final bytes = await processedFile.readAsBytes();
      img.Image? binaryImage = img.decodeImage(bytes);
      if (binaryImage == null) return '';

      // DILATION STEP: Connect broken 7-segment pieces
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

      // DEBUG: Save the dilated binary strip
      try {
        final stripBytes = img.encodeJpg(image);
        await File('/storage/emulated/0/Download/DEBUG_DILATED_STRIP_${DateTime.now().millisecondsSinceEpoch}.jpg')
            .writeAsBytes(stripBytes);
      } catch (_) {}

      // 2. Identify Digit Bounding Boxes
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

      // Group columns into contiguous islands
      List<List<int>> digitIslands = [];
      if (darkCols.isNotEmpty) {
        List<int> currentIsland = [darkCols[0]];
        const int maxGap = 8; // Increased gap tolerance for dilated images
        
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

      debugPrint('🔍 Found ${digitIslands.length} potential digit islands');

      String finalBuffer = '';
      int islandIdx = 0;
      for (var island in digitIslands) {
        final xStart = island.first;
        final xEnd = island.last;
        final width = xEnd - xStart;

        // SPATIAL FILTER: Ignore anything in the leftmost 35% (Likely labels SYS/DIA)
        // BP monitors almost always have the numbers on the far right.
        if (xStart < image.width * 0.35) {
          debugPrint('⏩ Skipping island at $xStart (Left Margin/Label)');
          continue;
        }

        // Crop this digit
        final rawDigit = img.copyCrop(image, x: xStart, y: 0, width: width, height: image.height);
        
        // 3. Sample 7-segment patterns
        final digit = _read7SegmentDigit(rawDigit);
        
        // DEBUG: Save each island with its detected value
        try {
          final label = digit.isEmpty ? "NONE" : digit;
          await File('/storage/emulated/0/Download/DEBUG_ISLAND_${islandIdx++}_VAL_$label.jpg')
              .writeAsBytes(img.encodeJpg(rawDigit));
        } catch (_) {}

        if (digit.isNotEmpty) {
          finalBuffer += digit;
          debugPrint('🎯 Island $islandIdx Mapped: $digit');
        }
      }

      try { await processedFile.delete(); } catch (_) {}
      
      debugPrint('✅ Final Assembled: "$finalBuffer"');
      
      // QUALITY FILTER: If we only found 1 digit, it's very likely a label fragment or noise.
      // BP readings and Sugar are almost always 2 or 3 digits.
      if (finalBuffer.length < 2) {
        debugPrint('⚠️ Ignoring "$finalBuffer" - too short to be a valid reading.');
        return '';
      }
      
      return finalBuffer;

    } catch (e) {
      debugPrint('❌ Custom 7-segment error: $e');
      return '';
    }
  }

  String _read7SegmentDigit(img.Image digit) {
    // 1. Precise Trim (Top/Bottom/Left/Right)
    int t = 0, b = digit.height - 1, l = 0, r = digit.width - 1;
    
    // Find boundaries
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

    // AREA-BASED PROBING (3x3 grid)
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
      return darkPoints >= 3; // Majority of 3x3 window is dark
    }

    // Probe points (A-G)
    final sA = isDark(0.5, 0.1);  // top
    final sB = isDark(0.9, 0.25); // upper right
    final sC = isDark(0.9, 0.75); // lower right
    final sD = isDark(0.5, 0.9);  // bottom
    final sE = isDark(0.1, 0.75); // lower left
    final sF = isDark(0.1, 0.25); // upper left
    final sG = isDark(0.5, 0.5);  // middle

    final pattern = [sA, sB, sC, sD, sE, sF, sG].map((b) => b ? "1" : "0").join();
    debugPrint('🧩 Aspect: ${w}x${h} Pattern: $pattern');

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

  /// Extract values using Gemini AI Pro Vision (High Accuracy)
  Future<bool> _extractWithGemini(File imageFile, ReadingType type) async {
    // Use CACHED connectivity to avoid 500ms+ delay of Connectivity().checkConnectivity()
    if (!_isOnline) {
      debugPrint('📴 Device is offline (cached). Skipping Gemini extraction.');
      return false;
    }

    if (_geminiApiKey.isEmpty) {
      debugPrint('⚠️ Gemini API key is missing. Skipping AI pass.');
      return false;
    }

    try {
      debugPrint('🚀 Sending image to Gemini (${type == ReadingType.bp ? "BP" : "Sugar"})...');
      
      // Use gemini-2.0-flash for speed and reliability
      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: _geminiApiKey,
      );

      final imageBytes = await imageFile.readAsBytes();
      
      final String prompt = type == ReadingType.bp 
        ? "Extract the Systolic (SYS), Diastolic (DIA), and Pulse (PULSE/PUL) values from this blood pressure monitor image. Look closely at the 7-segment display digits. Return ONLY a JSON object: {\"sys\": number, \"dia\": number, \"pulse\": number}. Use null if not found or unreadable."
        : "Extract the Glucose/Sugar value from this glucometer/sugar monitor image. Return ONLY a JSON object: {\"sugar\": number}. Use null if not found or unreadable.";

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await model.generateContent(content);
      final String? text = response.text;
      debugPrint('🤖 Gemini Response: $text');

      if (text != null && text.contains('{')) {
        // Simple JSON extraction from the text block
        final jsonStart = text.indexOf('{');
        final jsonEnd = text.lastIndexOf('}') + 1;
        final jsonStr = text.substring(jsonStart, jsonEnd);
        final data = jsonDecode(jsonStr);

        if (type == ReadingType.bp) {
          if (data['sys'] != null) _sysController.text = data['sys'].toString();
          if (data['dia'] != null) _diaController.text = data['dia'].toString();
          if (data['pulse'] != null) _pulseController.text = data['pulse'].toString();
          return _sysController.text.isNotEmpty || _diaController.text.isNotEmpty;
        } else {
          if (data['sugar'] != null) _sugarController.text = data['sugar'].toString();
          return _sugarController.text.isNotEmpty;
        }
      }
    } catch (e) {
      debugPrint('❌ Gemini AI Error: $e');
      // Only show error if we think we have internet
      if (_isOnline) {
        // Silently fail as per user request to remove popups
        debugPrint('Gemini AI failed: $e');
      }
    }
    return false;
  }

  // Removed Tesseract and old preprocessors per "No OCR, no ML" manual logic approach.

  /// Perform OCR using HORIZONTAL SLICE approach
  /// This takes full-width strips at the vertical position of each label
  Future<void> _performOCR(File imageFile, ReadingType type) async {
    try {
      debugPrint('=== INTELLIGENT OCR WORKFLOW ===');
      
      setState(() {
        // CLEAR PREVIOUS VALUES BEFORE NEW SCAN
        if (type == ReadingType.bp) {
          _sysController.clear();
          _diaController.clear();
          _pulseController.clear();
        } else {
          _sugarController.clear();
        }
      });

      // --- PASS 1: Gemini AI (The "Gold Standard" - Try this first on full image) ---
      if (_geminiApiKey.isNotEmpty) {
        final success = await _extractWithGemini(imageFile, type);
        if (success) {
          setState(() {
            _isLoading = false;
          });
          return; // Success! No need to run ML Kit or strips.
        }
        
        // Only log failure if we actually have internet
        if (_isOnline) {
          debugPrint('⚠️ Gemini extraction failed or incomplete. Falling back to Local Logic...');
        } else {
          debugPrint('ℹ️ Offline: Falling back to Local Logic for instant preview...');
        }
      }
    } catch (e) {

      // --- PASS 2: Local Logic (ML Kit Anchors + Horizontal Strips) ---
      debugPrint('--- Falling back to Horizontal Slice Detection ---');
      
      // STEP 1: ML Kit to find label positions
      final InputImage inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      debugPrint('ML Kit detected text: ${recognizedText.text}');
      setState(() {
        _ocrRawText = recognizedText.text;
      });

      if (type == ReadingType.bp) {
        // STEP 2: Find Vertical Anchors
        final sysBox = _findLabelBoundingBox(recognizedText, 'SYS');
        final diaBox = _findLabelBoundingBox(recognizedText, 'DIA');
        final pulseBox = _findLabelBoundingBox(recognizedText, 'PULSE') ?? 
                         _findLabelBoundingBox(recognizedText, 'PUL');
        
        String sys = '', dia = '', pulse = '';
        
        // Take strips for each
        if (sysBox != null) {
          final strip = await _cropHorizontalStrip(imageFile, sysBox, 'SYS');
          if (strip != null) {
            sys = await _extractDigitsFromRegion(strip);
            await strip.delete();
          }
        }
        
        if (diaBox != null) {
          final strip = await _cropHorizontalStrip(imageFile, diaBox, 'DIA');
          if (strip != null) {
            dia = await _extractDigitsFromRegion(strip);
            await strip.delete();
          }
        }
        
        if (pulseBox != null) {
          final strip = await _cropHorizontalStrip(imageFile, pulseBox, 'PULSE');
          if (strip != null) {
            pulse = await _extractDigitsFromRegion(strip);
            await strip.delete();
          }
        }
        
        if (sys.isNotEmpty) {
          final val = int.tryParse(sys) ?? 0;
          if (val >= 70 && val <= 250) {
            _sysController.text = sys;
            debugPrint('✅ SYS Validated: $sys');
          } else {
            debugPrint('⚠️ SYS Out of Range (70-250): $sys');
          }
        }
        
        if (dia.isNotEmpty) {
          final val = int.tryParse(dia) ?? 0;
          if (val >= 40 && val <= 150) {
            _diaController.text = dia;
            debugPrint('✅ DIA Validated: $dia');
          } else {
            debugPrint('⚠️ DIA Out of Range (40-150): $dia');
          }
        }
        
        if (pulse.isNotEmpty) {
          final val = int.tryParse(pulse) ?? 0;
          if (val >= 30 && val <= 220) {
            _pulseController.text = pulse;
            debugPrint('✅ PULSE Validated: $pulse');
          } else {
            debugPrint('⚠️ PULSE Out of Range (30-220): $pulse');
          }
        }
        
        setState(() {
          _isLoading = false;
        });
      } else {
        // Sugar
        final sugarBox = _findLabelBoundingBox(recognizedText, 'GLUCOSE') ??
                         _findLabelBoundingBox(recognizedText, 'GLU') ??
                         _findLabelBoundingBox(recognizedText, 'mg/dL');
        
        String sugar = '';
        if (sugarBox != null) {
          final strip = await _cropHorizontalStrip(imageFile, sugarBox, 'SUGAR');
          if (strip != null) {
            sugar = await _extractDigitsFromRegion(strip);
            await strip.delete();
          }
        }
        
        if (sugar.isNotEmpty) {
          final val = int.tryParse(sugar) ?? 0;
          if (val >= 20 && val <= 600) {
            _sugarController.text = sugar;
            debugPrint('✅ Sugar Validated: $sugar');
          }
        }
        
        setState(() {
          _isLoading = false;
        });
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'OCR Error: $e';
      });
      _showSnackBar('OCR failed. Please enter manually.');
    }
  }



  /// Add timestamp overlay to image at BOTTOM-LEFT corner with LARGE text
  /// Compresses image to under 500KB using JPEG encoding
  Future<Uint8List?> _addTimestampToImage(File imageFile, String timestamp) async {
    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        debugPrint('Failed to decode image');
        return null;
      }

      // Ensure proper orientation
      originalImage = img.bakeOrientation(originalImage);

      int imgWidth = originalImage.width;
      int imgHeight = originalImage.height;

      // Resize if image is very large (helps with compression)
      const int maxDimension = 1920;
      if (imgWidth > maxDimension || imgHeight > maxDimension) {
        if (imgWidth > imgHeight) {
          originalImage = img.copyResize(originalImage, width: maxDimension);
        } else {
          originalImage = img.copyResize(originalImage, height: maxDimension);
        }
        imgWidth = originalImage.width;
        imgHeight = originalImage.height;
        debugPrint('Resized image to: ${imgWidth}x$imgHeight');
      }

      // Format timestamp with date clearly
      final DateTime now = DateTime.now();
      final String dateStr = DateFormat('dd-MMM-yyyy').format(now);
      final String timeStr = DateFormat('HH:mm:ss').format(now);
      final String fullTimestamp = '$dateStr | $timeStr';

      // Use LARGER padding for better visibility
      final int padding = 20;
      
      // Use the largest available font (arial48)
      // Estimate text width based on font
      final textWidth = fullTimestamp.length * 20; // Approximate width per char for arial48
      final textHeight = 48 + padding;

      // Position at BOTTOM-LEFT
      final xPos = padding;
      final yPos = imgHeight - textHeight - padding;

      // Draw LARGE semi-transparent black background rectangle
      img.fillRect(
        originalImage,
        x1: 0,
        y1: (yPos - padding).clamp(0, imgHeight),
        x2: (textWidth + padding * 3).clamp(0, imgWidth),
        y2: imgHeight,
        color: img.ColorRgba8(0, 0, 0, 220),
      );

      // Draw timestamp text in WHITE with LARGE font (arial48)
      img.drawString(
        originalImage,
        fullTimestamp,
        font: img.arial48, // LARGEST available font
        x: xPos,
        y: yPos.clamp(0, imgHeight - 50),
        color: img.ColorRgb8(255, 255, 255),
      );

      // Encode as JPEG with quality compression
      // Start with quality 85 and reduce if needed to stay under 500KB
      int quality = 85;
      Uint8List compressedBytes = Uint8List.fromList(img.encodeJpg(originalImage, quality: quality));
      
      // Compress until under 500KB (500 * 1024 = 512000 bytes)
      const int targetSize = 500 * 1024;
      while (compressedBytes.length > targetSize && quality > 30) {
        quality -= 10;
        compressedBytes = Uint8List.fromList(img.encodeJpg(originalImage, quality: quality));
        debugPrint('Compressing: quality=$quality, size=${compressedBytes.length} bytes');
      }

      final sizeKB = (compressedBytes.length / 1024).toStringAsFixed(1);
      debugPrint('✓ Image compressed: ${sizeKB}KB (quality: $quality)');
      debugPrint('Timestamp added: $fullTimestamp');
      return compressedBytes;

    } catch (e) {
      debugPrint('Error adding timestamp to image: $e');
      return null;
    }
  }

  /// Save image to DOWNLOAD folder for easy access
  Future<String?> _saveImageToStorage(Uint8List imageData, String filename) async {
    try {
      debugPrint('Attempting to save image: $filename');
      
      // Request storage permission first
      // On Android 13+, Permission.storage might not be enough for Downloads
      // We also check manageExternalStorage which we added for Android 11+
      
      bool permissionGranted = false;
      
      if (await Permission.manageExternalStorage.isGranted) {
        permissionGranted = true;
      } else {
        final status = await Permission.manageExternalStorage.request();
        permissionGranted = status.isGranted;
      }

      if (!permissionGranted) {
        final status = await Permission.storage.request();
        permissionGranted = status.isGranted;
        debugPrint('Permission status (Storage): $status');
      }

      if (!permissionGranted) {
        debugPrint('❌ Storage permission DENIED');
        // Fall back to app documents directory
        final Directory appDir = await getApplicationDocumentsDirectory();
        final Directory imagesDir = Directory('${appDir.path}/readings_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        final String filePath = '${imagesDir.path}/$filename';
        final File imageFile = File(filePath);
        await imageFile.writeAsBytes(imageData, flush: true);
        debugPrint('✓ Saved to app fallback dir: $filePath');
        return filePath;
      }

      // Save to Download folder
      const String downloadPath = '/storage/emulated/0/Download';
      final Directory downloadDir = Directory(downloadPath);

      // Create directory if it doesn't exist (though Download always exists)
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
        debugPrint('Created Download directory: ${downloadDir.path}');
      }

      final String filePath = '$downloadPath/$filename';
      final File imageFile = File(filePath);
      
      // Write with flush to ensure data is written to disk
      await imageFile.writeAsBytes(imageData, flush: true);

      // VERIFY the file was saved
      if (await imageFile.exists()) {
        final fileSize = await imageFile.length();
        debugPrint('✅ Image SAVED to Download: $filePath ($fileSize bytes)');
        
        // IMPORTANT: We don't trigger media scan here as it's complex in Flutter without packages
        // but the file is definitely there on disk.
        
        return filePath;
      } else {
        debugPrint('❌ Image save FAILED - file does not exist after write');
        return null;
      }

    } catch (e) {
      debugPrint('❌ Error saving image: $e');
      return null;
    }
  }

  /// Fast internal save using File.copy - avoid byte processing for speed
  Future<String?> _saveImageInternally(File imageFile, String prefix) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory imagesDir = Directory('${appDir.path}/readings_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String filename = '${prefix}_$timestamp.jpg';
      final String filePath = '${imagesDir.path}/$filename';
      
      await imageFile.copy(filePath);
      debugPrint('⚡ Fast Save: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('❌ Fast Save Error: $e');
      return null;
    }
  }

  /// Save image to DOWNLOAD folder for easy access
  Future<void> _saveReadings() async {
    final hasBPImage = _bpImage != null;
    final hasSugarImage = _sugarImage != null;
    
    final hasBPData = _sysController.text.isNotEmpty || _diaController.text.isNotEmpty;
    final hasSugarData = _sugarController.text.isNotEmpty;

    if (!hasBPImage && !hasSugarImage && !hasBPData && !hasSugarData) {
      _showSnackBar('Please capture or fill in at least one reading.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving...';
    });

    try {
      final DateTime now = DateTime.now();
      final String timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      String? bpImagePath = widget.existingData?['bp_image_path'];
      String? sugarImagePath = widget.existingData?['sugar_image_path'];

      // 1. Process BP image (Fast internal copy if new)
      if (_bpImage != null) {
        if (_bpImage!.path != bpImagePath) {
          bpImagePath = await _saveImageInternally(_bpImage!, 'bp');
        }
      } else {
        bpImagePath = null;
      }

      // 2. Process Sugar image (Fast internal copy if new)
      if (_sugarImage != null) {
        if (_sugarImage!.path != sugarImagePath) {
          sugarImagePath = await _saveImageInternally(_sugarImage!, 'sugar');
        }
      } else {
        sugarImagePath = null;
      }

      // Create unified record
      final healthData = {
        'timestamp': timestamp,
        'clientUpdatedAt': now.millisecondsSinceEpoch,
        'is_temporary': true,
        
        // BP Fields
        'has_bp': hasBPImage || hasBPData,
        'systolic': int.tryParse(_sysController.text),
        'diastolic': int.tryParse(_diaController.text),
        'pulse': int.tryParse(_pulseController.text),
        'bp_image_path': bpImagePath,
        'bp_needs_extraction': hasBPImage && !hasBPData,
        
        // Sugar Fields
        'has_sugar': hasSugarImage || hasSugarData,
        'sugar_value': _sugarController.text.trim(),
        'sugar_image_path': sugarImagePath,
        'sugar_needs_extraction': hasSugarImage && !hasSugarData,
        
        // Global tracking
        'needs_gemini_extraction': (hasBPImage && !hasBPData) || (hasSugarImage && !hasSugarData),
      };

      // Save or Update Firestore record
      if (widget.docId != null) {
        FirebaseFirestore.instance.collection('health_readings').doc(widget.docId).update(healthData).catchError((e) {
          debugPrint('Update Error: $e');
        });
        _showSnackBar('Readings updated successfully!', isSuccess: true);
        Navigator.pop(context); // Go back after edit
      } else {
        FirebaseFirestore.instance.collection('health_readings').add(healthData).catchError((e) {
          debugPrint('Background Firestore Error: $e');
        });
        _showSnackBar('Readings saved successfully!', isSuccess: true);
        _clearForm();
      }
      
      // Trigger extraction immediately if online
      HealthOCRService.processPendingReadings();

    } catch (e) {
      debugPrint('Save Error: $e');
      _showSnackBar('Error saving: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Clear form fields and reset state
  void _clearForm() {
    setState(() {
      _sysController.clear();
      _diaController.clear();
      _pulseController.clear();
      _sugarController.clear();
      _bpImage = null;
      _sugarImage = null;
      _ocrRawText = '';
      _statusMessage = '';
    });
  }

  /// Show snackbar message
  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Readings'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Gemini Settings',
          ),
          if (_bpImage != null || _sugarImage != null ||
              _sysController.text.isNotEmpty ||
              _sugarController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearForm,
              tooltip: 'Clear All',
            ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Storage Location Info
                if (_storageDirectory != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.folder, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Storage: $_storageDirectory',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // BP Section with its own image
                _buildBPSection(),
                
                const SizedBox(height: 16),
                
                // Divider with AND/OR text
                _buildDivider(),
                
                const SizedBox(height: 16),
                
                // Sugar Section with its own image
                _buildSugarSection(),
                
                const SizedBox(height: 24),
                
                // Save Button
                _buildSaveButton(),
                
                const SizedBox(height: 16),
                
                // Status Message
                if (_statusMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _statusMessage.contains('✓') 
                          ? Colors.green.shade50 
                          : _statusMessage.contains('⚠️')
                              ? Colors.orange.shade50
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _statusMessage.contains('✓')
                            ? Colors.green.shade300
                            : _statusMessage.contains('⚠️')
                                ? Colors.orange.shade300
                                : Colors.grey.shade300,
                      ),
                    ),
                    child: SelectableText(
                      _statusMessage,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: _statusMessage.contains('✓')
                            ? Colors.green.shade700
                            : _statusMessage.contains('⚠️')
                                ? Colors.orange.shade800
                                : Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 100), // Extra space at bottom
              ],
            ),
          ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Processing...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Show dialog to enter Gemini API Key
  void _showSettingsDialog() {
    final TextEditingController keyController = TextEditingController(text: _geminiApiKey);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gemini AI Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Google AI (Gemini) API Key to enable advanced vision extraction.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keyController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'Paste your key here',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Key is stored in memory for this session.',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _geminiApiKey = keyController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Build BP section card with its own image preview
  Widget _buildBPSection() {
    final bool hasBPImage = _bpImage != null;
    
    return Card(
      elevation: hasBPImage ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: hasBPImage 
            ? BorderSide(color: Colors.red.shade300, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.favorite,
                  color: Colors.red.shade400,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Blood Pressure Reading',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (hasBPImage)
                  Icon(Icons.check_circle, color: Colors.green.shade400),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Manual entry hint
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If OCR cannot read LCD display, please enter values manually.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Systolic and Diastolic in a row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Systolic',
                      hintText: 'e.g., 120',
                      suffixText: 'mmHg',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _diaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Diastolic',
                      hintText: 'e.g., 80',
                      suffixText: 'mmHg',
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Pulse field
            TextFormField(
              controller: _pulseController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pulse',
                hintText: 'e.g., 72',
                suffixText: 'BPM',
              ),
            ),
            
            const SizedBox(height: 16),
            
            // BP Image Preview
            if (hasBPImage) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _bpImage!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _bpImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            
            // Capture BP Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _captureImage(ReadingType.bp),
                icon: Icon(hasBPImage ? Icons.refresh : Icons.camera_alt),
                label: Text(hasBPImage ? 'Recapture BP Image' : 'Capture BP Reading'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build divider with AND text (since user can capture both)
  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'AND / OR',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const Expanded(child: Divider(thickness: 1)),
      ],
    );
  }

  /// Build Sugar section card with its own image preview
  Widget _buildSugarSection() {
    final bool hasSugarImage = _sugarImage != null;
    
    return Card(
      elevation: hasSugarImage ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: hasSugarImage 
            ? BorderSide(color: Colors.blue.shade300, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.water_drop,
                  color: Colors.blue.shade400,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sugar Reading',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (hasSugarImage)
                  Icon(Icons.check_circle, color: Colors.green.shade400),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Manual entry hint
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If OCR cannot read LCD display, please enter value manually.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Sugar value field (supports text like "LOW", "HIGH")
            TextFormField(
              controller: _sugarController,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'Sugar Value',
                hintText: 'e.g., 105 or LOW/HIGH',
                suffixText: 'mg/dL',
                helperText: 'Can be a number or text (LOW, HIGH)',
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Sugar Image Preview
            if (hasSugarImage) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _sugarImage!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _sugarImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            
            // Capture Sugar Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _captureImage(ReadingType.sugar),
                icon: Icon(hasSugarImage ? Icons.refresh : Icons.camera_alt),
                label: Text(hasSugarImage ? 'Recapture Sugar Image' : 'Capture Sugar Reading'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade400,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build save button
  Widget _buildSaveButton() {
    final hasBP = _bpImage != null || _sysController.text.isNotEmpty;
    final hasSugar = _sugarImage != null || _sugarController.text.isNotEmpty;
    final bool canSave = hasBP || hasSugar;
    
    String buttonText = 'Save Readings';
    if (hasBP && hasSugar) {
      buttonText = 'Save Both Readings';
    } else if (hasBP) {
      buttonText = 'Save BP Reading';
    } else if (hasSugar) {
      buttonText = 'Save Sugar Reading';
    }
    
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isLoading || !canSave ? null : _saveReadings,
        icon: const Icon(Icons.save),
        label: Text(
          buttonText,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
        ),
      ),
    );
  }
}