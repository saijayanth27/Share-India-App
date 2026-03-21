import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'ante_natal_care_page.dart';
import 'app_drawer.dart';
import 'language_provider.dart';

class AnteNatalCareReportPage extends StatefulWidget {
  const AnteNatalCareReportPage({super.key});

  @override
  State<AnteNatalCareReportPage> createState() => _AnteNatalCareReportPageState();
}

class _AnteNatalCareReportPageState extends State<AnteNatalCareReportPage> {
  final TextEditingController _searchController = TextEditingController();
  String _activeSearchQuery = '';
  String _searchField = 'All';
  bool _isSearchingActive = false;

  final Map<String, String> _fieldMapping = {
    'Sync': 'Sync',
    'Family Code': 'Family_Code',
    'Name': 'Female',
    'Husband Name': 'Husband_Name',
    'LMP Date': 'LMP_Date',
    'Select Entry': 'Select_Entry_Screen',
    'Uniq Reg No': 'uniq_Registration_Number',
    'Reg No': 'Registration_Number',
    'TT1 Given': 'st_Given_Y_N',
    'TT1 By': 'st_Given_By',
    'TT1 Date': 'st_Dt',
    'TT2 Given': 'nd_Given_Y_N',
    'TT2 By': 'nd_Given_By',
    'TT2 Date': 'nd_Dt',
    'IFA1 Given': 'st_Given_Y_N1',
    'IFA1 Date': 'st_Dt1',
    'IFA1 By': 'st_Given_By1',
    'IFA2 Given': 'nd_Given_Y_N1',
    'IFA2 Date': 'nd_Dt1',
    'IFA2 By': 'nd_Given_By1',
    'IFA3 Given': 'rd_Given_Y_N',
    'IFA3 Date': 'rd_Dt',
    'IFA3 By': 'rd_Given_Y_N1',
    'IFA4 Given': 'TH_Given_Y_N',
    'IFA4 Date': 'th_Dt',
    'IFA4 By': 'TH_Given_Y_N1',
    'Delivery Type': 'Delivery_Type',
    'Delivery Date': 'Delivery_Dt',
    'Delivery Place': 'Delivery_Place',
    'Place Details': 'Delivery_Place_Details',
    'Outcome': 'Delivery',
    'Live Births': 'Total_Live_Births',
    'Remarks': 'Remarks2',
    'Gender': 'Gender',
    'No. of Births': 'No_of_Births',
    'Female Births': 'No_of_Birth_of_Female1',
  };

  void _deleteRecord(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Delete Record')),
        content: Text(tr('Are you sure you want to delete this ANC record?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('ante_natal_care').doc(docId).delete();
              Navigator.pop(context);
            },
            child: Text(tr('Delete'), style: const TextStyle(color: Colors.red)),
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
              Navigator.push(context, MaterialPageRoute(builder: (context) => AnteNatalCarePage(existingData: record, docId: doc.id)));
            } else if (value == 'delete') {
              _deleteRecord(doc.id);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: Text(tr('Edit')),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(tr('Delete')),
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
            Text(tr(label), style: const TextStyle(fontWeight: FontWeight.bold)),
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
    return LocalizedBuilder(
      builder: (context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: _isSearchingActive
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: tr('Search {field}...')
                        .replaceFirst('{field}', tr(_searchField)),
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
              : Text(tr('ANC Report'), style: const TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.pink.shade700, Colors.pink.shade400],
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
        stream: FirebaseFirestore.instance.collection('ante_natal_care').snapshots(includeMetadataChanges: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${tr('Error')}: ${snapshot.error}'));
          }

          final fromCache = snapshot.data?.metadata.isFromCache ?? false;
          final syncing = snapshot.data?.metadata.hasPendingWrites ?? false;

          var docs = snapshot.data?.docs ?? [];
          
          // Sort by latest update first
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
                Expanded(child: Center(child: Text(tr('No records found.')))),
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
                      headingRowColor: WidgetStateProperty.all(Colors.pink.shade50),
                      headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.pink.shade900),
                      columns: [
                        ..._fieldMapping.keys.map((label) => _buildSearchColumn(label)),
                        DataColumn(
                          label: Text(
                            tr('Actions'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
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
