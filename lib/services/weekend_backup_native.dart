import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'data_service.dart';
import 'export_service.dart';

Future<void> runWeekendAttendanceBackup(DataService data) async {
  if (!Platform.isAndroid) return;
  final now = DateTime.now();
  if (now.weekday != DateTime.saturday && now.weekday != DateTime.sunday) return;

  final weekStart = now.subtract(Duration(days: now.weekday - DateTime.monday));
  final weekKey = weekStart.toIso8601String().substring(0, 10);
  final preferences = await SharedPreferences.getInstance();
  if (preferences.getString('lastWeekendAttendanceBackup') == weekKey) return;

  await data.flushPersistence();
  final fileLocation = await ExportService.exportExcel(
    data,
    fileName: 'school-attendance-backup-$weekKey.xlsx',
  );
  if (fileLocation != null) {
    await preferences.setString('lastWeekendAttendanceBackup', weekKey);
  }
}
