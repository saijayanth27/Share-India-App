import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

/* ============================================================
   APP ROOT
============================================================ */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Firestore Offline First',
      theme: ThemeData(useMaterial3: true),
      home: const FamilyFormPage(),
    );
  }
}

/* ============================================================
   FAMILY FORM PAGE (INSTANT SAVE – OFFLINE FIRST)
============================================================ */

class FamilyFormPage extends StatefulWidget {
  const FamilyFormPage({super.key});

  @override
  State<FamilyFormPage> createState() => _FamilyFormPageState();
}

class _FamilyFormPageState extends State<FamilyFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _familyId = TextEditingController();
  final _houseNo = TextEditingController();
  final _head = TextEditingController();

  @override
  void dispose() {
    _familyId.dispose();
    _houseNo.dispose();
    _head.dispose();
    super.dispose();
  }

  /// 🔥 OFFLINE-FIRST SAVE (NO AWAIT, NO LOADING)
  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'family_id': _familyId.text,
      'house_no': _houseNo.text,
      'head_of_family': _head.text,

      // Offline-safe timestamps
      'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    };

    // 🚀 FIRE-AND-FORGET WRITE
    FirebaseFirestore.instance
        .collection('client')
        .doc(_familyId.text)
        .set(data, SetOptions(merge: true));

    // UI updates immediately
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved locally (syncing automatically)'),
        backgroundColor: Colors.green,
      ),
    );

    _familyId.clear();
    _houseNo.clear();
    _head.clear();
  }

  void _openList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecordsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Form'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _openList,
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _familyId,
              decoration: const InputDecoration(labelText: 'Family ID'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _houseNo,
              decoration: const InputDecoration(labelText: 'House No'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _head,
              decoration: const InputDecoration(labelText: 'Head of Family'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   RECORDS PAGE (OFFLINE SAFE + SYNC STATUS)
============================================================ */

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Records')),
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
            return const Center(child: Text('Loading...'));
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No records found'));
          }

          final fromCache = snapshot.data!.metadata.isFromCache;
          final hasPendingWrites = snapshot.data!.metadata.hasPendingWrites;

          return Column(
            children: [
              // 🔔 OFFLINE / ONLINE / SYNC STATUS
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color:
                    fromCache ? Colors.orange.shade100 : Colors.green.shade100,
                child: Text(
                  fromCache
                      ? 'Offline mode (showing cached data)'
                      : hasPendingWrites
                          ? 'Online – syncing changes...'
                          : 'Online – all data synced',
                  textAlign: TextAlign.center,
                ),
              ),

              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final pending = doc.metadata.hasPendingWrites;

                    return ListTile(
                      title: Text(data['family_id'] ?? 'N/A'),
                      subtitle: Text(
                        '${data['house_no'] ?? ''} | ${data['head_of_family'] ?? ''}',
                      ),
                      trailing: pending
                          ? const Icon(Icons.sync, color: Colors.orange)
                          : const Icon(Icons.check, color: Colors.green),
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
}
