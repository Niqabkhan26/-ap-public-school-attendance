import 'package:flutter/material.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';
import 'attendance_status_toggle.dart';

class StudentAttendanceCard extends StatefulWidget {
  final Student student;
  final String status;
  final String remarks;
  final int rate;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onRemarksChanged;

  const StudentAttendanceCard({
    super.key,
    required this.student,
    required this.status,
    required this.remarks,
    required this.rate,
    required this.onStatusChanged,
    required this.onRemarksChanged,
  });

  @override
  State<StudentAttendanceCard> createState() => _StudentAttendanceCardState();
}

class _StudentAttendanceCardState extends State<StudentAttendanceCard> {
  bool _showRemarksField = false;
  late TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController(text: widget.remarks);
    if (widget.remarks.isNotEmpty) {
      _showRemarksField = true;
    }
  }

  @override
  void didUpdateWidget(covariant StudentAttendanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remarks != widget.remarks) {
      _remarksController.text = widget.remarks;
      if (widget.remarks.isNotEmpty) {
        _showRemarksField = true;
      }
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color rateColor = AppTheme.present;
    if (widget.rate < 75) {
      rateColor = AppTheme.absent;
    } else if (widget.rate <= 85) {
      rateColor = AppTheme.late;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                // Roll No Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primaryLight,
                  child: Text(
                    '#${widget.student.rollNo}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name & ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.student.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            widget.student.id,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: rateColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${widget.rate}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: rateColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Toggle Buttons (P / A / L / E)
                AttendanceStatusToggle(
                  currentStatus: widget.status,
                  onStatusChanged: widget.onStatusChanged,
                ),
                // Toggle Note button
                IconButton(
                  icon: Icon(
                    _showRemarksField ? Icons.comment : Icons.comment_outlined,
                    size: 18,
                    color: widget.remarks.isNotEmpty
                        ? AppTheme.primary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
                  onPressed: () {
                    setState(() {
                      _showRemarksField = !_showRemarksField;
                    });
                  },
                  tooltip: 'Add Note/Reason',
                ),
              ],
            ),
            // Expandable Remark Field
            if (_showRemarksField) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _remarksController,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Note / Reason (e.g. sick leave, bus breakdown)...',
                  hintStyle: const TextStyle(fontSize: 12),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  suffixIcon: _remarksController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () {
                            _remarksController.clear();
                            widget.onRemarksChanged('');
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: widget.onRemarksChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
