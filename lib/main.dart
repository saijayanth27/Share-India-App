// This is the COMPLETE main.dart file
// Location: lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart' hide Context;
import 'package:path/path.dart' show join;
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  print("Firebase Initialized");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Code Creation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const FamilyCodeCreationPage(),
    );
  }
}

// Database Helper Class
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('family_codes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE family_codes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        family_id TEXT,
        house_no TEXT,
        state TEXT,
        family_type TEXT,
        head_of_family TEXT,
        family_status TEXT,
        own_house TEXT,
        no_of_rooms TEXT,
        type_of_house TEXT,
        roof TEXT,
        wall TEXT,
        floor TEXT,
        where_cook TEXT,
        where_cook_other TEXT,
        separate_kitchen TEXT,
        fuel_types TEXT,
        fuel_other TEXT,
        mainly_used TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');
  }

  Future<int> insertFamilyCode(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('family_codes', data);
  }

  Future<List<Map<String, dynamic>>> getAllFamilyCodes() async {
    final db = await database;
    return await db.query('family_codes', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRecords() async {
    final db = await database;
    return await db.query('family_codes', where: 'synced = ?', whereArgs: [0]);
  }

  Future<int> markAsSynced(int id) async {
    final db = await database;
    return await db.update(
      'family_codes',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteRecord(int id) async {
    final db = await database;
    return await db.delete('family_codes', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateFamilyCode(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'family_codes',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// Main Form Page
class FamilyCodeCreationPage extends StatefulWidget {
  final Map<String, dynamic>? record;
  const FamilyCodeCreationPage({super.key, this.record});

  @override
  State<FamilyCodeCreationPage> createState() => _FamilyCodeCreationPageState();
}

class _FamilyCodeCreationPageState extends State<FamilyCodeCreationPage> {
  bool _isEdit = false;
  int? _recordId;
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  @override
  void initState() {
    super.initState();

    if (widget.record != null) {
      _isEdit = true;
      _recordId = widget.record!['id'];

      _familyIdController.text = widget.record!['family_id'] ?? '';
      _houseNoController.text = widget.record!['house_no'] ?? '';
      _headOfFamilyController.text = widget.record!['head_of_family'] ?? '';
      _noOfRoomsController.text = widget.record!['no_of_rooms'] ?? '';
      _whereCookOtherController.text = widget.record!['where_cook_other'] ?? '';
      _fuelOtherController.text = widget.record!['fuel_other'] ?? '';
      _mainlyUsedController.text = widget.record!['mainly_used'] ?? '';
      _selectedState = widget.record!['state']?.toString().trim();
      _selectedFamilyType = widget.record!['family_type'];
      _selectedTypeOfHouse = widget.record!['type_of_house'];
      _selectedRoof = widget.record!['roof'];
      _selectedWall = widget.record!['wall'];
      _selectedFloor = widget.record!['floor'];

      _familyStatus = widget.record!['family_status'];
      _ownHouse = widget.record!['own_house'];
      _whereCook = widget.record!['where_cook'];
      _separateKitchen = widget.record!['separate_kitchen'];

      _fuelTypes.clear();
      if (widget.record!['fuel_types'] != null) {
        _fuelTypes.addAll(
          widget.record!['fuel_types'].split(','),
        );
      }
    }
  }

  final Map<String, String> _statePrefixes = {
    'Telangana': 'TS',
  };

  // Text Controllers
  final _familyIdController = TextEditingController();
  final _houseNoController = TextEditingController();
  final _headOfFamilyController = TextEditingController();
  final _noOfRoomsController = TextEditingController();
  final _whereCookOtherController = TextEditingController();
  final _fuelOtherController = TextEditingController();
  final _mainlyUsedController = TextEditingController();

  // Dropdown values
  String? _selectedState;
  String? _selectedFamilyType;
  String? _selectedTypeOfHouse;
  String? _selectedRoof;
  String? _selectedWall;
  String? _selectedFloor;

  // Radio button values
  String _familyStatus = '0';
  String _ownHouse = '1';
  String _whereCook = '1';
  String _separateKitchen = '1';

  // Checkbox values for fuel types
  final Set<String> _fuelTypes = {};

  bool _isSaving = false;

  @override
  void dispose() {
    _familyIdController.dispose();
    _houseNoController.dispose();
    _headOfFamilyController.dispose();
    _noOfRoomsController.dispose();
    _whereCookOtherController.dispose();
    _fuelOtherController.dispose();
    _mainlyUsedController.dispose();
    super.dispose();
  }

  Future<void> _generateFamilyId(String state) async {
    // Get prefix for selected state
    String prefix = _statePrefixes[state] ?? 'XX';

    // Query local database for existing IDs with this prefix
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> records = await db.query(
      'family_codes',
      where: 'family_id LIKE ?',
      whereArgs: ['$prefix%'],
      orderBy: 'family_id DESC',
      limit: 1,
    );

    int nextNumber = 1;

    if (records.isNotEmpty) {
      String lastId = records[0]['family_id'] ?? '';
      // Extract number from last ID (e.g., "TS005" -> 5)
      String numberPart = lastId.replaceAll(RegExp(r'[^0-9]'), '');
      if (numberPart.isNotEmpty) {
        nextNumber = int.parse(numberPart) + 1;
      }
    }

    // Format: TS001, TS002, etc.
    String newFamilyId = '$prefix${nextNumber.toString().padLeft(3, '0')}';

    // Set the Family ID
    setState(() {
      _familyIdController.text = newFamilyId;
    });
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final data = {
        'family_id': _familyIdController.text,
        'house_no': _houseNoController.text,
        'state': _selectedState ?? '',
        'family_type': _selectedFamilyType ?? '',
        'head_of_family': _headOfFamilyController.text,
        'family_status': _familyStatus,
        'own_house': _ownHouse,
        'no_of_rooms': _noOfRoomsController.text,
        'type_of_house': _selectedTypeOfHouse ?? '',
        'roof': _selectedRoof ?? '',
        'wall': _selectedWall ?? '',
        'floor': _selectedFloor ?? '',
        'where_cook': _whereCook,
        'where_cook_other': _whereCookOtherController.text,
        'separate_kitchen': _separateKitchen,
        'fuel_types': _fuelTypes.join(','),
        'fuel_other': _fuelOtherController.text,
        'mainly_used': _mainlyUsedController.text,
        'synced': 0,
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        if (_isEdit) {
          await _dbHelper.updateFamilyCode(_recordId!, data);
        } else {
          await _dbHelper.insertFamilyCode(data);
        }

        await _syncToFirebase(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEdit
                    ? '✓ Record updated & synced'
                    : '✓ Record saved & synced',
              ),
              backgroundColor: Colors.green,
            ),
          );
         _clearForm();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _syncToFirebase(Map<String, dynamic> data) async {
    final docId = data['family_id'];

    await FirebaseFirestore.instance.collection('client').doc(docId).set(
      {
        ...data,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true), 
    );
  }

  void _clearForm() {
    _familyIdController.clear();
    _houseNoController.clear();
    _headOfFamilyController.clear();
    _noOfRoomsController.clear();
    _whereCookOtherController.clear();
    _fuelOtherController.clear();
    _mainlyUsedController.clear();
    setState(() {
      _selectedState = null;
      _selectedFamilyType = null;
      _selectedTypeOfHouse = null;
      _selectedRoof = null;
      _selectedWall = null;
      _selectedFloor = null;
      _familyStatus = '0';
      _ownHouse = '1';
      _whereCook = '1';
      _separateKitchen = '1';
      _fuelTypes.clear();
    });
  }

  Future<void> _viewSavedRecords() async {
    final records = await _dbHelper.getAllFamilyCodes();
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavedRecordsPage(records: records),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Code Creation'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: _viewSavedRecords,
            tooltip: 'View Saved Records',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Family ID and House No
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _familyIdController,
                    decoration: const InputDecoration(
                      labelText: 'Family ID',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _houseNoController,
                    decoration: const InputDecoration(
                      labelText: 'House No',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // State and Family Type
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: (_selectedState != null &&
                            [
                              'Telangana',
                              'Andhra Pradesh',
                              'Karnataka',
                              'Tamil Nadu',
                              'Maharashtra'
                            ].contains(_selectedState))
                        ? _selectedState
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'State',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      'Telangana',
                      'Andhra Pradesh',
                      'Karnataka',
                      'Tamil Nadu',
                      'Maharashtra'
                    ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: _isEdit
                        ? null
                        : (val) async {
                            setState(() {
                              _selectedState = val;
                            });
                            if (val != null) {
                              await _generateFamilyId(val);
                            }
                          },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: (_selectedFamilyType != null &&
                            ['Nuclear', 'Joint', 'Extended']
                                .contains(_selectedFamilyType))
                        ? _selectedFamilyType
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Family Type',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: ['Nuclear', 'Joint', 'Extended']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedFamilyType = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Head of Family
            TextFormField(
              controller: _headOfFamilyController,
              decoration: const InputDecoration(
                labelText: 'Head of the family',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Family Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Family Status',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('(0) Vacant'),
                            value: '0',
                            groupValue: _familyStatus,
                            onChanged: (val) =>
                                setState(() => _familyStatus = val!),
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('(1) Active'),
                            value: '1',
                            groupValue: _familyStatus,
                            onChanged: (val) =>
                                setState(() => _familyStatus = val!),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Question 1: Do you Own this house
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. Do you Own this house?',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('(1) Yes'),
                            value: '1',
                            groupValue: _ownHouse,
                            onChanged: (val) =>
                                setState(() => _ownHouse = val!),
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('(2) No'),
                            value: '2',
                            groupValue: _ownHouse,
                            onChanged: (val) =>
                                setState(() => _ownHouse = val!),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Question 2: No of rooms
            TextFormField(
              controller: _noOfRoomsController,
              decoration: const InputDecoration(
                labelText: '2. No of rooms',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // Question 3: House Details
            const Text('3',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: (_selectedTypeOfHouse != null &&
                            ['Pucca', 'Semi-Pucca', 'Kuchha']
                                .contains(_selectedTypeOfHouse))
                        ? _selectedTypeOfHouse
                        : null,
                    decoration: const InputDecoration(
                      labelText: '3. Type of House',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: ['Pucca', 'Semi-Pucca', 'Kuchha']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedTypeOfHouse = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: (_selectedRoof != null &&
                            [
                              'Concrete',
                              'Tiles',
                              'Thatch',
                              'Metal Sheet',
                              'Asbestos'
                            ].contains(_selectedRoof))
                        ? _selectedRoof
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Roof',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      'Concrete',
                      'Tiles',
                      'Thatch',
                      'Metal Sheet',
                      'Asbestos'
                    ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedRoof = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: (_selectedWall != null &&
                            ['Brick', 'Stone', 'Mud', 'Wood', 'Cement']
                                .contains(_selectedWall))
                        ? _selectedWall
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Wall',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: ['Brick', 'Stone', 'Mud', 'Wood', 'Cement']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedWall = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: (_selectedFloor != null &&
                            ['Cement', 'Tiles', 'Mud', 'Wood', 'Marble']
                                .contains(_selectedFloor))
                        ? _selectedFloor
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Floor',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: ['Cement', 'Tiles', 'Mud', 'Wood', 'Marble']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedFloor = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Question 4: Where do you cook
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('4. Where do you cook?',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    RadioListTile<String>(
                      title: const Text('(1) In the House'),
                      value: '1',
                      groupValue: _whereCook,
                      onChanged: (val) => setState(() => _whereCook = val!),
                      dense: true,
                    ),
                    RadioListTile<String>(
                      title: const Text('(2) In a separate Building'),
                      value: '2',
                      groupValue: _whereCook,
                      onChanged: (val) => setState(() => _whereCook = val!),
                      dense: true,
                    ),
                    RadioListTile<String>(
                      title: const Text('(3) Outdoors'),
                      value: '3',
                      groupValue: _whereCook,
                      onChanged: (val) => setState(() => _whereCook = val!),
                      dense: true,
                    ),
                    RadioListTile<String>(
                      title: const Text('(4) Other'),
                      value: '4',
                      groupValue: _whereCook,
                      onChanged: (val) => setState(() => _whereCook = val!),
                      dense: true,
                    ),
                    if (_whereCook == '4')
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: TextFormField(
                          controller: _whereCookOtherController,
                          decoration: const InputDecoration(
                            labelText: 'If Others Please Mention',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Question 5: Separate Room for kitchen
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('5. Separate Room for kitchen',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('(1) Yes'),
                            value: '1',
                            groupValue: _separateKitchen,
                            onChanged: (val) =>
                                setState(() => _separateKitchen = val!),
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('(2) No'),
                            value: '2',
                            groupValue: _separateKitchen,
                            onChanged: (val) =>
                                setState(() => _separateKitchen = val!),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Question 6: Type of fuel
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('6. Type of fuel used for cooking?',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildCheckbox('1', 'Electricity'),
                        _buildCheckbox('2', 'LPG/N.GAS'),
                        _buildCheckbox('3', 'Kerosene'),
                        _buildCheckbox('4', 'Wood'),
                        _buildCheckbox('5', 'Coal'),
                        _buildCheckbox('6', 'Crop Residues'),
                        _buildCheckbox('7', 'Dung Cakes'),
                        _buildCheckbox('77', 'Other'),
                      ],
                    ),
                    if (_fuelTypes.contains('77'))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextFormField(
                          controller: _fuelOtherController,
                          decoration: const InputDecoration(
                            labelText: 'If Others Please Mention',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _mainlyUsedController,
                      decoration: const InputDecoration(
                        labelText: 'Mainly Used',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveForm,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _isSaving ? 'SAVING...' : 'SAVE',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(String value, String label) {
    return SizedBox(
      width: 160,
      child: CheckboxListTile(
        title: Text('($value) $label', style: const TextStyle(fontSize: 13)),
        value: _fuelTypes.contains(value),
        onChanged: (bool? checked) {
          setState(() {
            if (checked == true) {
              _fuelTypes.add(value);
            } else {
              _fuelTypes.remove(value);
            }
          });
        },
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}

// Saved Records Page
class SavedRecordsPage extends StatefulWidget {
  final List<Map<String, dynamic>> records;

  const SavedRecordsPage({super.key, required this.records});

  @override
  State<SavedRecordsPage> createState() => _SavedRecordsPageState();
}

class _SavedRecordsPageState extends State<SavedRecordsPage> {
  late List<Map<String, dynamic>> _records;

  @override
  void initState() {
    super.initState();
    _records = widget.records;
  }

  Future<void> _deleteRecord(int id, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteRecord(id);
      setState(() {
        _records.removeAt(index);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Record deleted'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Records (${_records.length})'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
    ),
    body: _records.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No records found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
            columnSpacing: 20,
            headingRowColor:
                MaterialStateProperty.all(Colors.blue.shade100),
            columns: const [
              DataColumn(label: Text('Family ID')),
              DataColumn(label: Text('House No')),
              DataColumn(label: Text('Head')),
              DataColumn(label: Text('State')),
              DataColumn(label: Text('Rooms')),
              DataColumn(label: Text('Sync')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _records.map((record) {
              final isSynced = record['synced'] == 1;

              return DataRow(
                cells: [
                  DataCell(Text(record['family_id'] ?? '')),
                  DataCell(Text(record['house_no'] ?? '')),
                  DataCell(Text(record['head_of_family'] ?? '')),
                  DataCell(Text(record['state'] ?? '')),
                  DataCell(Text(record['no_of_rooms'] ?? '')),
                  DataCell(
                    Row(
                      children: [
                        Icon(
                          isSynced
                              ? Icons.cloud_done
                              : Icons.cloud_off,
                          color: isSynced
                              ? Colors.green
                              : Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(isSynced ? 'Synced' : 'Pending'),
                      ],
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.blue),
                          onPressed: () async {
                            final updated =
                                await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    FamilyCodeCreationPage(
                                        record: record),
                              ),
                            );
                            if (updated == true) {
                              final refreshed =
                                  await DatabaseHelper.instance
                                      .getAllFamilyCodes();
                              setState(() => _records = refreshed);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.red),
                          onPressed: () =>
                              _deleteRecord(record['id'],
                                  _records.indexOf(record)),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),

    );
  }

  void _showRecordDetails(Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Family ID', record['family_id']),
              _buildDetailRow('House No', record['house_no']),
              _buildDetailRow('State', record['state']),
              _buildDetailRow('Family Type', record['family_type']),
              _buildDetailRow('Head of Family', record['head_of_family']),
              _buildDetailRow('No of Rooms', record['no_of_rooms']),
              _buildDetailRow('Type of House', record['type_of_house']),
              _buildDetailRow('Roof', record['roof']),
              _buildDetailRow('Wall', record['wall']),
              _buildDetailRow('Floor', record['floor']),
              _buildDetailRow('Fuel Types', record['fuel_types']),
              _buildDetailRow('Mainly Used', record['mainly_used']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value?.toString() ?? 'N/A'),
          ),
        ],
      ),
    );
  }
}
