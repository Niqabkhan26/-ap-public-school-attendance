import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../models/student.dart';
import '../models/section.dart';
import '../theme/app_theme.dart';
import 'section_management_screen.dart';

class StudentRosterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const StudentRosterScreen({super.key, this.onBack});

  @override
  State<StudentRosterScreen> createState() => _StudentRosterScreenState();
}

class _StudentRosterScreenState extends State<StudentRosterScreen> {
  String _searchQuery = '';
  String _selectedClassFilter = 'all';
  String? _selectedSectionFilter;

  Future<void> _showImportDialog() async {
    final data = DataService();
    final controller = TextEditingController();
    var classId = _selectedClassFilter == 'all' ? data.classes.first.id : _selectedClassFilter;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Import Students'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: classId,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: data.classes
                      .map((schoolClass) => DropdownMenuItem(
                            value: schoolClass.id,
                            child: Text(
                              schoolClass.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => classId = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  minLines: 5,
                  maxLines: 9,
                  decoration: const InputDecoration(
                    labelText: 'One student per line',
                    hintText: 'Roll number, name, parent phone number',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {'classId': classId, 'rows': controller.text}),
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null) return;

    var imported = 0;
    final rows = result['rows']!.split(RegExp(r'\r?\n'));
    for (var index = 0; index < rows.length; index++) {
      final columns = rows[index].split(',').map((value) => value.trim()).toList();
      if (columns.length < 3) continue;
      final rollNo = int.tryParse(columns[0]);
      if (rollNo == null || columns[1].isEmpty || columns[2].isEmpty) continue;
      data.addStudent(Student(
        id: 'STU-${DateTime.now().microsecondsSinceEpoch}-$index',
        rollNo: rollNo,
        name: columns[1],
        classId: result['classId']!,
        gender: 'Male',
        guardianName: 'Parent',
        guardianPhone: columns[2],
      ));
      imported++;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$imported student(s) imported.'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 80),
      ),
    );
  }

  void _showStudentDialog({Student? student}) {
    final data = DataService();
    final isEditing = student != null;
    final idController =
        TextEditingController(text: student?.id ?? 'STU-${1000 + data.students.length + 1}');
    final rollController =
        TextEditingController(text: student?.rollNo.toString() ?? '${data.students.length + 1}');
    final nameController = TextEditingController(text: student?.name ?? '');
    String classId = student?.classId ?? data.classes.first.id;
    String? sectionId = student?.sectionId;
    String gender = student?.gender ?? 'Male';
    final dobController = TextEditingController(text: student?.dob ?? '');
    final guardianController = TextEditingController(text: student?.guardianName ?? '');
    final phoneController = TextEditingController(text: student?.guardianPhone ?? '');
    final addressController = TextEditingController(text: student?.address ?? '');
    String status = student?.status ?? 'active';
    String? photoPath = student?.photoPath;

    bool isFormModified = false;
    final formKey = GlobalKey<FormState>();
    final picker = ImagePicker();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final sectionsForClass = data.getSectionsForClass(classId);

          // Validate sectionId belongs to this class
          if (sectionId != null &&
              !sectionsForClass.any((s) => s.id == sectionId)) {
            sectionId = null;
          }

          Future<bool> confirmCancel() async {
            if (!isFormModified && nameController.text.isEmpty) return true;
            final leave = await showDialog<bool>(
              context: ctx,
              builder: (c) => AlertDialog(
                title: const Text('Discard Changes?'),
                content: const Text('You have unsaved changes in this student form. Discard?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep Editing')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.absent),
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            );
            return leave ?? false;
          }

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (!didPop) {
                final discard = await confirmCancel();
                if (discard && ctx.mounted) {
                  Navigator.pop(ctx);
                }
              }
            },
            child: AlertDialog(
              title: Row(
                children: [
                  Icon(isEditing ? Icons.edit : Icons.person_add, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(isEditing ? 'Edit Student Details' : 'Add New Student'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    onChanged: () => isFormModified = true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Photo Avatar Picker
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
                                isFormModified = true;
                                setDialogState(() => photoPath = picked.path);
                              }
                            } catch (_) {}
                          },
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              _buildStudentAvatar(photoPath, 42),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 1. Student ID & Roll Number
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: idController,
                                enabled: !isEditing,
                                decoration: const InputDecoration(labelText: 'Student ID *', isDense: true),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: rollController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Roll No *', isDense: true),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // 2. Student Full Name
                        TextFormField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Student Full Name *', isDense: true),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Please enter student name' : null,
                        ),
                        const SizedBox(height: 10),

                        // 3. Class Field
                        DropdownButtonFormField<String>(
                          value: classId,
                          decoration: const InputDecoration(labelText: 'Class *', isDense: true),
                          items: data.classes
                              .map((c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null && val != classId) {
                              setDialogState(() {
                                isFormModified = true;
                                classId = val;
                                // Clear previously selected section and reload
                                sectionId = null;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 10),

                        // 4. Section Field
                        sectionsForClass.isEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'No sections available. Please add a section first.',
                                        style: TextStyle(fontSize: 11, color: Colors.black87),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const SectionManagementScreen()),
                                        ).then((_) {
                                          setDialogState(() {});
                                        });
                                      },
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: const Text('Add Section', style: TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                              )
                            : DropdownButtonFormField<String?>(
                                value: sectionId,
                                decoration: const InputDecoration(
                                  labelText: 'Section *',
                                  isDense: true,
                                  helperText: 'Select section for this class',
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('— Select Section —'),
                                  ),
                                  ...sectionsForClass.map(
                                    (sec) => DropdownMenuItem<String?>(
                                      value: sec.id,
                                      child: Text(sec.name),
                                    ),
                                  ),
                                ],
                                validator: (val) {
                                  if (sectionsForClass.isNotEmpty && val == null) {
                                    return 'Please select a section';
                                  }
                                  return null;
                                },
                                onChanged: (val) {
                                  isFormModified = true;
                                  setDialogState(() => sectionId = val);
                                },
                              ),
                        const SizedBox(height: 10),

                        // 5. Gender & 6. Date of Birth
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                value: gender,
                                decoration: const InputDecoration(labelText: 'Gender', isDense: true),
                                items: ['Male', 'Female', 'Other']
                                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    isFormModified = true;
                                    setDialogState(() => gender = val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: dobController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Date of Birth',
                                  isDense: true,
                                  suffixIcon: Icon(Icons.calendar_today, size: 16),
                                ),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                                    firstDate: DateTime(1990),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    isFormModified = true;
                                    setDialogState(() {
                                      dobController.text = DateFormat('yyyy-MM-dd').format(picked);
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // 7. Guardian Name & 8. Guardian Contact Number
                        TextFormField(
                          controller: guardianController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Guardian / Parent Name *', isDense: true),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Please enter guardian name' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Guardian Contact Number *', isDense: true),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Please enter contact number' : null,
                        ),
                        const SizedBox(height: 10),

                        // 9. Address
                        TextFormField(
                          controller: addressController,
                          decoration: const InputDecoration(labelText: 'Address (optional)', isDense: true),
                        ),
                        const SizedBox(height: 10),

                        // Enrollment Status
                        DropdownButtonFormField<String>(
                          value: status,
                          decoration: const InputDecoration(labelText: 'Enrollment Status', isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'active', child: Text('Active Enrolled')),
                            DropdownMenuItem(value: 'inactive', child: Text('Inactive / On Leave')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              isFormModified = true;
                              setDialogState(() => status = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final discard = await confirmCancel();
                    if (discard && ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final studentObj = Student(
                        id: idController.text.trim(),
                        rollNo: int.tryParse(rollController.text) ?? 1,
                        name: nameController.text.trim(),
                        classId: classId,
                        sectionId: sectionId,
                        gender: gender,
                        dob: dobController.text.trim().isNotEmpty ? dobController.text.trim() : null,
                        guardianName: guardianController.text.trim(),
                        guardianPhone: phoneController.text.trim(),
                        address: addressController.text.trim().isNotEmpty ? addressController.text.trim() : null,
                        status: status,
                        photoPath: photoPath,
                      );

                      if (isEditing) {
                        data.updateStudent(studentObj);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${studentObj.name} updated successfully'),
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                          ),
                        );
                      } else {
                        data.addStudent(studentObj);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${studentObj.name} added to roster'),
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                          ),
                        );
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(isEditing ? 'Update Student' : 'Save Student'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStudentAvatar(String? photoPath, double radius) {
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
      child: Icon(Icons.person, color: AppTheme.primary, size: radius),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = DataService();
    final bool showBackButton = widget.onBack != null || Navigator.canPop(context);

    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        var list = data.students;

        if (_selectedClassFilter != 'all') {
          list = list.where((s) => s.classId == _selectedClassFilter).toList();
        }

        if (_selectedSectionFilter != null) {
          list = list.where((s) => s.sectionId == _selectedSectionFilter).toList();
        }

        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          list = list
              .where((s) =>
                  s.name.toLowerCase().contains(q) ||
                  s.id.toLowerCase().contains(q) ||
                  s.guardianName.toLowerCase().contains(q) ||
                  s.guardianPhone.contains(q))
              .toList();
        }

        final sectionsForCurrentClass = _selectedClassFilter != 'all'
            ? data.getSectionsForClass(_selectedClassFilter)
            : <Section>[];

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
            title: const Text('Student & Class Roster'),
            actions: [
              IconButton(
                tooltip: 'Section Management',
                icon: const Icon(Icons.class_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SectionManagementScreen()),
                  );
                },
              ),
              IconButton(
                tooltip: 'Import students',
                onPressed: _showImportDialog,
                icon: const Icon(Icons.file_upload_outlined),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showStudentDialog(),
            icon: const Icon(Icons.person_add),
            label: const Text('Add Student'),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Search Field
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by student name, ID, or phone...',
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

                // Class Filter Chips
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: FilterChip(
                          label: const Text('All Classes'),
                          selected: _selectedClassFilter == 'all',
                          onSelected: (_) => setState(() {
                            _selectedClassFilter = 'all';
                            _selectedSectionFilter = null;
                          }),
                        ),
                      ),
                      ...data.classes.map((c) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: FilterChip(
                            label: Text(c.shortName),
                            selected: _selectedClassFilter == c.id,
                            onSelected: (_) => setState(() {
                              _selectedClassFilter = c.id;
                              _selectedSectionFilter = null;
                            }),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Section Filter Chips (if class selected and has sections)
                if (sectionsForCurrentClass.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: const Text('All Sections', style: TextStyle(fontSize: 12)),
                            selected: _selectedSectionFilter == null,
                            onSelected: (_) => setState(() => _selectedSectionFilter = null),
                          ),
                        ),
                        ...sectionsForCurrentClass.map((sec) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(sec.name, style: const TextStyle(fontSize: 12)),
                              selected: _selectedSectionFilter == sec.id,
                              onSelected: (_) => setState(() => _selectedSectionFilter = sec.id),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                // Results Count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${list.length} students',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                // Student List
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_outline, size: 48, color: Colors.grey),
                              const SizedBox(height: 8),
                              const Text('No students match the criteria.'),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.person_add, size: 16),
                                label: const Text('Add Student'),
                                onPressed: () => _showStudentDialog(),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final student = list[index];
                            final cls = data.getClassById(student.classId);
                            final sec = data.getSectionById(student.sectionId);
                            final stats = data.calculateStudentStats(student.id);
                            final rate = stats['rate'] as int;

                            Color badgeColor = AppTheme.present;
                            if (rate < 75) badgeColor = AppTheme.absent;
                            else if (rate <= 85) badgeColor = AppTheme.late;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              child: ListTile(
                                leading: _buildStudentAvatar(student.photoPath, 22),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${student.rollNo}. ${student.name}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$rate%',
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        cls?.name ?? student.classId,
                                        if (sec != null) sec.name,
                                        'ID: ${student.id}',
                                      ].join(' • '),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Guardian: ${student.guardianName} (${student.guardianPhone})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      _showStudentDialog(student: student);
                                    } else if (action == 'delete') {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Student?'),
                                          content: Text('Remove ${student.name} from the school directory?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.absent),
                                              onPressed: () {
                                                data.deleteStudent(student.id);
                                                Navigator.pop(ctx);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('${student.name} removed from roster.'),
                                                    behavior: SnackBarBehavior.floating,
                                                    margin: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                                                  ),
                                                );
                                              },
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(children: [
                                        Icon(Icons.edit, size: 16),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ]),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(children: [
                                        Icon(Icons.delete, color: AppTheme.absent, size: 16),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: AppTheme.absent)),
                                      ]),
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
}
