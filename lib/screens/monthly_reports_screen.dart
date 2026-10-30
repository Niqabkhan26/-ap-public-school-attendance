import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/data_service.dart';
import '../models/section.dart';
import '../theme/app_theme.dart';

class MonthlyReportsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const MonthlyReportsScreen({super.key, this.onBack});

  @override
  State<MonthlyReportsScreen> createState() => _MonthlyReportsScreenState();
}

class _MonthlyReportsScreenState extends State<MonthlyReportsScreen> {
  String _selectedClassId = 'CLS-CLASS_10';
  String? _selectedSectionId; // null = all sections
  late DateTime _reportFromDate;
  late DateTime _reportToDate;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _reportFromDate = DateTime(today.year, today.month, today.day - today.weekday + 1);
    _reportToDate = _reportFromDate.add(const Duration(days: 6));
    final data = DataService();
    if (data.classes.isNotEmpty) {
      _selectedClassId = data.classes.first.id;
    }
  }

  Future<void> _pickReportDate({required bool fromDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fromDate ? _reportFromDate : _reportToDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (fromDate) {
        _reportFromDate = picked;
        if (_reportToDate.isBefore(picked)) _reportToDate = picked;
      } else {
        _reportToDate = picked;
        if (_reportFromDate.isAfter(picked)) _reportFromDate = picked;
      }
    });
  }

  Future<void> _createWeeklyPdf(DataService data) async {
    final from = DateTime(_reportFromDate.year, _reportFromDate.month, _reportFromDate.day);
    final to = DateTime(_reportToDate.year, _reportToDate.month, _reportToDate.day);
    final dates = <DateTime>[];
    for (var date = from; !date.isAfter(to); date = date.add(const Duration(days: 1))) {
      dates.add(date);
    }

    final cls = data.getClassById(_selectedClassId);
    final sec = data.getSectionById(_selectedSectionId);
    final title = '${cls?.name ?? _selectedClassId}${sec != null ? " / ${sec.name}" : ""}';

    final studentsForReport = data.getStudentsForClassAndSection(
      _selectedClassId,
      _selectedSectionId,
      status: 'active',
    );

    final dailyRows = <List<String>>[
      ['Date', 'Day', title, '%'],
    ];
    final absentRows = <List<String>>[
      ['Date', 'Roll', 'Student', 'Reason'],
    ];
    var totalPresent = 0;
    var totalRecords = 0;

    for (final date in dates) {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final dateLabel = DateFormat.yMMMd().format(date);
      if (data.isHolidayDate(dateKey)) {
        dailyRows.add([dateLabel, DateFormat('EEEE').format(date), 'Holiday', '-']);
        continue;
      }

      final dayRecords = data
          .getAttendanceForClassSectionAndDate(_selectedClassId, _selectedSectionId, dateKey)
          .where((r) => studentsForReport.any((s) => s.id == r.studentId))
          .toList();

      final presentCount = dayRecords.where((r) => r.status == 'P' || r.status == 'L').length;
      totalPresent += presentCount;
      totalRecords += dayRecords.length;

      String classValue() {
        if (dayRecords.isEmpty) return 'Not recorded';
        final denom = dayRecords.length < studentsForReport.length ? dayRecords.length : studentsForReport.length;
        return '${((presentCount / denom) * 100).round()}%';
      }

      final dayRate = dayRecords.isEmpty ? '-' : '${((presentCount / dayRecords.length) * 100).round()}%';
      dailyRows.add([
        dateLabel,
        DateFormat('EEEE').format(date),
        classValue(),
        dayRate,
      ]);

      for (final record in dayRecords.where((item) => item.status == 'A')) {
        final student = data.getStudentById(record.studentId);
        absentRows.add([
          dateLabel,
          '${student?.rollNo ?? ''}',
          student?.name ?? record.studentId,
          record.remarks.isEmpty ? 'Not provided' : record.remarks,
        ]);
      }
    }

    final report = pw.Document();
    report.addPage(pw.MultiPage(
      build: (context) => [
        pw.Text(data.schoolName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Weekly Attendance Report — $title', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(
          '${DateFormat.yMMMMd().format(from)} – ${DateFormat.yMMMMd().format(to)}',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(data: dailyRows, headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text(
          'Summary Attendance: ${totalRecords == 0 ? 0 : ((totalPresent / totalRecords) * 100).round()}%',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 16),
        pw.Text('Absent Students and Reasons', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(data: absentRows, headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) async => report.save());
  }

  @override
  Widget build(BuildContext context) {
    final data = DataService();
    final bool showBackButton = widget.onBack != null || Navigator.canPop(context);

    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final classes = data.classes;
        final sections = data.getSectionsForClass(_selectedClassId);

        // Validate sectionId when class changes
        if (_selectedSectionId != null &&
            !sections.any((s) => s.id == _selectedSectionId)) {
          _selectedSectionId = null;
        }

        final students = data.getStudentsForClassAndSection(
          _selectedClassId,
          _selectedSectionId,
          status: 'active',
        );

        // Calculate aggregated counts for filtered records
        int totalP = 0;
        int totalA = 0;
        int totalL = 0;
        int totalE = 0;
        int criticalCount = 0;
        int totalRateSum = 0;

        for (var s in students) {
          final stats = data.calculateStudentStats(s.id);
          totalP += stats['present'] as int;
          totalA += stats['absent'] as int;
          totalL += stats['late'] as int;
          totalE += stats['excused'] as int;

          final r = stats['rate'] as int;
          totalRateSum += r;
          if (r < data.warningThreshold) criticalCount++;
        }

        final avgRate = students.isNotEmpty ? (totalRateSum / students.length).round() : 0;
        final selectedClassObj = data.getClassById(_selectedClassId);
        final selectedSecObj = data.getSectionById(_selectedSectionId);

        return Scaffold(
          appBar: AppBar(
            leading: showBackButton
                ? BackButton(onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      widget.onBack?.call();
                    }
                  })
                : null,
            title: const Text('Attendance Reports & Summaries'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Export CSV',
                onPressed: () {
                  final label =
                      '${selectedClassObj?.name ?? _selectedClassId}${selectedSecObj != null ? " / ${selectedSecObj.name}" : ""}';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Monthly attendance summary exported for $label'),
                      backgroundColor: AppTheme.present,
                    ),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Class & Section Filter Card
                Card(
                  margin: const EdgeInsets.all(14),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: _selectedClassId,
                                decoration: const InputDecoration(
                                  labelText: 'Select Class',
                                  isDense: true,
                                ),
                                items: classes
                                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedClassId = val;
                                      _selectedSectionId = null;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String?>(
                                value: _selectedSectionId,
                                decoration: const InputDecoration(
                                  labelText: 'Section',
                                  isDense: true,
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All Sections'),
                                  ),
                                  ...sections.map(
                                    (sec) => DropdownMenuItem<String?>(
                                      value: sec.id,
                                      child: Text(sec.name),
                                    ),
                                  ),
                                ],
                                onChanged: (val) => setState(() => _selectedSectionId = val),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Date Range & Export Actions Card
                Card(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month, size: 16),
                          label: Text('From: ${DateFormat.yMd().format(_reportFromDate)}'),
                          onPressed: () => _pickReportDate(fromDate: true),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month, size: 16),
                          label: Text('To: ${DateFormat.yMd().format(_reportToDate)}'),
                          onPressed: () => _pickReportDate(fromDate: false),
                        ),
                        FilledButton.icon(
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                          label: const Text('Export PDF Report'),
                          onPressed: () => _createWeeklyPdf(data),
                        ),
                      ],
                    ),
                  ),
                ),

                // KPI Metric Strip
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStripItem('Total Students', '${students.length}', AppTheme.primary),
                      _buildStripItem('Present (P)', '$totalP', AppTheme.present),
                      _buildStripItem('Absent (A)', '$totalA', AppTheme.absent),
                      _buildStripItem('Late (L)', '$totalL', AppTheme.late),
                      _buildStripItem('Leave (E)', '$totalE', AppTheme.excused),
                      _buildStripItem('Rate %', '$avgRate%', avgRate >= 75 ? AppTheme.present : AppTheme.absent),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Header for Breakdown
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Student Breakdown (${students.length} students)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'P / A / L / E Counts',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),

                // List of student records
                Expanded(
                  child: students.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_outline, size: 48, color: Colors.grey),
                              const SizedBox(height: 8),
                              Text(
                                _selectedSectionId != null
                                    ? 'No students enrolled in this section.'
                                    : 'No students found in this class.',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            final stats = data.calculateStudentStats(student.id);
                            final rate = stats['rate'] as int;
                            final sec = data.getSectionById(student.sectionId);

                            Color rateColor = AppTheme.present;
                            if (rate < 75) rateColor = AppTheme.absent;
                            else if (rate <= 85) rateColor = AppTheme.late;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppTheme.primaryLight,
                                      child: Text(
                                        '${student.rollNo}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(height: 2),
                                          Text(
                                            sec != null ? '${student.id} • ${sec.name}' : student.id,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        _buildCountBadge('P', stats['present'] as int, AppTheme.present),
                                        const SizedBox(width: 4),
                                        _buildCountBadge('A', stats['absent'] as int, AppTheme.absent),
                                        const SizedBox(width: 4),
                                        _buildCountBadge('L', stats['late'] as int, AppTheme.late),
                                        const SizedBox(width: 4),
                                        _buildCountBadge('E', stats['excused'] as int, AppTheme.excused),
                                      ],
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      width: 46,
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      decoration: BoxDecoration(
                                        color: rateColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$rate%',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: rateColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStripItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildCountBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
