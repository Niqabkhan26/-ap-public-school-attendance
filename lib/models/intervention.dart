class Intervention {
  final String id;
  final String studentId;
  final String date;
  final String channel;
  final String staff;
  final String notes;
  final String resolution;

  Intervention({
    required this.id,
    required this.studentId,
    required this.date,
    required this.channel,
    required this.staff,
    required this.notes,
    required this.resolution,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'studentId': studentId,
    'date': date,
    'channel': channel,
    'staff': staff,
    'notes': notes,
    'resolution': resolution,
  };

  factory Intervention.fromJson(Map<String, dynamic> json) => Intervention(
    id: json['id'] as String,
    studentId: json['studentId'] as String,
    date: json['date'] as String,
    channel: json['channel'] as String,
    staff: json['staff'] as String,
    notes: json['notes'] as String,
    resolution: json['resolution'] as String,
  );
}

class AuditEntry {
  final String id;
  final String timestamp;
  final String type; // 'SUBMISSION', 'CORRECTION', 'ROSTER', 'INTERVENTION'
  final String action;
  final String details;
  final String previousState;
  final String newState;
  final String recordedBy;
  final String reason;

  AuditEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.action,
    required this.details,
    required this.previousState,
    required this.newState,
    required this.recordedBy,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp,
    'type': type,
    'action': action,
    'details': details,
    'previousState': previousState,
    'newState': newState,
    'recordedBy': recordedBy,
    'reason': reason,
  };

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
    id: json['id'] as String,
    timestamp: json['timestamp'] as String,
    type: json['type'] as String,
    action: json['action'] as String,
    details: json['details'] as String,
    previousState: json['previousState'] as String,
    newState: json['newState'] as String,
    recordedBy: json['recordedBy'] as String,
    reason: json['reason'] as String,
  );
}
