import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat Message Model matching Firebase 'chatmessages' collection fields exactly
/// Fields: message, read, receiverid, senderid, timestamp
class ChatMessage {
  final String id;
  final String senderid;
  final String receiverid;
  final String message;
  final bool read;
  final DateTime? timestamp;
  
  // Additional UI fields (populated from user data)
  final String? senderName;
  final String? receiverName;

  ChatMessage({
    required this.id,
    required this.senderid,
    required this.receiverid,
    required this.message,
    required this.read,
    this.timestamp,
    this.senderName,
    this.receiverName,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate;
    if (json['timestamp'] != null) {
      if (json['timestamp'] is Timestamp) {
        parseDate = (json['timestamp'] as Timestamp).toDate();
      } else if (json['timestamp'] is String) {
        parseDate = DateTime.tryParse(json['timestamp']);
      }
    }

    return ChatMessage(
      id: json['id'] ?? json['_id'] ?? '',
      senderid: json['senderid'] ?? '',
      receiverid: json['receiverid'] ?? '',
      message: json['message'] ?? '',
      read: json['read'] ?? false,
      timestamp: parseDate,
      senderName: json['senderName'],
      receiverName: json['receiverName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderid': senderid,
      'receiverid': receiverid,
      'message': message,
      'read': read,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : Timestamp.now(),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? senderid,
    String? receiverid,
    String? message,
    bool? read,
    DateTime? timestamp,
    String? senderName,
    String? receiverName,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderid: senderid ?? this.senderid,
      receiverid: receiverid ?? this.receiverid,
      message: message ?? this.message,
      read: read ?? this.read,
      timestamp: timestamp ?? this.timestamp,
      senderName: senderName ?? this.senderName,
      receiverName: receiverName ?? this.receiverName,
    );
  }
  
  /// Alias for senderid (camelCase for backward compatibility)
  String get senderId => senderid;
  
  /// Alias for receiverid (camelCase for backward compatibility)
  String get receiverId => receiverid;
  
  /// Alias for timestamp (backward compatibility)
  DateTime? get createdAt => timestamp;
}

/// Chat Conversation helper class
class ChatConversation {
  final String userId;
  final String userName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;

  ChatConversation({
    required this.userId,
    required this.userName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate;
    if (json['lastMessageTime'] != null) {
      if (json['lastMessageTime'] is Timestamp) {
        parseDate = (json['lastMessageTime'] as Timestamp).toDate();
      } else if (json['lastMessageTime'] is String) {
        parseDate = DateTime.tryParse(json['lastMessageTime']);
      }
    }

    return ChatConversation(
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Unknown',
      lastMessage: json['lastMessage'] ?? '',
      lastMessageTime: parseDate ?? DateTime.now(),
      unreadCount: json['unreadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadCount': unreadCount,
    };
  }
}
