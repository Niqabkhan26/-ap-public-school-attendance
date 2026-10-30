import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/export_service.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'section_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const SettingsScreen({super.key, this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _sessionController;
  late TextEditingController _termController;
  bool _pinEnabled = true;

  @override
  void initState() {
    super.initState();
    final data = DataService();
    _nameController = TextEditingController(text: data.schoolName);
    _sessionController = TextEditingController(text: data.academicYear);
    _termController = TextEditingController(text: data.currentTerm);
    _loadPinEnabled();
  }

  Future<void> _loadPinEnabled() async {
    final enabled = await LoginScreen.isPinEnabled();
    if (mounted) setState(() => _pinEnabled = enabled);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sessionController.dispose();
    _termController.dispose();
    super.dispose();
  }

  Future<void> _addHoliday(DataService data) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Holiday reason'),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason', hintText: 'Eid, 14 Aug, etc.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, reasonController.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || reason.isEmpty) return;
    await data.addHoliday(DateFormat('yyyy-MM-dd').format(date), reason);
  }

  /// Builds a CircleAvatar for teacher photo (FileImage, NetworkImage, or Icon fallback)
  Widget _buildTeacherAvatar(String? photoPath, double radius) {
    if (photoPath != null && photoPath.isNotEmpty) {
      if (photoPath.startsWith('http://') ||
          photoPath.startsWith('https://') ||
          photoPath.startsWith('blob:') ||
          photoPath.startsWith('data:')) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(photoPath),
          onBackgroundImageError: (_, __) {},
        );
      } else if (!kIsWeb) {
        final file = File(photoPath);
        if (file.existsSync()) {
          return CircleAvatar(
            radius: radius,
            backgroundImage: FileImage(file),
            onBackgroundImageError: (_, __) {},
          );
        }
      }
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primaryLight,
      child: Icon(Icons.person, color: AppTheme.primary, size: radius * 1.1),
    );
  }

  /// Opens an edit dialog for a single class teacher with photo picker and name field.
  void _editTeacher(DataService data, String classId, String className, String currentTeacher) {
    final ctrl = TextEditingController(text: currentTeacher);
    String? teacherPhoto = data.teacherPhotos[classId];
    final picker = ImagePicker();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit Teacher — $className'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final action = await showModalBottomSheet<ImageSource>(
                      context: ctx,
                      builder: (_) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('Take Photo'),
                              onTap: () => Navigator.pop(ctx, ImageSource.camera),
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('Choose from Gallery'),
                              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (action == null) return;
                    try {
                      final picked = await picker.pickImage(
                        source: action,
                        maxWidth: 512,
                        maxHeight: 512,
                        imageQuality: 80,
                      );
                      if (picked != null) {
                        setDialogState(() => teacherPhoto = picked.path);
                      }
                    } catch (_) {}
                  },
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      _buildTeacherAvatar(teacherPhoto, 36),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Teacher Name'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = ctrl.text.trim();
                if (name.isEmpty) return;
                await data.saveClassTeacher(classId, name, photoPath: teacherPhoto);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    ).then((_) => ctrl.dispose());
  }

  /// Dialog to update the 4-digit security PIN.
  void _showChangePinDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Security PIN'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Current PIN',
                  counterText: '',
                ),
                validator: (v) => v == null || v.length < 4 ? 'Enter 4 digits' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: newCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'New PIN (4 digits)',
                  counterText: '',
                ),
                validator: (v) => v == null || v.length != 4 ? 'Must be exactly 4 digits' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirmCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Confirm New PIN',
                  counterText: '',
                ),
                validator: (v) => v != newCtrl.text ? 'PINs do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final saved = await LoginScreen.savedPin();
              if (currentCtrl.text != saved) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Current PIN is incorrect.'),
                      behavior: SnackBarBehavior.floating,
                      margin: EdgeInsets.fromLTRB(16, 0, 16, 90),
                    ),
                  );
                }
                return;
              }
              await LoginScreen.savePin(newCtrl.text);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN updated successfully!'),
                    backgroundColor: AppTheme.present,
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.fromLTRB(16, 0, 16, 90),
                  ),
                );
              }
            },
            child: const Text('Save PIN'),
          ),
        ],
      ),
    ).then((_) {
      currentCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = DataService();

    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final bool showBackButton = widget.onBack != null || Navigator.canPop(context);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings & Configuration'),
            leading: showBackButton
                ? BackButton(onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      widget.onBack?.call();
                    }
                  })
                : const Icon(Icons.settings_outlined),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Login & Security Settings ───────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.lock_outline, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Login & Security Settings',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Configure 4-digit PIN authentication for app startup.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Require PIN on Startup', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(_pinEnabled ? 'PIN lock is active' : 'PIN lock is disabled', style: const TextStyle(fontSize: 12)),
                          value: _pinEnabled,
                          onChanged: (val) async {
                            await LoginScreen.setPinEnabled(val);
                            setState(() => _pinEnabled = val);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(val ? 'PIN lock enabled.' : 'PIN lock disabled.'),
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                                ),
                              );
                            }
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.password, color: AppTheme.primary, size: 22),
                          title: const Text('Change Security PIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Default PIN: 1234', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showChangePinDialog,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.logout, color: AppTheme.absent, size: 22),
                          title: const Text('Log Out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.absent)),
                          subtitle: const Text('Sign out of your active session', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.exit_to_app, color: AppTheme.absent, size: 18),
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Log Out?'),
                                content: const Text('Are you sure you want to sign out?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.absent),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Log Out'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await AuthService().logout();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Section Management ──────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.class_outlined, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Section Management',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add, rename, or delete sections within each class.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.view_list_outlined, color: AppTheme.primary, size: 22),
                          title: const Text('Manage Sections', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Builder(builder: (context) {
                            final data = DataService();
                            final total = data.sections.length;
                            return Text('$total section(s) across all classes', style: const TextStyle(fontSize: 12));
                          }),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SectionManagementScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── User Role Switcher ──────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.badge_outlined, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Role-Based Access',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Switch role to simulate different user permissions.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'admin', label: Text('Admin'), icon: Icon(Icons.admin_panel_settings, size: 16)),
                            ButtonSegment(value: 'teacher', label: Text('Teacher'), icon: Icon(Icons.school, size: 16)),
                            ButtonSegment(value: 'staff', label: Text('Staff'), icon: Icon(Icons.person, size: 16)),
                          ],
                          selected: {data.currentRole},
                          onSelectionChanged: (set) {
                            data.switchRole(set.first);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Switched to ${data.currentUserName}'),
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Appearance & Theme ──────────────────────────────────
                Card(
                  child: SwitchListTile(
                    title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Toggle between dark and light themes'),
                    secondary: Icon(
                      data.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                      color: AppTheme.primary,
                    ),
                    value: data.themeMode == ThemeMode.dark,
                    onChanged: (_) => data.toggleTheme(),
                  ),
                ),

                const SizedBox(height: 14),

                // ── School Profile Form ─────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.account_balance, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'School Profile & Thresholds',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'School Name'),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _sessionController,
                                decoration: const InputDecoration(labelText: 'Academic Session'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _termController,
                                decoration: const InputDecoration(labelText: 'Term'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Warning Threshold
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Chronic Absence Warning Threshold:',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${data.warningThreshold}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.absent),
                            ),
                          ],
                        ),
                        Slider(
                          value: data.warningThreshold.toDouble(),
                          min: 50,
                          max: 95,
                          divisions: 9,
                          label: '${data.warningThreshold}%',
                          onChanged: (val) {
                            setState(() {
                              data.warningThreshold = val.round();
                            });
                          },
                        ),
                        // Consecutive Days Threshold
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Consecutive Absences Alert Trigger:',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${data.consecutiveThreshold} Days',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.absent),
                            ),
                          ],
                        ),
                        Slider(
                          value: data.consecutiveThreshold.toDouble(),
                          min: 2,
                          max: 7,
                          divisions: 5,
                          label: '${data.consecutiveThreshold} Days',
                          onChanged: (val) {
                            setState(() {
                              data.consecutiveThreshold = val.round();
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await data.saveSchoolSettings(
                              name: _nameController.text.trim(),
                              year: _sessionController.text.trim(),
                              term: _termController.text.trim(),
                              warning: data.warningThreshold,
                              consecutive: data.consecutiveThreshold,
                            );
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('School settings updated!'),
                                backgroundColor: AppTheme.present,
                                behavior: SnackBarBehavior.floating,
                                margin: EdgeInsets.fromLTRB(16, 0, 16, 90),
                              ),
                            );
                          },
                          child: const Text('Save Settings'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Class Teachers ListView (Prep – Class 10) ───────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.school_outlined, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Class Teachers (Prep – Class 10)',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap Edit to update teacher name and photo for each class.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: data.classes.length,
                          itemBuilder: (context, index) {
                            final cls = data.classes[index];
                            final teacher = data.classTeachers[cls.id] ?? cls.teacher;
                            final photo = data.teacherPhotos[cls.id];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  _buildTeacherAvatar(photo, 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      cls.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      teacher,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => _editTeacher(data, cls.id, cls.name, teacher),
                                    child: const Text('Edit'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Holiday Calendar ────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_busy_outlined, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Holiday Calendar',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Add Holiday',
                              onPressed: () => _addHoliday(data),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                        const Text(
                          'Sundays are automatically excluded from attendance.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        if (data.holidays.isEmpty)
                          const Text('No custom holidays added.', style: TextStyle(color: Colors.grey))
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: data.holidays.length,
                            itemBuilder: (context, index) {
                              final entries = (data.holidays.entries.toList()
                                ..sort((a, b) => a.key.compareTo(b.key)));
                              final entry = entries[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(DateFormat.yMMMd().format(DateTime.parse(entry.key))),
                                trailing: IconButton(
                                  tooltip: 'Remove holiday',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => data.removeHoliday(entry.key),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Data Backup & Reset ─────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.backup_outlined, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Text('Data & Recovery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.table_view_outlined, color: AppTheme.present),
                          title: const Text('Backup to Excel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Export attendance rows to .xlsx', style: TextStyle(fontSize: 12)),
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final path = await ExportService.exportExcel(data);
                            if (!mounted) return;
                            messenger.showSnackBar(SnackBar(
                              content: Text(path == null ? 'Excel export failed.' : 'Excel backup saved: $path'),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                            ));
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.cloud_download_outlined, color: AppTheme.primary),
                          title: const Text('Backup Data', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Export a complete JSON backup', style: TextStyle(fontSize: 12)),
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final path = await ExportService.exportJson(data);
                            if (!mounted) return;
                            messenger.showSnackBar(SnackBar(
                              content: Text(path == null ? 'JSON export failed.' : 'JSON backup saved: $path'),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                            ));
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.restore, color: AppTheme.absent),
                          title: const Text(
                            'Reset Sample Data',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.absent),
                          ),
                          subtitle: const Text(
                            'Repopulates fresh classes, students, and 2 weeks of sample attendance',
                            style: TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Reset to Sample Data?'),
                                content: const Text(
                                  'This will reset classes, rosters, and attendance back to default sample records.',
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.absent),
                                    onPressed: () {
                                      data.resetSampleData();
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Sample data re-seeded successfully.'),
                                          behavior: SnackBarBehavior.floating,
                                          margin: EdgeInsets.fromLTRB(16, 0, 16, 90),
                                        ),
                                      );
                                    },
                                    child: const Text('Reset Data'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const Divider(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
