import 'package:cloud_firestore/cloud_firestore.dart';

/// User Model matching Firebase 'users' collection fields exactly
/// Fields: createdat, email, name, phone, role, university
class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? university;
  final DateTime? createdat;
  final String? profilePicture;
  final String? course;
  final String? year;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.university,
    this.createdat,
    this.profilePicture,
    this.course,
    this.year,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseCreatedAt;
    if (json['createdat'] != null) {
      if (json['createdat'] is Timestamp) {
        parseCreatedAt = (json['createdat'] as Timestamp).toDate();
      } else if (json['createdat'] is String) {
        parseCreatedAt = DateTime.tryParse(json['createdat']);
      }
    }

    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      phone: json['phone'],
      university: json['university'],
      createdat: parseCreatedAt,
      profilePicture: json['profilePicture'] ?? json['photoUrl'],
      course: json['course'],
      year: json['year'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone ?? '',
      'university': university ?? '',
      'createdat': createdat != null ? Timestamp.fromDate(createdat!) : Timestamp.now(),
      'profilePicture': profilePicture,
      'course': course,
      'year': year,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? phone,
    String? university,
    DateTime? createdat,
    String? profilePicture,
    String? course,
    String? year,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      university: university ?? this.university,
      createdat: createdat ?? this.createdat,
      profilePicture: profilePicture ?? this.profilePicture,
      course: course ?? this.course,
      year: year ?? this.year,
    );
  }
  
  /// Alias for university (for backward compatibility - profile screen expects collegeName)
  String? get collegeName => university;
  
  /// Alias for phone (for backward compatibility - profile screen expects contactNumber)
  String? get contactNumber => phone;
}
