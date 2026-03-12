import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

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
      version: 3,
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
            'data': jsonEncode(detail)
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
        'data': jsonEncode(detail)
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // --- Family Members Management ---

  Future<void> saveMember(Map<String, dynamic> member) async {
    final db = await database;
    // unique_id should be something like Aadhar or Serial or docId
    String uId = (member['unique_id'] ?? member['uniq_Registration_Number'] ?? member['Name'] + '_' + member['Family_Code']).toString();
    String fId = member['Family_Code']?.toString() ?? '';
    
    await db.insert('family_members', {
      'unique_id': uId,
      'family_id': fId,
      'data': jsonEncode(member)
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getMembersByFamily(String familyId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'family_members',
      where: 'family_id = ?',
      whereArgs: [familyId],
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
