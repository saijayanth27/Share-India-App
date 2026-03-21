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
import 'anthropometry_page.dart';
import 'anthropometry_report_page.dart';
import 'blood_sample_status_page.dart';
import 'blood_sample_status_report_page.dart';
import 'refused_form_page.dart';
import 'refused_form_report_page.dart';
import 'doctor_prescriptions_page.dart';
import 'doctor_prescriptions_report_page.dart';
import 'medicines_entry_page.dart';
import 'medicines_entry_report_page.dart';
import 'tb_questionnaire_page.dart';
import 'tb_questionnaire_report_page.dart';
import 'colposcopy_page.dart';
import 'colposcopy_report_page.dart';
import 'eye_examination_page.dart';
import 'eye_examination_report_page.dart';
import 'cytology_page.dart';
import 'cytology_report_page.dart';
import 'lab_investigation_page.dart';
import 'lab_investigation_report_page.dart';
import 'cervical_cancer_screening_questionnaire_page.dart';
import 'cervical_cancer_screening_questionnaire_report_page.dart';
import 'quarterly_survey_questionnaire_page.dart';
import 'quarterly_survey_report_page.dart';
import 'blood_sugar_fasting_page.dart';
import 'blood_sugar_fasting_report_page.dart';
import 'local_database_service.dart';
import 'family_planning_page.dart';
import 'family_planning_report_page.dart';
import 'home_page.dart';
import 'language_provider.dart';
import 'main.dart';

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
              gradient: LinearGradient(
                colors: [Colors.indigo.shade700, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.health_and_safety, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                Text(
                  tr('Share India'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: Colors.indigo),
            title: Text(tr('Dashboard'), style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            },
          ),
          const Divider(),
          
          // --- REACH MODULE ---
          ExpansionTile(
            leading: const Icon(Icons.corporate_fare, color: Colors.blue),
            title: Text(
              tr('REACH'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            initiallyExpanded: true,
            children: [
              ListTile(
                leading: const Icon(Icons.description, color: Colors.blue),
                title: Text(tr('Family Code Creation')),
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
                title: Text(tr('Records List')),
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
                leading: const Icon(Icons.person_add, color: Colors.indigo),
                title: Text(tr('Personal Details')),
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
                title: Text(tr('Personal Details Report')),
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
                title: Text(tr('Ante Natal Care')),
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
                title: Text(tr('ANC Report')),
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
                title: Text(tr('ANC Checkup')),
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
                title: Text(tr('ANC Checkup Report')),
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
                title: Text(tr('Child Immunization')),
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
                title: Text(tr('Immunization Report')),
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
                title: Text(tr('Aarogya Assessment')),
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
                title: Text(tr('Aarogya Report')),
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
                leading: const Icon(Icons.family_restroom, color: Colors.blueAccent),
                title: Text(tr('Family Planning')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FamilyPlanningPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics_outlined, color: Colors.teal),
                title: Text(tr('Family Planning Report')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FamilyPlanningReportPage()),
                  );
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.storage, color: Colors.blueGrey),
                title: Text(tr('Local Database Stats')),
                onTap: () {
                  _showDatabaseStats(context);
                },
              ),
            ],
          ),

          // --- TETRA MODULE ---
          ExpansionTile(
            leading: const Icon(Icons.biotech, color: Colors.purple),
            title: Text(
              tr('TETRA'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            initiallyExpanded: true,
            children: [
              ListTile(
                leading: const Icon(Icons.health_and_safety, color: Colors.green),
                title: Text(tr('Questionnaire')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestionnairePage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics, color: Colors.teal),
                title: Text(tr('All Questionnaires')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordsPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.monitor_heart, color: Colors.red),
                title: Text(tr('BP Form')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthReadingsPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.assessment, color: Colors.blueGrey),
                title: Text(tr('BP Form Report')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.medical_services, color: Colors.orange),
                title: Text(tr('Blood Sugar Form(After Eating)')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BloodSugarFastingPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.deepOrange),
                title: Text(tr('Blood Sugar Form Fasting Report')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BloodSugarFastingReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.straighten, color: Colors.brown),
                title: Text(tr('Anthropometry Measurement Form')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AnthropometryPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt_outlined, color: Colors.blueGrey),
                title: Text(tr('Anthropometry Measurement Report')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AnthropometryReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.biotech, color: Colors.blue),
                title: Text(tr('Blood Sample Status')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BloodSampleStatusPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment_turned_in_outlined, color: Colors.teal),
                title: Text(tr('Blood Sample Status Report')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BloodSampleStatusReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.assignment, color: Colors.deepPurple),
                title: Text(tr('Quarterly Survey Questionnaire')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const QuarterlySurveyPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics, color: Colors.indigo),
                title: Text(tr('Quarterly Survey Questionnaire Report')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const QuarterlySurveyReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: Text(tr('Refused Form')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RefusedFormPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt, color: Colors.orange),
                title: Text(tr('Refused Form Report')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RefusedFormReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.medical_information, color: Colors.blue),
                title: Text(tr('Doctor Prescriptions Form')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorPrescriptionsPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment, color: Colors.teal),
                title: Text(tr('Doctor Prescriptions Form Report')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorPrescriptionReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.medication, color: Colors.purple),
                title: Text(tr('Medicines Entry')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicinesEntryPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt, color: Colors.indigo),
                title: Text(tr('Medicines Entry Report')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicinesEntryReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.healing, color: Colors.red),
                title: Text(tr('TUBERCULOSIS QUESTIONNAIRE')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TBQuestionnairePage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.poll, color: Colors.blueGrey),
                title: Text(tr('TUBERCULOSIS QUESTIONNAIRE REPORT')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TBQuestionnaireReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.camera, color: Colors.red),
                title: Text(tr('Colposcopy')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ColposcopyPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.assessment, color: Colors.blue),
                title: Text(tr('Colposcopy Report')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ColposcopyReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.blueAccent),
                title: Text(tr('Eye Examination')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EyeExaminationPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.remove_red_eye, color: Colors.teal),
                title: Text(tr('All Eye Examinations')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EyeExaminationReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.video_call, color: Colors.indigo),
                title: Text(tr('Zoho Meeting Request')),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tr('Zoho Meeting Request Form Coming Soon')),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics, color: Colors.indigoAccent),
                title: Text(tr('Zoho Meeting Request Report')),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tr('Zoho Meeting Request Report Coming Soon')),
                    ),
                  );
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.science, color: Colors.purple),
                title: Text(tr('Cytology')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CytologyPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.biotech, color: Colors.blueGrey),
                title: Text(tr('All Cytologies')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CytologyReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.hub, color: Colors.blue),
                title: Text(tr('Lab')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LabInvestigationPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_shared, color: Colors.indigo),
                title: Text(tr('All Labs')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LabInvestigationReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.deepPurple),
                title: Text(tr('Cervical Screening Questionnaire')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CervicalCancerScreeningPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics, color: Colors.teal),
                title: Text(tr('All Screening Reports')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CervicalCancerScreeningReportPage()));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDatabaseStats(BuildContext context) async {
    final dbService = LocalDatabaseService();
    final codesCount = await dbService.getRecordCount('family_codes');
    final detailsCount = await dbService.getRecordCount('family_details');

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('Local Database Stats')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(tr('Family Codes')),
                trailing: Text(codesCount.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                title: Text(tr('Family Details')),
                trailing: Text(detailsCount.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('Close')),
            ),
          ],
        ),
      );
    }
  }
}


