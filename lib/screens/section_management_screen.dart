import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../models/section.dart';
import '../theme/app_theme.dart';

/// Full-screen Section Management page.
/// Shows all classes and their sections with add / edit / delete controls.
class SectionManagementScreen extends StatefulWidget {
  const SectionManagementScreen({super.key});

  @override
  State<SectionManagementScreen> createState() => _SectionManagementScreenState();
}

class _SectionManagementScreenState extends State<SectionManagementScreen> {
  // Expand the first class by default
  String? _expandedClassId;

  @override
  void initState() {
    super.initState();
    final data = DataService();
    if (data.classes.isNotEmpty) {
      _expandedClassId = data.classes.first.id;
    }
  }

  Future<void> _showAddSectionDialog(String classId, String className) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Section to $className'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Section Name *',
            hintText: 'e.g. Section A',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty || !mounted) return;

    final data = DataService();
    final ok = data.addSection(classId, result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '"$result" added to $className'
            : 'A section named "$result" already exists in $className.'),
        backgroundColor: ok ? AppTheme.present : AppTheme.absent,
      ),
    );
  }

  Future<void> _showRenameSectionDialog(Section section) async {
    final controller = TextEditingController(text: section.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Section'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'New Name *'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty || !mounted) return;

    final data = DataService();
    final ok = data.renameSection(section.id, result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Section renamed to "$result"' : 'A section with that name already exists.'),
        backgroundColor: ok ? AppTheme.present : AppTheme.absent,
      ),
    );
  }

  Future<void> _confirmDeleteSection(Section section, String className) async {
    final data = DataService();
    final studentsInSection = data.students
        .where((s) => s.sectionId == section.id)
        .length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Section?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remove "${section.name}" from $className?'),
            if (studentsInSection > 0) ...[
              const SizedBox(height: 10),
              Text(
                '$studentsInSection student(s) are assigned to this section and will be unlinked.',
                style: const TextStyle(color: AppTheme.absent, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.absent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    DataService().deleteSection(section.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${section.name}" deleted from $className.'),
        backgroundColor: AppTheme.absent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = DataService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Section Management'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          final classes = data.classes;
          return classes.isEmpty
              ? const Center(child: Text('No classes available.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: classes.length,
                  itemBuilder: (context, index) {
                    final cls = classes[index];
                    final clsSections = data.getSectionsForClass(cls.id);
                    final isExpanded = _expandedClassId == cls.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Class header / expand toggle
                          InkWell(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            onTap: () => setState(() {
                              _expandedClassId = isExpanded ? null : cls.id;
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppTheme.primaryLight,
                                    radius: 18,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cls.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          '${clsSections.length} section(s)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Add section button
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                                    tooltip: 'Add section',
                                    onPressed: () => _showAddSectionDialog(cls.id, cls.name),
                                  ),
                                  Icon(
                                    isExpanded ? Icons.expand_less : Icons.expand_more,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Expanded section list
                          if (isExpanded) ...[
                            const Divider(height: 1),
                            if (clsSections.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'No sections yet. Tap + to add one.',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: clsSections.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                                itemBuilder: (context, i) {
                                  final sec = clsSections[i];
                                  final studentCount = data.students
                                      .where((s) => s.sectionId == sec.id)
                                      .length;
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                    leading: const CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppTheme.presentSubtle,
                                      child: Icon(Icons.class_, size: 14, color: AppTheme.present),
                                    ),
                                    title: Text(
                                      sec.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      '$studentCount student(s)',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 20),
                                      onSelected: (action) {
                                        if (action == 'rename') {
                                          _showRenameSectionDialog(sec);
                                        } else if (action == 'delete') {
                                          _confirmDeleteSection(sec, cls.name);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'rename',
                                          child: Row(children: [
                                            Icon(Icons.edit, size: 16),
                                            SizedBox(width: 8),
                                            Text('Rename'),
                                          ]),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(children: [
                                            Icon(Icons.delete, size: 16, color: AppTheme.absent),
                                            SizedBox(width: 8),
                                            Text('Delete', style: TextStyle(color: AppTheme.absent)),
                                          ]),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ],
                      ),
                    );
                  },
                );
        },
      ),
    );
  }
}

