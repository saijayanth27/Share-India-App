import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MariaDBService {
  // We'll derive the base URL from the one set in .env
  static String get _baseUrl {
    String url = dotenv.get('MARIADB_API_URL', fallback: '');
    // If it ends with the specific endpoint, strip it to get the base
    if (url.endsWith('/add-questionnaire')) {
      return url.replaceAll('/add-questionnaire', '');
    }
    return url;
  }

  static Future<void> syncQuestionnaire(Map<String, dynamic> data) async {
    final url = '$_baseUrl/add-questionnaire';
    if (_baseUrl.isEmpty) {
      debugPrint('⚠️ MariaDB API URL is not set in .env');
      return;
    }
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Successfully synced to MariaDB');
      } else {
        debugPrint('❌ Failed to sync to MariaDB: ${response.body}');
      }
    } catch (e) {
      debugPrint('⚠️ Error connecting to MariaDB API: $e');
    }
  }

  static Future<List<dynamic>> getQuestionnaires() async {
    final url = '$_baseUrl/get-questionnaires';
    if (_baseUrl.isEmpty) return [];
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('❌ Failed to fetch from MariaDB: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching from MariaDB API: $e');
      return [];
    }
  }
}
