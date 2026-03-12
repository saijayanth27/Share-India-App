import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'anthropometry_page.dart';

class AnthropometryReportPage extends StatefulWidget {
  const AnthropometryReportPage({super.key});

  @override
  State<AnthropometryReportPage> createState() => _AnthropometryReportPageState();
}

class _AnthropometryReportPageState extends State<AnthropometryReportPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchingActive = false;

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
                  hintText: 'Search by Reg No or Name...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _isSearchingActive = false;
                      });
                    },
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              )
            : const Text('Anthropometry Reports', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.brown.shade700, Colors.brown.shade400],
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
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.brown.shade50,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('anthropometry').snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;
                return Text(
                  'Total Records: $count',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.brown.shade800, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('anthropometry').orderBy('clientUpdatedAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No anthropometry records found.'));
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final regNo = (data['Registration_Number'] ?? '').toString().toLowerCase();
                  final name = (data['Name'] ?? '').toString().toLowerCase();
                  return regNo.contains(_searchQuery) || name.contains(_searchQuery);
                }).toList();

                return ListView.builder(
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
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text((index + 1).toString(), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(data['Name'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Reg No: ${data['Registration_Number'] ?? 'N/A'}'),
                            Text('Family ID: ${data['Family_ID'] ?? 'N/A'}'),
                            if (data['weight'] != null || data['Height'] != null)
                              Text('Wt: ${data['weight']}kg | Ht: ${data['Height']}cm', style: const TextStyle(fontSize: 12)),
                            if (data['clientUpdatedAt'] != null)
                              Text('Date: ${DateFormat('dd-MMM-yyyy HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(data['clientUpdatedAt']))}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AnthropometryPage(existingData: data, docId: docId),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
