import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Firebase Offline Demo',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
      ),
      home: const FamilyFormPage(),
    );
  }
}

/* ============================================================
   FAMILY FORM PAGE (CREATE / EDIT)
============================================================ */

class FamilyFormPage extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? record;

  const FamilyFormPage({super.key, this.docId, this.record});

  @override
  State<FamilyFormPage> createState() => _FamilyFormPageState();
}

class _FamilyFormPageState extends State<FamilyFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  final _familyId = TextEditingController();
  final _houseNo = TextEditingController();
  final _head = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.record != null) {
      _familyId.text = widget.record!['family_id'] ?? '';
      _houseNo.text = widget.record!['house_no'] ?? '';
      _head.text = widget.record!['head_of_family'] ?? '';
    }
  }

  @override
  void dispose() {
    _familyId.dispose();
    _houseNo.dispose();
    _head.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final data = {
      'family_id': _familyId.text,
      'house_no': _houseNo.text,
      'head_of_family': _head.text,

      // 🔑 OFFLINE-SAFE TIMESTAMPS
      'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('client')
          .doc(_familyId.text)
          .set(data, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved (works offline)'),
            backgroundColor: Colors.green,
          ),
        );
        _clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  void _clear() {
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
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   RECORDS PAGE (OFFLINE SAFE LIST)
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
              .snapshots(includeMetadataChanges: true),
          builder: (context, snapshot) {
            // 1️⃣ Show error if any
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            // 2️⃣ FIRST LOAD ONLY (no cache, no server)
            if (!snapshot.hasData) {
              return const Center(child: Text('Loading records...'));
            }

            final docs = snapshot.data!.docs;

            // 3️⃣ Data loaded but empty
            if (docs.isEmpty) {
              return const Center(child: Text('No records found'));
            }

            // 4️⃣ Normal state (ONLINE or OFFLINE)
            final fromCache = snapshot.data!.metadata.isFromCache;

            return Column(
              children: [
                // 🔔 Offline / Online indicator
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: fromCache
                      ? Colors.orange.shade100
                      : Colors.green.shade100,
                  child: Text(
                    fromCache ? 'Offline mode' : 'Online mode',
                    textAlign: TextAlign.center,
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(data['family_id'] ?? 'N/A'),
                        subtitle: Text(data['house_no'] ?? ''),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ));
  }
}
