import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';
import '../widgets/intervention_dialog.dart';

class AbsenceAlertsScreen extends StatelessWidget {
  final VoidCallback? onBack;

  const AbsenceAlertsScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final data = DataService();
    final bool showBackButton = onBack != null || Navigator.canPop(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: showBackButton
              ? BackButton(onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    onBack?.call();
                  }
                })
              : null,
          title: const Text('Absence Follow-Up & Early Warning'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.warning_amber), text: 'Flagged Students'),
              Tab(icon: Icon(Icons.history), text: 'Intervention Log'),
            ],
          ),
        ),
        body: SafeArea(
          child: ListenableBuilder(
          listenable: data,
          builder: (context, _) {
            final flagged = data.detectFlaggedStudents();
            final interventions = data.interventions;

            return TabBarView(
              children: [
                // TAB 1: Flagged Students List
                flagged.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, size: 64, color: AppTheme.present),
                            const SizedBox(height: 12),
                            const Text(
                              'All Clear!',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No students currently have chronic absences or low attendance.',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: flagged.length,
                        itemBuilder: (context, index) {
                          final item = flagged[index];
                          final student = item['student'] as Student;
                          final rate = item['rate'] as int;
                          final consec = item['consecutiveAbsences'] as int;
                          final cls = data.getClassById(student.classId);

                          final isUrgent = consec >= 3;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: isUrgent ? AppTheme.absentSubtle : AppTheme.lateSubtle,
                                        child: Icon(
                                          isUrgent ? Icons.error_outline : Icons.warning_amber_rounded,
                                          color: isUrgent ? AppTheme.absent : AppTheme.late,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              student.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${cls != null ? cls.name : student.classId} • Roll #${student.rollNo} • ID: ${student.id}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (isUrgent ? AppTheme.absent : AppTheme.late).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isUrgent ? '$consec Days In A Row' : '$rate% Attendance',
                                          style: TextStyle(
                                            color: isUrgent ? AppTheme.absentDark : AppTheme.lateDark,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Parent: ${student.guardianName}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            student.guardianPhone,
                                            style: const TextStyle(fontSize: 12, color: AppTheme.primary),
                                          ),
                                        ],
                                      ),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        ),
                                        icon: const Icon(Icons.call, size: 16),
                                        label: const Text('Contact Guardian', style: TextStyle(fontSize: 12)),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => InterventionDialog(
                                              student: student,
                                              rate: rate,
                                              consecutiveAbsences: consec,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                // TAB 2: Communication & Intervention History
                interventions.isEmpty
                    ? Center(
                        child: Text(
                          'No guardian contacts logged yet.',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: interventions.length,
                        itemBuilder: (context, index) {
                          final item = interventions[index];
                          final student = data.getStudentById(item.studentId);

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppTheme.primaryLight,
                                child: Icon(Icons.chat_bubble_outline, color: AppTheme.primary, size: 18),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      student != null ? student.name : item.studentId,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.presentSubtle,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.channel,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.presentDark),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    item.notes,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'By ${item.staff} • ${item.resolution}',
                                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                                      ),
                                      Text(
                                        item.date,
                                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }
}
