import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'bpgluco.dart'; // For ReadingType

class HealthOCRService {
  static const String geminiApiKey = 'AIzaSyA7DhZc6K8uPdjsh3toKYTwdzvS_-hv_R0';

  static Future<void> processPendingReadings() async {
    try {
      final dynamic result = await Connectivity().checkConnectivity();
      final connectivityResult = (result is List) 
          ? (result.isNotEmpty ? result.first : ConnectivityResult.none) 
          : result;
          
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint('📴 HealthOCR: Device is offline. Skipping background extraction.');
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('health_readings')
          .where('needs_gemini_extraction', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) return;

      debugPrint('🔍 Found ${snapshot.docs.length} health readings pending GEMINI extraction. Processing in PARALLEL...');

      // Process all readings in parallel for maximum speed
      await Future.wait(snapshot.docs.map((doc) => _processSingleReading(doc)));
      
      debugPrint('✅ Parallel background OCR complete.');
    } catch (e) {
      debugPrint('❌ Error in background health OCR: $e');
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

    // Process BP if needed
    if (bpPending) {
      final String? imagePath = data['bp_image_path'];
      if (imagePath != null && File(imagePath).existsSync()) {
        try {
          final File imageFile = File(imagePath);
          Uint8List bytes = await imageFile.readAsBytes();
          
          // SPEED OPTIMIZATION: Compress image for faster background upload to Gemini
          try {
            final decodedImage = img.decodeImage(bytes);
            if (decodedImage != null && (decodedImage.width > 1024 || decodedImage.height > 1024)) {
              final resized = img.copyResize(decodedImage, width: 1024);
              bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 80));
              debugPrint('📉 Compressed BP image for Gemini: ${(bytes.length / 1024).toStringAsFixed(1)} KB');
            }
          } catch (e) {
            debugPrint('⚠️ Compression failed, sending original: $e');
          }

          final prompt = "Extract the Systolic (SYS), Diastolic (DIA), and Pulse (PULSE/PUL) values from this blood pressure monitor image. Look closely at the 7-segment display digits. Return ONLY a JSON object: {\"sys\": number, \"dia\": number, \"pulse\": number}. Use null if not found or unreadable.";
          
          final content = [Content.multi([TextPart(prompt), DataPart('image/jpeg', bytes)])];
          final response = await model.generateContent(content);
          final text = response.text;
          
          if (text != null && text.contains('{')) {
            final jsonStr = text.substring(text.indexOf('{'), text.lastIndexOf('}') + 1);
            final result = jsonDecode(jsonStr);
            updates['systolic'] = result['sys'];
            updates['diastolic'] = result['dia'];
            updates['pulse'] = result['pulse'];
            updates['bp_needs_extraction'] = false;
          }
        } catch (e) {
          debugPrint('❌ BP Gemini Error: $e');
        }
      } else {
        updates['bp_needs_extraction'] = false;
      }
    }

    // Process Sugar if needed
    if (sugarPending) {
      final String? imagePath = data['sugar_image_path'];
      if (imagePath != null && File(imagePath).existsSync()) {
        try {
          final File imageFile = File(imagePath);
          Uint8List bytes = await imageFile.readAsBytes();
          
          // SPEED OPTIMIZATION: Compress image for faster background upload to Gemini
          try {
            final decodedImage = img.decodeImage(bytes);
            if (decodedImage != null && (decodedImage.width > 1024 || decodedImage.height > 1024)) {
              final resized = img.copyResize(decodedImage, width: 1024);
              bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 80));
              debugPrint('📉 Compressed Sugar image for Gemini: ${(bytes.length / 1024).toStringAsFixed(1)} KB');
            }
          } catch (e) {
            debugPrint('⚠️ Compression failed, sending original: $e');
          }

          final prompt = "Extract the Glucose/Sugar value from this glucometer/sugar monitor image. Return ONLY a JSON object: {\"sugar\": number}. Use null if not found or unreadable.";
          
          final content = [Content.multi([TextPart(prompt), DataPart('image/jpeg', bytes)])];
          final response = await model.generateContent(content);
          final text = response.text;
          
          if (text != null && text.contains('{')) {
            final jsonStr = text.substring(text.indexOf('{'), text.lastIndexOf('}') + 1);
            final result = jsonDecode(jsonStr);
            updates['sugar_value'] = result['sugar']?.toString();
            updates['sugar_needs_extraction'] = false;
          }
        } catch (e) {
          debugPrint('❌ Sugar Gemini Error: $e');
        }
      } else {
        updates['sugar_needs_extraction'] = false;
      }
    }

    // Final global status - only mark as fully done if nothing is pending anymore
    final bool stillBpPending = updates['bp_needs_extraction'] ?? bpPending;
    final bool stillSugarPending = updates['sugar_needs_extraction'] ?? sugarPending;
    
    updates['needs_gemini_extraction'] = stillBpPending || stillSugarPending;
    
    await doc.reference.update(updates);
    debugPrint('✅ Updated unified health reading ${doc.id}');
  }
}
