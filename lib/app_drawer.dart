import 'package:flutter/material.dart';
import 'main.dart';
import 'bpgluco.dart';
import 'health_report_page.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: const Center(
              child: Text(
                'Share India App',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description, color: Colors.blue),
            title: const Text('Family Code Form'),
            onTap: () {
              Navigator.pop(context);
              // If not already on home, go home and clear stack
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const FamilyFormPage()),
                (route) => false,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.monitor_heart, color: Colors.redAccent),
            title: const Text('Health Readings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HealthReadingsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_chart, color: Colors.blueGrey),
            title: const Text('Health Report'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HealthReportPage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.list_alt, color: Colors.teal),
            title: const Text('Records List'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecordsPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
