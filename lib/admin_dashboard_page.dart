import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Map<String, dynamic> _locationData = {};
  bool _isLoading = true;
  List<String> _states = [];
  String? _selectedState;

  String? _selectedDistrict;
  String? _selectedMandal;
  final TextEditingController _villageSearchController = TextEditingController();
  String _villageSearchQuery = '';

  @override
  void dispose() {
    _tabController.dispose();
    _villageSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // First, fetch the list of available states (documents in 'locations')
      final statesSnapshot = await FirebaseFirestore.instance.collection('locations').get();
      _states = statesSnapshot.docs.map((doc) => doc.id.toUpperCase()).toList();
      _states.sort();

      if (_states.isNotEmpty && _selectedState == null) {
        _selectedState = _states.contains('TELANGANA') ? 'TELANGANA' : _states.first;
      }

      if (_selectedState != null) {
        final doc = await FirebaseFirestore.instance
            .collection('locations')
            .doc(_selectedState!.toLowerCase())
            .get();
        
        if (doc.exists) {
          _locationData = doc.data() as Map<String, dynamic>;
        } else {
          _locationData = {'districts': {}};
        }
      }
    } catch (e) {
      debugPrint('Error loading states: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _saveToFirebase() async {
    if (_selectedState == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(_selectedState!.toLowerCase())
          .set(_locationData);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved successfully!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving changes: $e'), backgroundColor: Colors.red),
      );
    }
  }
  void _addItem(String type, String parentName) {
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
            onPressed: () async {
              if (nameController.text.isNotEmpty && codeController.text.isNotEmpty) {
                final name = nameController.text.trim();
                final code = codeController.text.trim().toUpperCase();
                setState(() {
                  _updateLocalData(type, name, code);
                });
                if (context.mounted) Navigator.pop(context);
                await _saveToFirebase();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _updateLocalData(String type, String name, String code) {
    if (type == 'State') {
       // State creation is handled separately via _saveToFirebase since it's a new document
       // but we'll add it to our _states list and switch to it.
       if (!_states.contains(name.toUpperCase())) {
         _states.add(name.toUpperCase());
         _selectedState = name.toUpperCase();
         _locationData = {'districts': {}};
       }
    } else if (type == 'District') {
      _locationData['districts'] ??= {};
      _locationData['districts'][name] = {'code': code, 'mandals': {}};
    } else if (type == 'Mandal' && _selectedState != null && _selectedDistrict != null) {
      final districts = _locationData['districts'] as Map<String, dynamic>;
      final district = districts[_selectedDistrict];
      district['mandals'] ??= {};
      district['mandals'][name] = {'code': code, 'Villages': {}};
    } else if (type == 'Village' && _selectedState != null && _selectedDistrict != null && _selectedMandal != null) {
      final districts = _locationData['districts'] as Map<String, dynamic>;
      final mandal = districts[_selectedDistrict]['mandals'][_selectedMandal];
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
            onPressed: () async {
              setState(() {
                if (type == 'State') {
                  FirebaseFirestore.instance.collection('locations').doc(name.toLowerCase()).delete();
                  _states.remove(name.toUpperCase());
                  if (_selectedState == name.toUpperCase()) {
                    _selectedState = _states.isNotEmpty ? _states.first : null;
                    _loadData();
                  }
                } else if (type == 'District') {
                  (_locationData['districts'] as Map<String, dynamic>).remove(name);
                  if (_selectedDistrict == name) {
                    _selectedDistrict = null;
                    _selectedMandal = null;
                  }
                } else if (type == 'Mandal') {
                  (_locationData['districts'][_selectedDistrict]['mandals'] as Map<String, dynamic>).remove(name);
                  if (_selectedMandal == name) _selectedMandal = null;
                } else if (type == 'Village') {
                  (_locationData['districts'][_selectedDistrict]['mandals'][_selectedMandal]['Villages'] as Map<String, dynamic>).remove(name);
                }
              });
              Navigator.pop(context);
              if (type != 'State') await _saveToFirebase();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.indigo.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.map_outlined), text: 'Locations'),
            Tab(icon: Icon(Icons.people_outline), text: 'Users'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Location Management
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.indigo.shade800, Colors.indigo.shade600],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Location Management',
                                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Hierarchical structure for family units',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: () => _addItem('State', 'App'),
                              icon: const Icon(Icons.add, color: Colors.white, size: 26),
                              tooltip: 'Add State',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _states.isEmpty
                        ? _buildEmptyState('No states configured. Start by adding one.')
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                            itemCount: _states.length,
                            itemBuilder: (context, index) => _buildStateTile(_states[index]),
                          ),
                    ),
                  ],
                ),

                // Tab 2: User Management
                _buildUserManagementTab(),
              ],
            ),
    );
  }

  Widget _buildStateTile(String stateName) {
    final districts = (_locationData['districts'] as Map<String, dynamic>?) ?? {};
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.map_outlined, color: Colors.indigo.shade700, size: 22),
          ),
          title: Text(stateName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87)),
          subtitle: Text('${districts.length} Districts', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(Icons.add, Colors.green, () {
                setState(() => _selectedState = stateName);
                _addItem('District', stateName);
              }),
              const SizedBox(width: 8),
              _buildActionButton(Icons.delete_outline, Colors.red, () => _deleteItem('State', stateName)),
            ],
          ),
          children: [
            if (districts.isEmpty)
              _buildEmptyHint('No districts in $stateName')
            else
              ... (districts.keys.toList()..sort()).map((dName) => _buildDistrictTile(stateName, dName)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictTile(String stateName, String districtName) {
    final mandals = (_locationData['districts'][districtName]['mandals'] as Map<String, dynamic>?) ?? {};
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: Colors.blueGrey.shade50.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        dense: true,
        leading: Icon(Icons.location_city_outlined, color: Colors.blue.shade700, size: 20),
        title: Text(districtName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black87)),
        subtitle: Text('${mandals.length} Mandals', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionButton(Icons.add, Colors.green, () {
              setState(() {
                 _selectedState = stateName;
                 _selectedDistrict = districtName;
              });
              _addItem('Mandal', districtName);
            }, mini: true),
            const SizedBox(width: 4),
            _buildActionButton(Icons.delete_outline, Colors.red, () => _deleteItem('District', districtName), mini: true),
          ],
        ),
        children: [
          if (mandals.isEmpty)
            _buildEmptyHint('No mandals in $districtName')
          else
            ...(mandals.keys.toList()..sort()).map((mName) => _buildMandalTile(stateName, districtName, mName)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMandalTile(String stateName, String districtName, String mandalName) {
    final villages = (_locationData['districts'][districtName]['mandals'][mandalName]['Villages'] as Map<String, dynamic>?) ?? {};
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ExpansionTile(
        dense: true,
        leading: Icon(Icons.account_balance_outlined, color: Colors.orange.shade700, size: 18),
        title: Text(mandalName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
        subtitle: Text('${villages.length} Villages', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionButton(Icons.add, Colors.green, () {
              setState(() {
                 _selectedState = stateName;
                 _selectedDistrict = districtName;
                 _selectedMandal = mandalName;
              });
              _addItem('Village', mandalName);
            }, mini: true),
            const SizedBox(width: 4),
            _buildActionButton(Icons.delete_outline, Colors.red, () => _deleteItem('Mandal', mandalName), mini: true),
          ],
        ),
        children: [
          if (villages.isEmpty)
            _buildEmptyHint('No villages in $mandalName')
          else
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
              child: Column(
                children: (villages.keys.toList()..sort()).map((vName) => _buildVillageTile(vName)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVillageTile(String villageName) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(Icons.home_outlined, color: Colors.grey.shade400, size: 16),
      title: Text(villageName, style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500)),
      trailing: IconButton(
        icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade200, size: 18),
        onPressed: () => _deleteItem('Village', villageName),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap, {bool mini = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(mini ? 4 : 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color.withOpacity(0.8), size: mini ? 18 : 20),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildEmptyHint(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Text(message, style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontStyle: FontStyle.italic)),
    );
  }

  Widget _buildUserManagementTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState('No users found.');
        }
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade800, Colors.indigo.shade600],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('User Management',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${docs.length} registered user(s)',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final email = data['email']?.toString() ?? 'Unknown';
                  final role = data['role']?.toString() ?? 'user';
                  final isAdmin = role == 'admin';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 1,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: isAdmin ? Colors.indigo.shade100 : Colors.green.shade100,
                        child: Icon(
                          isAdmin ? Icons.admin_panel_settings : Icons.person,
                          color: isAdmin ? Colors.indigo.shade700 : Colors.green.shade700,
                        ),
                      ),
                      title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                        isAdmin ? 'Admin' : 'User',
                        style: TextStyle(
                          color: isAdmin ? Colors.indigo.shade600 : Colors.green.shade600,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Delete user',
                        onPressed: () => _confirmDeleteUser(doc.id, email),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteUser(String docId, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to remove "$email" from the system? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance.collection('users').doc(docId).delete();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('User "$email" removed.'), backgroundColor: Colors.green),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
