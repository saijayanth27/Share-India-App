import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'aarogya_page.dart';
import 'app_drawer.dart';
import 'widget.dart';
import 'auth_service.dart';

class AarogyaReportPage extends StatefulWidget {
  const AarogyaReportPage({super.key});

  @override
  State<AarogyaReportPage> createState() => _AarogyaReportPageState();
}

class _AarogyaReportPageState extends State<AarogyaReportPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isAdmin = false;
  Set<String> _selectedIds = {};
  late Stream<QuerySnapshot> _reportStream;

  @override
  void initState() {
    super.initState();
    _reportStream = FirebaseFirestore.instance
        .collection('aarogya')
        .snapshots(includeMetadataChanges: true);
    
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    AuthService().isAdmin().then((v) { if (mounted) setState(() => _isAdmin = v); });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _deleteRecord(String docId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('aarogya').doc(docId).delete();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBulk() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Selected Records'),
        content: Text('Delete ${_selectedIds.length} record(s)? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete All', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final id in _selectedIds) {
      batch.delete(FirebaseFirestore.instance.collection('aarogya').doc(id));
    }
    await batch.commit();
    if (mounted) setState(() => _selectedIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Aarogya Report', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _reportStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final fromCache = snapshot.data?.metadata.isFromCache ?? false;
          final syncing = snapshot.data?.metadata.hasPendingWrites ?? false;
          var docs = snapshot.data?.docs ?? [];

          docs.sort((a, b) {
            final aVal = (a.data() as Map)['clientUpdatedAt'] ?? 0;
            final bVal = (b.data() as Map)['clientUpdatedAt'] ?? 0;
            return bVal.compareTo(aVal);
          });

          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            docs = docs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final fc = (d['Family_Code'] ?? d['Family_code'] ?? d['Family_Code_Creation'] ?? '').toString().toLowerCase();
              final name = (d['Name'] ?? '').toString().toLowerCase();
              return fc.contains(q) || name.contains(q);
            }).toList();
          }

          return Column(
            children: [
              _buildBanner(fromCache, syncing, docs.length),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [UpperCaseTextFormatter()],
                        decoration: InputDecoration(
                          hintText: 'Search by Family Code or Name...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        onSubmitted: (v) => setState(() => _searchQuery = v.trim()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => setState(() => _searchQuery = _searchController.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Search'),
                    ),
                  ],
                ),
              ),
              adminBulkDeleteBar(isAdmin: _isAdmin, totalCount: docs.length, selectedCount: _selectedIds.length, onToggleAll: () => setState(() { if (_selectedIds.length == docs.length) _selectedIds.clear(); else _selectedIds = docs.map((d) => d.id).toSet(); }), onDeleteSelected: _deleteBulk),
              if (docs.isEmpty)
                const Expanded(child: Center(child: Text('No records found.')))
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final familyCode = (data['Family_Code'] ?? data['Family_code'] ?? data['Family_Code_Creation'] ?? 'N/A').toString();
                      final name = (data['Name'] ?? 'N/A').toString();
                      final needsSync = data['needs_zoho_sync'] == true || data['is_temporary'] == true;
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        color: Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          onTap: !_isAdmin ? null : () => setState(() { if (_selectedIds.contains(doc.id)) _selectedIds.remove(doc.id); else _selectedIds.add(doc.id); }),
                          leading: reportItemLeading(isAdmin: _isAdmin, isSelected: _selectedIds.contains(doc.id), onToggle: () => setState(() { if (_selectedIds.contains(doc.id)) _selectedIds.remove(doc.id); else _selectedIds.add(doc.id); }), index: index, needsSync: needsSync),
                          title: Text(name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          subtitle: Text(familyCode,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (value) {
                              if (value == 'edit') {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => AarogyaPage(existingData: data, docId: doc.id),
                                ));
                              } else if (value == 'delete') {
                                _deleteRecord(doc.id);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, color: Colors.blue, size: 18), title: Text('Edit'), contentPadding: EdgeInsets.zero, dense: true)),
                              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red, size: 18), title: Text('Delete'), contentPadding: EdgeInsets.zero, dense: true)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBanner(bool fromCache, bool syncing, int count) {
    final label = fromCache ? 'Offline mode' : syncing ? 'Online – syncing...' : 'Online – synced';
    final bgColor = fromCache ? Colors.orange.shade100 : Colors.green.shade100;
    final textColor = fromCache ? Colors.orange.shade800 : Colors.green.shade800;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: bgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor)),
          Text('$count records', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }
}
