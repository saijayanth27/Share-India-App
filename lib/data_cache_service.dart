import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'local_database_service.dart';

class DataCacheService {
  static final DataCacheService _instance = DataCacheService._internal();
  factory DataCacheService() => _instance;
  DataCacheService._internal();

  List<String> _familyCodes = [];
  bool _isFetchingCodes = false;

  List<Map<String, dynamic>> _familyDetails = [];
  bool _isFetchingDetails = false;

  List<String> get familyCodes => _familyCodes;
  List<Map<String, dynamic>> get familyDetails => _familyDetails;

  final _db = LocalDatabaseService();

  Future<List<String>> fetchFamilyCodes({bool forceRefresh = false}) async {
    // 1. Check in-memory
    if (_familyCodes.isNotEmpty && !forceRefresh) return _familyCodes;

    // 2. Prevent simultaneous fetches
    if (_isFetchingCodes) {
      while (_isFetchingCodes) await Future.delayed(const Duration(milliseconds: 100));
      return _familyCodes;
    }
    _isFetchingCodes = true;

    try {
      // 3. Check Local DB
      final localCodes = await _db.getFamilyCodes();
      if (localCodes.isNotEmpty && !forceRefresh) {
        _familyCodes = localCodes..sort();
        debugPrint('DataCacheService: Loaded ${_familyCodes.length} codes from Local DB.');
        _isFetchingCodes = false;
        return _familyCodes;
      }

      // 4. Optimization: DO NOT fetch all codes from Firestore here.
      // Instead, we rely on the main "Download All" sync or lookups from Cache.
      debugPrint('DataCacheService: Full Code Refresh requested. Checking Firestore CACHE for latest...');
      final snapshot = await FirebaseFirestore.instance
          .collection('Family Code Creation')
          .get(const GetOptions(source: Source.cache));
      
      final codes = snapshot.docs.map((doc) => doc.data()['family_id']?.toString()).whereType<String>().toSet().toList();
      if (codes.isNotEmpty) {
        _familyCodes = codes..sort();
        await _db.saveFamilyCodes(_familyCodes);
      }
    } catch (e) {
      debugPrint('DataCacheService: Error loading codes: $e');
    } finally {
      _isFetchingCodes = false;
    }
    return _familyCodes;
  }

  Future<List<Map<String, dynamic>>> fetchFamilyDetails({bool forceRefresh = false}) async {
    // 1. Check in-memory
    if (_familyDetails.isNotEmpty && !forceRefresh) return _familyDetails;

    if (_isFetchingDetails) {
      while (_isFetchingDetails) await Future.delayed(const Duration(milliseconds: 100));
      return _familyDetails;
    }
    _isFetchingDetails = true;

    try {
      // 2. Check Local DB
      final localDetails = await _db.getFamilyDetails();
      if (localDetails.isNotEmpty && !forceRefresh) {
        _familyDetails = localDetails;
        debugPrint('DataCacheService: Loaded ${_familyDetails.length} details from Local DB.');
        _isFetchingDetails = false;
        return _familyDetails;
      }

      // 3. Optimization: DO NOT fetch all details from Firestore here.
      debugPrint('DataCacheService: Full Details Refresh. Reading from Firestore CACHE...');
      final snapshot = await FirebaseFirestore.instance
          .collection('family_details')
          .get(const GetOptions(source: Source.cache));
      
      _familyDetails = snapshot.docs.map((doc) => doc.data()).toList();
      if (_familyDetails.isNotEmpty) {
        await _db.saveFamilyDetails(_familyDetails);
      }
    } catch (e) {
      debugPrint('DataCacheService: Error loading details: $e');
    } finally {
      _isFetchingDetails = false;
    }
    return _familyDetails;
  }

  Future<void> addGeneratedCode(String code) async {
    if (!_familyCodes.contains(code)) {
      _familyCodes.add(code);
      _familyCodes.sort();
      await _db.addSingleFamilyCode(code);
      debugPrint('DataCacheService: Added new code $code to local cache.');
    }
  }

  Future<void> addGeneratedDetail(Map<String, dynamic> detail) async {
    // Check if record already exists based on some unique ID or just add it
    // For lookup simplicity, we often just append or replace
    _familyDetails.add(detail);
    await _db.addSingleFamilyDetail(detail);
    debugPrint('DataCacheService: Added new member detail to local cache.');
  }

  Future<void> clearCache() async {
    _familyCodes = [];
    _familyDetails = [];
    await _db.clearAll();
  }
}
