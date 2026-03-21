import 'package:flutter/material.dart';

import 'aarogya_page.dart';
import 'ante_natal_care_checkup_page.dart';
import 'ante_natal_care_page.dart';
import 'anthropometry_page.dart';
import 'app_drawer.dart';
import 'blood_sample_status_page.dart';
import 'blood_sugar_fasting_page.dart';
import 'bpgluco.dart';
import 'cervical_cancer_screening_questionnaire_page.dart';
import 'child_immunization_page.dart';
import 'colposcopy_page.dart';
import 'cytology_page.dart';
import 'doctor_prescriptions_page.dart';
import 'eye_examination_page.dart';
import 'family_planning_page.dart';
import 'lab_investigation_page.dart';
import 'language_provider.dart';
import 'main.dart';
import 'medicines_entry_page.dart';
import 'personal_details_page.dart';
import 'questionnaire_page.dart';
import 'quarterly_survey_questionnaire_page.dart';
import 'refused_form_page.dart';
import 'tb_questionnaire_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageProvider.instance.isTeluguNotifier,
      builder: (context, _, __) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              tr('Dashboard'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: const [LanguageToggleButton()],
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade700, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          drawer: const AppDrawer(),
          body: Container(
            decoration: BoxDecoration(color: Colors.grey.shade50),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Welcome Back'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('Select a form to start recording data'),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  _buildModuleSection(
                    context,
                    title: 'REACH MODULE',
                    icon: Icons.corporate_fare,
                    color: Colors.blue.shade700,
                    items: [
                      _DashboardItem(
                        title: 'Family Code',
                        icon: Icons.description,
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FamilyFormPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'Personal Details',
                        icon: Icons.person_add,
                        color: Colors.indigo,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PersonalDetailsPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'ANC',
                        icon: Icons.pregnant_woman,
                        color: Colors.pink,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AnteNatalCarePage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'Family Planning',
                        icon: Icons.family_restroom,
                        color: Colors.blueAccent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FamilyPlanningPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'Child Imm.',
                        icon: Icons.child_care,
                        color: Colors.orange,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChildImmunizationPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'Aarogya',
                        icon: Icons.health_and_safety,
                        color: Colors.deepPurple,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AarogyaPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'ANC Checkup',
                        icon: Icons.medical_services,
                        color: Colors.orange,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AnteNatalCareCheckupPage()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildModuleSection(
                    context,
                    title: 'TETRA MODULE',
                    icon: Icons.biotech,
                    color: Colors.purple.shade700,
                    items: [
                      _DashboardItem(
                        title: 'Questionnaire',
                        icon: Icons.assignment_outlined,
                        color: Colors.green,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const QuestionnairePage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'BP / Gluco',
                        icon: Icons.monitor_heart,
                        color: Colors.red,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HealthReadingsPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'Blood Sugar',
                        icon: Icons.bloodtype,
                        color: Colors.deepOrange,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BloodSugarFastingPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'Anthropometry',
                        icon: Icons.straighten,
                        color: Colors.brown,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AnthropometryPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'Sample Status',
                        icon: Icons.biotech,
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BloodSampleStatusPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'Quarterly Sur.',
                        icon: Icons.assignment,
                        color: Colors.deepPurple,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const QuarterlySurveyPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'Refused Form',
                        icon: Icons.cancel,
                        color: Colors.redAccent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RefusedFormPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'Doctor Pres.',
                        icon: Icons.medical_information,
                        color: Colors.lightBlue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DoctorPrescriptionsPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'Medicines',
                        icon: Icons.medication,
                        color: Colors.purpleAccent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MedicinesEntryPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'TB Quest.',
                        icon: Icons.healing,
                        color: Colors.red,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TBQuestionnairePage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'Colposcopy',
                        icon: Icons.camera,
                        color: Colors.redAccent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ColposcopyPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'Eye Exam',
                        icon: Icons.visibility,
                        color: Colors.blueAccent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EyeExaminationPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'Cytology',
                        icon: Icons.science,
                        color: Colors.purple,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CytologyPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'Lab',
                        icon: Icons.hub,
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LabInvestigationPage()),
                        ),
                      ),
                      _DashboardItem(
                        title: 'Cervical Scr.',
                        icon: Icons.description,
                        color: Colors.deepPurpleAccent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CervicalCancerScreeningPage()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModuleSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<_DashboardItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Text(
              tr(title),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildGridItem(items[index]),
        ),
      ],
    );
  }

  Widget _buildGridItem(_DashboardItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: item.color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              tr(item.title),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardItem {
  const _DashboardItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
