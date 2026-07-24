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
        _locationData = decoded;
        debugPrint('LocationService: Initialized with cached data.');
      } else {
        _locationData = locationMapping;
        debugPrint('LocationService: No cache found, using default mapping.');
      }
    } catch (e) {
      debugPrint('LocationService Error loading cache: $e');
      _locationData = locationMapping;
    }

    _isInitialized = true;
    // Initial refresh to get the standard data (telangana) and discover others
    refreshFromFirebase();
  }

  Future<void> refreshFromFirebase({String? stateId}) async {
    try {
      // 1. If no stateId is provided, we fetch 'telangana' by default 
      // but also discover all other available states to update the UI later.
      final targetId = (stateId ?? 'telangana').toLowerCase();
      
      final doc = await FirebaseFirestore.instance
          .collection('locations')
          .doc(targetId)
          .get();

      if (doc.exists && doc.data() != null) {
        final firestoreData = doc.data()!;
        _locationData = firestoreData;
        
        // Update cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, json.encode(firestoreData));
        
        debugPrint('LocationService: Refreshed data for $targetId');
      }

      // 2. Discover all states to ensure the State dropdown is accurate
      final statesSnapshot = await FirebaseFirestore.instance
          .collection('locations')
          .get(const GetOptions(source: Source.serverAndCache));
      
      final states = statesSnapshot.docs.map((d) => d.id.toUpperCase()).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('available_states', json.encode(states));
      
    } catch (e) {
      debugPrint('LocationService: Error refreshing from Firebase: $e');
    }
  }

  Future<List<String>> getAvailableStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('available_states');
      if (cached != null) {
        return (json.decode(cached) as List).cast<String>();
      }
    } catch (_) {}
    return ['Telangana'];
  }

  // Simplified merge is no longer needed if Firestore is the source of truth
  // and Admin View manages the full structure.
}
