import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'cytology_page.dart';
import 'app_drawer.dart';

class CytologyReportPage extends StatefulWidget {
  const CytologyReportPage({super.key});

  @override
  State<CytologyReportPage> createState() => _CytologyReportPageState();
}

class _CytologyReportPageState extends State<CytologyReportPage> {
  final TextEditingController _searchController = TextEditingController();
  String _activeSearchQuery = '';
  String _searchField = 'All';
  bool _isSearchingActive = false;

  final Map<String, String> _fieldMapping = {
    'Sync': 'Sync',
    'Family Code': 'Family_Code_Creation',
    'Name': 'Name',
    'Reg No': 'Registration_Number',
    'Gender': 'Gender',
    'Date Received': 'Date_received',
    'Adequacy': 'Specimen_adequacy',
    'Diagnosis': 'Epithelial_cell_diagnosis',
  };

  void _deleteRecord(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this cytology entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('cytology').doc(docId).delete();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  DataCell _buildDataCell(String label, Map<String, dynamic> record, QueryDocumentSnapshot doc) {
    if (label == 'Sync') {
      final isTemp = record['is_temporary'] == true;
      final needsSync = record['needs_zoho_sync'] == true;
      return DataCell(
        (isTemp || needsSync)
            ? const Icon(Icons.timer, color: Colors.orange, size: 18)
            : const Icon(Icons.check_circle, color: Colors.green, size: 18),
      );
    }
    if (label == 'Actions') {
      return DataCell(
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CytologyPage(
                    existingData: record,
                    docId: doc.id,
                  ),
                ),
              );
            } else if (value == 'delete') {
              _deleteRecord(doc.id);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit, color: Colors.blue),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      );
    }

    final key = _fieldMapping[label];
    if (key == null) return const DataCell(Text(''));
    final value = record[key];

    if (value is Timestamp) {
      return DataCell(Text(DateFormat('dd-MMM-yyyy').format(value.toDate())));
    }
    return DataCell(Text(value?.toString() ?? ''));
  }

  DataColumn _buildSearchColumn(String label) {
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (label != 'Actions')
            IconButton(
              icon: const Icon(Icons.search, size: 16),
              onPressed: () => setState(() {
                _searchField = label;
                _isSearchingActive = true;
              }),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearchingActive
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by Name or Reg No...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _activeSearchQuery = '';
                        _isSearchingActive = false;
                      });
                    },
                  ),
                ),
                onChanged: (value) => setState(() => _activeSearchQuery = value.toLowerCase()),
              )
            : const Text('Cytology Reports', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.pink.shade700, Colors.pinkAccent.shade200],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (!_isSearchingActive)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _isSearchingActive = true),
            ),
        ],
      ),
      drawer: const AppDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('cytology').snapshots(includeMetadataChanges: true),
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
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aVal = aData['clientUpdatedAt'] ?? 0;
            final bVal = bData['clientUpdatedAt'] ?? 0;
            return bVal.compareTo(aVal);
          });

          if (_activeSearchQuery.isNotEmpty) {
            final query = _activeSearchQuery.toLowerCase();
            docs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              if (_searchField == 'All') {
                return data.values.any((v) => v.toString().toLowerCase().contains(query));
              } else {
                final key = _fieldMapping[_searchField];
                return data[key]?.toString().toLowerCase().contains(query) ?? false;
              }
            }).toList();
          }

          return Column(
            children: [
              _buildSyncBanner(fromCache, syncing, docs.length),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final docId = doc.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.pink.shade700,
                          child: Text((index + 1).toString(), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(data['Name'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Reg No: ${data['Registration_Number'] ?? 'N/A'}'),
                            Text('Family Code: ${data['Family_Code_Creation'] ?? 'N/A'}'),
                            if (data['Date_received'] != null)
                              Text('Received: ${data['Date_received'] is Timestamp ? DateFormat('dd-MMM-yyyy').format((data['Date_received'] as Timestamp).toDate()) : data['Date_received'].toString()}'),
                            Text('Diagnosis: ${data['Epithelial_cell_diagnosis'] ?? 'N/A'}'),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CytologyPage(
                                    existingData: data,
                                    docId: docId,
                                  ),
                                ),
                              );
                            } else if (value == 'delete') {
                              _deleteRecord(docId);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, color: Colors.blue), title: Text('Edit'), contentPadding: EdgeInsets.zero)),
                            const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete'), contentPadding: EdgeInsets.zero)),
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

  Widget _buildSyncBanner(bool fromCache, bool syncing, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: fromCache ? Colors.orange.shade100 : Colors.green.shade100,
      child: Text(
        '${fromCache ? 'Offline mode' : syncing ? 'Online – syncing...' : 'Online – synced'}  |  $count records',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
