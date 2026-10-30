class Holiday {
  final String id;
  final String date; // YYYY-MM-DD
  final String reason;

  Holiday({
    required this.id,
    required this.date,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'reason': reason,
  };

  factory Holiday.fromJson(Map<String, dynamic> json) => Holiday(
    id: json['id'] as String,
    date: json['date'] as String,
    reason: json['reason'] as String,
  );
}
