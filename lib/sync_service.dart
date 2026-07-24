import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'data_cache_service.dart';
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
  bool _isPulling = false;

  /// Initialize the service. Call this once from main() after Firebase.initializeApp().
  void initialize() {
    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final isOnline = result != ConnectivityResult.none;
      if (isOnline) {
        debugPrint('SyncService: Network restored. Starting full sync...');
        runFullSync();
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
      runFullSync();
    }
  }

  /// Runs both push and pull operations
  Future<void> runFullSync() async {
    await syncPendingSubmissions();
    await pullRemoteUpdates();
  }

  /// Pulls new data from Firestore that was added by other devices.
  Future<void> pullRemoteUpdates() async {
    if (_isPulling) {
      debugPrint('SyncService: Pull already in progress. Skipping.');
      return;
    }
    
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) return;

    _isPulling = true;
    debugPrint('SyncService: Checking for remote updates...');

    try {
      final collections = ['Family Code Creation', 'personal_details'];
      
      for (final collection in collections) {
        final lastPullStr = await _db.getMetadata('last_pull_$collection');
        DateTime lastPullDate = DateTime.fromMillisecondsSinceEpoch(0);
        if (lastPullStr != null) {
          lastPullDate = DateTime.parse(lastPullStr);
        }

        // Query Firestore for docs updated after our last pull
        // We use serverUpdatedAt as the source of truth for sync
        final query = FirebaseFirestore.instance
            .collection(collection)
            .where('serverUpdatedAt', isGreaterThan: lastPullDate)
            .orderBy('serverUpdatedAt', descending: false)
            .limit(100);

        final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
        
        if (snapshot.docs.isNotEmpty) {
          debugPrint('SyncService: Pulling ${snapshot.docs.length} new records from $collection...');
          
          DateTime maxTimestamp = lastPullDate;

          for (final doc in snapshot.docs) {
            final data = doc.data();
            data['firestoreDocId'] = doc.id;
            
            // Save to SQLite
            if (collection == 'Family Code Creation') {
              await DataCacheService().addGeneratedDetail({...data, 'family_id': data['family_id'] ?? data['FAM_ID'] ?? doc.id});
            } else if (collection == 'personal_details') {
              await DataCacheService().addMember(data);
            }

            final timestamp = data['serverUpdatedAt'];
            if (timestamp is Timestamp) {
              final dt = timestamp.toDate();
              if (dt.isAfter(maxTimestamp)) maxTimestamp = dt;
            }
          }

          // Update the last pull timestamp
          await _db.setMetadata('last_pull_$collection', maxTimestamp.toIso8601String());
          debugPrint('SyncService: Updated last_pull_$collection to $maxTimestamp');
        } else {
          debugPrint('SyncService: No new updates for $collection.');
        }
      }
    } catch (e) {
      debugPrint('SyncService: Error during pull: $e');
    } finally {
      _isPulling = false;
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

          // Remove temp flags and internal fields before saving to Firestore
          firestoreData.remove('is_temporary');
          firestoreData.remove('firestoreDocId');
          firestoreData.remove('village_prefix');
          firestoreData.remove('needs_final_id');

          // Mark as synced in Firestore so report icons turn green
          firestoreData['needs_zoho_sync'] = false;

          // Always stamp server time so pull sync can detect this update
          firestoreData['serverUpdatedAt'] = FieldValue.serverTimestamp();

          // Track the final synced family_id (may change during ID promotion)
          String finalSyncedId = (data['family_id'] ?? '').toString();

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
            
            finalSyncedId = finalRealId;
            debugPrint('SyncService: Promoted record to Final ID $finalRealId');

            // Update SQLite so searching the real ID works offline too
            final String oldFamilyId = (data['family_id'] ?? '').toString();
            await _db.promoteFamilyId(oldFamilyId, finalRealId, data);
            if (oldFamilyId.isNotEmpty && oldFamilyId != finalRealId) {
              await _db.updateFamilyCodeInPending(oldFamilyId, finalRealId);
              debugPrint('SyncService: Updated Family_Code $oldFamilyId → $finalRealId in pending submissions.');
            }
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

          // --- Post-Sync Logic: Handle Head of Family updates ---
          if (collection == 'personal_details' && 
              firestoreData['Relation_with_Head'] == 'HEAD OF THE FAMILY' && 
              firestoreData['Family_Code'] != null) {
            
            final fCode = firestoreData['Family_Code'].toString();
            final hName = firestoreData['Name'].toString();
            
            // 1. Update Local Cache
            await DataCacheService().updateHeadOfFamily(fCode, hName);

            // 2. Update Firestore Family Header
            final familyQuery = await FirebaseFirestore.instance
                .collection('Family Code Creation')
                .where('family_id', isEqualTo: fCode)
                .get();
            
            if (familyQuery.docs.isNotEmpty) {
              await FirebaseFirestore.instance
                  .collection('Family Code Creation')
                  .doc(familyQuery.docs.first.id)
                  .update({
                    'head_of_family': hName,
                    'Head_of_the_family': hName, 
                  });
            }
            debugPrint('SyncService: Updated Head of Family for $fCode to $hName');
          }

          // Mark the local record as synced
          await _db.markSubmissionSynced(id);

          // Push to Zoho Creator microservice with the final correct ID
          _pushToZohoMicroservice(collection, {...data, 'family_id': finalSyncedId});

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

  static const Map<String, String> _zohoMicroserviceUrls = {
    'Family Code Creation': 'https://www.zohoapis.in/creator/custom/shareindia/FamilyCodeCreationformFromFB?publickey=sC3sTn6SMeGRA56fBrjG7DqHg',
  };

  void _pushToZohoMicroservice(String collection, Map<String, dynamic> data) {
    final url = _zohoMicroserviceUrls[collection];
    if (url == null) return;
    debugPrint('ZohoMicroservice: Triggering for collection=$collection');
    try {
      final safeData = _toJsonSafe(data);
      final body = jsonEncode({'firebase_data': safeData});
      http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).then((response) {
        debugPrint('ZohoMicroservice [$collection]: ${response.statusCode} — ${response.body}');
      }).catchError((e) {
        debugPrint('ZohoMicroservice [$collection]: HTTP Error — $e');
      });
    } catch (e) {
      debugPrint('ZohoMicroservice [$collection]: Failed to prepare/send — $e');
    }
  }

  dynamic _toJsonSafe(dynamic value) {
    if (value == null || value is bool || value is num || value is String) return value;
    if (value is List) return value.map(_toJsonSafe).toList();
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), _toJsonSafe(v)));
    return value.toString();
  }
}
