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
          
          // --- REACH MODULE ---
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
                title: const Text('Family Code Creation'),
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
                leading: const Icon(Icons.family_restroom, color: Colors.blueAccent),
                title: const Text('Family Planning'),
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
                title: const Text('Family Planning Report'),
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
                title: const Text('Local Database Stats'),
                onTap: () {
                  _showDatabaseStats(context);
                },
              ),
            ],
          ),

          // --- TETRA MODULE ---
          ExpansionTile(
            leading: const Icon(Icons.biotech, color: Colors.purple),
            title: const Text(
              'TETRA',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            initiallyExpanded: true,
            children: [
              ListTile(
                leading: const Icon(Icons.health_and_safety, color: Colors.green),
                title: const Text('Questionnaire'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestionnairePage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics, color: Colors.teal),
                title: const Text('All Questionnaires'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestionnaireReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.monitor_heart, color: Colors.red),
                title: const Text('BP Form'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthReadingsPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.assessment, color: Colors.blueGrey),
                title: const Text('BP Form Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.medical_services, color: Colors.orange),
                title: const Text('Blood Sugar Form(After Eating)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BloodSugarFastingPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.deepOrange),
                title: const Text('Blood Sugar Form Fasting Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BloodSugarFastingReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.straighten, color: Colors.brown),
                title: const Text('Anthropometry Measurement Form'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AnthropometryPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt_outlined, color: Colors.blueGrey),
                title: const Text('Anthropometry Measurement Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AnthropometryReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.biotech, color: Colors.blue),
                title: const Text('Blood sample Status'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BloodSampleStatusPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment_turned_in_outlined, color: Colors.teal),
                title: const Text('Blood sample Status Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BloodSampleStatusReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.assignment, color: Colors.deepPurple),
                title: const Text('Quarterly Survey Questionnaire'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const QuarterlySurveyPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics, color: Colors.indigo),
                title: const Text('Quarterly Survey Questionnaire Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const QuarterlySurveyReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Refused Form'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RefusedFormPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt, color: Colors.orange),
                title: const Text('Refused Form Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RefusedFormReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.medical_information, color: Colors.blue),
                title: const Text('Doctor Prescriptions Form'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorPrescriptionsPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment, color: Colors.teal),
                title: const Text('Doctor Prescriptions Form Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorPrescriptionReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.medication, color: Colors.purple),
                title: const Text('Medicines Entry'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicinesEntryPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt, color: Colors.indigo),
                title: const Text('Medicines Entry Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicinesEntryReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.healing, color: Colors.red),
                title: const Text('TUBERCULOSIS QUESTIONNAIRE'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TBQuestionnairePage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.poll, color: Colors.blueGrey),
                title: const Text('TUBERCULOSIS QUESTIONNAIRE REPORT'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TBQuestionnaireReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.camera, color: Colors.red),
                title: const Text('Colposcopy'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ColposcopyPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.assessment, color: Colors.blue),
                title: const Text('Colposcopy Report'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ColposcopyReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.blueAccent),
                title: const Text('Eye Examination'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EyeExaminationPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.remove_red_eye, color: Colors.teal),
                title: const Text('All Eye Examinations'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EyeExaminationReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.video_call, color: Colors.indigo),
                title: const Text('Zoho Meeting Request'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zoho Meeting Request Form Coming Soon')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics, color: Colors.indigoAccent),
                title: const Text('Zoho Meeting Request Report'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zoho Meeting Request Report Coming Soon')));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.science, color: Colors.purple),
                title: const Text('Cytology'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CytologyPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.biotech, color: Colors.blueGrey),
                title: const Text('All Cytologies'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CytologyReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.hub, color: Colors.blue),
                title: const Text('Lab'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LabInvestigationPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_shared, color: Colors.indigo),
                title: const Text('All Labs'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LabInvestigationReportPage()));
                },
              ),
              const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.deepPurple),
                title: const Text('Cervical Screening Questionnaire'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CervicalCancerScreeningPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics, color: Colors.teal),
                title: const Text('All Screening Reports'),
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
          title: const Text('Local Database Stats'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Family Codes'),
                trailing: Text(codesCount.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                title: const Text('Family Details'),
                trailing: Text(detailsCount.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }
}
