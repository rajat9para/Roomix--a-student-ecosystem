import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:roomix/models/university_model.dart';

/// Central Firebase service for all Firestore operations
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references matching Firebase collection names exactly
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _roomsCollection => _firestore.collection('rooms');
  CollectionReference get _messCollection => _firestore.collection('mess');
  CollectionReference get _roommateProfilesCollection => _firestore.collection('roommateprofiles');
  CollectionReference get _bookmarksCollection => _firestore.collection('bookmarks');
  CollectionReference get _chatMessagesCollection => _firestore.collection('chatmessages');
  CollectionReference get _universitiesCollection => _firestore.collection('universities');
  CollectionReference get _marketItemsCollection => _firestore.collection('marketItems');
  CollectionReference get _lostItemsCollection => _firestore.collection('lostItems');
  CollectionReference get _utilitiesCollection => _firestore.collection('utilities');
  CollectionReference get _notificationsCollection => _firestore.collection('notifications');

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // ==================== UNIVERSITIES ====================

  /// Get all universities
  Future<List<UniversityModel>> getUniversities({bool forceRefresh = false}) async {
    try {
      QuerySnapshot query;

      if (forceRefresh) {
        query = await _firestore
            .collection('universities')
            .get(const GetOptions(source: Source.server)); // 🔥 force fetch
      } else {
        query = await _firestore.collection('universities').get();
      }

      return query.docs
          .map((doc) => UniversityModel.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new university
  Future<String> createUniversity(Map<String, dynamic> data) async {
    try {
      final docRef = await _universitiesCollection.add({
        ...data,
        'createdAt': Timestamp.now(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating university: $e');
      throw Exception('Failed to create university');
    }
  }

  /// Get university by ID
  Future<Map<String, dynamic>?> getUniversityById(String id) async {
    try {
      final doc = await _universitiesCollection.doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting university: $e');
      return null;
    }
  }

  // ==================== USERS ====================

  /// Create a new user document
  Future<void> createUser({
    required String userId,
    required String email,
    required String name,
    required String role,
    String? phone,
    String? university,
  }) async {
    try {
      await _usersCollection.doc(userId).set({
        'email': email,
        'name': name,
        'role': role,
        'phone': phone ?? '',
        'university': university ?? '',
        'createdat': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error creating user: $e');
      throw Exception('Failed to create user');
    }
  }

  /// Get user by ID
  Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user: $e');
      throw Exception('Failed to get user');
    }
  }

  /// Update user
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      await _usersCollection.doc(userId).update(updates);
    } catch (e) {
      debugPrint('Error updating user: $e');
      throw Exception('Failed to update user');
    }
  }

  // ==================== ROOMS ====================

  /// Get all rooms
  Stream<List<Map<String, dynamic>>> getRooms() {
    return _roomsCollection
        .orderBy('ceratedat', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get rooms by university
  Stream<List<Map<String, dynamic>>> getRoomsByUniversity(String university) {
    return _roomsCollection
        .where('university', isEqualTo: university)
        .orderBy('ceratedat', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<Map<String, dynamic>?> getRoomById(String roomId) async {
    try {
      final doc = await _roomsCollection.doc(roomId).get();

      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    } catch (e) {
      debugPrint("getRoomById error: $e");
      return null;
    }
  }

  /// Get rooms by owner
  Stream<List<Map<String, dynamic>>> getRoomsByOwner(String ownerId) {
    return _roomsCollection
        .where('ownerid', isEqualTo: ownerId)
        .orderBy('ceratedat', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Create a new room
  Future<String> createRoom({
    required String title,
    required String location,
    required double price,
    required String type,
    required String imageurl,
    required String contact,
    required List<String> amenities,
    required String university,
    String? ownerid,
  }) async {
    try {
      final docRef = await _roomsCollection.add({
        'title': title,
        'location': location,
        'price': price,
        'type': type,
        'imageurl': imageurl,
        'contact': contact,
        'amenities': amenities,
        'university': university,
        'ownerid': ownerid ?? currentUserId,
        'ceratedat': Timestamp.now(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating room: $e');
      throw Exception('Failed to create room');
    }
  }

  /// Update room
  Future<void> updateRoom(String roomId, Map<String, dynamic> updates) async {
    try {
      await _roomsCollection.doc(roomId).update(updates);
    } catch (e) {
      debugPrint('Error updating room: $e');
      throw Exception('Failed to update room');
    }
  }

  /// Delete room
  Future<void> deleteRoom(String roomId) async {
    try {
      await _roomsCollection.doc(roomId).delete();
    } catch (e) {
      debugPrint('Error deleting room: $e');
      throw Exception('Failed to delete room');
    }
  }

  // ==================== MESS ====================

  /// Get all mess listings
  Stream<List<Map<String, dynamic>>> getMessListings() {
    return _messCollection
        .orderBy('createdat', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get mess by owner
  Stream<List<Map<String, dynamic>>> getMessByOwner(String ownerId) {
    return _messCollection
        .where('ownerid', isEqualTo: ownerId)
        .orderBy('createdat', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Create a new mess listing
  Future<String> createMess({
    required String name,
    required String location,
    required double pricepermonth,
    required String foodtype,
    required String contact,
    required List<String> menu,
    required String imageurl,
    String? timings,
    String? university,
    String? ownerid,
  }) async {
    try {
      final docRef = await _messCollection.add({
        'name': name,
        'location': location,
        'pricepermonth': pricepermonth,
        'foodtype': foodtype,
        'contact': contact,
        'menu': menu,
        'imageurl': imageurl,
        'timings': timings ?? '',
        'university': university ?? '',
        'ownerid': ownerid ?? currentUserId,
        'createdat': Timestamp.now(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating mess: $e');
      throw Exception('Failed to create mess listing');
    }
  }

  /// Update mess listing
  Future<void> updateMess(String messId, Map<String, dynamic> updates) async {
    try {
      await _messCollection.doc(messId).update(updates);
    } catch (e) {
      debugPrint('Error updating mess: $e');
      throw Exception('Failed to update mess listing');
    }
  }

  /// Delete mess listing
  Future<void> deleteMess(String messId) async {
    try {
      await _messCollection.doc(messId).delete();
    } catch (e) {
      debugPrint('Error deleting mess: $e');
      throw Exception('Failed to delete mess listing');
    }
  }

  // ==================== ROOMMATE PROFILES ====================

  /// Get all roommate profiles
  Stream<List<Map<String, dynamic>>> getRoommateProfiles() {
    return _roommateProfilesCollection
        .orderBy('createdat', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get roommate profile by user ID
  Future<Map<String, dynamic>?> getRoommateProfileByUserId(String userId) async {
    try {
      final query = await _roommateProfilesCollection
          .where('userid', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data() as Map<String, dynamic>;
        data['id'] = query.docs.first.id;
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting roommate profile: $e');
      throw Exception('Failed to get roommate profile');
    }
  }

  /// Create roommate profile
  Future<String> createRoommateProfile({
    required String userid,
    required String username,
    required String bio,
    required String college,
    required String courseYear,
    required String gender,
    required List<String> interests,
    required Map<String, dynamic> preferences,
  }) async {
    try {
      final docRef = await _roommateProfilesCollection.add({
        'userid': userid,
        'username': username,
        'bio': bio,
        'college': college,
        'courseYear': courseYear,
        'gender': gender,
        'interests': interests,
        'preferences': preferences,
        'createdat': Timestamp.now(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating roommate profile: $e');
      throw Exception('Failed to create roommate profile');
    }
  }

  /// Update roommate profile
  Future<void> updateRoommateProfile(String profileId, Map<String, dynamic> updates) async {
    try {
      await _roommateProfilesCollection.doc(profileId).update(updates);
    } catch (e) {
      debugPrint('Error updating roommate profile: $e');
      throw Exception('Failed to update roommate profile');
    }
  }

  /// Delete roommate profile
  Future<void> deleteRoommateProfile(String profileId) async {
    try {
      await _roommateProfilesCollection.doc(profileId).delete();
    } catch (e) {
      debugPrint('Error deleting roommate profile: $e');
      throw Exception('Failed to delete roommate profile');
    }
  }

  // ==================== BOOKMARKS ====================

  /// Get bookmarks for current user
  Stream<List<Map<String, dynamic>>> getBookmarks(String userId) {
    return _bookmarksCollection
        .where('userid', isEqualTo: userId)
        .orderBy('ceratedat', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Add bookmark
  Future<String> addBookmark({
    required String userid,
    required String itemid,
    required String itemtype,
    String? itemTitle,
    String? itemImage,
    double? itemPrice,
    String? location,
  }) async {
    try {
      final existing = await _bookmarksCollection
          .where('userid', isEqualTo: userid)
          .where('itemid', isEqualTo: itemid)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return existing.docs.first.id;
      }

      final docRef = await _bookmarksCollection.add({
        'userid': userid,
        'itemid': itemid,
        'itemtype': itemtype,

        // ⭐ IMPORTANT DATA
        'itemTitle': itemTitle ?? '',
        'itemImage': itemImage ?? '',
        'itemPrice': itemPrice ?? 0,
        'location': location ?? '',

        'ceratedat': Timestamp.now(),
      });

      return docRef.id;
    } catch (e) {
      debugPrint('Error adding bookmark: $e');
      throw Exception('Failed to add bookmark');
    }
  }

  /// Remove bookmark
  Future<void> removeBookmark(String bookmarkId) async {
    try {
      await _bookmarksCollection.doc(bookmarkId).delete();
    } catch (e) {
      debugPrint('Error removing bookmark: $e');
      throw Exception('Failed to remove bookmark');
    }
  }

  /// Remove bookmark by item ID
  Future<void> removeBookmarkByItemId(String userId, String itemId) async {
    try {
      final query = await _bookmarksCollection
          .where('userid', isEqualTo: userId)
          .where('itemid', isEqualTo: itemId)
          .get();
      
      for (var doc in query.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error removing bookmark: $e');
      throw Exception('Failed to remove bookmark');
    }
  }

  /// Check if item is bookmarked
  Future<bool> isBookmarked(String userId, String itemId) async {
    try {
      final query = await _bookmarksCollection
          .where('userid', isEqualTo: userId)
          .where('itemid', isEqualTo: itemId)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking bookmark: $e');
      return false;
    }
  }

  // ==================== CHAT MESSAGES ====================

  /// Get chat messages between two users
  Stream<List<Map<String, dynamic>>> getChatMessages(String userId1, String userId2) {
    return _chatMessagesCollection
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final sender = data['senderid'] as String;
            final receiver = data['receiverid'] as String;
            return (sender == userId1 && receiver == userId2) ||
                   (sender == userId2 && receiver == userId1);
          })
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          })
          .toList();
    });
  }

  /// Get conversations for a user
  Stream<List<Map<String, dynamic>>> getConversations(String userId) {
    return _chatMessagesCollection
        .where('senderid', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // Group by conversation partner
      final Map<String, Map<String, dynamic>> conversations = {};
      for (var msg in messages) {
        final partnerId = msg['receiverid'] as String;
        if (!conversations.containsKey(partnerId)) {
          conversations[partnerId] = msg;
        }
      }
      
      return conversations.values.toList();
    });
  }

  /// Send message
  Future<String> sendMessage({
    required String senderid,
    required String receiverid,
    required String message,
  }) async {
    try {
      final docRef = await _chatMessagesCollection.add({
        'senderid': senderid,
        'receiverid': receiverid,
        'message': message,
        'read': false,
        'timestamp': Timestamp.now(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error sending message: $e');
      throw Exception('Failed to send message');
    }
  }

  /// Mark message as read
  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _chatMessagesCollection.doc(messageId).update({'read': true});
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  /// Mark all messages from a user as read
  Future<void> markConversationAsRead(String currentUserId, String otherUserId) async {
    try {
      final query = await _chatMessagesCollection
          .where('receiverid', isEqualTo: currentUserId)
          .where('senderid', isEqualTo: otherUserId)
          .where('read', isEqualTo: false)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in query.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking conversation as read: $e');
    }
  }

  /// Get unread message count
  Future<int> getUnreadCount(String userId) async {
    try {
      final query = await _chatMessagesCollection
          .where('receiverid', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .count()
          .get();
      return query.count ?? 0;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  // ==================== MARKET ITEMS ====================

  /// Get all market items
  Stream<List<Map<String, dynamic>>> getMarketItems() {
    return _marketItemsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get market items by seller
  Stream<List<Map<String, dynamic>>> getMarketItemsBySeller(String sellerId) {
    return _marketItemsCollection
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Create a new market item
  Future<String> createMarketItem({
    required String title,
    required String description,
    required double price,
    required String condition,
    required String category,
    String? image,
    required String sellerId,
    required String sellerName,
    required String sellerContact,
  }) async {
    try {
      final docRef = await _marketItemsCollection.add({
        'title': title,
        'description': description,
        'price': price,
        'condition': condition,
        'category': category,
        'image': image,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'sellerContact': sellerContact,
        'sold': false,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating market item: $e');
      throw Exception('Failed to create market item');
    }
  }

  /// Update market item
  Future<void> updateMarketItem(String itemId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _marketItemsCollection.doc(itemId).update(updates);
    } catch (e) {
      debugPrint('Error updating market item: $e');
      throw Exception('Failed to update market item');
    }
  }

  /// Delete market item
  Future<void> deleteMarketItem(String itemId) async {
    try {
      await _marketItemsCollection.doc(itemId).delete();
    } catch (e) {
      debugPrint('Error deleting market item: $e');
      throw Exception('Failed to delete market item');
    }
  }

  // ==================== LOST & FOUND ====================

  /// Get all lost items
  Stream<List<Map<String, dynamic>>> getLostItems() {
    return _lostItemsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get lost items by status (lost/found)
  Stream<List<Map<String, dynamic>>> getLostItemsByStatus(String status) {
    return _lostItemsCollection
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Create a new lost/found item
  Future<String> createLostItem({
    required String title,
    required String description,
    required String status,
    required DateTime date,
    required String location,
    required String contact,
    String? image,
    required String userId,
  }) async {
    try {
      final docRef = await _lostItemsCollection.add({
        'title': title,
        'description': description,
        'status': status,
        'date': Timestamp.fromDate(date),
        'location': location,
        'contact': contact,
        'image': image,
        'userId': userId,
        'claimStatus': 'Unclaimed',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating lost item: $e');
      throw Exception('Failed to create lost item');
    }
  }

  /// Update lost item
  Future<void> updateLostItem(String itemId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _lostItemsCollection.doc(itemId).update(updates);
    } catch (e) {
      debugPrint('Error updating lost item: $e');
      throw Exception('Failed to update lost item');
    }
  }

  /// Delete lost item
  Future<void> deleteLostItem(String itemId) async {
    try {
      await _lostItemsCollection.doc(itemId).delete();
    } catch (e) {
      debugPrint('Error deleting lost item: $e');
      throw Exception('Failed to delete lost item');
    }
  }

  // ==================== UTILITIES ====================

  /// Get all utilities
  Stream<List<Map<String, dynamic>>> getUtilities() {
    return _utilitiesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get utilities by category
  Stream<List<Map<String, dynamic>>> getUtilitiesByCategory(String category) {
    return _utilitiesCollection
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Create a new utility
  Future<String> createUtility({
    required String name,
    required String category,
    required String address,
    String? phone,
    String? description,
    String? image,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final docRef = await _utilitiesCollection.add({
        'name': name,
        'category': category,
        'address': address,
        'contact': phone != null ? {'phone': phone} : null,
        'description': description,
        'image': image,
        'location': latitude != null && longitude != null
            ? {'coordinates': [longitude, latitude], 'address': address}
            : {'coordinates': [0.0, 0.0], 'address': address},
        'verified': false,
        'rating': 0.0,
        'reviews': [],
        'isActive': true,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating utility: $e');
      throw Exception('Failed to create utility');
    }
  }

  /// Update utility
  Future<void> updateUtility(String utilityId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _utilitiesCollection.doc(utilityId).update(updates);
    } catch (e) {
      debugPrint('Error updating utility: $e');
      throw Exception('Failed to update utility');
    }
  }

  /// Delete utility
  Future<void> deleteUtility(String utilityId) async {
    try {
      await _utilitiesCollection.doc(utilityId).delete();
    } catch (e) {
      debugPrint('Error deleting utility: $e');
      throw Exception('Failed to delete utility');
    }
  }

  // ==================== NOTIFICATIONS ====================

  /// Get notifications for user
  Stream<List<Map<String, dynamic>>> getNotifications(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Create a notification
  Future<String> createNotification({
    required String userId,
    required String title,
    required String message,
    String? type,
    String? relatedId,
  }) async {
    try {
      final docRef = await _notificationsCollection.add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type ?? 'general',
        'relatedId': relatedId,
        'read': false,
        'createdAt': Timestamp.now(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating notification: $e');
      throw Exception('Failed to create notification');
    }
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({'read': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      throw Exception('Failed to delete notification');
    }
  }

  /// Get unread notification count
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final query = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .count()
          .get();
      return query.count ?? 0;
    } catch (e) {
      debugPrint('Error getting unread notification count: $e');
      return 0;
    }
  }
}
