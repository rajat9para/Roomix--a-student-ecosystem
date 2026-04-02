import 'package:cloud_firestore/cloud_firestore.dart';

/// Roommate Profile Model matching Firebase 'roommateprofiles' collection fields exactly
/// Fields: bio, college, courseYear, createdat, gender, interests, preferences, userid, username
class RoommateProfile {
  final String id;
  final String userid;
  final String username;
  final String bio;
  final String college;
  final String course;
  final String courseYear;
  final String gender;
  final List<String> interests;
  final Map<String, dynamic> preferences;
  final DateTime? createdat;
  
  // UI helper fields
  final int? compatibility;

  RoommateProfile({
    required this.id,
    required this.userid,
    required this.username,
    required this.bio,
    required this.college,
    this.course = '',
    required this.courseYear,
    required this.gender,
    required this.interests,
    required this.preferences,
    this.createdat,
    this.compatibility,
  });

  factory RoommateProfile.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate;
    if (json['createdat'] != null) {
      if (json['createdat'] is Timestamp) {
        parseDate = (json['createdat'] as Timestamp).toDate();
      } else if (json['createdat'] is String) {
        parseDate = DateTime.tryParse(json['createdat']);
      }
    }

    // Handle preferences which can be a Map or nested structure
    Map<String, dynamic> prefs = {};
    if (json['preferences'] != null) {
      if (json['preferences'] is Map) {
        prefs = Map<String, dynamic>.from(json['preferences']);
      }
    }

    return RoommateProfile(
      id: json['id'] ?? json['_id'] ?? '',
      userid: json['userid'] ?? '',
      username: json['username'] ?? '',
      bio: json['bio'] ?? '',
      college: json['college'] ?? '',
      course: json['course'] ?? '',
      courseYear: json['courseYear'] ?? '',
      gender: json['gender'] ?? 'other',
      interests: List<String>.from(json['interests'] ?? []),
      preferences: prefs,
      createdat: parseDate,
      compatibility: json['compatibility'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userid': userid,
      'username': username,
      'bio': bio,
      'college': college,
      'course': course,
      'courseYear': courseYear,
      'gender': gender,
      'interests': interests,
      'preferences': preferences,
      'createdat': createdat != null ? Timestamp.fromDate(createdat!) : Timestamp.now(),
    };
  }

  RoommateProfile copyWith({
    String? id,
    String? userid,
    String? username,
    String? bio,
    String? college,
    String? course,
    String? courseYear,
    String? gender,
    List<String>? interests,
    Map<String, dynamic>? preferences,
    DateTime? createdat,
    int? compatibility,
  }) {
    return RoommateProfile(
      id: id ?? this.id,
      userid: userid ?? this.userid,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      college: college ?? this.college,
      course: course ?? this.course,
      courseYear: courseYear ?? this.courseYear,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      preferences: preferences ?? this.preferences,
      createdat: createdat ?? this.createdat,
      compatibility: compatibility ?? this.compatibility,
    );
  }

  /// Get preference value by key
  String? getPreference(String key) {
    return preferences[key]?.toString();
  }

  /// Check if profile is complete
  bool get isComplete {
    return bio.isNotEmpty && 
           college.isNotEmpty && 
           courseYear.isNotEmpty && 
           interests.isNotEmpty;
  }
  
  /// Alias for userid (camelCase for backward compatibility)
  String get userId => userid;
  
  /// Alias for username (camelCase for backward compatibility)
  String get userName => username;
  
  /// Placeholder for userEmail (for backward compatibility)
  String get userEmail => '';
}
