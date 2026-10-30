class SchoolClass {
  final String id;
  final String name;
  final String shortName;
  final String room;
  final String teacher;

  SchoolClass({
    required this.id,
    required this.name,
    required this.shortName,
    required this.room,
    required this.teacher,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'shortName': shortName,
    'room': room,
    'teacher': teacher,
  };

  factory SchoolClass.fromJson(Map<String, dynamic> json) => SchoolClass(
    id: json['id'] as String,
    name: json['name'] as String,
    shortName: json['shortName'] as String,
    room: json['room'] as String,
    teacher: json['teacher'] as String,
  );
}
