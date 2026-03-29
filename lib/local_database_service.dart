import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  static Database? _database;

  LocalDatabaseService._internal();

  factory LocalDatabaseService() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'lookup_cache_v3.db'); // Bump version in filename for clean start
    return await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE family_codes (family_id TEXT PRIMARY KEY)');
        await db.execute('''
          CREATE TABLE family_details (
            family_id TEXT PRIMARY KEY,
            data TEXT
          )
        ''');
        await db.execute('CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT)');
        await db.execute('''
          CREATE TABLE family_members (
            unique_id TEXT PRIMARY KEY,
            family_id TEXT,
            data TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE offline_submissions (
            id TEXT PRIMARY KEY,
            collection TEXT,
            data TEXT,
            timestamp INTEGER,
            synced_at INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS family_details');
          await db.execute('''
            CREATE TABLE family_details (
              family_id TEXT PRIMARY KEY,
              data TEXT
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS family_members (
              unique_id TEXT PRIMARY KEY,
              family_id TEXT,
              data TEXT
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS offline_submissions (
              id TEXT PRIMARY KEY,
              collection TEXT,
              data TEXT,
              timestamp INTEGER,
              synced_at INTEGER
            )
          ''');
        }
        if (oldVersion < 5) {
          // Add synced_at column to existing offline_submissions table
          try {
            await db.execute('ALTER TABLE offline_submissions ADD COLUMN synced_at INTEGER');
          } catch (_) {} // Column may already exist
        }
      },
    );
  }

  // --- Family Codes Management ---

  Future<void> saveFamilyCodes(List<String> codes) async {
    final db = await database;
    final sw = Stopwatch()..start();
    debugPrint('LocalDB: Saving ${codes.length} family codes...');
    await db.transaction((txn) async {
      await txn.delete('family_codes');
      Batch batch = txn.batch();
      for (var code in codes) {
        batch.insert('family_codes', {'family_id': code}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
    debugPrint('LocalDB: Saved family codes in ${sw.elapsedMilliseconds}ms.');
  }

  Future<List<String>> getFamilyCodes() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query('family_codes');
    return results.map((e) => e['family_id'] as String).toList();
  }

  Future<void> addSingleFamilyCode(String code) async {
    final db = await database;
    await db.insert('family_codes', {'family_id': code}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Family Details Management ---

  Future<void> saveFamilyDetails(List<Map<String, dynamic>> details, {bool clearFirst = true}) async {
    final db = await database;
    final sw = Stopwatch()..start();
    debugPrint('LocalDB: Saving ${details.length} family details...');
    await db.transaction((txn) async {
      if (clearFirst) await txn.delete('family_details');
      Batch batch = txn.batch();
      for (var detail in details) {
        // Use either 'family_id' or 'Family_ID' depending on what Firestore returns
        String fId = (detail['family_id'] ?? detail['Family_ID'])?.toString() ?? '';
        if (fId.isNotEmpty) {
          batch.insert('family_details', {
            'family_id': fId,
            'data': jsonEncode(detail, toEncodable: (val) => val is Timestamp ? val.toDate().toIso8601String() : val.toString())
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
    debugPrint('LocalDB: Saved family details in ${sw.elapsedMilliseconds}ms.');
  }

  Future<Map<String, dynamic>?> getSingleFamilyDetail(String familyId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'family_details',
      where: 'family_id = ?',
      whereArgs: [familyId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getFamilyDetails() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query('family_details');
    return results.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
  }

  Future<void> addSingleFamilyDetail(Map<String, dynamic> detail) async {
    final db = await database;
    String fId = (detail['family_id'] ?? detail['Family_ID'])?.toString() ?? '';
    if (fId.isNotEmpty) {
      await db.insert('family_details', {
        'family_id': fId,
        'data': jsonEncode(detail, toEncodable: (val) => val is Timestamp ? val.toDate().toIso8601String() : val.toString())
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // --- Family Members Management ---

  Future<void> saveMember(Map<String, dynamic> member) async {
    final db = await database;
    // unique_id should be something like Aadhar or Serial or docId
    String uId = (member['unique_id'] ?? member['uniq_Registration_Number'] ?? (member['Name'].toString() + '_' + (member['Family_Code'] ?? ''))).toString();
    String fId = member['Family_Code']?.toString().trim().toUpperCase() ?? '';
    
    await db.insert('family_members', {
      'unique_id': uId,
      'family_id': fId,
      'data': jsonEncode(member, toEncodable: (val) => val is Timestamp ? val.toDate().toIso8601String() : val.toString())
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getMembersByFamily(String familyId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'family_members',
      where: 'UPPER(family_id) = ?',
      whereArgs: [familyId.trim().toUpperCase()],
    );
    return results.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> searchFamilyDetails(String query, {int limit = 50}) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'family_details',
      where: 'family_id LIKE ?',
      whereArgs: ['$query%'],
      orderBy: 'family_id DESC',
      limit: limit,
    );
    return results.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
  }

  // --- Offline Submissions Management ---

  Future<void> saveOfflineSubmission(String collection, Map<String, dynamic> data) async {
    final db = await database;
    
    // Priority for unique ID:
    // 1. firestoreDocId (If editing, this is the most reliable unique key)
    // 2. id (explicitly provided)
    // 3. Registration_Number
    // 4. Name
    // 5. Timestamp (fallback)
    String uId = (data['firestoreDocId'] ?? data['id'] ?? data['Registration_Number']?.toString() ?? data['Name']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString()).toString();
    
    await db.insert('offline_submissions', {
      'id': uId,
      'collection': collection,
      'data': jsonEncode(data, toEncodable: (Object? value) {
        if (value is Timestamp) {
          return value.toDate().toIso8601String();
        }
        return value.toString();
      }),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'synced_at': null, // Explicitly set to NULL to mark as pending
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getOfflineSubmissions(String collection) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'offline_submissions',
      where: 'collection = ?',
      whereArgs: [collection],
      orderBy: 'timestamp DESC',
    );
    return results.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
  }

  /// Returns all submissions that have NOT been synced to Firestore yet.
  Future<List<Map<String, dynamic>>> getPendingSubmissions() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'offline_submissions',
      where: 'synced_at IS NULL',
      orderBy: 'timestamp ASC',
    );
    return results.map((row) => {
      'id': row['id'] as String,
      'collection': row['collection'] as String,
      'rawData': row['data'] as String, // raw JSON string
      'timestamp': row['timestamp'] as int,
    }).toList();
  }

  /// Marks a submission as synced by recording the sync timestamp.
  Future<void> markSubmissionSynced(String id) async {
    final db = await database;
    await db.update(
      'offline_submissions',
      {'synced_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Permanently deletes a submission after successful sync cleanup.
  Future<void> deleteOfflineSubmission(String id) async {
    final db = await database;
    await db.delete(
      'offline_submissions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Utility Methods ---

  Future<int> getRecordCount(String table) async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<bool> hasData(String table) async {
    int count = await getRecordCount(table);
    return count > 0;
  }

  Future<void> setMetadata(String key, String value) async {
    final db = await database;
    await db.insert('metadata', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getMetadata(String key) async {
    final db = await database;
    final results = await db.query('metadata', where: 'key = ?', whereArgs: [key]);
    if (results.isNotEmpty) return results.first['value'] as String;
    return null;
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('family_codes');
    await db.delete('family_details');
    await db.delete('family_members');
    await db.delete('metadata');
  }

  Future<int> getFamilyCountByPrefix(String prefix) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> res = await db.rawQuery(
        'SELECT COUNT(*) as count FROM family_details WHERE family_id LIKE ?',
        ['$prefix%'],
      );
      if (res.isNotEmpty) {
        return res.first['count'] as int;
      }
    } catch (e) {
      debugPrint('Local DB count error: $e');
    }
    return 0;
  }
}
