import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'local_database_service.dart';

/// SyncService — a singleton that listens for network connectivity changes
/// and automatically syncs pending offline submissions to Firestore.
///
/// Usage: Call `SyncService().initialize()` once in `main()` after Firebase init.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final _db = LocalDatabaseService();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isSyncing = false;

  /// Initialize the service. Call this once from main() after Firebase.initializeApp().
  void initialize() {
    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final isOnline = result != ConnectivityResult.none;
      if (isOnline) {
        debugPrint('SyncService: Network restored. Starting sync...');
        syncPendingSubmissions();
      }
    });

    // Also attempt sync immediately on startup (in case internet is already available)
    _checkAndSync();
    debugPrint('SyncService: Initialized and listening for connectivity changes.');
  }

  Future<void> _checkAndSync() async {
    final result = await Connectivity().checkConnectivity();
    final isOnline = result != ConnectivityResult.none;
    if (isOnline) {
      syncPendingSubmissions();
    }
  }

  /// Fetches all unsynced records from SQLite and pushes them to Firestore.
  /// Records are processed in chronological order (oldest first).
  Future<void> syncPendingSubmissions() async {
    if (_isSyncing) {
      debugPrint('SyncService: Sync already in progress. Skipping.');
      return;
    }
    _isSyncing = true;

    try {
      final pending = await _db.getPendingSubmissions();
      if (pending.isEmpty) {
        debugPrint('SyncService: No pending submissions to sync.');
        _isSyncing = false;
        return;
      }

      debugPrint('SyncService: Found ${pending.length} pending submission(s). Syncing...');

      for (final submission in pending) {
        final String id = submission['id'] as String;
        final String collection = submission['collection'] as String;
        final String rawData = submission['rawData'] as String;

        try {
          // Decode the JSON string back to a map
          final Map<String, dynamic> data = jsonDecode(rawData) as Map<String, dynamic>;

          // Convert ISO date strings back to Firestore Timestamps
          final firestoreData = _convertDatesToTimestamps(data);

          // Determine if this is an update or a new record.
          // We use the `firestoreDocId` field if it was stored, otherwise we add a new doc.
          final String? firestoreDocId = data['firestoreDocId'] as String?;

          // Remove the temporary flag and the firestoreDocId field before saving
          firestoreData.remove('is_temporary');
          firestoreData.remove('firestoreDocId');
          firestoreData.remove('village_prefix');

          // Ensure serverUpdatedAt is a real FieldValue if the user intended it
          if (firestoreData.containsKey('serverUpdatedAt')) {
            firestoreData['serverUpdatedAt'] = FieldValue.serverTimestamp();
          }

          // --- Logic for Sequential ID Promotion ---
          if (data['needs_final_id'] == true && collection == 'Family Code Creation') {
            final String prefix = data['village_prefix'] ?? '';
            String finalRealId = '';
            
            await FirebaseFirestore.instance.runTransaction((transaction) async {
              final counterRef = FirebaseFirestore.instance.collection('village_counters').doc(prefix);
              final counterSnap = await transaction.get(counterRef);
              
              int lastSuffix = 0;
              if (counterSnap.exists) {
                lastSuffix = counterSnap.data()?['last_suffix'] ?? 0;
              }
              
              final nextSuffix = lastSuffix + 1;
              finalRealId = '$prefix${nextSuffix.toString().padLeft(5, '0')}';
              
              transaction.set(counterRef, {'last_suffix': nextSuffix}, SetOptions(merge: true));
              
              // Clean data for final doc
              final finalData = Map<String, dynamic>.from(firestoreData);
              finalData.remove('needs_final_id');
              finalData['family_id'] = finalRealId;
              finalData['is_temporary'] = false;
              
              transaction.set(FirebaseFirestore.instance.collection(collection).doc(finalRealId), finalData);
              
              // If we are promoting from a temp doc, delete the temp doc
              if (firestoreDocId != null && firestoreDocId != finalRealId) {
                transaction.delete(FirebaseFirestore.instance.collection(collection).doc(firestoreDocId));
              }
            }).timeout(const Duration(seconds: 20));
            
            debugPrint('SyncService: Promoted record to Final ID $finalRealId');
          } else if (firestoreDocId != null && firestoreDocId.isNotEmpty) {
            // It's an update to an existing Firestore document OR a new doc without promotion
            await FirebaseFirestore.instance
                .collection(collection)
                .doc(firestoreDocId)
                .set(firestoreData, SetOptions(merge: true))
                .timeout(const Duration(seconds: 15));
            debugPrint('SyncService: Synced doc $firestoreDocId in $collection.');
          } else {
            // It's a new document to add with a generated ID
            await FirebaseFirestore.instance
                .collection(collection)
                .add(firestoreData)
                .timeout(const Duration(seconds: 15));
            debugPrint('SyncService: Added new random doc to $collection.');
          }

          // Mark the local record as synced
          await _db.markSubmissionSynced(id);

        } catch (e) {
          // Log the error but continue with other submissions
          debugPrint('SyncService: Failed to sync submission $id from $collection: $e');
        }
      }

      debugPrint('SyncService: Sync cycle complete.');
    } catch (e) {
      debugPrint('SyncService: Critical sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Recursively converts ISO 8601 date strings in the map to Firestore Timestamps.
  Map<String, dynamic> _convertDatesToTimestamps(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is String) {
        final dt = DateTime.tryParse(value);
        // Only convert strings that look like ISO dates (e.g., "2023-01-15T00:00:00.000")
        if (dt != null && value.contains('T')) {
          result[entry.key] = Timestamp.fromDate(dt);
        } else {
          result[entry.key] = value;
        }
      } else if (value is Map<String, dynamic>) {
        result[entry.key] = _convertDatesToTimestamps(value);
      } else if (value is List) {
        result[entry.key] = value.map((item) {
          if (item is Map<String, dynamic>) return _convertDatesToTimestamps(item);
          return item;
        }).toList();
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
