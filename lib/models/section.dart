/// Represents a section within a class (e.g., "Section A" inside "Class 5").
class Section {
  final String id;       // e.g. "SEC-CLS-CLASS_5-A"
  final String classId;  // parent class, e.g. "CLS-CLASS_5"
  final String name;     // e.g. "Section A"

  Section({
    required this.id,
    required this.classId,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'classId': classId,
        'name': name,
      };

  factory Section.fromJson(Map<String, dynamic> json) => Section(
        id: json['id'] as String,
        classId: json['classId'] as String,
        name: json['name'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Section && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

