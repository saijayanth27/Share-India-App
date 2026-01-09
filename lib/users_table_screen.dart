import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RecordsTablePage extends StatelessWidget {
  const RecordsTablePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Records (Table View)')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('client')
            .orderBy('clientUpdatedAt', descending: true)
            .snapshots(includeMetadataChanges: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No records found'));
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
                columnSpacing: 20,
                headingRowColor:
                    MaterialStateProperty.all(Colors.grey.shade200),
                columns: const [
                  DataColumn(label: Text('Family ID')),
                  DataColumn(label: Text('House No')),
                  DataColumn(label: Text('Head of Family')),
                  DataColumn(label: Text('Sync Status')),
                ],
                rows: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final pending = doc.metadata.hasPendingWrites;

                  return DataRow(
                    cells: [
                      DataCell(Text(data['family_id'] ?? '')),
                      DataCell(Text(data['house_no'] ?? '')),
                      DataCell(Text(data['head_of_family'] ?? '')),
                      DataCell(
                        pending
                            ? const Text('Pending',
                                style: TextStyle(color: Colors.orange))
                            : const Text('Synced',
                                style: TextStyle(color: Colors.green)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}
