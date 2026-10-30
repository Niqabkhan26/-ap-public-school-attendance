import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/intervention.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';

class InterventionDialog extends StatefulWidget {
  final Student student;
  final int rate;
  final int consecutiveAbsences;

  const InterventionDialog({
    super.key,
    required this.student,
    required this.rate,
    required this.consecutiveAbsences,
  });

  @override
  State<InterventionDialog> createState() => _InterventionDialogState();
}

class _InterventionDialogState extends State<InterventionDialog> {
  final _formKey = GlobalKey<FormState>();
  String _channel = 'Phone Call';
  late TextEditingController _staffController;
  final _notesController = TextEditingController();
  String _resolution = 'Contacted - Parent Informed';

  final List<String> _channels = [
    'Phone Call',
    'WhatsApp / SMS',
    'In-Person Meeting',
    'Official Warning Letter',
  ];

  final List<String> _resolutions = [
    'Contacted - Parent Informed',
    'Medical Certificate Requested',
    'Unreachable - Follow-up Required',
    'Resolved - Returning to School',
  ];

  @override
  void initState() {
    super.initState();
    _staffController = TextEditingController(text: DataService().currentUserName);
  }

  @override
  void dispose() {
    _staffController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.support_agent, color: AppTheme.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Log Guardian Follow-up',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student Header Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.student.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '${widget.rate}% Rate',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.absent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Guardian: ${widget.student.guardianName} (${widget.student.guardianPhone})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (widget.consecutiveAbsences > 0)
                      Text(
                        'Alert: ${widget.consecutiveAbsences} consecutive unexcused days',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.absent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Channel Dropdown
              const Text('Communication Channel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _channel,
                isDense: true,
                items: _channels.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _channel = val);
                },
              ),
              const SizedBox(height: 12),

              // Staff Caller
              const Text('Staff Caller / Recorder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              TextFormField(
                controller: _staffController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(isDense: true),
                validator: (val) => val == null || val.isEmpty ? 'Please enter staff name' : null,
              ),
              const SizedBox(height: 12),

              // Call Notes
              const Text('Notes & Parent Response', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Enter conversation summary, reasons given, and agreements...',
                  isDense: true,
                ),
                validator: (val) => val == null || val.isEmpty ? 'Please enter notes' : null,
              ),
              const SizedBox(height: 12),

              // Resolution Status
              const Text('Outcome / Resolution', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _resolution,
                isDense: true,
                items: _resolutions.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _resolution = val);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final newIntervention = Intervention(
                id: 'INT-${DateTime.now().millisecondsSinceEpoch}',
                studentId: widget.student.id,
                date: 'Today',
                channel: _channel,
                staff: _staffController.text.trim(),
                notes: _notesController.text.trim(),
                resolution: _resolution,
              );
              DataService().addIntervention(newIntervention);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Intervention logged for ${widget.student.name}'),
                  backgroundColor: AppTheme.present,
                ),
              );
            }
          },
          child: const Text('Save Record'),
        ),
      ],
    );
  }
}
