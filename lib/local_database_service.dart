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
      version: 13,
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
        await db.execute('CREATE INDEX IF NOT EXISTS idx_member_family ON family_members(family_id)');
        await db.execute('''
          CREATE TABLE offline_submissions (
            id TEXT PRIMARY KEY,
            collection TEXT,
            data TEXT,
            timestamp INTEGER,
            synced_at INTEGER
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sub_synced ON offline_submissions(synced_at)');
        await db.execute('''
          CREATE TABLE anc_records (
            reg_no TEXT PRIMARY KEY,
            family_id TEXT,
            data TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_anc_family ON anc_records(family_id)');
        await db.execute('''
          CREATE TABLE anc_checkups (
            id TEXT PRIMARY KEY,
            reg_no TEXT,
            family_id TEXT,
            data TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_ancc_family ON anc_checkups(family_id)');
        await db.execute('''
          CREATE TABLE child_immunization (
            unique_id TEXT PRIMARY KEY,
            family_id TEXT,
            data TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_ci_family ON child_immunization(family_id)');
        await db.execute('''
          CREATE TABLE family_planning_records (
            reg_no TEXT PRIMARY KEY,
            family_id TEXT,
            name TEXT,
            data TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_fp_family ON family_planning_records(family_id)');
        await db.execute('''
          CREATE TABLE bp_records (
            unique_id TEXT PRIMARY KEY,
            reg_no TEXT,
            family_id TEXT,
            name TEXT,
            data TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_bp_family ON bp_records(family_id)');
        await db.execute('''
          CREATE TABLE refusal_records (
            reg_no TEXT PRIMARY KEY,
            family_id TEXT,
            name TEXT,
            data TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_ref_family ON refusal_records(family_id)');
        await db.execute('''
          CREATE TABLE tb_records (
            reg_no TEXT PRIMARY KEY,
            family_id TEXT,
            name TEXT,
            data TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_tb_family ON tb_records(family_id)');
        await db.execute('''
          CREATE TABLE fbs_records (
            unique_id TEXT PRIMARY KEY,
            reg_no TEXT,
            family_id TEXT,
            name TEXT,
            data TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_fbs_family ON fbs_records(family_id)');
        await db.execute('''
          CREATE TABLE blood_sample_records (
            reg_no TEXT PRIMARY KEY,
            family_id TEXT,
            name TEXT,
            data TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_samp_family ON blood_sample_records(family_id)');
        await db.execute('''
          CREATE TABLE cc_records (
            reg_no TEXT PRIMARY KEY,
            family_id TEXT,
            name TEXT,
            data TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_family ON cc_records(family_id)');
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
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS anc_records (
              reg_no TEXT PRIMARY KEY,
              family_id TEXT,
              data TEXT
            )
          ''');
          try { await db.execute('CREATE INDEX IF NOT EXISTS idx_anc_family ON anc_records(family_id)'); } catch (_) {}
          await db.execute('''
            CREATE TABLE IF NOT EXISTS anc_checkups (
              id TEXT PRIMARY KEY,
              reg_no TEXT,
              family_id TEXT,
              data TEXT
            )
          ''');
          try { await db.execute('CREATE INDEX IF NOT EXISTS idx_ancc_family ON anc_checkups(family_id)'); } catch (_) {}
        }
        if (oldVersion < 7) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS child_immunization (
              unique_id TEXT PRIMARY KEY,
              family_id TEXT,
              data TEXT
            )
          ''');
          try { await db.execute('CREATE INDEX IF NOT EXISTS idx_ci_family ON child_immunization(family_id)'); } catch (_) {}
        }
        if (oldVersion < 8) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS family_planning_records (
              reg_no TEXT PRIMARY KEY,
              family_id TEXT,
              name TEXT,
              data TEXT
            )
          ''');
          try { await db.execute('CREATE INDEX IF NOT EXISTS idx_fp_family ON family_planning_records(family_id)'); } catch (_) {}
        }
        if (oldVersion < 9) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS bp_records (
              unique_id TEXT PRIMARY KEY,
              reg_no TEXT,
              family_id TEXT,
              name TEXT,
              data TEXT
            )
          ''');
          try { await db.execute('CREATE INDEX IF NOT EXISTS idx_bp_family ON bp_records(family_id)'); } catch (_) {}
          await db.execute('''
            CREATE TABLE IF NOT EXISTS refusal_records (
              reg_no TEXT PRIMARY KEY,
              family_id TEXT,
              name TEXT,
              data TEXT
            )
          ''');
          try { await db.execute('CREATE INDEX IF NOT EXISTS idx_ref_family ON refusal_records(family_id)'); } catch (_) {}
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tb_records (
              reg_no TEXT PRIMARY KEY,
              family_id TEXT,
              name TEXT,
              data TEXT
            )
          ''');
          try { await db.execute('CREATE INDEX IF NOT EXISTS idx_tb_family ON tb_records(family_id)'); } catch (_) {}
        }
        if (oldVersion < 10) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS fbs_records (
              unique_id TEXT PRIMARY KEY,
              reg_no TEXT,
              family_id TEXT,
              name TEXT,
              data TEXT
            )
          ''');
          try { await db.execute('CREATE INDEX IF NOT EXISTS idx_fbs_family ON fbs_records(family_id)'); } catch (_) {}
        }
        if (oldVersion < 11) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS blood_sample_records (
              reg_no TEXT PRIMARY KEY,
              family_id TEXT,
              name TEXT,
              data TEXT
            )
          ''');
          try { await db.execute('CREATE INDEX IF NOT EXISTS idx_samp_family ON blood_sample_records(family_id)'); } catch (_) {}
        }
        if (oldVersion < 12) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cc_records (
              reg_no TEXT PRIMARY KEY,
              family_id TEXT,
              name TEXT,
              data TEXT
            )
          ''');
          try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_family ON cc_records(family_id)'); } catch (_) {}
        }
        if (oldVersion < 13) {
          try { await db.execute('CREATE INDEX IF NOT EXISTS idx_member_family ON family_members(family_id)'); } catch (_) {}
          try { await db.execute('CREATE INDEX IF NOT EXISTS idx_sub_synced ON offline_submissions(synced_at)'); } catch (_) {}
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
        String fId = (detail['family_id'] ?? detail['Family_ID'] ?? detail['FAM_ID'])?.toString() ?? '';
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

  Future<void> promoteFamilyId(String oldId, String newId, Map<String, dynamic> data) async {
    final db = await database;
    final updatedData = {...data, 'family_id': newId};
    final encoded = jsonEncode(updatedData, toEncodable: (val) => val is Timestamp ? val.toDate().toIso8601String() : val.toString());
    await db.transaction((txn) async {
      // Remove old records
      await txn.delete('family_details', where: 'family_id = ?', whereArgs: [oldId]);
      await txn.delete('family_codes', where: 'family_id = ?', whereArgs: [oldId]);
      // Insert with new real ID
      await txn.insert('family_details', {'family_id': newId, 'data': encoded}, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('family_codes', {'family_id': newId}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    debugPrint('LocalDB: Promoted family_id $oldId → $newId in SQLite');
  }

  Future<void> addSingleFamilyDetail(Map<String, dynamic> detail) async {
    final db = await database;
    String fId = (detail['family_id'] ?? detail['Family_ID'] ?? detail['FAM_ID'])?.toString() ?? '';
    if (fId.isNotEmpty) {
      await db.insert('family_details', {
        'family_id': fId,
        'data': jsonEncode(detail, toEncodable: (val) => val is Timestamp ? val.toDate().toIso8601String() : val.toString())
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // --- Family Members Management ---

  Future<void> saveMembers(List<Map<String, dynamic>> members, {bool clearFirst = false}) async {
    final db = await database;
    final sw = Stopwatch()..start();
    debugPrint('LocalDB: Saving ${members.length} member details...');
    await db.transaction((txn) async {
      if (clearFirst) await txn.delete('family_members');
      Batch batch = txn.batch();
      for (var member in members) {
        String uId = (member['unique_id'] ?? member['uniq_Registration_Number'] ?? (member['Name'].toString() + '_' + (member['Family_Code'] ?? ''))).toString();
        String fId = member['Family_Code']?.toString().trim().toUpperCase() ?? '';
        if (fId.isNotEmpty) {
          batch.insert('family_members', {
            'unique_id': uId,
            'family_id': fId,
            'data': jsonEncode(member, toEncodable: (val) => val is Timestamp ? val.toDate().toIso8601String() : val.toString())
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
    debugPrint('LocalDB: Saved ${members.length} members in ${sw.elapsedMilliseconds}ms.');
  }

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
      where: 'family_id = ?',
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

    // For new records (no firestoreDocId), generate a stable Firestore doc ID now.
    // This makes sync idempotent: retries use .set(merge:true) on the same doc
    // instead of .add() creating a new duplicate document each time.
    if (data['firestoreDocId'] == null || (data['firestoreDocId'] as String?)?.isEmpty == true) {
      data['firestoreDocId'] = FirebaseFirestore.instance.collection(collection).doc().id;
    }

    // The firestoreDocId is now always set, so use it as the local unique key.
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

  /// Updates Family_Code in all pending (unsynced) submissions that reference oldCode.
  /// Called after a family code is promoted from offline placeholder to final Firestore ID.
  Future<void> updateFamilyCodeInPending(String oldCode, String newCode) async {
    final db = await database;
    final List<Map<String, dynamic>> pending = await db.query(
      'offline_submissions',
      where: 'synced_at IS NULL',
    );
    for (final row in pending) {
      final rawData = row['data'] as String? ?? '';
      if (!rawData.contains(oldCode)) continue;
      try {
        final decoded = Map<String, dynamic>.from(jsonDecode(rawData) as Map);
        bool changed = false;
        if (decoded['Family_Code']?.toString() == oldCode) {
          decoded['Family_Code'] = newCode;
          changed = true;
        }
        if (decoded['Family_code']?.toString() == oldCode) {
          decoded['Family_code'] = newCode;
          changed = true;
        }
        if (changed) {
          await db.update(
            'offline_submissions',
            {'data': jsonEncode(decoded)},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      } catch (_) {}
    }
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

  // --- ANC Records ---

  Future<void> saveAncRecords(List<Map<String, dynamic>> records, {bool clearFirst = false}) async {
    final db = await database;
    final sw = Stopwatch()..start();
    await db.transaction((txn) async {
      if (clearFirst) await txn.delete('anc_records');
      final batch = txn.batch();
      for (final r in records) {
        final regNo = r['Registration_Number']?.toString() ?? '';
        final familyId = r['Family_Code']?.toString().trim().toUpperCase() ?? '';
        if (regNo.isNotEmpty) {
          batch.insert('anc_records', {
            'reg_no': regNo,
            'family_id': familyId,
            'data': jsonEncode(r),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
    debugPrint('LocalDB: Saved ${records.length} ANC records in ${sw.elapsedMilliseconds}ms');
  }

  Future<List<Map<String, dynamic>>> getAncRecordsByFamily(String familyId) async {
    final db = await database;
    final results = await db.query(
      'anc_records',
      where: 'family_id = ?',
      whereArgs: [familyId.trim().toUpperCase()],
    );
    return results.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
  }

  // --- ANC Checkups ---

  Future<void> saveAncCheckups(List<Map<String, dynamic>> records, {bool clearFirst = false}) async {
    final db = await database;
    final sw = Stopwatch()..start();
    await db.transaction((txn) async {
      if (clearFirst) await txn.delete('anc_checkups');
      final batch = txn.batch();
      for (final r in records) {
        final regNo = r['Registration_Number']?.toString() ?? '';
        final visitNo = r['Visit_No']?.toString() ?? '0';
        final familyId = r['Family_Code']?.toString().trim().toUpperCase() ?? '';
        if (regNo.isNotEmpty) {
          batch.insert('anc_checkups', {
            'id': '${regNo}_$visitNo',
            'reg_no': regNo,
            'family_id': familyId,
            'data': jsonEncode(r),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
    debugPrint('LocalDB: Saved ${records.length} ANC checkups in ${sw.elapsedMilliseconds}ms');
  }

  Future<List<Map<String, dynamic>>> getAncCheckupsByFamily(String familyId) async {
    final db = await database;
    final results = await db.query(
      'anc_checkups',
      where: 'family_id = ?',
      whereArgs: [familyId.trim().toUpperCase()],
    );
    return results.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
  }

  // --- Child Immunization ---

  Future<void> saveChildImmunization(List<Map<String, dynamic>> records, {bool clearFirst = false}) async {
    final db = await database;
    final sw = Stopwatch()..start();
    await db.transaction((txn) async {
      if (clearFirst) await txn.delete('child_immunization');
      final batch = txn.batch();
      for (final r in records) {
        final regNo = r['Registration_Number']?.toString() ?? '';
        final familyId = r['Family_Code']?.toString().trim().toUpperCase() ?? '';
        final uid = regNo.isNotEmpty ? regNo : '${familyId}_${r['Name'] ?? ''}';
        if (familyId.isNotEmpty) {
          batch.insert('child_immunization', {
            'unique_id': uid,
            'family_id': familyId,
            'data': jsonEncode(r),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
    debugPrint('LocalDB: Saved ${records.length} child immunization records in ${sw.elapsedMilliseconds}ms');
  }

  Future<List<Map<String, dynamic>>> getChildImmunizationByFamily(String familyId) async {
    final db = await database;
    final results = await db.query(
      'child_immunization',
      where: 'family_id = ?',
      whereArgs: [familyId.trim().toUpperCase()],
    );
    return results.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> getChildImmunizationByName(String familyId, String name) async {
    final db = await database;
    final results = await db.rawQuery(
      "SELECT data FROM child_immunization WHERE UPPER(family_id) = ? AND json_extract(data, '\$.Name') = ?",
      [familyId.trim().toUpperCase(), name],
    );
    if (results.isEmpty) return null;
    return jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
  }

  // --- Family Planning Records ---

  Future<void> saveFamilyPlanningRecords(List<Map<String, dynamic>> records, {bool clearFirst = false}) async {
    final db = await database;
    final sw = Stopwatch()..start();
    await db.transaction((txn) async {
      if (clearFirst) await txn.delete('family_planning_records');
      final batch = txn.batch();
      for (final r in records) {
        final regNo = r['Registration_Number']?.toString() ?? '';
        final familyId = r['Family_Code']?.toString().trim().toUpperCase() ?? '';
        final name = r['Name']?.toString() ?? '';
        final uid = regNo.isNotEmpty ? regNo : '${familyId}_$name';
        if (familyId.isNotEmpty) {
          batch.insert('family_planning_records', {
            'reg_no': uid,
            'family_id': familyId,
            'name': name,
            'data': jsonEncode(r),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
    debugPrint('LocalDB: Saved ${records.length} family planning records in ${sw.elapsedMilliseconds}ms');
  }

  Future<List<Map<String, dynamic>>> getFamilyPlanningByFamily(String familyId) async {
    final db = await database;
    final results = await db.query(
      'family_planning_records',
      where: 'family_id = ?',
      whereArgs: [familyId.trim().toUpperCase()],
    );
    return results.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> getFamilyPlanningByName(String familyId, String name) async {
    final db = await database;
    final results = await db.query(
      'family_planning_records',
      where: 'UPPER(family_id) = ? AND name = ?',
      whereArgs: [familyId.trim().toUpperCase(), name],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
  }

  // --- BP Records ---

  Future<void> saveBpRecords(List<Map<String, dynamic>> records, {bool clearFirst = false}) async {
    final db = await database;
    final sw = Stopwatch()..start();
    await db.transaction((txn) async {
      if (clearFirst) await txn.delete('bp_records');
      final batch = txn.batch();
      for (final r in records) {
        final regNo = r['Registration_Number']?.toString() ?? '';
        final date = r['Date_of_Interview']?.toString() ?? '';
        final uid = regNo.isNotEmpty ? '${regNo}_$date' : '';
        final familyId = r['Family_Code']?.toString().trim().toUpperCase() ?? '';
        final name = r['Name']?.toString() ?? '';
        if (familyId.isNotEmpty && uid.isNotEmpty) {
          batch.insert('bp_records', {
            'unique_id': uid,
            'reg_no': regNo,
            'family_id': familyId,
            'name': name,
            'data': jsonEncode(r),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
    debugPrint('LocalDB: Saved ${records.length} BP records in ${sw.elapsedMilliseconds}ms');
  }

  Future<List<Map<String, dynamic>>> getBpRecordsByFamily(String familyId) async {
    final db = await database;
    final results = await db.query('bp_records', where: 'family_id = ?', whereArgs: [familyId.trim().toUpperCase()]);
    return results.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> getBpRecordByName(String familyId, String name) async {
    final db = await database;
    // Return the most recent record for this member (highest date)
    final results = await db.query(
      'bp_records',
      where: 'UPPER(family_id) = ? AND name = ?',
      whereArgs: [familyId.trim().toUpperCase(), name],
      orderBy: 'unique_id DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
  }

  // --- Refusal Records ---

  Future<void> saveRefusalRecords(List<Map<String, dynamic>> records, {bool clearFirst = false}) async {
    final db = await database;
    final sw = Stopwatch()..start();
    await db.transaction((txn) async {
      if (clearFirst) await txn.delete('refusal_records');
      final batch = txn.batch();
      for (final r in records) {
        final regNo = r['Registration_Number']?.toString() ?? '';
        final familyId = r['Family_Code']?.toString().trim().toUpperCase() ?? '';
        final name = r['Name']?.toString() ?? '';
        if (regNo.isNotEmpty) {
          batch.insert('refusal_records', {
            'reg_no': regNo,
            'family_id': familyId,
            'name': name,
            'data': jsonEncode(r),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
    debugPrint('LocalDB: Saved ${records.length} refusal records in ${sw.elapsedMilliseconds}ms');
  }

  Future<List<Map<String, dynamic>>> getRefusalRecordsByFamily(String familyId) async {
    final db = await database;
    final results = await db.query('refusal_records', where: 'family_id = ?', whereArgs: [familyId.trim().toUpperCase()]);
    return results.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> getRefusalRecordByName(String familyId, String name) async {
    final db = await database;
    final results = await db.query(
      'refusal_records',
      where: 'UPPER(family_id) = ? AND name = ?',
      whereArgs: [familyId.trim().toUpperCase(), name],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
  }

  // --- TB Records ---

  Future<void> saveTbRecords(List<Map<String, dynamic>> records, {bool clearFirst = false}) async {
    final db = await database;
    final sw = Stopwatch()..start();
    await db.transaction((txn) async {
      if (clearFirst) await txn.delete('tb_records');
      final batch = txn.batch();
      for (final r in records) {
        final regNo = r['Registration_Number']?.toString() ?? '';
        final familyId = r['Family_Code']?.toString().trim().toUpperCase() ?? '';
        final name = r['Name']?.toString() ?? '';
        if (regNo.isNotEmpty) {
          batch.insert('tb_records', {
            'reg_no': regNo,
            'family_id': familyId,
            'name': name,
            'data': jsonEncode(r),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
    debugPrint('LocalDB: Saved ${records.length} TB records in ${sw.elapsedMilliseconds}ms');
  }

  Future<List<Map<String, dynamic>>> getTbRecordsByFamily(String familyId) async {
    final db = await database;
    final results = await db.query('tb_records', where: 'family_id = ?', whereArgs: [familyId.trim().toUpperCase()]);
    return results.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> getTbRecordByName(String familyId, String name) async {
    final db = await database;
    final results = await db.query(
      'tb_records',
      where: 'UPPER(family_id) = ? AND name = ?',
      whereArgs: [familyId.trim().toUpperCase(), name],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
  }

  // --- FBS Records ---

  Future<void> saveFbsRecords(List<Map<String, dynamic>> records, {bool clearFirst = false}) async {
    final db = await database;
    final sw = Stopwatch()..start();
    await db.transaction((txn) async {
      if (clearFirst) await txn.delete('fbs_records');
      final batch = txn.batch();
      for (final r in records) {
        final regNo = r['Registration_Number']?.toString() ?? '';
        final date = r['Date_of_Interview']?.toString() ?? '';
        final uid = regNo.isNotEmpty ? '${regNo}_$date' : '';
        final familyId = r['Family_code']?.toString().trim().toUpperCase() ?? '';
        final name = r['Name']?.toString() ?? '';
        if (familyId.isNotEmpty && uid.isNotEmpty) {
          batch.insert('fbs_records', {
            'unique_id': uid,
            'reg_no': regNo,
            'family_id': familyId,
            'name': name,
            'data': jsonEncode(r),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
    debugPrint('LocalDB: Saved ${records.length} FBS records in ${sw.elapsedMilliseconds}ms');
  }

  Future<Map<String, dynamic>?> getFbsRecordByName(String familyId, String name) async {
    final db = await database;
    final results = await db.query(
      'fbs_records',
      where: 'UPPER(family_id) = ? AND name = ?',
      whereArgs: [familyId.trim().toUpperCase(), name],
      orderBy: 'unique_id DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
  }

  // --- Blood Sample Records ---

  Future<void> saveBloodSampleRecords(List<Map<String, dynamic>> records, {bool clearFirst = false}) async {
    final db = await database;
    final sw = Stopwatch()..start();
    await db.transaction((txn) async {
      if (clearFirst) await txn.delete('blood_sample_records');
      final batch = txn.batch();
      for (final r in records) {
        final regNo = r['Registration_Number']?.toString() ?? '';
        final familyId = r['Family_code']?.toString().trim().toUpperCase() ?? '';
        final name = r['Name']?.toString() ?? '';
        if (regNo.isNotEmpty) {
          batch.insert('blood_sample_records', {
            'reg_no': regNo,
            'family_id': familyId,
            'name': name,
            'data': jsonEncode(r),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
    debugPrint('LocalDB: Saved ${records.length} blood sample records in ${sw.elapsedMilliseconds}ms');
  }

  Future<Map<String, dynamic>?> getBloodSampleRecordByName(String familyId, String name) async {
    final db = await database;
    final results = await db.query(
      'blood_sample_records',
      where: 'UPPER(family_id) = ? AND name = ?',
      whereArgs: [familyId.trim().toUpperCase(), name],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
  }

  // --- Cervical Cancer Screening Records ---

  Future<void> saveCcRecords(List<Map<String, dynamic>> records, {bool clearFirst = false}) async {
    final db = await database;
    final sw = Stopwatch()..start();
    await db.transaction((txn) async {
      if (clearFirst) await txn.delete('cc_records');
      final batch = txn.batch();
      for (final r in records) {
        final regNo = r['Registration_Number']?.toString() ?? '';
        final familyId = r['Family_ID']?.toString().trim().toUpperCase() ?? '';
        final name = r['Name']?.toString() ?? '';
        if (regNo.isNotEmpty) {
          batch.insert('cc_records', {
            'reg_no': regNo,
            'family_id': familyId,
            'name': name,
            'data': jsonEncode(r),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
    debugPrint('LocalDB: Saved ${records.length} CC records in ${sw.elapsedMilliseconds}ms');
  }

  Future<Map<String, dynamic>?> getCcRecordByName(String familyId, String name) async {
    final db = await database;
    final results = await db.query(
      'cc_records',
      where: 'UPPER(family_id) = ? AND name = ?',
      whereArgs: [familyId.trim().toUpperCase(), name],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
  }
}
