import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'bpgluco.dart'; // For ReadingType

class HealthOCRService {
  static const String geminiApiKey = 'AIzaSyB4MBq0hMEx-UTB6eAr5FTDVR_kjOf-lUU';
  static bool _isProcessing = false;

  static Future<void> processPendingReadings() async {
    if (_isProcessing) {
      debugPrint('⏳ HealthOCR: Already processing. Skipping...');
      return;
    }
    _isProcessing = true;
    
    try {
      final dynamic result = await Connectivity().checkConnectivity();
      final connectivityResult = (result is List) 
          ? (result.isNotEmpty ? result.first : ConnectivityResult.none) 
          : result;
          
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint('📴 HealthOCR: Device is offline. Skipping background extraction.');
        return;
      }

      // 1. Check for records needing storage upload (images saved while offline)
      final storageSnapshot = await FirebaseFirestore.instance
          .collection('health_readings')
          .where('needs_storage_upload', isEqualTo: true)
          .get();

      // 2. Check for records needing Gemini extraction
      final geminiSnapshot = await FirebaseFirestore.instance
          .collection('health_readings')
          .where('needs_gemini_extraction', isEqualTo: true)
          .get();

      final allDocs = <String, QueryDocumentSnapshot>{};
      for (var doc in storageSnapshot.docs) allDocs[doc.id] = doc;
      for (var doc in geminiSnapshot.docs) allDocs[doc.id] = doc;

      if (allDocs.isEmpty) return;

      debugPrint('🔍 Found ${allDocs.length} health readings pending processing (Storage/Gemini). Processing in PARALLEL...');

      // Process all readings in parallel for maximum speed
      await Future.wait(allDocs.values.map((doc) => _processSingleReading(doc)));
      
      debugPrint('✅ Parallel background OCR complete.');
    } catch (e) {
      debugPrint('❌ Error in background health OCR: $e');
    } finally {
      _isProcessing = false;
    }
  }

  static Future<void> _processSingleReading(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    
    final bool bpPending = data['bp_needs_extraction'] == true;
    final bool sugarPending = data['sugar_needs_extraction'] == true;
    
    if (!bpPending && !sugarPending) return;

    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: geminiApiKey,
    );

    Map<String, dynamic> updates = {
      'extracted_at': FieldValue.serverTimestamp(),
    };

    final String recordId = doc.id;
    bool anyUploads = false;

    // Process BP if needed (BATCHED for speed)
    if (bpPending) {
      final List<String?> imagePaths = [
        data['bp_image_path'],
        data['bp_image_path2'],
        data['bp_image_path3'],
      ];

      final List<DataPart> imageParts = [];
      final List<int> activeIndices = [];

      for (int i = 0; i < 3; i++) {
        final String? localPath = imagePaths[i];
        String? storagePath = data[i == 0 ? 'bp_storage_path' : 'bp_storage_path${i + 1}'];
        
        // 0. UPLOAD IF MISSING (Saved while offline)
        if (storagePath == null && localPath != null && File(localPath).existsSync()) {
          try {
            debugPrint('☁️ Background Uploading BP image $i for $recordId');
            final String filename = 'bp${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final storageRef = FirebaseStorage.instance.ref().child('health_readings/$recordId/$filename');
            final uploadTask = storageRef.putFile(File(localPath), SettableMetadata());
            final snapshot = await uploadTask.whenComplete(() => {});
            storagePath = snapshot.ref.fullPath;
            updates[i == 0 ? 'bp_storage_path' : 'bp_storage_path${i + 1}'] = storagePath;
            anyUploads = true;
          } catch (e) {
            debugPrint('❌ Background Upload Error (BP $i): $e');
          }
        }

        Uint8List? bytes;
        try {
          if (localPath != null && File(localPath).existsSync()) {
            bytes = await File(localPath).readAsBytes();
          } else if (storagePath != null) {
            bytes = await FirebaseStorage.instance.ref(storagePath).getData();
          }

          if (bytes != null) {
            // Processing in background isolate for speed
            final stopwatch = Stopwatch()..start();
            final optimizedBytes = await compute(_optimizeImageBackgroundTask, bytes);
            stopwatch.stop();
            debugPrint('⏱️ Image $i processed in ${stopwatch.elapsedMilliseconds}ms');
            
            if (optimizedBytes != null) {
              imageParts.add(DataPart('image/jpeg', optimizedBytes));
              activeIndices.add(i);
            }
          }
        } catch (e) {
          debugPrint('❌ BP Load/Process Error (Image $i): $e');
        }
      }

      if (imageParts.isNotEmpty) {
        try {
          debugPrint('🚀 Sending ${imageParts.length} BP images to Gemini in a SINGLE BATCH...');
          
          final String prompt = "You are looking at ${imageParts.length} images of blood pressure monitor readings from the same patient. "
              "For each image, extract the Systolic (SYS), Diastolic (DIA), and Pulse (PULSE/PUL) values. "
              "Return ONLY a JSON object with keys 'reading0', 'reading1', etc., where each value is another object: {\"sys\": number, \"dia\": number, \"pulse\": number}. "
              "If a value is missing or unreadable in an image, use null. "
              "ORDER matches the order of the images provided.";

          final content = [Content.multi([TextPart(prompt), ...imageParts])];
          final response = await model.generateContent(content);
          final text = response.text;
          
          if (text != null && text.contains('{')) {
            final jsonStr = text.substring(text.indexOf('{'), text.lastIndexOf('}') + 1);
            final batchResult = jsonDecode(jsonStr);
            
            for (int k = 0; k < activeIndices.length; k++) {
              final int originalIndex = activeIndices[k];
              final String resultKey = 'reading$k';
              final result = batchResult[resultKey];
              
              if (result != null) {
                final suffix = originalIndex == 0 ? '' : (originalIndex + 1).toString();
                if (result['sys'] != null) updates['systolic$suffix'] = result['sys'];
                if (result['dia'] != null) updates['diastolic$suffix'] = result['dia'];
                if (result['pulse'] != null) updates['pulse$suffix'] = result['pulse'];
              }
            }
          }
        } catch (e) {
          debugPrint('❌ BP Batch Gemini Error: $e');
        }
      }
      updates['bp_needs_extraction'] = false;
    }

    // Process Sugar if needed
    if (sugarPending) {
      final String? localPath = data['sugar_image_path'];
      String? storagePath = data['sugar_storage_path'];
      
      Uint8List? bytes;

      // 0. UPLOAD IF MISSING (Saved while offline)
      if (storagePath == null && localPath != null && File(localPath).existsSync()) {
        try {
          debugPrint('☁️ Background Uploading Sugar image for $recordId');
          final String filename = 'sugar_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final storageRef = FirebaseStorage.instance.ref().child('health_readings/$recordId/$filename');
          final uploadTask = storageRef.putFile(File(localPath), SettableMetadata());
          final snapshot = await uploadTask.whenComplete(() => {});
          storagePath = snapshot.ref.fullPath;
          updates['sugar_storage_path'] = storagePath;
          anyUploads = true;
        } catch (e) {
          debugPrint('❌ Background Upload Error (Sugar): $e');
        }
      }

      try {
        // 1. Try local file first
        if (localPath != null && File(localPath).existsSync()) {
          bytes = await File(localPath).readAsBytes();
        } 
        // 2. Fallback to Firebase Storage
        else if (storagePath != null) {
          debugPrint('☁️ Fetching Sugar image from Storage: $storagePath');
          bytes = await FirebaseStorage.instance.ref(storagePath).getData();
        }

        if (bytes != null) {
          final stopwatch = Stopwatch()..start();
          final optimizedBytes = await compute(_optimizeImageBackgroundTask, bytes);
          stopwatch.stop();
          debugPrint('⏱️ Sugar image processed in ${stopwatch.elapsedMilliseconds}ms');

          if (optimizedBytes != null) {
            final prompt = "Extract the Glucose/Sugar value from this glucometer/sugar monitor image. Return ONLY a JSON object: {\"sugar\": number}. Use null if not found or unreadable.";
            
            final content = [Content.multi([TextPart(prompt), DataPart('image/jpeg', optimizedBytes)])];
            final response = await model.generateContent(content);
            final text = response.text;
            if (text != null && text.contains('{')) {
              final jsonStr = text.substring(text.indexOf('{'), text.lastIndexOf('}') + 1);
              final result = jsonDecode(jsonStr);
              updates['sugar_value'] = result['sugar']?.toString();
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Sugar Gemini Error: $e');
      }
      updates['sugar_needs_extraction'] = false;
    }

    // Final global status - only mark as fully done if nothing is pending anymore
    final bool stillBpPending = updates['bp_needs_extraction'] ?? bpPending;
    final bool stillSugarPending = updates['sugar_needs_extraction'] ?? sugarPending;
    
    updates['needs_gemini_extraction'] = stillBpPending || stillSugarPending;
    
    // Check if storage upload is still needed
    if (anyUploads) {
       // If we just uploaded something, re-check everything for this record
       final updatedData = (await doc.reference.get()).data() as Map<String, dynamic>;
       bool stillNeedsUpload = false;
       if (updatedData['bp_image_path'] != null && updatedData['bp_storage_path'] == null && updates['bp_storage_path'] == null) stillNeedsUpload = true;
       if (updatedData['bp_image_path2'] != null && updatedData['bp_storage_path2'] == null && updates['bp_storage_path2'] == null) stillNeedsUpload = true;
       if (updatedData['bp_image_path3'] != null && updatedData['bp_storage_path3'] == null && updates['bp_storage_path3'] == null) stillNeedsUpload = true;
       if (updatedData['sugar_image_path'] != null && updatedData['sugar_storage_path'] == null && updates['sugar_storage_path'] == null) stillNeedsUpload = true;
       updates['needs_storage_upload'] = stillNeedsUpload;
    } else {
       updates['needs_storage_upload'] = false;
    }
    
    await doc.reference.update(updates);
    debugPrint('✅ Updated unified health reading ${doc.id}');
  }

  /// Helper for compute() - runs in background isolate
  static Uint8List? _optimizeImageBackgroundTask(Uint8List bytes) {
    try {
      img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) return null;
      
      decodedImage = img.bakeOrientation(decodedImage);
      if (decodedImage.width > 1024 || decodedImage.height > 1024) {
        decodedImage = img.copyResize(decodedImage, width: 1024);
      }
      return Uint8List.fromList(img.encodeJpg(decodedImage, quality: 80));
    } catch (e) {
      debugPrint('❌ Isolate process error: $e');
      return null;
    }
  }
}
