import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map<String, dynamic> _locationData = {};
  bool _isLoading = true;
  String? _selectedState = 'Telangana';

  String? _selectedDistrict;
  String? _selectedMandal;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    // Force refresh from Firebase
    await LocationService().refreshFromFirebase();
    setState(() {
      _locationData = LocationService().locationData;
      _isLoading = false;
    });
  }

  Future<void> _saveToFirebase() async {
    try {
      await FirebaseFirestore.instance
          .collection('locations')
          .doc('telangana') // For now, we use 'telangana' as the primary doc
          .set(_locationData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving changes: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _addItem(String type, String parentName) {
    String? newItemName;
    String? newItemCode;
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New $type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: '$type Name')),
            TextField(controller: codeController, decoration: InputDecoration(labelText: '$type Code (2-3 chars)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && codeController.text.isNotEmpty) {
                setState(() {
                  _updateLocalData(type, nameController.text.trim(), codeController.text.trim().toUpperCase());
                });
                Navigator.pop(context);
                _saveToFirebase();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _updateLocalData(String type, String name, String code) {
    if (type == 'District') {
      _locationData['districts'] ??= {};
      _locationData['districts'][name] = {'code': code, 'mandals': {}};
    } else if (type == 'Mandal' && _selectedState != null && _selectedDistrict != null) {
      final district = _locationData['districts'][_selectedDistrict];
      district['mandals'] ??= {};
      district['mandals'][name] = {'code': code, 'Villages': {}};
    } else if (type == 'Village' && _selectedState != null && _selectedDistrict != null && _selectedMandal != null) {
      final mandal = _locationData['districts'][_selectedDistrict]['mandals'][_selectedMandal];
      mandal['Villages'] ??= {};
      mandal['Villages'][name] = {'code': code};
    }
  }

  void _deleteItem(String type, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $type'),
        content: Text('Are you sure you want to delete $name? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() {
                if (type == 'District') {
                  _locationData['districts'].remove(name);
                  if (_selectedDistrict == name) {
                    _selectedDistrict = null;
                    _selectedMandal = null;
                  }
                } else if (type == 'Mandal') {
                  _locationData['districts'][_selectedDistrict]['mandals'].remove(name);
                  if (_selectedMandal == name) _selectedMandal = null;
                } else if (type == 'Village') {
                  _locationData['districts'][_selectedDistrict]['mandals'][_selectedMandal]['Villages'].remove(name);
                }
              });
              Navigator.pop(context);
              _saveToFirebase();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final districts = (_locationData['districts'] as Map<String, dynamic>?) ?? {};
    final mandals = _selectedDistrict != null 
        ? (districts[_selectedDistrict]['mandals'] as Map<String, dynamic>?) ?? {}
        : {};
    final villages = _selectedMandal != null
        ? (mandals[_selectedMandal]['Villages'] as Map<String, dynamic>?) ?? {}
        : {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Manage Locations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // Districts Section
                  _buildSectionHeader('Districts', () => _addItem('District', 'State')),
                  _buildList(districts.keys.cast<String>().toList(), (name) {
                    setState(() {
                      _selectedDistrict = name;
                      _selectedMandal = null;
                    });
                  }, _selectedDistrict, 'District'),
                  
                  const Divider(height: 40),
                  
                  // Mandals Section
                  if (_selectedDistrict != null) ...[
                    _buildSectionHeader('Mandals in $_selectedDistrict', () => _addItem('Mandal', _selectedDistrict!)),
                  _buildList(mandals.keys.cast<String>().toList(), (name) {
                    setState(() {
                      _selectedMandal = name;
                    });
                  }, _selectedMandal, 'Mandal'),
                  const Divider(height: 40),
                ],
                
                // Villages Section
                if (_selectedMandal != null) ...[
                  _buildSectionHeader('Villages in $_selectedMandal', () => _addItem('Village', _selectedMandal!)),
                  _buildList(villages.keys.cast<String>().toList(), (name) {}, null, 'Village'),
                ],

                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
        IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: onAdd),
      ],
    );
  }

  Widget _buildList(List<String> items, Function(String) onSelect, String? selectedItem, String type) {
    if (items.isEmpty) return const Padding(padding: EdgeInsets.all(8.0), child: Text('No items found. Click + to add.'));
    
    return Wrap(
      spacing: 8,
      children: items.map((name) {
        final isSelected = name == selectedItem;
        return ActionChip(
          label: Text(name),
          backgroundColor: isSelected ? Colors.indigo.shade100 : Colors.grey.shade100,
          labelStyle: TextStyle(color: isSelected ? Colors.indigo : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
          onPressed: () => onSelect(name),
          avatar: IconButton(
            icon: const Icon(Icons.close, size: 14, color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _deleteItem(type, name),
          ),
        );
      }).toList(),
    );
  }
}
