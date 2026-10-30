class AttendanceRecord {
  final String id;
  final String date; // YYYY-MM-DD
  final String classId;
  final String? sectionId; // nullable for backward-compat
  final String studentId;
  String status; // 'P' (Present), 'A' (Absent), 'L' (Late), 'E' (Excused)
  String remarks;
  final String recordedBy;
  final String timestamp;

  AttendanceRecord({
    required this.id,
    required this.date,
    required this.classId,
    this.sectionId,
    required this.studentId,
    required this.status,
    this.remarks = '',
    required this.recordedBy,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'classId': classId,
        'sectionId': sectionId,
        'studentId': studentId,
        'status': status,
        'remarks': remarks,
        'recordedBy': recordedBy,
        'timestamp': timestamp,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: json['id'] as String,
        date: json['date'] as String,
        classId: json['classId'] as String,
        sectionId: json['sectionId'] as String?,
        studentId: json['studentId'] as String,
        status: json['status'] as String,
        remarks: json['remarks'] as String? ?? '',
        recordedBy: json['recordedBy'] as String,
        timestamp: json['timestamp'] as String,
      );
}
