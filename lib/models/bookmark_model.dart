import 'package:cloud_firestore/cloud_firestore.dart';

/// Bookmark Model matching Firebase 'bookmarks' collection fields exactly
/// Fields: ceratedat, itemid, itemtype, userid
class BookmarkModel {
  final String id;
  final String userid;
  final String itemid;
  final String itemtype;
  final DateTime? ceratedat;
  
  // Additional fields for UI display (not in Firebase)
  final String? itemTitle;
  final String? itemImage;
  final double? itemPrice;

  BookmarkModel({
    required this.id,
    required this.userid,
    required this.itemid,
    required this.itemtype,
    this.ceratedat,
    this.itemTitle,
    this.itemImage,
    this.itemPrice,
  });

  factory BookmarkModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate;
    if (json['ceratedat'] != null) {
      if (json['ceratedat'] is Timestamp) {
        parseDate = (json['ceratedat'] as Timestamp).toDate();
      } else if (json['ceratedat'] is String) {
        parseDate = DateTime.tryParse(json['ceratedat']);
      }
    }

    return BookmarkModel(
      id: json['id'] ?? json['_id'] ?? '',
      userid: json['userid'] ?? '',
      itemid: json['itemid'] ?? '',
      itemtype: json['itemtype'] ?? 'room',
      ceratedat: parseDate,
      itemTitle: json['itemTitle'],
      itemImage: json['itemImage'],
      itemPrice: (json['itemPrice'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userid': userid,
      'itemid': itemid,
      'itemtype': itemtype,
      'ceratedat': ceratedat != null ? Timestamp.fromDate(ceratedat!) : Timestamp.now(),
    };
  }

  BookmarkModel copyWith({
    String? id,
    String? userid,
    String? itemid,
    String? itemtype,
    DateTime? ceratedat,
    String? itemTitle,
    String? itemImage,
    double? itemPrice,
  }) {
    return BookmarkModel(
      id: id ?? this.id,
      userid: userid ?? this.userid,
      itemid: itemid ?? this.itemid,
      itemtype: itemtype ?? this.itemtype,
      ceratedat: ceratedat ?? this.ceratedat,
      itemTitle: itemTitle ?? this.itemTitle,
      itemImage: itemImage ?? this.itemImage,
      itemPrice: itemPrice ?? this.itemPrice,
    );
  }
  
  /// Alias for itemtype (for backward compatibility)
  String get type => itemtype;
  
  /// Alias for ceratedat (for backward compatibility)
  DateTime? get createdAt => ceratedat;
  
  /// Alias for itemPrice (for backward compatibility)  
  double? get rating => itemPrice;
}
