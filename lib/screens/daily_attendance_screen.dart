import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/data_service.dart';
import '../models/student.dart';
import '../models/section.dart';
import '../theme/app_theme.dart';
import '../widgets/student_card.dart';
import 'section_management_screen.dart';

class DailyAttendanceScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final String? initialClassId;

  const DailyAttendanceScreen({
    super.key,
    this.onBack,
    this.initialClassId,
  });

  @override
  State<DailyAttendanceScreen> createState() => _DailyAttendanceScreenState();
}

class _DailyAttendanceScreenState extends State<DailyAttendanceScreen> {
  String? _selectedClassId;
  String? _selectedSectionId;
  late DateTime _selectedDate;
  final Map<String, String> _statusMap = {}; // studentId -> 'P'|'A'|'L'|'E'
  final Map<String, String> _remarksMap = {}; // studentId -> remark
  bool _isDirty = false;
  bool _hasSavedAttendance = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    final data = DataService();

    if (widget.initialClassId != null &&
        data.classes.any((c) => c.id == widget.initialClassId)) {
      _selectedClassId = widget.initialClassId;
    } else if (data.classes.isNotEmpty) {
      _selectedClassId = data.classes.first.id;
    }

    // Auto-select first section if available
    if (_selectedClassId != null) {
      final secs = data.getSectionsForClass(_selectedClassId!);
      if (secs.isNotEmpty) {
        _selectedSectionId = secs.first.id;
      }
    }

    _loadClassData();
  }

  List<Section> _getSectionsForClass(String? classId) {
    if (classId == null || classId.isEmpty) return [];
    return DataService().getSectionsForClass(classId);
  }

  void _loadClassData() {
    if (_selectedClassId == null) {
      setState(() {
        _statusMap.clear();
        _remarksMap.clear();
      });
      return;
    }

    final data = DataService();
    final availableSections = data.getSectionsForClass(_selectedClassId!);

    // If this class has sections, require a section selection
    if (availableSections.isNotEmpty && _selectedSectionId == null) {
      _statusMap.clear();
      _remarksMap.clear();
      _isDirty = false;
      _hasSavedAttendance = false;
      setState(() {});
      return;
    }

    final dateStr = _selectedDate.toIso8601String().split('T')[0];

    // Load existing records for selected class, section and date
    final existing = data.getAttendanceForClassSectionAndDate(
      _selectedClassId!,
      _selectedSectionId,
      dateStr,
    );

    // Load only students belonging to the selected Class and Section
    final students = data.getStudentsForClassAndSection(
      _selectedClassId!,
      _selectedSectionId,
      status: 'active',
    );

    _statusMap.clear();
    _remarksMap.clear();

    for (var s in students) {
      final rec = existing.where((a) => a.studentId == s.id).toList();
      if (rec.isNotEmpty) {
        _statusMap[s.id] = rec.first.status;
        _remarksMap[s.id] = rec.first.remarks;
      } else {
        _statusMap[s.id] = 'P'; // Default Present
        _remarksMap[s.id] = '';
      }
    }

    _isDirty = false;
    _hasSavedAttendance = existing.isNotEmpty;
    setState(() {});
  }

  Future<void> _changeStatus(Student student, String newStatus) async {
    if (newStatus != 'A' && newStatus != 'L' && newStatus != 'E') {
      setState(() {
        _statusMap[student.id] = newStatus;
        if (newStatus == 'P') _remarksMap[student.id] = '';
        _isDirty = true;
        _hasSavedAttendance = false;
      });
      return;
    }

    var reason = newStatus == 'E' ? 'Approved Leave' : (newStatus == 'A' ? 'Sick' : 'Late arrival');
    final otherController = TextEditingController();
    final title = newStatus == 'A'
        ? 'Absence Reason'
        : (newStatus == 'L' ? 'Late Arrival Reason' : 'Leave Reason');

    final selectedReason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: [
                  DropdownMenuItem(value: reason, child: Text(reason)),
                  const DropdownMenuItem(value: 'Medical / Doctor Visit', child: Text('Medical / Doctor Visit')),
                  const DropdownMenuItem(value: 'Family Emergency', child: Text('Family Emergency')),
                  const DropdownMenuItem(value: 'Transport Issue', child: Text('Transport Issue')),
                  const DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => reason = value);
                },
              ),
              if (reason == 'Other') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: otherController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Enter specific reason'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (reason == 'Other' && otherController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, reason == 'Other' ? otherController.text.trim() : reason);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    otherController.dispose();

    if (selectedReason == null || !mounted) return;
    setState(() {
      _statusMap[student.id] = newStatus;
      _remarksMap[student.id] = selectedReason;
      _isDirty = true;
      _hasSavedAttendance = false;
    });
  }

  Future<void> _showAbsentWhatsAppList() async {
    if (_selectedClassId == null) return;
    final data = DataService();
    final absentStudents = data
        .getStudentsForClassAndSection(_selectedClassId!, _selectedSectionId, status: 'active')
        .where((student) => _statusMap[student.id] == 'A')
        .toList();

    if (absentStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No absent students recorded today.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Notify Absent Guardians (WhatsApp)'),
        content: SizedBox(
          width: 420,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: absentStudents.length,
            itemBuilder: (context, index) {
              final student = absentStudents[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.chat_outlined, color: AppTheme.present),
                title: Text(student.name),
                subtitle: Text('${student.guardianName} (${student.guardianPhone})'),
                trailing: IconButton(
                  tooltip: 'Open WhatsApp',
                  icon: const Icon(Icons.send_rounded, color: AppTheme.present),
                  onPressed: () => _openWhatsAppDraft(student),
                ),
                onTap: () => _openWhatsAppDraft(student),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> _openWhatsAppDraft(Student student) async {
    final data = DataService();
    final phone = student.guardianPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final date = DateFormat.yMMMMd().format(_selectedDate);
    final reason = _remarksMap[student.id]?.trim().isNotEmpty == true
        ? _remarksMap[student.id]!
        : 'Not provided';
    final message =
        'Assalam o Alaikum, Parent of ${student.name} - Your child was absent on $date at ${data.schoolName}. Reason recorded: $reason. - School Administration';
    final uri = Uri.https('wa.me', '/$phone', {'text': message});
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp for this number.')),
      );
    }
  }

  void _markAll(String status) {
    setState(() {
      _statusMap.updateAll((key, value) => status);
      if (status == 'P') _remarksMap.updateAll((key, value) => '');
      _isDirty = true;
      _hasSavedAttendance = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(status == 'P' ? 'All marked Present' : 'Attendance cleared'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 120)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadClassData();
    }
  }

  Future<bool> _confirmLeaveIfDirty() async {
    if (!_isDirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved attendance marks. Are you sure you want to navigate away without saving?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay & Save')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.absent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _saveAttendance() async {
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class first.')),
      );
      return;
    }

    final data = DataService();
    final messenger = ScaffoldMessenger.of(context);
    final dateStr = _selectedDate.toIso8601String().split('T')[0];

    if (data.isHolidayDate(dateStr)) {
      messenger.showSnackBar(
        SnackBar(content: Text('Attendance is disabled: ${data.holidayReason(dateStr)}.')),
      );
      return;
    }

    if (_statusMap.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No students to save attendance for.')),
      );
      return;
    }

    try {
      await data.saveDailyAttendance(
        dateStr: dateStr,
        classId: _selectedClassId!,
        sectionId: _selectedSectionId,
        statusMap: _statusMap,
        remarksMap: _remarksMap,
        recordedBy: data.currentUserName,
      );

      if (!mounted) return;
      setState(() {
        _isDirty = false;
        _hasSavedAttendance = true;
      });

      final cls = data.getClassById(_selectedClassId!);
      final sec = data.getSectionById(_selectedSectionId);
      final label = '${cls?.name ?? _selectedClassId}${sec != null ? " - ${sec.name}" : ""}';

      messenger.showSnackBar(
        SnackBar(
          content: Text('Attendance saved successfully for $label (${_statusMap.length} students)!'),
          backgroundColor: AppTheme.present,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save attendance: $e'),
          backgroundColor: AppTheme.absent,
        ),
      );
    }
  }

  void _handleBackPress() async {
    final canLeave = await _confirmLeaveIfDirty();
    if (canLeave && mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        widget.onBack?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = DataService();
    final classes = data.classes;
    final sections = _getSectionsForClass(_selectedClassId);
    final hasSectionsForClass = sections.isNotEmpty;
    final requiresSectionSelection = hasSectionsForClass && _selectedSectionId == null;

    final students = requiresSectionSelection
        ? <Student>[]
        : data.getStudentsForClassAndSection(
            _selectedClassId ?? '',
            _selectedSectionId,
            status: 'active',
          );

    final selectedClass = _selectedClassId != null ? data.getClassById(_selectedClassId!) : null;
    final selectedSection = data.getSectionById(_selectedSectionId);
    final dateStr = _selectedDate.toIso8601String().split('T')[0];

    // Real-time counts
    int countP = 0, countA = 0, countL = 0, countE = 0;
    _statusMap.forEach((_, status) {
      if (status == 'P') countP++;
      else if (status == 'A') countA++;
      else if (status == 'L') countL++;
      else if (status == 'E') countE++;
    });

    final bool showBackButton = widget.onBack != null || Navigator.canPop(context);

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _isDirty) {
          final leave = await _confirmLeaveIfDirty();
          if (leave && mounted) {
            setState(() => _isDirty = false);
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              widget.onBack?.call();
            }
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: showBackButton
              ? BackButton(onPressed: _handleBackPress)
              : null,
          title: const Text('Daily Attendance Entry'),
          actions: [
            if (_isDirty)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.lateSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.late),
                    ),
                    child: const Text(
                      'Unsaved',
                      style: TextStyle(
                        color: AppTheme.lateDark,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Filter Card (Class, Section, Date)
              Card(
                margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Class & Date Row
                      Row(
                        children: [
                          // Step 2: Select Class
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: _selectedClassId,
                              decoration: const InputDecoration(
                                labelText: '1. Class *',
                                isDense: true,
                              ),
                              items: classes.map((c) {
                                return DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null && val != _selectedClassId) {
                                  setState(() {
                                    _selectedClassId = val;
                                    // When class changes, reset the selected section
                                    final newSecs = data.getSectionsForClass(val);
                                    _selectedSectionId = newSecs.isNotEmpty ? newSecs.first.id : null;
                                  });
                                  _loadClassData();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Step 4: Select Attendance Date
                          Expanded(
                            flex: 2,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month, size: 16),
                              label: Text(
                                dateStr,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: _pickDate,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Step 3: Select Section
                      Row(
                        children: [
                          Expanded(
                            child: hasSectionsForClass
                                ? DropdownButtonFormField<String>(
                                    value: _selectedSectionId,
                                    decoration: InputDecoration(
                                      labelText: '2. Section *',
                                      isDense: true,
                                      prefixIcon: const Icon(Icons.meeting_room_outlined, size: 20),
                                      helperText: 'Select a section to load students',
                                      helperStyle: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    items: sections.map((sec) {
                                      final studentCount = data
                                          .getStudentsForClassAndSection(
                                              _selectedClassId!, sec.id,
                                              status: 'active')
                                          .length;
                                      return DropdownMenuItem(
                                        value: sec.id,
                                        child: Text(
                                          '${sec.name} ($studentCount students)',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedSectionId = val);
                                        _loadClassData();
                                      }
                                    },
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      border: Border.all(color: Colors.amber.shade300),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'No sections added for this class yet.',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const SectionManagementScreen(),
                                              ),
                                            ).then((_) => setState(() {}));
                                          },
                                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                          child: const Text('Add Section', style: TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Teacher & Quick Actions Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (selectedClass != null)
                                  Text(
                                    'Class: ${selectedClass.name} • Teacher: ${selectedClass.teacher}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (selectedSection != null)
                                  Text(
                                    'Active Section: ${selectedSection.name}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.done_all, size: 16),
                                label: const Text('Mark All P', style: TextStyle(fontSize: 12)),
                                onPressed: students.isEmpty ? null : () => _markAll('P'),
                              ),
                              TextButton(
                                onPressed: students.isEmpty ? null : () => _markAll('P'),
                                child: const Text('Reset', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Student Attendance List (Step 5 & 6)
              Expanded(
                child: data.isHolidayDate(dateStr)
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event_busy, size: 48, color: AppTheme.late),
                            const SizedBox(height: 8),
                            const Text('School Holiday', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(data.holidayReason(dateStr) ?? 'Holiday', style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : requiresSectionSelection
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_upward_rounded, size: 40, color: AppTheme.primary),
                                const SizedBox(height: 10),
                                const Text(
                                  'Please select a section above to view students',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Attendance is recorded separately for each section.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : students.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.people_outline, size: 44, color: Colors.grey),
                                    const SizedBox(height: 8),
                                    Text(
                                      selectedSection != null
                                          ? 'No students enrolled in ${selectedSection.name}.'
                                          : 'No active students found in this class.',
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.person_add, size: 16),
                                      label: const Text('Assign Students to this Section'),
                                      onPressed: () {
                                        if (widget.onBack != null) {
                                          widget.onBack?.call();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: students.length,
                                itemBuilder: (context, index) {
                                  final student = students[index];
                                  final status = _statusMap[student.id] ?? 'P';
                                  final remarks = _remarksMap[student.id] ?? '';
                                  final stats = data.calculateStudentStats(student.id);

                                  return StudentAttendanceCard(
                                    student: student,
                                    status: status,
                                    remarks: remarks,
                                    rate: stats['rate'] as int,
                                    onStatusChanged: (newStatus) => _changeStatus(student, newStatus),
                                    onRemarksChanged: (newRemark) {
                                      _remarksMap[student.id] = newRemark;
                                      _isDirty = true;
                                      _hasSavedAttendance = false;
                                    },
                                  );
                                },
                              ),
              ),

              // Step 7: Bottom Save & Summary Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      // Status count badges
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildStatChip('P', countP, AppTheme.present, AppTheme.presentSubtle),
                            _buildStatChip('A', countA, AppTheme.absent, AppTheme.absentSubtle),
                            _buildStatChip('L', countL, AppTheme.late, AppTheme.lateSubtle),
                            _buildStatChip('E', countE, AppTheme.excused, AppTheme.excusedSubtle),
                          ],
                        ),
                      ),
                      // Save Register button
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.save, size: 18),
                            label: const Text('Save Register'),
                            onPressed: (data.isHolidayDate(dateStr) || students.isEmpty)
                                ? null
                                : _saveAttendance,
                          ),
                          if (_hasSavedAttendance && !data.isHolidayDate(dateStr))
                            TextButton.icon(
                              icon: const Icon(Icons.chat, size: 15),
                              label: const Text(
                                'Absent WhatsApp',
                                style: TextStyle(fontSize: 11),
                              ),
                              onPressed: _showAbsentWhatsAppList,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String code, int count, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$code: $count',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
