import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_codes.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static const String _storageKey = 'location_config_cache';
  Map<String, dynamic> _locationData = locationMapping;
  bool _isInitialized = false;

  Map<String, dynamic> get locationData => _locationData;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_storageKey);
      
      if (cachedData != null) {
        final decoded = json.decode(cachedData) as Map<String, dynamic>;
        // Merge with local mapping to ensure codes are always present 
        // even if Firestore data is partial or missing codes.
        _locationData = decoded;
        debugPrint('LocationService: Loaded data from cache');
      } else {
        _locationData = locationMapping;
        debugPrint('LocationService: No cache found, using default mapping');
      }

    } catch (e) {
      debugPrint('LocationService Error loading cache: $e');
      _locationData = locationMapping;
    }

    _isInitialized = true;
    
    // Refresh from Firebase in the background
    refreshFromFirebase();
  }

  Future<void> refreshFromFirebase() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('locations')
          .doc('telangana')
          .get();

      if (doc.exists && doc.data() != null) {
        final firestoreData = doc.data()!;
        _locationData = firestoreData;
        
        // Update cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, json.encode(firestoreData));
        
        debugPrint('LocationService: Successfully refreshed from Firebase');
      }
    } catch (e) {
      debugPrint('LocationService: Error refreshing from Firebase: $e');
    }
  }

  // Simplified merge is no longer needed if Firestore is the source of truth
  // and Admin View manages the full structure.
}
