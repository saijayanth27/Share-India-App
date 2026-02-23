import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'app_drawer.dart';
import 'bpgluco.dart';

class HealthReportPage extends StatefulWidget {
  const HealthReportPage({super.key});

  @override
  State<HealthReportPage> createState() => _HealthReportPageState();
}

class _HealthReportPageState extends State<HealthReportPage> {
  final TextEditingController _searchController = TextEditingController();
  String _activeSearchQuery = '';
  String _searchField = 'All';
  bool _isSearchingActive = false;

  final Map<String, String> _fieldMapping = {
    'Date & Time': 'timestamp',
    'BP 1': 'systolic',
    'BP 2': 'systolic2',
    'BP 3': 'systolic3',
    'Sugar': 'sugar_value',
  };
  void _deleteRecord(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this health record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('health_readings').doc(docId).delete();
              Navigator.pop(context);
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
      appBar: AppBar(
        title: _isSearchingActive
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search $_searchField...',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _isSearchingActive = false;
                      _activeSearchQuery = '';
                      _searchController.clear();
                    }),
                  ),
                ),
                onChanged: (val) => setState(() => _activeSearchQuery = val),
              )
            : const Text('Health Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
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
        stream: FirebaseFirestore.instance
            .collection('health_readings')
            .orderBy('clientUpdatedAt', descending: true)
            .snapshots(includeMetadataChanges: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          var docs = snapshot.data?.docs ?? [];
          final fromCache = snapshot.data?.metadata.isFromCache ?? false;
          final syncing = snapshot.data?.metadata.hasPendingWrites ?? false;

          // Sorting logic (latest first)
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aVal = aData['clientUpdatedAt'] ?? 0;
            final bVal = bData['clientUpdatedAt'] ?? 0;
            return bVal.compareTo(aVal);
          });

          // Search filtering
          if (_activeSearchQuery.isNotEmpty) {
            final query = _activeSearchQuery.toLowerCase();
            docs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              if (_searchField == 'All') {
                return data.values.any((v) => v.toString().toLowerCase().contains(query));
              } else {
                final key = _fieldMapping[_searchField];
                if (key == null) return false;
                if (key == 'systolic' || key == 'systolic2' || key == 'systolic3') {
                  // Check sys/dia/pulse for BP slots
                  final suffix = key == 'systolic' ? '' : key.substring(8); // '' or '2' or '3'
                  final s = data['systolic$suffix']?.toString() ?? '';
                  final d = data['diastolic$suffix']?.toString() ?? '';
                  final p = data['pulse$suffix']?.toString() ?? '';
                  return s.contains(query) || d.contains(query) || p.contains(query);
                }
                return data[key]?.toString().toLowerCase().contains(query) ?? false;
              }
            }).toList();
          }

          final totalCount = docs.length;

          return Column(
            children: [
              // Online status banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: fromCache ? Colors.orange.shade100 : Colors.green.shade100,
                child: Text(
                  '${fromCache ? 'Offline mode' : syncing ? 'Online – syncing...' : 'Online – synced'}  |  $totalCount / $totalCount records',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: docs.isEmpty 
                  ? const Center(child: Text('No health records found.', style: TextStyle(color: Colors.grey)))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 25,
                          headingRowHeight: 56,
                          dataRowHeight: 64,
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                          columns: [
                            const DataColumn(label: Text('Actions')),
                            const DataColumn(label: Text('Sync')),
                            _buildHeaderWithSearch('Date & Time'),
                            _buildHeaderWithSearch('BP 1'),
                            _buildHeaderWithSearch('BP 2'),
                            _buildHeaderWithSearch('BP 3'),
                            _buildHeaderWithSearch('Sugar'),
                            const DataColumn(label: Text('Images')),
                          ],
                          rows: docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final bool isPending = data['needs_gemini_extraction'] == true || data['needs_storage_upload'] == true;
                            final bool hasBP = data['has_bp'] == true;
                            final bool hasSugar = data['has_sugar'] == true;

                            String bp1 = '--';
                            if (hasBP) {
                              if (data['bp_needs_extraction'] == true && data['systolic'] == null) bp1 = '...';
                              else bp1 = '${data['systolic'] ?? '--'}/${data['diastolic'] ?? '--'} (${data['pulse'] ?? '--'})';
                            }

                            String bp2 = '--';
                            if (data['systolic2'] != null || data['diastolic2'] != null) {
                              bp2 = '${data['systolic2'] ?? '--'}/${data['diastolic2'] ?? '--'} (${data['pulse2'] ?? '--'})';
                            } else if (data['bp_image_path2'] != null) {
                              bp2 = '...';
                            }

                            String bp3 = '--';
                            if (data['systolic3'] != null || data['diastolic3'] != null) {
                              bp3 = '${data['systolic3'] ?? '--'}/${data['diastolic3'] ?? '--'} (${data['pulse3'] ?? '--'})';
                            } else if (data['bp_image_path3'] != null) {
                              bp3 = '...';
                            }
                            
                            String sugarStr = '--';
                            if (hasSugar) {
                              if (data['sugar_needs_extraction'] == true && data['sugar_value'] == null) sugarStr = '...';
                              else sugarStr = '${data['sugar_value'] ?? '--'} mg/dL';
                            }

                            return DataRow(cells: [
                              DataCell(
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => HealthReadingsPage(
                                            existingData: data,
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
                              ),
                              DataCell(Icon(
                                isPending ? Icons.timer_outlined : Icons.check_circle_rounded,
                                color: isPending ? Colors.orange : Colors.green,
                                size: 22,
                              )),
                              DataCell(Text(data['timestamp'] ?? '', style: const TextStyle(fontSize: 12))),
                              DataCell(Text(bp1, style: const TextStyle(fontWeight: FontWeight.w500))),
                              DataCell(Text(bp2)),
                              DataCell(Text(bp3)),
                              DataCell(Text(sugarStr, style: const TextStyle(fontWeight: FontWeight.w500))),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (data['bp_image_path'] != null || data['bp_storage_path'] != null) 
                                      _buildImageButton(data['bp_image_path'], data['bp_storage_path'], 'BP 1'),
                                    if (data['bp_image_path2'] != null || data['bp_storage_path2'] != null) 
                                      _buildImageButton(data['bp_image_path2'], data['bp_storage_path2'], 'BP 2'),
                                    if (data['bp_image_path3'] != null || data['bp_storage_path3'] != null) 
                                      _buildImageButton(data['bp_image_path3'], data['bp_storage_path3'], 'BP 3'),
                                    if (data['sugar_image_path'] != null || data['sugar_storage_path'] != null) 
                                      _buildImageButton(data['sugar_image_path'], data['sugar_storage_path'], 'Sugar'),
                                  ],
                              )),
                            ]);
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

  Widget _buildImageButton(String? localPath, String? storagePath, String label) {
    if (localPath == null && storagePath == null) return const SizedBox.shrink();
    
    return IconButton(
      icon: const Icon(Icons.image, size: 20, color: Colors.blue),
      tooltip: 'View $label',
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                    maxWidth: MediaQuery.of(context).size.width * 0.8,
                  ),
                  child: _buildImageDisplay(localPath, storagePath),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageDisplay(String? localPath, String? storagePath) {
    // 1. Try local file first (fastest, keeps original quality)
    if (localPath != null && File(localPath).existsSync()) {
      return Image.file(File(localPath), fit: BoxFit.contain);
    }
    
    // 2. Fallback to Firebase Storage
    if (storagePath != null) {
      return FutureBuilder<String>(
        future: FirebaseStorage.instance.ref(storagePath).getDownloadURL(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Error loading image from cloud', style: TextStyle(color: Colors.red)),
            );
          }
          if (!snapshot.hasData) return const Text('No cloud image found');
          
          return Image.network(
            snapshot.data!,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            },
          );
        },
      );
    }
    
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Text('Image not found locally or in cloud'),
    );
  }

  DataColumn _buildHeaderWithSearch(String label) {
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (label != 'Actions' && label != 'Sync' && label != 'Images') ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.search, size: 16, color: Colors.grey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() {
                _searchField = label;
                _isSearchingActive = true;
              }),
            ),
          ],
        ],
      ),
    );
  }
}
