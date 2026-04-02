import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:roomix/models/room_model.dart';
import 'package:roomix/models/mess_model.dart';
import 'package:roomix/models/event_model.dart';
import 'package:roomix/models/utility_model.dart';
import 'package:roomix/models/university_model.dart';
import 'package:roomix/services/firebase_service.dart';

/// ApiService - Compatibility layer bridging old REST API calls to Firebase
class ApiService {
  static final FirebaseService _firebaseService = FirebaseService();
  static final dynamic dio = _FakeDio();

  // ==================== ROOMS ====================
  static Future<List<RoomModel>> getRooms() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .orderBy('ceratedat', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => RoomModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching rooms: $e');
      return [];
    }
  }

  static Future<RoomModel?> getRoomById(String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(id)
          .get();
      if (doc.exists) {
        return RoomModel.fromJson({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching room: $e');
      return null;
    }
  }

  // ==================== MESS ====================
  static Future<Map<String, dynamic>> getMessMenu({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('mess')
          .orderBy('createdat', descending: true)
          .limit(limit)
          .get();
      final items = snapshot.docs
          .map((doc) => MessModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      return {
        'data': items,
        'pagination': {
          'currentPage': page,
          'hasMore': snapshot.docs.length == limit,
        },
      };
    } catch (e) {
      return {
        'data': <MessModel>[],
        'pagination': {'currentPage': page, 'hasMore': false},
      };
    }
  }

  static Future<MessModel?> getMessById(String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('mess')
          .doc(id)
          .get();
      if (doc.exists) {
        return MessModel.fromJson({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==================== EVENTS ====================
  static Future<Map<String, dynamic>> getEvents({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .orderBy('date', descending: true)
          .limit(limit)
          .get();
      final items = snapshot.docs
          .map((doc) => EventModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      return {
        'data': items,
        'pagination': {
          'currentPage': page,
          'hasMore': snapshot.docs.length == limit,
        },
      };
    } catch (e) {
      return {
        'data': <EventModel>[],
        'pagination': {'currentPage': page, 'hasMore': false},
      };
    }
  }

  // ==================== UTILITIES ====================
  static Future<List<UtilityModel>> getUtilities({String? category}) async {
    try {
      Query query = FirebaseFirestore.instance.collection('utilities');
      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }
      final snapshot = await query.orderBy('createdat', descending: true).get();
      return snapshot.docs
          .map(
            (doc) => UtilityModel.fromJson({
              ...(doc.data() as Map<String, dynamic>),
              'id': doc.id,
            }),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<UtilityModel>> getUtilitiesByCategory(
    String category,
  ) async {
    return getUtilities(category: category);
  }

  /// Get utilities nearby - accepts positional args for compatibility
  static Future<List<UtilityModel>> getUtilitiesNearby(
    double latitude,
    double longitude, {
    double radius = 5.0,
  }) async {
    // For now, return all utilities (implement geospatial queries in production)
    return getUtilities();
  }

  static Future<List<UtilityModel>> searchUtilities(String query) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('utilities')
          .orderBy('name')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .get();
      return snapshot.docs
          .map(
            (doc) => UtilityModel.fromJson({
              ...(doc.data() as Map<String, dynamic>),
              'id': doc.id,
            }),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<UtilityModel?> getUtility(String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('utilities')
          .doc(id)
          .get();
      if (doc.exists) {
        return UtilityModel.fromJson({
          ...(doc.data() as Map<String, dynamic>),
          'id': doc.id,
        });
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Create utility - accepts both phone (String) and contact (Map)
  static Future<UtilityModel?> createUtility({
    required String name,
    required String category,
    String? description,
    String? address,
    String? phone,
    Map<String, dynamic>? contact,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('utilities').doc();
      // Build contact map from phone if provided
      final contactMap = contact ?? (phone != null ? {'phone': phone} : null);

      await docRef.set({
        'name': name,
        'category': category,
        'description': description ?? '',
        'location': {
          'coordinates': [longitude ?? 0.0, latitude ?? 0.0],
          'address': address ?? '',
        },
        'contact': contactMap,
        'verified': false,
        'addedBy': {'name': 'System'},
        'rating': 0.0,
        'reviews': [],
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return getUtility(docRef.id);
    } catch (e) {
      debugPrint('Error creating utility: $e');
      return null;
    }
  }

  /// Update utility - accepts both phone (String) and contact (Map)
  static Future<UtilityModel?> updateUtility(
    String id, {
    String? name,
    String? category,
    String? description,
    String? address,
    String? phone,
    Map<String, dynamic>? contact,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (name != null) updates['name'] = name;
      if (category != null) updates['category'] = category;
      if (description != null) updates['description'] = description;
      if (address != null) updates['location.address'] = address;
      if (contact != null) updates['contact'] = contact;
      if (phone != null) updates['contact.phone'] = phone;
      if (latitude != null)
        updates['location.coordinates'] = [longitude ?? 0.0, latitude];

      await FirebaseFirestore.instance
          .collection('utilities')
          .doc(id)
          .update(updates);
      return getUtility(id);
    } catch (e) {
      debugPrint('Error updating utility: $e');
      return null;
    }
  }

  static Future<bool> deleteUtility(String id) async {
    try {
      await FirebaseFirestore.instance.collection('utilities').doc(id).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<UtilityModel?> addReviewToUtility(
    String utilityId, {
    required String userId,
    required double rating,
    required String comment,
  }) async {
    try {
      final reviewRef = FirebaseFirestore.instance
          .collection('utilities')
          .doc(utilityId)
          .collection('reviews')
          .doc();

      await reviewRef.set({
        'userid': userId,
        'rating': rating,
        'comment': comment,
        'createdat': FieldValue.serverTimestamp(),
      });

      return getUtility(utilityId);
    } catch (e) {
      return null;
    }
  }

  static Future<List<UtilityModel>> getAllUtilitiesAdmin() async {
    return getUtilities();
  }

  static Future<List<UtilityModel>> getPendingUtilities() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('utilities')
          .where('verified', isEqualTo: false)
          .get();
      return snapshot.docs
          .map(
            (doc) => UtilityModel.fromJson({
              ...(doc.data() as Map<String, dynamic>),
              'id': doc.id,
            }),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<UtilityModel?> verifyUtility(String utilityId) async {
    try {
      await FirebaseFirestore.instance
          .collection('utilities')
          .doc(utilityId)
          .update({'verified': true});
      return getUtility(utilityId);
    } catch (e) {
      return null;
    }
  }

  static Future<UtilityModel?> rejectUtility(
    String utilityId, {
    String? reason,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('utilities')
          .doc(utilityId)
          .update({'verified': false, 'rejectionReason': reason ?? ''});
      return getUtility(utilityId);
    } catch (e) {
      return null;
    }
  }

  // ==================== UNIVERSITIES ====================
  static Future<List<UniversityModel>> getAllUniversities() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('universities')
          .orderBy('name')
          .get();
      return snapshot.docs
          .map((doc) => UniversityModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<UniversityModel?> getUniversityById(String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('universities')
          .doc(id)
          .get();
      if (doc.exists) {
        return UniversityModel.fromJson({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==================== ROOM REVIEWS ====================

  /// Add a review to a room (persists to Firestore subcollection)
  static Future<bool> addRoomReview({
    required String roomId,
    required String userId,
    required String userName,
    required double rating,
    required String comment,
    String? userImage,
  }) async {
    try {
      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .get();
      if (!roomDoc.exists) return false;

      final ownerId = roomDoc.data()?['ownerid']?.toString();
      if (ownerId != null && ownerId == userId) {
        debugPrint('⚠️ REVIEW: Owner attempted self-review for room $roomId');
        return false;
      }

      // Write review to subcollection
      final reviewRef = FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('reviews')
          .doc(); // auto-generate ID

      await reviewRef.set({
        'id': reviewRef.id,
        'userid': userId,
        'username': userName,
        'rating': rating,
        'comment': comment,
        'userImage': userImage,
        'createdat': FieldValue.serverTimestamp(),
      });

      // Recalculate average rating on the parent document
      await _recalculateRoomRating(roomId);

      debugPrint('✅ REVIEW: Room review saved to Firestore (roomId=$roomId)');
      return true;
    } catch (e) {
      debugPrint('❌ REVIEW: Failed to save room review: $e');
      return false;
    }
  }

  /// Check if a user has already reviewed a specific room
  static Future<bool> hasUserReviewedRoom(String roomId, String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('reviews')
          .where('userid', isEqualTo: userId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ REVIEW: Error checking room review: $e');
      return false;
    }
  }

  /// Fetch all reviews for a room from Firestore subcollection
  static Future<List<Map<String, dynamic>>> getRoomReviews(
    String roomId,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('reviews')
          .orderBy('createdat', descending: true)
          .get();
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      debugPrint('❌ REVIEW: Error fetching room reviews: $e');
      return [];
    }
  }

  /// Recalculate and update the average rating on a room document
  static Future<void> _recalculateRoomRating(String roomId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('reviews')
          .get();

      if (snapshot.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('rooms').doc(roomId).update(
          {'rating': 0.0},
        );
        return;
      }

      double total = 0;
      for (final doc in snapshot.docs) {
        total += (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
      }
      final avg = total / snapshot.docs.length;

      await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
        'rating': double.parse(avg.toStringAsFixed(1)),
      });
      debugPrint(
        '✅ RATING: Room $roomId avg rating updated to ${avg.toStringAsFixed(1)}',
      );
    } catch (e) {
      debugPrint('❌ RATING: Failed to recalculate room rating: $e');
    }
  }

  // ==================== MESS REVIEWS ====================

  /// Add a review to a mess (persists to Firestore subcollection)
  static Future<bool> addMessReview({
    required String messId,
    required String userId,
    required String userName,
    required double rating,
    required String comment,
  }) async {
    try {
      final messDoc = await FirebaseFirestore.instance
          .collection('mess')
          .doc(messId)
          .get();
      if (!messDoc.exists) return false;

      final ownerId = messDoc.data()?['ownerid']?.toString();
      if (ownerId != null && ownerId == userId) {
        debugPrint('⚠️ REVIEW: Owner attempted self-review for mess $messId');
        return false;
      }

      final reviewRef = FirebaseFirestore.instance
          .collection('mess')
          .doc(messId)
          .collection('reviews')
          .doc();

      await reviewRef.set({
        'id': reviewRef.id,
        'userid': userId,
        'username': userName,
        'rating': rating,
        'comment': comment,
        'createdat': FieldValue.serverTimestamp(),
      });

      // Recalculate average rating
      await _recalculateMessRating(messId);

      debugPrint('✅ REVIEW: Mess review saved to Firestore (messId=$messId)');
      return true;
    } catch (e) {
      debugPrint('❌ REVIEW: Failed to save mess review: $e');
      return false;
    }
  }

  /// Check if a user has already reviewed a specific mess
  static Future<bool> hasUserReviewedMess(String messId, String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('mess')
          .doc(messId)
          .collection('reviews')
          .where('userid', isEqualTo: userId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ REVIEW: Error checking mess review: $e');
      return false;
    }
  }

  /// Fetch all reviews for a mess from Firestore subcollection
  static Future<List<Map<String, dynamic>>> getMessReviews(
    String messId,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('mess')
          .doc(messId)
          .collection('reviews')
          .orderBy('createdat', descending: true)
          .get();
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      debugPrint('❌ REVIEW: Error fetching mess reviews: $e');
      return [];
    }
  }

  /// Recalculate and update the average rating on a mess document
  static Future<void> _recalculateMessRating(String messId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('mess')
          .doc(messId)
          .collection('reviews')
          .get();

      if (snapshot.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('mess').doc(messId).update({
          'rating': 0.0,
        });
        return;
      }

      double total = 0;
      for (final doc in snapshot.docs) {
        total += (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
      }
      final avg = total / snapshot.docs.length;

      await FirebaseFirestore.instance.collection('mess').doc(messId).update({
        'rating': double.parse(avg.toStringAsFixed(1)),
      });
      debugPrint(
        '✅ RATING: Mess $messId avg rating updated to ${avg.toStringAsFixed(1)}',
      );
    } catch (e) {
      debugPrint('❌ RATING: Failed to recalculate mess rating: $e');
    }
  }
}

/// Fake Dio class for compatibility — only used for legacy GET calls.
/// POST calls for reviews now go through ApiService static methods directly.
class _FakeDio {
  Future<_FakeResponse> get(String path) async {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final collection = parts[0];
      final docId = parts[1];
      final doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .get();
      return _FakeResponse(
        data: doc.exists ? {...doc.data()!, 'id': doc.id} : null,
        statusCode: doc.exists ? 200 : 404,
      );
    }
    return _FakeResponse(data: null, statusCode: 404);
  }

  /// Legacy post — should NOT be used for reviews anymore.
  /// Reviews should use ApiService.addRoomReview / ApiService.addMessReview.
  Future<_FakeResponse> post(String path, {dynamic data}) async {
    debugPrint(
      '⚠️ _FakeDio.post called for $path — this is a legacy stub. Use ApiService methods instead.',
    );
    return _FakeResponse(data: {'success': true}, statusCode: 201);
  }
}

class _FakeResponse {
  final dynamic data;
  final int statusCode;
  _FakeResponse({required this.data, required this.statusCode});
}
