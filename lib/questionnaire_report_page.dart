import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';
import 'questionnaire_page.dart';
import 'maria_db_service.dart';

class QuestionnaireReportPage extends StatefulWidget {
  const QuestionnaireReportPage({super.key});

  @override
  State<QuestionnaireReportPage> createState() => _QuestionnaireReportPageState();
}

class _QuestionnaireReportPageState extends State<QuestionnaireReportPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<dynamic> _allData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final data = await MariaDBService.getQuestionnaires();
    setState(() {
      _allData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Questionnaire Report (MariaDB)'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          )
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Reg No or Name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _allData.isEmpty
                ? const Center(child: Text('No questionnaires found in MariaDB.'))
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final filteredDocs = _allData.where((data) {
      final regNo = (data['Regno'] ?? '').toString().toLowerCase();
      final name = (data['INTNAME'] ?? '').toString().toLowerCase();
      return regNo.contains(_searchQuery) || name.contains(_searchQuery);
    }).toList();

    if (filteredDocs.isEmpty) {
      return const Center(child: Text('No matching records found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredDocs.length,
      itemBuilder: (context, index) {
        final data = filteredDocs[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text((index + 1).toString(), style: const TextStyle(color: Colors.white)),
            ),
            title: Text(data['INTNAME'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reg No: ${data['Regno'] ?? 'N/A'}'),
                if (data['INTDT'] != null)
                  Text('Date: ${data['INTDT']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuestionnairePage(existingData: data),
                  ),
                ).then((_) => _refreshData()); // Refresh when coming back
              },
            ),
          ),
        );
      },
    );
  }
}
