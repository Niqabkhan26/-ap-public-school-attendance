class Student {
  final String id;
  final int rollNo;
  final String name;
  final String classId;
  final String? sectionId; // nullable for backward-compat with existing records
  final String gender;
  final String? dob; // YYYY-MM-DD Date of birth
  final String guardianName;
  final String guardianPhone;
  final String? address;
  final String status; // 'active' or 'inactive'
  final String? photoPath; // local file path or http URL

  Student({
    required this.id,
    required this.rollNo,
    required this.name,
    required this.classId,
    this.sectionId,
    required this.gender,
    this.dob,
    required this.guardianName,
    required this.guardianPhone,
    this.address,
    this.status = 'active',
    this.photoPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'rollNo': rollNo,
        'name': name,
        'classId': classId,
        'sectionId': sectionId,
        'gender': gender,
        'dob': dob,
        'guardianName': guardianName,
        'guardianPhone': guardianPhone,
        'address': address,
        'status': status,
        'photoPath': photoPath,
      };

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String,
        rollNo: json['rollNo'] as int,
        name: json['name'] as String,
        classId: json['classId'] as String,
        sectionId: json['sectionId'] as String?,
        gender: json['gender'] as String,
        dob: json['dob'] as String?,
        guardianName: json['guardianName'] as String,
        guardianPhone: json['guardianPhone'] as String,
        address: json['address'] as String?,
        status: json['status'] as String? ?? 'active',
        photoPath: json['photoPath'] as String?,
      );

  Student copyWith({
    String? id,
    int? rollNo,
    String? name,
    String? classId,
    Object? sectionId = _sentinel,
    String? gender,
    String? dob,
    String? guardianName,
    String? guardianPhone,
    String? address,
    String? status,
    String? photoPath,
  }) {
    return Student(
      id: id ?? this.id,
      rollNo: rollNo ?? this.rollNo,
      name: name ?? this.name,
      classId: classId ?? this.classId,
      sectionId: sectionId == _sentinel ? this.sectionId : sectionId as String?,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      guardianName: guardianName ?? this.guardianName,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      address: address ?? this.address,
      status: status ?? this.status,
      photoPath: photoPath ?? this.photoPath,
    );
  }
}

// Sentinel object for nullable copyWith fields
const Object _sentinel = Object();
