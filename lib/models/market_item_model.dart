class MarketItemModel {
  final String id;
  final String title;
  final String? description;
  final double price;
  final String condition;
  final String? category;
  final String? image;
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
    required this.sellerContact,
    required this.sellerName,
    this.sellerId,
    required this.sold,
    this.soldTo,
    this.soldDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MarketItemModel.fromJson(Map<String, dynamic> json) {
    return MarketItemModel(
      id: json['_id'] ?? json['id'],
      title: json['title'],
      description: json['description'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      condition: json['condition'],
      category: json['category'],
      image: json['image'],
      sellerContact: json['sellerContact'],
      sellerName: json['sellerName'],
      sellerId: json['user']?['_id'] ?? json['user'],
      sold: json['sold'] ?? false,
      soldTo: json['soldTo']?['_id'] ?? json['soldTo'],
      soldDate: json['soldDate'] != null ? DateTime.parse(json['soldDate']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
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
      'sellerContact': sellerContact,
      'sellerName': sellerName,
      'user': sellerId,
      'sold': sold,
      'soldTo': soldTo,
      'soldDate': soldDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
