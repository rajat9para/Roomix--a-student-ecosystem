class LostItemModel {
  final String id;
  final String title;
  final String description;
  final String status;
  final DateTime date;
  final String? location;
  final String? image;
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
    required this.contact,
    this.userId,
    required this.claimStatus,
    this.claimedBy,
    this.claimDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LostItemModel.fromJson(Map<String, dynamic> json) {
    return LostItemModel(
      id: json['_id'] ?? json['id'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      date: DateTime.parse(json['date']),
      location: json['location'],
      image: json['image'],
      contact: json['contact'],
      userId: json['user']?['_id'] ?? json['user'],
      claimStatus: json['claimStatus'] ?? 'Unclaimed',
      claimedBy: json['claimedBy']?['_id'] ?? json['claimedBy'],
      claimDate: json['claimDate'] != null ? DateTime.parse(json['claimDate']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
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
