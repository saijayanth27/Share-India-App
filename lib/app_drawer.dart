import 'package:flutter/material.dart';
import 'main.dart';
import 'bpgluco.dart';
import 'health_report_page.dart';
import 'personal_details_page.dart';
import 'personal_details_report_page.dart';
import 'ante_natal_care_page.dart';
import 'ante_natal_care_report_page.dart';
import 'child_immunization_page.dart';
import 'child_immunization_report_page.dart';
import 'ante_natal_care_checkup_page.dart';
import 'ante_natal_care_checkup_report_page.dart';
import 'aarogya_page.dart';
import 'aarogya_report_page.dart';
import 'questionnaire_page.dart';
import 'questionnaire_report_page.dart';
import 'anthropometry_page.dart';
import 'anthropometry_report_page.dart';
import 'blood_sample_status_page.dart';
import 'blood_sample_status_report_page.dart';
import 'refused_form_page.dart';
import 'refused_form_report_page.dart';

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
          ExpansionTile(
            leading: const Icon(Icons.corporate_fare, color: Colors.blue),
            title: const Text(
              'REACH',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            initiallyExpanded: true,
            children: [
              ListTile(
                leading: const Icon(Icons.description, color: Colors.blue),
                title: const Text('Family Code Form'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const FamilyFormPage()),
                    (route) => false,
                  );
                },
              ),
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
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
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
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.person_add, color: Colors.indigo),
                title: const Text('Personal Details'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PersonalDetailsPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.assessment, color: Colors.deepOrange),
                title: const Text('Personal Details Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PersonalDetailsReportPage()),
                  );
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.pregnant_woman, color: Colors.pink),
                title: const Text('Ante Natal Care'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnteNatalCarePage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt, color: Colors.purple),
                title: const Text('ANC Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnteNatalCareReportPage()),
                  );
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.medical_services, color: Colors.orange),
                title: const Text('ANC Checkup'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnteNatalCareCheckupPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long, color: Colors.blueAccent),
                title: const Text('ANC Checkup Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnteNatalCareCheckupReportPage()),
                  );
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.child_care, color: Colors.blue),
                title: const Text('Child Immunization'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChildImmunizationPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics, color: Colors.green),
                title: const Text('Immunization Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChildImmunizationReportPage()),
                  );
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.security, color: Colors.green),
                title: const Text('Aarogya Assessment'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AarogyaPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart, color: Colors.indigo),
                title: const Text('Aarogya Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AarogyaReportPage()),
                  );
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.health_and_safety, color: Colors.green),
                title: const Text('Health Questionnaire'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuestionnairePage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined, color: Colors.blue),
                title: const Text('Questionnaire Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuestionnaireReportPage()),
                  );
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.straighten, color: Colors.brown),
                title: const Text('Anthropometry Measurement'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnthropometryPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt_outlined, color: Colors.blueGrey),
                title: const Text('Anthropometry Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnthropometryReportPage()),
                  );
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.biotech, color: Colors.blue),
                title: const Text('Blood Sample Status'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BloodSampleStatusPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment_turned_in_outlined, color: Colors.teal),
                title: const Text('Blood Sample Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BloodSampleStatusReportPage()),
                  );
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: const Text('Refused Form'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RefusedFormPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt, color: Colors.orange),
                title: const Text('Refused Form Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RefusedFormReportPage()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
