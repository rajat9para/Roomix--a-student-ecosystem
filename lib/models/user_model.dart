import 'package:cloud_firestore/cloud_firestore.dart';

/// User Model matching Firebase 'users' collection fields exactly
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
  final String? telegramPhone; // Phone number linked to Telegram
  final String? ownerType; // 'pg_owner' or 'mess_owner'
  final String? description; // User bio / about me

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
    this.telegramPhone,
    this.ownerType,
    this.description,
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
    final normalizedRole = json['role']?.toString().trim().toLowerCase();

    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: (normalizedRole != null && normalizedRole.isNotEmpty)
          ? normalizedRole
          : 'student',
      phone: json['phone'],
      university: json['university'],
      createdat: parseCreatedAt,
      profilePicture: json['profilePicture'] ?? json['photoUrl'],
      course: json['course'],
      year: json['year'],
      telegramPhone:
          json['telegramPhone'] ??
          json['telegram_phone'] ??
          json['telegramNumber'] ??
          json['telegram_number'] ??
          json['telegramNo'] ??
          json['telegram_no'] ??
          json['telegramContact'] ??
          json['telegram'] ??
          // Legacy: also check telegramUsername (may contain phone in old data)
          json['telegramUsername'] ??
          json['telegram_username'],
      ownerType: json['ownerType'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.trim().toLowerCase(),
      'phone': phone ?? '',
      'university': university ?? '',
      'createdat': createdat != null
          ? Timestamp.fromDate(createdat!)
          : Timestamp.now(),
      'profilePicture': profilePicture,
      'course': course,
      'year': year,
      'telegramPhone': telegramPhone,
      if (ownerType != null) 'ownerType': ownerType,
      if (description != null) 'description': description,
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
    String? telegramPhone,
    String? ownerType,
    String? description,
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
      telegramPhone: telegramPhone ?? this.telegramPhone,
      ownerType: ownerType ?? this.ownerType,
      description: description ?? this.description,
    );
  }

  /// Alias for university (for backward compatibility)
  String? get collegeName => university;

  /// Alias for phone (for backward compatibility)
  String? get contactNumber => phone;

  /// Returns the best available Telegram contact (phone number)
  String? get effectiveTelegramContact =>
      (telegramPhone != null && telegramPhone!.isNotEmpty)
      ? telegramPhone
      : null;

  /// Returns true if core profile fields are filled out (role-aware)
  bool get isProfileComplete {
    final normalizedRole = role.trim().toLowerCase();
    // Base requirements for ALL roles
    final hasName = name.isNotEmpty;
    final hasTelegram = telegramPhone?.isNotEmpty ?? false;

    // Owners only need name + contact info
    if (normalizedRole == 'owner') {
      return hasName && hasTelegram;
    }

    // Students need full academic info
    return hasName &&
        (university?.isNotEmpty ?? false) &&
        (course?.isNotEmpty ?? false) &&
        (year?.isNotEmpty ?? false) &&
        (profilePicture != null && profilePicture!.isNotEmpty) &&
        hasTelegram;
  }
}
