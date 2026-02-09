import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_drawer.dart';
import 'bpgluco.dart';

class HealthReportPage extends StatefulWidget {
  const HealthReportPage({super.key});

  @override
  State<HealthReportPage> createState() => _HealthReportPageState();
}

class _HealthReportPageState extends State<HealthReportPage> {
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
        title: const Text('Health Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
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

          final docs = snapshot.data?.docs ?? [];
          final totalCount = docs.length; // Simplified for this view
          final fromCache = snapshot.data?.metadata.isFromCache ?? false;
          final syncing = snapshot.data?.metadata.hasPendingWrites ?? false;

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
                            _buildHeaderWithSearch('BP (S/D)'),
                            _buildHeaderWithSearch('Pulse'),
                            _buildHeaderWithSearch('Sugar'),
                          ],
                          rows: docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final bool isPending = data['needs_gemini_extraction'] == true;
                            final bool hasBP = data['has_bp'] == true;
                            final bool hasSugar = data['has_sugar'] == true;

                            String bpStr = '--';
                            if (hasBP) {
                              if (data['bp_needs_extraction'] == true) bpStr = 'Processing...';
                              else bpStr = '${data['systolic'] ?? '--'}/${data['diastolic'] ?? '--'}';
                            }

                            String pulseStr = hasBP ? (data['pulse']?.toString() ?? '--') : '--';
                            
                            String sugarStr = '--';
                            if (hasSugar) {
                              if (data['sugar_needs_extraction'] == true) sugarStr = 'Processing...';
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
                              DataCell(Text(bpStr, style: const TextStyle(fontWeight: FontWeight.w500))),
                              DataCell(Text(pulseStr)),
                              DataCell(Text(sugarStr, style: const TextStyle(fontWeight: FontWeight.w500))),
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

  DataColumn _buildHeaderWithSearch(String label) {
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          const Icon(Icons.search, size: 16, color: Colors.grey),
        ],
      ),
    );
  }
}
