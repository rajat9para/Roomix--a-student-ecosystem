import 'package:cloud_firestore/cloud_firestore.dart';

class MarketItemModel {
  final String id;
  final String title;
  final String? description;
  final double price;
  final String condition;
  final String? category;
  final String? image; // Legacy single image (backward compat)
  final List<String> images; // Multiple images (up to 4)
  final String sellerContact;
  final String sellerName;
  final String? sellerId;
  final bool sold;
  final String? soldTo;
  final DateTime? soldDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  MarketItemModel({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    required this.condition,
    this.category,
    this.image,
    this.images = const [],
    required this.sellerContact,
    required this.sellerName,
    this.sellerId,
    required this.sold,
    this.soldTo,
    this.soldDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get all available images (combines images list + legacy single image)
  List<String> get allImages {
    final all = <String>[];
    if (images.isNotEmpty) {
      all.addAll(images);
    }
    // Add legacy single image if not already in list
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

  factory MarketItemModel.fromJson(Map<String, dynamic> json) {
    // Parse images list
    List<String> imagesList = [];
    if (json['images'] != null && json['images'] is List) {
      imagesList = (json['images'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }

    return MarketItemModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      condition: json['condition'] ?? 'Good',
      category: json['category'],
      image: json['image'],
      images: imagesList,
      sellerContact: json['sellerContact'] ?? '',
      sellerName: json['sellerName'] ?? '',
      sellerId: json['sellerId'] ?? json['user']?['_id'] ?? json['user'],
      sold: json['sold'] ?? false,
      soldTo: json['soldTo']?['_id'] ?? json['soldTo'],
      soldDate: json['soldDate'] != null ? _parseDate(json['soldDate']) : null,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'price': price,
      'condition': condition,
      'category': category,
      'image': image,
      'images': images,
      'sellerContact': sellerContact,
      'sellerName': sellerName,
      'sellerId': sellerId,
      'sold': sold,
      'soldTo': soldTo,
      'soldDate': soldDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
