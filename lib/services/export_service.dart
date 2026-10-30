import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import 'data_service.dart';
import 'download_service.dart';

class ExportService {
  static Future<String?> exportJson(DataService data) async {
    await data.flushPersistence();
    final payload = {
      'schoolName': data.schoolName,
      'academicYear': data.academicYear,
      'currentTerm': data.currentTerm,
      'teachers': data.classTeachers,
      'holidays': data.holidays,
      'students': data.students.map((student) => student.toJson()).toList(),
      'attendance': data.attendance.map((record) => record.toJson()).toList(),
      'interventions': data.interventions.map((item) => item.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
    final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)));
    return saveDownloadFile(bytes, 'school-attendance-backup.json', 'application/json');
  }

  static Future<String?> exportExcel(DataService data, {String fileName = 'school-attendance-backup.xlsx'}) async {
    await data.flushPersistence();
    final output = buildExcelBytes(data);
    if (output == null) return null;
    return saveDownloadFile(
      output,
      fileName,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  static Uint8List? buildExcelBytes(DataService data) {
    final workbook = Excel.createExcel();
    workbook.delete('Sheet1');
    for (final schoolClass in data.classes) {
      final sheet = workbook[schoolClass.shortName];
      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Day'),
        TextCellValue('Roll No'),
        TextCellValue('Student'),
        TextCellValue('Status'),
        TextCellValue('Reason'),
        TextCellValue('Recorded By'),
      ]);

      final classRecords = data.attendance.where((record) => record.classId == schoolClass.id).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      for (final record in classRecords) {
        final student = data.getStudentById(record.studentId);
        sheet.appendRow([
          TextCellValue(record.date),
          TextCellValue(DateFormat('EEEE').format(DateTime.parse(record.date))),
          IntCellValue(student?.rollNo ?? 0),
          TextCellValue(student?.name ?? record.studentId),
          TextCellValue(record.status),
          TextCellValue(record.remarks),
          TextCellValue(record.recordedBy),
        ]);
      }
    }

    final bytes = workbook.save();
    if (bytes == null) return null;
    return Uint8List.fromList(bytes);
  }
}
