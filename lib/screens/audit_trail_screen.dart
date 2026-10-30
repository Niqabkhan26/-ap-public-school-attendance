import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';

class AuditTrailScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const AuditTrailScreen({super.key, this.onBack});

  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  String _selectedType = 'ALL';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final data = DataService();
    final bool showBackButton = widget.onBack != null || Navigator.canPop(context);

    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        var logs = data.auditLog;

        if (_selectedType != 'ALL') {
          logs = logs.where((e) => e.type == _selectedType).toList();
        }

        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          logs = logs.where((e) =>
            e.action.toLowerCase().contains(q) ||
            e.details.toLowerCase().contains(q) ||
            e.recordedBy.toLowerCase().contains(q) ||
            e.reason.toLowerCase().contains(q)
          ).toList();
        }

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
            title: const Text('Security & Audit Trail'),
            actions: [
              IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: 'Export Audit Log CSV',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Audit log exported successfully.'),
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
              // Search & Filter Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Filter by action, staff, or student...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),

              // Filter Chips
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    _buildFilterChip('ALL', 'All Events'),
                    _buildFilterChip('SUBMISSION', 'Submissions'),
                    _buildFilterChip('CORRECTION', 'Corrections'),
                    _buildFilterChip('ROSTER', 'Roster Updates'),
                    _buildFilterChip('INTERVENTION', 'Interventions'),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${logs.length} audit records',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),

              // Log Timeline List
              Expanded(
                child: logs.isEmpty
                    ? const Center(child: Text('No audit events matching criteria.'))
                    : ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final item = logs[index];

                          Color typeColor = AppTheme.primary;
                          IconData typeIcon = Icons.info_outline;

                          if (item.type == 'SUBMISSION') {
                            typeColor = AppTheme.present;
                            typeIcon = Icons.assignment_turned_in;
                          } else if (item.type == 'CORRECTION') {
                            typeColor = AppTheme.late;
                            typeIcon = Icons.edit_note;
                          } else if (item.type == 'INTERVENTION') {
                            typeColor = AppTheme.excused;
                            typeIcon = Icons.support_agent;
                          } else if (item.type == 'ROSTER') {
                            typeColor = Colors.purple;
                            typeIcon = Icons.people_outline;
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: typeColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(typeIcon, size: 12, color: typeColor),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.type,
                                              style: TextStyle(color: typeColor, fontWeight: FontWeight.bold, fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        item.timestamp,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.action,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.details,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  // State transition
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Text('From: ', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                                        Text(item.previousState, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward, size: 12),
                                        const SizedBox(width: 8),
                                        Text('To: ', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                                        Text(item.newState, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.present)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'By: ${item.recordedBy}',
                                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                                      ),
                                      if (item.reason.isNotEmpty)
                                        Text(
                                          'Reason: ${item.reason}',
                                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                                        ),
                                    ],
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

  Widget _buildFilterChip(String type, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: FilterChip(
        label: Text(label),
        selected: _selectedType == type,
        onSelected: (_) => setState(() => _selectedType = type),
      ),
    );
  }
}
