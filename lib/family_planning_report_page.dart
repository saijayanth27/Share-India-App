import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'family_planning_page.dart';
import 'app_drawer.dart';

class FamilyPlanningReportPage extends StatefulWidget {
  const FamilyPlanningReportPage({super.key});

  @override
  State<FamilyPlanningReportPage> createState() => _FamilyPlanningReportPageState();
}

class _FamilyPlanningReportPageState extends State<FamilyPlanningReportPage> {
  final TextEditingController _searchController = TextEditingController();
  String _activeSearchQuery = '';
  String _searchField = 'All';
  bool _isSearchingActive = false;

  final Map<String, String> _fieldMapping = {
    'Sync': 'Sync',
    'Family Code': 'Family_Code',
    'Old Code': 'Family_Code_Old',
    'Final Code': 'Final_Family_Code',
    'Name': 'Name',
    'Husband Name': 'Husband_Name',
    'Entry Screen': 'Select_Entry_Screen',
    'Reg No': 'Registration_Number',
    'Oral?': 'Used_Oral_Contraceptives',
    'Oral Dur': 'How_Long_Use_Oral',
    'Oral Date': 'Last_Use_Oral_Date',
    'Inject?': 'Used_Injectable',
    'Inject Dur': 'How_Long_Using_Injectable',
    'Inject Date': 'Last_Use_Injectable_Date',
    'Condoms?': 'Used_Condoms',
    'Condoms Date': 'Condom_Last_Date',
    'Copper-T?': 'Used_CopperT',
    'Other?': 'Used_Other',
    'Other Details': 'If_Yes_Other',
    'Used?': 'Used',
    'Used Date': 'Used_Date',
    'Used Place': 'Used_Place',
  };

  void _deleteRecord(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('reproductive_health').doc(docId).delete();
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
              Navigator.push(context, MaterialPageRoute(builder: (context) => FamilyPlanningPage(existingData: record, docId: doc.id)));
            } else if (value == 'delete') {
              _deleteRecord(doc.id);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, color: Colors.blue), title: Text('Edit'), contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete'), contentPadding: EdgeInsets.zero)),
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
          if (label != 'Actions' && label != 'Sync')
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: _isSearchingActive
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search $_searchField...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () => setState(() {
                      _isSearchingActive = false;
                      _activeSearchQuery = '';
                      _searchController.clear();
                    }),
                  ),
                ),
                onChanged: (val) => setState(() => _activeSearchQuery = val),
              )
            : const Text('Family Planning Report', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade700, Colors.teal.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (!_isSearchingActive)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() {
                _isSearchingActive = true;
                _searchField = 'All';
              }),
            ),
        ],
      ),
      drawer: const AppDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reproductive_health').snapshots(includeMetadataChanges: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

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

          if (docs.isEmpty) {
            return Column(
              children: [
                _buildSyncBanner(fromCache, syncing, 0),
                const Expanded(child: Center(child: Text('No records found.'))),
              ],
            );
          }

          return Column(
            children: [
              _buildSyncBanner(fromCache, syncing, docs.length),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.teal.shade50),
                      headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                      columns: [
                        ..._fieldMapping.keys.map((label) => _buildSearchColumn(label)),
                        const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DataRow(
                          cells: [
                            ..._fieldMapping.keys.map((label) => _buildDataCell(label, data, doc)),
                            _buildDataCell('Actions', data, doc),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
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
