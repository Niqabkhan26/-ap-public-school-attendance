import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';
import '../widgets/intervention_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = DataService();
    final today = DateTime.now();
    final dateLabel = DateFormat('EEEE, d MMM yyyy').format(today);

    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final students = data.students.where((s) => s.status == 'active').toList();
        final query = _searchQuery.trim().toLowerCase();
        final searchResults = query.isEmpty
            ? <Student>[]
            : students
                .where((s) =>
                    s.name.toLowerCase().contains(query) ||
                    s.rollNo.toString().contains(query))
                .take(5)
                .toList();
        final flagged = data.detectFlaggedStudents();
        final classes = data.classes;

        // Latest date stats
        final allDates = data.attendance.map((a) => a.date).toSet().toList()..sort();
        final latestDate = allDates.isNotEmpty ? allDates.last : today.toIso8601String().split('T')[0];
        final todayRecords = data.attendance.where((a) => a.date == latestDate).toList();

        int p = 0, ab = 0, l = 0, e = 0;
        for (var r in todayRecords) {
          if (r.status == 'P') p++;
          else if (r.status == 'A') ab++;
          else if (r.status == 'L') l++;
          else if (r.status == 'E') e++;
        }

        final effectivePresent = p + l;
        final totalRec = todayRecords.isNotEmpty
            ? todayRecords.length
            : (students.isNotEmpty ? students.length : 1);
        final rate = ((effectivePresent / totalRec) * 100).round();
        final totalStudents = students.length;

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 72,
            title: Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/ap_logo.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => CircleAvatar(
                      backgroundColor: AppTheme.primaryLight,
                      radius: 24,
                      child: const Icon(Icons.school, color: AppTheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        data.schoolName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => widget.onNavigate(3),
              ),
              IconButton(
                icon: Icon(data.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => data.toggleTheme(),
                tooltip: 'Toggle Theme',
              ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async => data.refreshData(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Chronic Absence Banner ──────────────────────────
                  if (flagged.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.absentSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.absent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppTheme.absent, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${flagged.length} student(s) need attention (<75% or consecutive absences).',
                              style: const TextStyle(
                                color: AppTheme.absentDark,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () => widget.onNavigate(4),
                            child: const Text('Review', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── 2×2 KPI Grid ────────────────────────────────────
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.55,
                    children: [
                      _KpiTile(
                        label: 'Present Today',
                        value: '$p',
                        icon: Icons.check_circle_outline,
                        iconColor: AppTheme.present,
                        bgColor: AppTheme.presentSubtle,
                      ),
                      _KpiTile(
                        label: 'Absent Today',
                        value: '$ab',
                        icon: Icons.cancel_outlined,
                        iconColor: AppTheme.absent,
                        bgColor: AppTheme.absentSubtle,
                      ),
                      _KpiTile(
                        label: 'Total Students',
                        value: '$totalStudents',
                        icon: Icons.people_outline,
                        iconColor: AppTheme.primary,
                        bgColor: AppTheme.primaryLight,
                      ),
                      _KpiTile(
                        label: 'Attendance %',
                        value: '$rate%',
                        icon: Icons.percent,
                        iconColor: rate >= 75 ? AppTheme.present : AppTheme.absent,
                        bgColor: rate >= 75 ? AppTheme.presentSubtle : AppTheme.absentSubtle,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Search & Quick Actions ───────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search student by name or roll no.',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  ),
                            isDense: true,
                          ),
                          onChanged: (value) => setState(() => _searchQuery = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => widget.onNavigate(2),
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),

                  if (searchResults.isNotEmpty)
                    Card(
                      child: Column(
                        children: searchResults
                            .map((student) => ListTile(
                                  dense: true,
                                  leading: CircleAvatar(child: Text('${student.rollNo}')),
                                  title: Text(
                                    student.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    data.getClassById(student.classId)?.shortName ?? student.classId,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => widget.onNavigate(2),
                                ))
                            .toList(),
                      ),
                    )
                  else if (query.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No matching students found.'),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // ── Quick Actions ────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.edit_calendar, size: 18),
                          label: const Text('Mark Attendance'),
                          onPressed: () => widget.onNavigate(1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_download_outlined, size: 18),
                        label: const Text('Reports'),
                        onPressed: () => widget.onNavigate(5),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Class Attendance List (Prep → Class 10) ──────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Class Attendance Progress',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        latestDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: classes.length,
                    itemBuilder: (context, index) {
                      final cls = classes[index];
                      final classStudents = students.where((s) => s.classId == cls.id).toList();
                      final classRecs = todayRecords.where((r) => r.classId == cls.id).toList();
                      final isRecorded = classRecs.isNotEmpty;

                      final classPresent = classRecs.where((r) => r.status == 'P' || r.status == 'L').length;
                      final classRate = isRecorded && classStudents.isNotEmpty
                          ? ((classPresent / classStudents.length) * 100).round()
                          : 0;
                      final Color classRateColor = classRate < 75
                          ? AppTheme.absent
                          : classRate <= 85
                              ? AppTheme.late
                              : AppTheme.present;
                      final Color classRateDark = classRate < 75
                          ? AppTheme.absentDark
                          : classRate <= 85
                              ? AppTheme.lateDark
                              : AppTheme.presentDark;

                      final teacherName = data.classTeachers[cls.id] ?? cls.teacher;

                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: isRecorded ? AppTheme.presentSubtle : AppTheme.lateSubtle,
                            child: Icon(
                              isRecorded ? Icons.check : Icons.hourglass_top,
                              color: isRecorded ? AppTheme.present : AppTheme.late,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            cls.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            teacherName,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isRecorded)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: classRateColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$classRate%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: classRateDark,
                                    ),
                                  ),
                                )
                              else
                                const Chip(
                                  label: Text('Pending', style: TextStyle(fontSize: 11)),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios, size: 14),
                                onPressed: () => widget.onNavigate(1),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ── Chronic Absence Warnings ─────────────────────────
                  if (flagged.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Early Warning: Repeated Absences',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.absent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => widget.onNavigate(4),
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Card(
                      child: Column(
                        children: flagged.take(3).map((f) {
                          final student = f['student'] as Student;
                          final consec = f['consecutiveAbsences'] as int;
                          final studentRate = f['rate'] as int;

                          return ListTile(
                            title: Text(
                              student.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${student.classId} • Roll: #${student.rollNo}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  backgroundColor: consec >= 3 ? AppTheme.absentSubtle : AppTheme.lateSubtle,
                                  label: Text(
                                    consec >= 3 ? '$consec Days' : '$studentRate%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: consec >= 3 ? AppTheme.absentDark : AppTheme.lateDark,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.phone, color: AppTheme.primary, size: 20),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => InterventionDialog(
                                        student: student,
                                        rate: studentRate,
                                        consecutiveAbsences: consec,
                                      ),
                                    );
                                  },
                                  tooltip: 'Contact Parent',
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Recent Activity Feed ─────────────────────────────
                  const Text(
                    'Recent Activity & Audit Trail',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: data.auditLog.take(4).length,
                      itemBuilder: (context, index) {
                        final audit = data.auditLog[index];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: audit.type == 'SUBMISSION'
                                ? AppTheme.presentSubtle
                                : audit.type == 'CORRECTION'
                                    ? AppTheme.lateSubtle
                                    : AppTheme.primaryLight,
                            child: Icon(
                              audit.type == 'SUBMISSION'
                                  ? Icons.check
                                  : audit.type == 'CORRECTION'
                                      ? Icons.edit
                                      : Icons.info_outline,
                              size: 14,
                              color: audit.type == 'SUBMISSION'
                                  ? AppTheme.present
                                  : audit.type == 'CORRECTION'
                                      ? AppTheme.late
                                      : AppTheme.primary,
                            ),
                          ),
                          title: Text(
                            '${audit.action}: ${audit.details}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${audit.recordedBy} • ${audit.reason}',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            audit.timestamp,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Internal KPI tile widget ─────────────────────────────────────────────────
class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;

  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
