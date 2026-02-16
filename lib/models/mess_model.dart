import 'package:cloud_firestore/cloud_firestore.dart';

/// Mess Review Model
class MessReview {
  final String id;
  final String userId;
  final String userName;
  final String comment;
  final double rating;
  final DateTime? createdAt;

  MessReview({
    required this.id,
    required this.userId,
    required this.userName,
    required this.comment,
    required this.rating,
    this.createdAt,
  });

  factory MessReview.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate;
    if (json['createdat'] != null) {
      if (json['createdat'] is Timestamp) {
        parseDate = (json['createdat'] as Timestamp).toDate();
      } else if (json['createdat'] is String) {
        parseDate = DateTime.tryParse(json['createdat']);
      }
    }

    return MessReview(
      id: json['id'] ?? '',
      userId: json['userid'] ?? json['userId'] ?? '',
      userName: json['username'] ?? json['userName'] ?? 'Anonymous',
      comment: json['comment'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      createdAt: parseDate,
    );
  }
}

/// Mess Model matching Firebase 'mess' collection fields exactly
/// Fields: contact, createdat, foodtype, imageurl, location, menu, name, ownerid, pricepermonth, timings, university
class MessModel {
  final String id;
  final String name;
  final String location;
  final double pricepermonth;
  final String foodtype;
  final String contact;
  final List<String> menu;
  final String imageurl;
  final String ownerid;
  final String? timings;
  final String? university;
  final DateTime? createdat;
  
  // Additional fields for UI compatibility
  final double rating;
  final List<MessReview> reviews;
  final String? address;
  final String? specialization;
  final String? menuPreview;
  final List<String>? specialities;
  final String? openingTime;
  final String? closingTime;

  MessModel({
    required this.id,
    required this.name,
    required this.location,
    required this.pricepermonth,
    required this.foodtype,
    required this.contact,
    required this.menu,
    required this.imageurl,
    required this.ownerid,
    this.timings,
    this.university,
    this.createdat,
    this.rating = 0.0,
    this.reviews = const [],
    this.address,
    this.specialization,
    this.menuPreview,
    this.specialities,
    this.openingTime,
    this.closingTime,
  });
  
  /// Alias for imageurl (for backward compatibility)
  String get image => imageurl;
  
  /// Alias for pricepermonth (for backward compatibility)
  double get price => pricepermonth;

  factory MessModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate;
    if (json['createdat'] != null) {
      if (json['createdat'] is Timestamp) {
        parseDate = (json['createdat'] as Timestamp).toDate();
      } else if (json['createdat'] is String) {
        parseDate = DateTime.tryParse(json['createdat']);
      }
    }

    return MessModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      location: json['location'] ?? '',
      pricepermonth: (json['pricepermonth'] as num?)?.toDouble() ?? 0.0,
      foodtype: json['foodtype'] ?? 'veg',
      contact: json['contact'] ?? '',
      menu: List<String>.from(json['menu'] ?? []),
      imageurl: json['imageurl'] ?? '',
      ownerid: json['ownerid'] ?? '',
      timings: json['timings'],
      university: json['university'],
      createdat: parseDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'location': location,
      'pricepermonth': pricepermonth,
      'foodtype': foodtype,
      'contact': contact,
      'menu': menu,
      'imageurl': imageurl,
      'ownerid': ownerid,
      'timings': timings ?? '',
      'university': university ?? '',
      'createdat': createdat != null ? Timestamp.fromDate(createdat!) : Timestamp.now(),
    };
  }

  MessModel copyWith({
    String? id,
    String? name,
    String? location,
    double? pricepermonth,
    String? foodtype,
    String? contact,
    List<String>? menu,
    String? imageurl,
    String? ownerid,
    String? timings,
    String? university,
    DateTime? createdat,
  }) {
    return MessModel(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      pricepermonth: pricepermonth ?? this.pricepermonth,
      foodtype: foodtype ?? this.foodtype,
      contact: contact ?? this.contact,
      menu: menu ?? this.menu,
      imageurl: imageurl ?? this.imageurl,
      ownerid: ownerid ?? this.ownerid,
      timings: timings ?? this.timings,
      university: university ?? this.university,
      createdat: createdat ?? this.createdat,
    );
  }
}
