import 'package:cloud_firestore/cloud_firestore.dart';

/// Room Review Model
class RoomReview {
  final String id;
  final String userId;
  final String userName;
  final String comment;
  final double rating;
  final String? userImage;
  final DateTime? createdAt;

  RoomReview({
    required this.id,
    required this.userId,
    required this.userName,
    required this.comment,
    required this.rating,
    this.createdAt,
    this.userImage,
  });

  factory RoomReview.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate;
    if (json['createdat'] != null) {
      if (json['createdat'] is Timestamp) {
        parseDate = (json['createdat'] as Timestamp).toDate();
      } else if (json['createdat'] is String) {
        parseDate = DateTime.tryParse(json['createdat']);
      }
    }

    return RoomReview(
      id: json['id'] ?? '',
      userId: json['userid'] ?? json['userId'] ?? '',
      userName: json['username'] ?? json['userName'] ?? 'Anonymous',
      comment: json['comment'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      createdAt: parseDate,
      userImage: json['userImage'],
    );
  }
}

/// Room Model matching Firebase 'rooms' collection fields exactly
/// Fields: amenities, ceratedat, contact, imageurl, location, ownerid, price, title, type, university
class RoomModel {
  final String id;
  final String title;
  final String location;
  final double price;
  final String type;
  final String imageurl;
  final String contact;
  final List<String> amenities;
  final String ownerid;
  final String university;
  final DateTime? ceratedat;
  
  // Additional fields for UI compatibility
  final double rating;
  final bool verified;
  List<RoomReview> reviews;
  final double? latitude;
  final double? longitude;

  RoomModel({
    required this.id,
    required this.title,
    required this.location,
    required this.price,
    required this.type,
    required this.imageurl,
    required this.contact,
    required this.amenities,
    required this.ownerid,
    required this.university,
    this.ceratedat,
    this.rating = 0.0,
    this.verified = false,
    List<RoomReview>? reviews,
    this.latitude,
    this.longitude,
  }) : reviews = reviews ?? [];

  /// Alias for imageurl (for backward compatibility)
  String get image => imageurl;

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate;
    if (json['ceratedat'] != null) {
      if (json['ceratedat'] is Timestamp) {
        parseDate = (json['ceratedat'] as Timestamp).toDate();
      } else if (json['ceratedat'] is String) {
        parseDate = DateTime.tryParse(json['ceratedat']);
      }
    }

    return RoomModel(
      id: json['id'] ?? json['_id'] ?? '',
      title: json['title'] ?? '',
      location: json['location'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] ?? 'single',
      imageurl: json['imageurl'] ?? '',
      contact: json['contact'] ?? '',
      amenities: List<String>.from(json['amenities'] ?? []),
      ownerid: json['ownerid'] ?? '',
      university: json['university'] ?? '',
      ceratedat: parseDate,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      verified: json['verified'] ?? false,

      reviews: (json['reviews'] as List<dynamic>?)
          ?.map((e) => RoomReview.fromJson(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'location': location,
      'price': price,
      'type': type,
      'imageurl': imageurl,
      'contact': contact,
      'amenities': amenities,
      'ownerid': ownerid,
      'university': university,
      'ceratedat': ceratedat != null ? Timestamp.fromDate(ceratedat!) : Timestamp.now(),
    };
  }

  RoomModel copyWith({
    String? id,
    String? title,
    String? location,
    String? imageurl,
    String? type,
    double? price,
    double? rating,
    String? contact,
    bool? verified,
    List<String>? amenities,
    List<RoomReview>? reviews,
    double? latitude,
    double? longitude,
    DateTime? ceratedat,
    String? ownerid,
    String? university,
  }) {
    return RoomModel(
      id: id ?? this.id,
      title: title ?? this.title,
      location: location ?? this.location,
      imageurl: imageurl ?? this.imageurl,
      type: type ?? this.type,
      price: price ?? this.price,
      contact: contact ?? this.contact,
      amenities: amenities ?? this.amenities,
      ownerid: ownerid ?? this.ownerid,
      university: university ?? this.university,
      ceratedat: ceratedat ?? this.ceratedat,
      rating: rating ?? this.rating,
      verified: verified ?? this.verified,
      reviews: reviews ?? this.reviews,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
