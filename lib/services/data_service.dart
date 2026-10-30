import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';
import '../models/school_class.dart';
import '../models/attendance_record.dart';
import '../models/intervention.dart';
import '../models/section.dart';

/// Master class list — single source of truth used everywhere in the app.
const List<String> kClassNames = [
  'Prep',
  'Class 1',
  'Class 2',
  'Class 3',
  'Class 4',
  'Class 5',
  'Class 6',
  'Class 7',
  'Class 8',
  'Class 9',
  'Class 10',
];

String classIdFromName(String name) =>
    'CLS-${name.replaceAll(' ', '_').toUpperCase()}';

/// Generates a stable section ID from classId and section name.
String sectionId(String classId, String sectionName) =>
    'SEC-$classId-${sectionName.replaceAll(' ', '_').toUpperCase()}';

class DataService extends ChangeNotifier {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal() {
    initSampleData();
  }

  Future<void> loadSavedSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final savedStudents = preferences.getString('studentRecords');
    final savedAttendance = preferences.getString('attendanceRecords');
    final savedSections = preferences.getString('sectionRecords');

    if (savedStudents != null) {
      students = (jsonDecode(savedStudents) as List<dynamic>)
          .map((item) => Student.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    if (savedAttendance != null) {
      attendance = (jsonDecode(savedAttendance) as List<dynamic>)
          .map((item) => AttendanceRecord.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    if (savedSections != null) {
      sections = (jsonDecode(savedSections) as List<dynamic>)
          .map((item) => Section.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    schoolName = preferences.getString('schoolName') ?? schoolName;
    academicYear = preferences.getString('academicYear') ?? academicYear;
    currentTerm = preferences.getString('currentTerm') ?? currentTerm;
    warningThreshold = preferences.getInt('warningThreshold') ?? warningThreshold;
    consecutiveThreshold = preferences.getInt('consecutiveThreshold') ?? consecutiveThreshold;

    // Load per-class teacher names & photos
    for (final name in kClassNames) {
      final id = classIdFromName(name);
      final saved = preferences.getString('teacher_$id');
      if (saved != null) {
        classTeachers[id] = saved;
      }
      final savedPhoto = preferences.getString('teacher_photo_$id');
      if (savedPhoto != null) {
        teacherPhotos[id] = savedPhoto;
      }
    }

    holidays
      ..clear()
      ..addAll(preferences.getStringList('holidays')?.fold<Map<String, String>>({}, (map, item) {
        final separator = item.indexOf('|');
        if (separator > 0) map[item.substring(0, separator)] = item.substring(separator + 1);
        return map;
      }) ?? {});
    _applyTeacherNames();
    notifyListeners();
  }

  Future<void> _persistRecords() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('studentRecords', jsonEncode(students.map((student) => student.toJson()).toList()));
      await preferences.setString('attendanceRecords', jsonEncode(attendance.map((record) => record.toJson()).toList()));
      await preferences.setString('sectionRecords', jsonEncode(sections.map((s) => s.toJson()).toList()));
    } catch (e) {
      debugPrint('Persistence error: $e');
    }
  }

  void _applyTeacherNames() {
    classes = classes.map((schoolClass) {
      final teacher = classTeachers[schoolClass.id];
      if (teacher != null) {
        return SchoolClass(
          id: schoolClass.id,
          name: schoolClass.name,
          shortName: schoolClass.shortName,
          room: schoolClass.room,
          teacher: teacher,
        );
      }
      return schoolClass;
    }).toList();
  }

  bool isHolidayDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    return date != null && (date.weekday == DateTime.sunday || holidays.containsKey(dateStr));
  }

  String? holidayReason(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date?.weekday == DateTime.sunday) return 'Sunday';
    return holidays[dateStr];
  }

  Future<void> addHoliday(String dateStr, String reason) async {
    holidays[dateStr] = reason;
    await _saveHolidays();
    notifyListeners();
  }

  Future<void> removeHoliday(String dateStr) async {
    holidays.remove(dateStr);
    await _saveHolidays();
    notifyListeners();
  }

  Future<void> _saveHolidays() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('holidays', holidays.entries.map((entry) => '${entry.key}|${entry.value}').toList());
  }

  /// Save a single class teacher and optional photo, and persist.
  Future<void> saveClassTeacher(String classId, String teacher, {String? photoPath}) async {
    classTeachers[classId] = teacher;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('teacher_$classId', teacher);

    if (photoPath != null) {
      teacherPhotos[classId] = photoPath;
      await preferences.setString('teacher_photo_$classId', photoPath);
    }

    _applyTeacherNames();
    notifyListeners();
  }

  Future<void> saveSchoolSettings({
    required String name,
    required String year,
    required String term,
    required int warning,
    required int consecutive,
  }) async {
    updateSchoolSettings(name: name, year: year, term: term, warning: warning, consecutive: consecutive);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('schoolName', schoolName);
    await preferences.setString('academicYear', academicYear);
    await preferences.setString('currentTerm', currentTerm);
    await preferences.setInt('warningThreshold', warningThreshold);
    await preferences.setInt('consecutiveThreshold', consecutiveThreshold);
  }

  // School Settings
  String schoolName = 'AP Public Higher Secondary School';
  String academicYear = '2026-2027';
  String currentTerm = 'Term 1 (Mid-Year)';
  int warningThreshold = 75; // percentage
  int consecutiveThreshold = 3; // days

  // Compatibility getters
  String get grade9ATeacher => classTeachers['CLS-CLASS_9'] ?? 'Mr. Tariq Mehmood';
  String get grade9BTeacher => classTeachers['CLS-CLASS_10'] ?? 'Ms. Ayesha Khan';

  /// Map from classId -> teacher name. Pre-populated with defaults.
  Map<String, String> classTeachers = {
    'CLS-PREP': 'Ms. Razia Begum',
    'CLS-CLASS_1': 'Mr. Arif Hussain',
    'CLS-CLASS_2': 'Ms. Nadia Parveen',
    'CLS-CLASS_3': 'Mr. Khalid Mehmood',
    'CLS-CLASS_4': 'Ms. Saba Noor',
    'CLS-CLASS_5': 'Mr. Imran Baig',
    'CLS-CLASS_6': 'Ms. Saima Akhtar',
    'CLS-CLASS_7': 'Mr. Naveed Iqbal',
    'CLS-CLASS_8': 'Ms. Rukhsana Bibi',
    'CLS-CLASS_9': 'Mr. Tariq Mehmood',
    'CLS-CLASS_10': 'Ms. Ayesha Khan',
  };

  /// Map from classId -> teacher photo path (local file or network url)
  Map<String, String> teacherPhotos = {};

  final Map<String, String> holidays = {};

  // Current User Role
  String currentRole = 'admin'; // 'admin', 'teacher', 'staff'
  String currentUserName = 'Admin Office';

  // Theme Mode
  ThemeMode themeMode = ThemeMode.light;

  // Master Data Lists
  List<SchoolClass> classes = [];
  List<Student> students = [];
  List<AttendanceRecord> attendance = [];
  List<Intervention> interventions = [];
  List<AuditEntry> auditLog = [];

  /// Sections: dynamic list managed by the admin.
  List<Section> sections = [];

  void toggleTheme() {
    themeMode = (themeMode == ThemeMode.light) ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void refreshData() {
    notifyListeners();
  }

  void switchRole(String role) {
    currentRole = role;
    if (role == 'admin') {
      currentUserName = 'Admin Office';
    } else if (role == 'teacher') {
      currentUserName = 'Mr. Tariq Mehmood (Cl-9)';
    } else {
      currentUserName = 'Authorized Staff';
    }
    notifyListeners();
  }

  void initSampleData() {
    // Build classes from master list
    classes = kClassNames.map((name) {
      final id = classIdFromName(name);
      return SchoolClass(
        id: id,
        name: name,
        shortName: name,
        room: 'Room ${kClassNames.indexOf(name) + 1}',
        teacher: classTeachers[id] ?? 'TBD',
      );
    }).toList();

    // Initialize default sections if none exist yet
    if (sections.isEmpty) {
      sections = [
        Section(id: 'SEC-CLS-CLASS_9-A', classId: 'CLS-CLASS_9', name: 'Section A'),
        Section(id: 'SEC-CLS-CLASS_9-B', classId: 'CLS-CLASS_9', name: 'Section B'),
        Section(id: 'SEC-CLS-CLASS_10-A', classId: 'CLS-CLASS_10', name: 'Section A'),
        Section(id: 'SEC-CLS-CLASS_10-B', classId: 'CLS-CLASS_10', name: 'Section B'),
      ];
    }

    students = [
      // Prep
      Student(id: 'STU-P001', rollNo: 1, name: 'Zainab Bibi', classId: 'CLS-PREP', gender: 'Female', guardianName: 'Arif Hussain', guardianPhone: '+92 300 1110001'),
      Student(id: 'STU-P002', rollNo: 2, name: 'Hamid Khan', classId: 'CLS-PREP', gender: 'Male', guardianName: 'Sajid Khan', guardianPhone: '+92 300 1110002'),
      Student(id: 'STU-P003', rollNo: 3, name: 'Aroha Naz', classId: 'CLS-PREP', gender: 'Female', guardianName: 'Naz Begum', guardianPhone: '+92 300 1110003'),

      // Class 1
      Student(id: 'STU-C1-01', rollNo: 1, name: 'Bilal Shahid', classId: 'CLS-CLASS_1', gender: 'Male', guardianName: 'Shahid Iqbal', guardianPhone: '+92 301 1110011'),
      Student(id: 'STU-C1-02', rollNo: 2, name: 'Maham Aslam', classId: 'CLS-CLASS_1', gender: 'Female', guardianName: 'Aslam Mehmood', guardianPhone: '+92 301 1110012'),

      // Class 2
      Student(id: 'STU-C2-01', rollNo: 1, name: 'Uzair Farooq', classId: 'CLS-CLASS_2', gender: 'Male', guardianName: 'Farooq Ali', guardianPhone: '+92 302 1110021'),
      Student(id: 'STU-C2-02', rollNo: 2, name: 'Sana Fatima', classId: 'CLS-CLASS_2', gender: 'Female', guardianName: 'Fatima Noor', guardianPhone: '+92 302 1110022'),

      // Class 3
      Student(id: 'STU-C3-01', rollNo: 1, name: 'Awais Raza', classId: 'CLS-CLASS_3', gender: 'Male', guardianName: 'Raza Hussain', guardianPhone: '+92 303 1110031'),
      Student(id: 'STU-C3-02', rollNo: 2, name: 'Hira Qureshi', classId: 'CLS-CLASS_3', gender: 'Female', guardianName: 'Qureshi Sahib', guardianPhone: '+92 303 1110032'),

      // Class 4
      Student(id: 'STU-C4-01', rollNo: 1, name: 'Saad Nawaz', classId: 'CLS-CLASS_4', gender: 'Male', guardianName: 'Nawaz Sharif', guardianPhone: '+92 304 1110041'),
      Student(id: 'STU-C4-02', rollNo: 2, name: 'Laiba Imran', classId: 'CLS-CLASS_4', gender: 'Female', guardianName: 'Imran Gul', guardianPhone: '+92 304 1110042'),

      // Class 5
      Student(id: 'STU-C5-01', rollNo: 1, name: 'Faizan Baig', classId: 'CLS-CLASS_5', gender: 'Male', guardianName: 'Baig Sahib', guardianPhone: '+92 305 1110051'),
      Student(id: 'STU-C5-02', rollNo: 2, name: 'Amna Asif', classId: 'CLS-CLASS_5', gender: 'Female', guardianName: 'Asif Khan', guardianPhone: '+92 305 1110052'),

      // Class 6
      Student(id: 'STU-C6-01', rollNo: 1, name: 'Usman Ghani', classId: 'CLS-CLASS_6', gender: 'Male', guardianName: 'Ghani Rehman', guardianPhone: '+92 311 5551111'),
      Student(id: 'STU-C6-02', rollNo: 2, name: 'Sadia Malik', classId: 'CLS-CLASS_6', gender: 'Female', guardianName: 'Malik Akram', guardianPhone: '+92 312 5552222'),
      Student(id: 'STU-C6-03', rollNo: 3, name: 'Saad Rafique', classId: 'CLS-CLASS_6', gender: 'Male', guardianName: 'Rafique Zia', guardianPhone: '+92 313 5553333'),

      // Class 7
      Student(id: 'STU-C7-01', rollNo: 1, name: 'Zubair Shah', classId: 'CLS-CLASS_7', gender: 'Male', guardianName: 'Shah Nawaz', guardianPhone: '+92 321 5557777'),
      Student(id: 'STU-C7-02', rollNo: 2, name: 'Khadija Hussain', classId: 'CLS-CLASS_7', gender: 'Female', guardianName: 'Abid Hussain', guardianPhone: '+92 322 5558888'),
      Student(id: 'STU-C7-03', rollNo: 3, name: 'Hassan Noman', classId: 'CLS-CLASS_7', gender: 'Male', guardianName: 'Noman Riaz', guardianPhone: '+92 323 5559999'),

      // Class 8
      Student(id: 'STU-C8-01', rollNo: 1, name: 'Anum Fayyaz', classId: 'CLS-CLASS_8', gender: 'Female', guardianName: 'Fayyaz Gul', guardianPhone: '+92 324 5550000'),
      Student(id: 'STU-C8-02', rollNo: 2, name: 'Raza Ahmad', classId: 'CLS-CLASS_8', gender: 'Male', guardianName: 'Ahmad Khan', guardianPhone: '+92 324 5550001'),

      // Class 9 — Section A
      Student(id: 'STU-9001', rollNo: 1, name: 'Muhammad Ahmed', classId: 'CLS-CLASS_9', sectionId: 'SEC-CLS-CLASS_9-A', gender: 'Male', guardianName: 'Shahid Ahmed', guardianPhone: '+92 301 5551234'),
      Student(id: 'STU-9002', rollNo: 2, name: 'Fatima Zahra', classId: 'CLS-CLASS_9', sectionId: 'SEC-CLS-CLASS_9-A', gender: 'Female', guardianName: 'Zahra Begum', guardianPhone: '+92 302 5552345'),
      Student(id: 'STU-9003', rollNo: 3, name: 'Hamza Tariq', classId: 'CLS-CLASS_9', sectionId: 'SEC-CLS-CLASS_9-A', gender: 'Male', guardianName: 'Tariq Javed', guardianPhone: '+92 300 5553456'),
      // Class 9 — Section B
      Student(id: 'STU-9004', rollNo: 4, name: 'Zainab Noor', classId: 'CLS-CLASS_9', sectionId: 'SEC-CLS-CLASS_9-B', gender: 'Female', guardianName: 'Noor Muhammad', guardianPhone: '+92 303 5554567'),
      Student(id: 'STU-9005', rollNo: 5, name: 'Bilal Khan', classId: 'CLS-CLASS_9', sectionId: 'SEC-CLS-CLASS_9-B', gender: 'Male', guardianName: 'Asad Khan', guardianPhone: '+92 304 5555678'),

      // Class 10 — Section A
      Student(id: 'STU-1001', rollNo: 1, name: 'Ali Raza', classId: 'CLS-CLASS_10', sectionId: 'SEC-CLS-CLASS_10-A', gender: 'Male', guardianName: 'Raza Hussain', guardianPhone: '+92 306 5557890'),
      Student(id: 'STU-1002', rollNo: 2, name: 'Areeba Siddiqui', classId: 'CLS-CLASS_10', sectionId: 'SEC-CLS-CLASS_10-A', gender: 'Female', guardianName: 'Rashid Siddiqui', guardianPhone: '+92 307 5558901'),
      Student(id: 'STU-1003', rollNo: 3, name: 'Danish Farhan', classId: 'CLS-CLASS_10', sectionId: 'SEC-CLS-CLASS_10-A', gender: 'Male', guardianName: 'Farhan Sheikh', guardianPhone: '+92 308 5559012'),
      // Class 10 — Section B
      Student(id: 'STU-1004', rollNo: 4, name: 'Hania Imran', classId: 'CLS-CLASS_10', sectionId: 'SEC-CLS-CLASS_10-B', gender: 'Female', guardianName: 'Imran Bashir', guardianPhone: '+92 309 5550123'),
      Student(id: 'STU-1005', rollNo: 5, name: 'Maryam Asif', classId: 'CLS-CLASS_10', sectionId: 'SEC-CLS-CLASS_10-B', gender: 'Female', guardianName: 'Asif Mehmood', guardianPhone: '+92 305 5556789'),
    ];

    attendance = _generateHistoricalAttendance();

    interventions = [
      Intervention(
        id: 'INT-001',
        studentId: 'STU-9005',
        date: 'Yesterday 10:45 AM',
        channel: 'Phone Call',
        staff: 'Mr. Tariq (Staff)',
        notes: 'Called father Mr. Asad Khan. Advised regarding mandatory 75% board rule.',
        resolution: 'Contacted - Parent Informed',
      ),
      Intervention(
        id: 'INT-002',
        studentId: 'STU-1003',
        date: '2 days ago 11:20 AM',
        channel: 'WhatsApp',
        staff: 'Admin Office',
        notes: 'Prescription received for dengue fever. Approved medical leave.',
        resolution: 'Medical Certificate Requested',
      ),
    ];

    auditLog = [
      AuditEntry(
        id: 'AUD-001',
        timestamp: 'Today 08:30 AM',
        type: 'SUBMISSION',
        action: 'Daily Register Saved',
        details: 'Class 10',
        previousState: 'Pending',
        newState: 'Recorded',
        recordedBy: 'Ms. Ayesha Khan',
        reason: 'Regular morning attendance',
      ),
      AuditEntry(
        id: 'AUD-002',
        timestamp: 'Today 09:15 AM',
        type: 'CORRECTION',
        action: 'Status Corrected',
        details: 'Fatima Zahra (STU-9002)',
        previousState: 'Late (L)',
        newState: 'Present (P)',
        recordedBy: 'Admin Office',
        reason: 'Library duty slip produced',
      ),
    ];
    notifyListeners();
  }

  List<AttendanceRecord> _generateHistoricalAttendance() {
    final records = <AttendanceRecord>[];
    final today = DateTime.now();
    final pastDates = <String>[];

    for (int i = 13; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      if (d.weekday != DateTime.sunday) {
        pastDates.add(d.toIso8601String().split('T')[0]);
      }
    }

    for (int dateIdx = 0; dateIdx < pastDates.length; dateIdx++) {
      final dateStr = pastDates[dateIdx];

      for (var student in students) {
        String status = 'P';
        String remarks = '';

        if (student.id == 'STU-9005') {
          // Bilal Khan: 3 consecutive unexcused absences
          if (dateIdx >= pastDates.length - 3) {
            status = 'A';
            remarks = 'Unexcused - continuous absence';
          } else if (dateIdx % 3 == 0) {
            status = 'L';
            remarks = 'Late 15 mins';
          }
        } else if (student.id == 'STU-1003') {
          // Danish Farhan: Medical leave
          if (dateIdx >= pastDates.length - 4) {
            status = 'E';
            remarks = 'Medical leave';
          }
        } else {
          final rand = (student.rollNo * 17 + dateIdx * 31) % 100;
          if (rand < 3) {
            status = 'A';
          } else if (rand < 7) {
            status = 'L';
            remarks = 'Morning delay';
          } else if (rand < 9) {
            status = 'E';
            remarks = 'Leave requested';
          } else {
            status = 'P';
          }
        }

        records.add(AttendanceRecord(
          id: 'ATT-$dateStr-${student.id}',
          date: dateStr,
          classId: student.classId,
          sectionId: student.sectionId,
          studentId: student.id,
          status: status,
          remarks: remarks,
          recordedBy: 'Mr. Tariq (Staff)',
          timestamp: '${dateStr}T08:30:00Z',
        ));
      }
    }
    return records;
  }

  // ── Section Management ────────────────────────────────────────────────────

  /// Returns all sections for a given class.
  List<Section> getSectionsForClass(String classId) =>
      sections.where((s) => s.classId == classId).toList();

  /// Adds a new section. Returns false if a duplicate name already exists.
  bool addSection(String classId, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final duplicate = sections.any(
      (s) => s.classId == classId && s.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) return false;
    sections.add(Section(
      id: sectionId(classId, trimmed),
      classId: classId,
      name: trimmed,
    ));
    notifyListeners();
    _persistRecords();
    return true;
  }

  /// Renames a section. Returns false if name is duplicate.
  bool renameSection(String id, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;
    final idx = sections.indexWhere((s) => s.id == id);
    if (idx == -1) return false;
    final classId = sections[idx].classId;
    final duplicate = sections.any(
      (s) => s.classId == classId && s.name.toLowerCase() == trimmed.toLowerCase() && s.id != id,
    );
    if (duplicate) return false;
    sections[idx] = Section(id: id, classId: classId, name: trimmed);
    notifyListeners();
    _persistRecords();
    return true;
  }

  /// Deletes a section. Students in that section will have their sectionId cleared.
  void deleteSection(String id) {
    sections.removeWhere((s) => s.id == id);
    // Unlink students that belonged to this section
    students = students.map((s) {
      if (s.sectionId == id) return s.copyWith(sectionId: null);
      return s;
    }).toList();
    notifyListeners();
    _persistRecords();
  }

  Section? getSectionById(String? id) {
    if (id == null) return null;
    try {
      return sections.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  SchoolClass? getClassById(String classId) {
    try {
      return classes.firstWhere((c) => c.id == classId);
    } catch (_) {
      return null;
    }
  }

  void updateSchoolSettings({
    required String name,
    required String year,
    required String term,
    required int warning,
    required int consecutive,
  }) {
    schoolName = name;
    academicYear = year;
    currentTerm = term;
    warningThreshold = warning;
    consecutiveThreshold = consecutive;
    notifyListeners();
  }

  Student? getStudentById(String studentId) {
    try {
      return students.firstWhere((s) => s.id == studentId);
    } catch (_) {
      return null;
    }
  }

  List<Student> getStudentsForClass(String classId, {String status = 'all'}) {
    return students.where((s) {
      final matchesClass = (classId == 'all' || s.classId == classId);
      final matchesStatus = (status == 'all' || s.status == status);
      return matchesClass && matchesStatus;
    }).toList();
  }

  /// Returns students filtered by class and optionally by section.
  List<Student> getStudentsForClassAndSection(
    String classId,
    String? sectionId, {
    String status = 'all',
  }) {
    return students.where((s) {
      final matchesClass = s.classId == classId;
      final matchesSection = sectionId == null || s.sectionId == sectionId;
      final matchesStatus = (status == 'all' || s.status == status);
      return matchesClass && matchesSection && matchesStatus;
    }).toList();
  }

  List<AttendanceRecord> getAttendanceForClassAndDate(String classId, String dateStr) {
    return attendance.where((a) => a.classId == classId && a.date == dateStr).toList();
  }

  /// Returns attendance records for a specific class + section + date.
  List<AttendanceRecord> getAttendanceForClassSectionAndDate(
    String classId,
    String? sectionId,
    String dateStr,
  ) {
    return attendance.where((a) {
      final matchesClass = a.classId == classId;
      final matchesSection = sectionId == null || a.sectionId == sectionId;
      final matchesDate = a.date == dateStr;
      return matchesClass && matchesSection && matchesDate;
    }).toList();
  }

  // Student Attendance Statistics
  Map<String, dynamic> calculateStudentStats(String studentId) {
    final recs = attendance.where((a) => a.studentId == studentId && !isHolidayDate(a.date)).toList();
    if (recs.isEmpty) {
      return {'rate': 100, 'present': 0, 'absent': 0, 'late': 0, 'excused': 0, 'total': 0};
    }
    int p = 0, a = 0, l = 0, e = 0;
    for (var r in recs) {
      if (r.status == 'P') p++;
      else if (r.status == 'A') a++;
      else if (r.status == 'L') l++;
      else if (r.status == 'E') e++;
    }
    final effectivePresent = p + l;
    final rate = ((effectivePresent / recs.length) * 100).round();
    return {
      'rate': rate,
      'present': p,
      'absent': a,
      'late': l,
      'excused': e,
      'total': recs.length,
    };
  }

  // Chronic Absence Early Warning Scanner
  List<Map<String, dynamic>> detectFlaggedStudents() {
    final flagged = <Map<String, dynamic>>[];

    for (var student in students.where((s) => s.status == 'active')) {
      final recs = attendance.where((a) => a.studentId == student.id).toList()
        ..removeWhere((record) => isHolidayDate(record.date))
        ..sort((a, b) => a.date.compareTo(b.date));

      if (recs.isEmpty) continue;

      int presentCount = recs.where((a) => a.status == 'P' || a.status == 'L').length;
      int rate = ((presentCount / recs.length) * 100).round();

      // Count recent consecutive absences from back
      int consecutiveAbsences = 0;
      for (int i = recs.length - 1; i >= 0; i--) {
        if (recs[i].status == 'A') {
          consecutiveAbsences++;
        } else {
          break;
        }
      }

      final isConsecutiveAlert = consecutiveAbsences >= consecutiveThreshold;
      final isRateAlert = rate < warningThreshold;

      if (isConsecutiveAlert || isRateAlert) {
        final lastIntervention = interventions.where((it) => it.studentId == student.id).toList();
        flagged.add({
          'student': student,
          'rate': rate,
          'consecutiveAbsences': consecutiveAbsences,
          'isConsecutiveAlert': isConsecutiveAlert,
          'isRateAlert': isRateAlert,
          'lastIntervention': lastIntervention.isNotEmpty ? lastIntervention.first : null,
        });
      }
    }

    flagged.sort((a, b) {
      int cA = a['consecutiveAbsences'] as int;
      int cB = b['consecutiveAbsences'] as int;
      if (cA != cB) return cB.compareTo(cA);
      return (a['rate'] as int).compareTo(b['rate'] as int);
    });

    return flagged;
  }

  // Mutations
  Future<void> saveDailyAttendance({
    required String dateStr,
    required String classId,
    String? sectionId,
    required Map<String, String> statusMap, // studentId -> status
    required Map<String, String> remarksMap,
    required String recordedBy,
  }) async {
    if (isHolidayDate(dateStr)) return;

    int correctedCount = 0;

    statusMap.forEach((studentId, newStatus) {
      final student = getStudentById(studentId);
      final effectiveSectionId = sectionId ?? student?.sectionId;

      final existingIndex = attendance.indexWhere(
        (a) => a.date == dateStr && a.classId == classId && a.studentId == studentId,
      );

      final remark = remarksMap[studentId] ?? '';

      if (existingIndex != -1) {
        final old = attendance[existingIndex];
        if (old.status != newStatus) {
          correctedCount++;
          auditLog.insert(
            0,
            AuditEntry(
              id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
              timestamp: 'Today ${DateFormat.jm().format(DateTime.now())}',
              type: 'CORRECTION',
              action: 'Status Correction',
              details: 'Student ID: $studentId on $dateStr',
              previousState: old.status,
              newState: newStatus,
              recordedBy: recordedBy,
              reason: remark.isNotEmpty ? remark : 'Teacher update',
            ),
          );
        }
        old.status = newStatus;
        old.remarks = remark;
      } else {
        attendance.add(AttendanceRecord(
          id: 'ATT-$dateStr-$studentId',
          date: dateStr,
          classId: classId,
          sectionId: effectiveSectionId,
          studentId: studentId,
          status: newStatus,
          remarks: remark,
          recordedBy: recordedBy,
          timestamp: DateTime.now().toIso8601String(),
        ));
      }
    });

    final cls = getClassById(classId);
    final sec = getSectionById(sectionId);
    final details = '${cls != null ? cls.name : classId}${sec != null ? " / ${sec.name}" : ""} on $dateStr';
    auditLog.insert(
      0,
      AuditEntry(
        id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: 'Today',
        type: 'SUBMISSION',
        action: 'Attendance Saved',
        details: details,
        previousState: 'Draft',
        newState: '${statusMap.length} Students ($correctedCount corrections)',
        recordedBy: recordedBy,
        reason: 'Daily register submission',
      ),
    );

    notifyListeners();
    await _persistRecords();
  }

  void addStudent(Student s) {
    students.add(s);
    auditLog.insert(
      0,
      AuditEntry(
        id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: 'Just now',
        type: 'ROSTER',
        action: 'Student Enrolled',
        details: '${s.name} (${s.id})',
        previousState: 'N/A',
        newState: 'Active Enrolled',
        recordedBy: currentUserName,
        reason: 'New admission',
      ),
    );
    notifyListeners();
    _persistRecords();
  }

  void updateStudent(Student updated) {
    final idx = students.indexWhere((s) => s.id == updated.id);
    if (idx != -1) {
      students[idx] = updated;
      auditLog.insert(
        0,
        AuditEntry(
          id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: 'Just now',
          type: 'ROSTER',
          action: 'Student Updated',
          details: '${updated.name} (${updated.id})',
          previousState: 'Previous Profile',
          newState: 'Updated Profile',
          recordedBy: currentUserName,
          reason: 'Information modification',
        ),
      );
      notifyListeners();
      _persistRecords();
    }
  }

  void deleteStudent(String studentId) {
    final s = getStudentById(studentId);
    if (s != null) {
      students.removeWhere((item) => item.id == studentId);
      auditLog.insert(
        0,
        AuditEntry(
          id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: 'Just now',
          type: 'ROSTER',
          action: 'Student Removed',
          details: '${s.name} ($studentId)',
          previousState: 'Active',
          newState: 'Deleted',
          recordedBy: currentUserName,
          reason: 'Administrative deletion',
        ),
      );
      notifyListeners();
      _persistRecords();
    }
  }

  Future<void> flushPersistence() => Future<void>.value();

  void resetSampleData() {
    sections = [];
    initSampleData();
    _persistRecords();
  }

  void addIntervention(Intervention item) {
    interventions.insert(0, item);
    auditLog.insert(
      0,
      AuditEntry(
        id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: 'Just now',
        type: 'INTERVENTION',
        action: 'Guardian Communication',
        details: 'Student: ${item.studentId} via ${item.channel}',
        previousState: 'Warning Flagged',
        newState: item.resolution,
        recordedBy: item.staff,
        reason: item.notes,
      ),
    );
    notifyListeners();
  }
}
