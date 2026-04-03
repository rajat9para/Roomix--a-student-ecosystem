import 'package:cloud_firestore/cloud_firestore.dart';

class LostItemModel {
  final String id;
  final String title;
  final String description;
  final String status;
  final DateTime date;
  final String? location;
  final String? image;
  final List<String>? images; // Multi-image support (up to 4)
  final String contact;
  final String? userId;
  final String claimStatus;
  final String? claimedBy;
  final DateTime? claimDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  LostItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.date,
    this.location,
    this.image,
    this.images,
    required this.contact,
    this.userId,
    required this.claimStatus,
    this.claimedBy,
    this.claimDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get all images (handles both legacy single `image` and new `images` list)
  List<String> get allImages {
    final List<String> all = [];
    if (images != null && images!.isNotEmpty) {
      all.addAll(images!);
    }
    if (image != null && image!.isNotEmpty && !all.contains(image)) {
      all.insert(0, image!);
    }
    return all;
  }

  /// Safely parse a date field that could be a Timestamp, String, or null
  static DateTime _parseDate(dynamic value, {DateTime? fallback}) {
    if (value == null) return fallback ?? DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return fallback ?? DateTime.now();
      }
    }
    return fallback ?? DateTime.now();
  }

  factory LostItemModel.fromJson(Map<String, dynamic> json) {
    return LostItemModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'Lost',
      date: _parseDate(json['date']),
      location: json['location'],
      image: json['image'],
      images: json['images'] != null
          ? List<String>.from(json['images'])
          : null,
      contact: json['contact'] ?? '',
      userId: json['userId'] ?? json['user']?['_id'] ?? json['user'],
      claimStatus: json['claimStatus'] ?? 'Unclaimed',
      claimedBy: json['claimedBy']?['_id'] ?? json['claimedBy'],
      claimDate: json['claimDate'] != null ? _parseDate(json['claimDate']) : null,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'status': status,
      'date': date.toIso8601String(),
      'location': location,
      'image': image,
      'images': images,
      'contact': contact,
      'user': userId,
      'claimStatus': claimStatus,
      'claimedBy': claimedBy,
      'claimDate': claimDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
