import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:roomix/models/room_model.dart';
import 'package:roomix/models/mess_model.dart';
import 'package:roomix/models/event_model.dart';
import 'package:roomix/models/utility_model.dart';
import 'package:roomix/models/university_model.dart';
import 'package:roomix/services/firebase_service.dart';
import '../models/room_model.dart';

/// ApiService - Compatibility layer bridging old REST API calls to Firebase
class ApiService {
  static final FirebaseService _firebaseService = FirebaseService();
  static final dynamic dio = _FakeDio();

  // ==================== ROOMS ====================
  static Future<List<RoomModel>> getRooms() async {
    await Future.delayed(const Duration(milliseconds: 400));

    return [
      RoomModel(
        id: '1',
        title: 'Bhushan Boys PG',
        location: 'Near Graphic Era Hill University',
        price: 4000,
        type: 'boys',
        imageurl: 'https://img.staticmb.com/mbphoto/pg/grd2/cropped_images/2024/Aug/16/Photo_h400_w540/GR2-458945-2223343_400_540.jpg',
        contact: '7817823900',
        amenities: ['wifi','food'],
        ownerid: 'owner1',
        university: 'Graphic Era Hill University',
        rating: 4.5,
      ),

      RoomModel(
        id: '2',
        title: 'Rahtan Villa PG',
        location: 'Clement Town, Dehradun',
        price: 11000,
        type: 'girls',
        imageurl: 'https://img.staticmb.com/mbphoto/pg/grd2/cropped_images/2025/Oct/28/Photo_h400_w540/GR2-513673-2615101_400_540.jpeg',
        contact: '9634626940',
        amenities: ['wifi','laundry'],
        ownerid: 'owner1',
        university: 'Graphic Era Hill University',
        rating: 4.2,
      ),

      RoomModel(
        id: '3',
        title: 'Green Arc PG',
        location: 'Ballupur Chowk',
        price: 5200,
        type: 'mixed',
        imageurl: 'https://img.staticmb.com/mbphoto/pg/grd2/cropped_images/2023/May/05/Photo_h400_w540/GR2-368841-1740665_400_540.jpeg',
        contact: '1352751404',
        amenities: ['wifi'],
        ownerid: 'owner1',
        university: 'Graphic Era Hill University',
        rating: 4.0,
      ),
    ];
  }

  static Future<RoomModel?> getRoomById(String id) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('rooms').doc(id).get();
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
  static Future<Map<String, dynamic>> getMessMenu({int page = 1, int limit = 20}) async {
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
        'pagination': {'currentPage': page, 'hasMore': snapshot.docs.length == limit}
      };
    } catch (e) {
      return {'data': <MessModel>[], 'pagination': {'currentPage': page, 'hasMore': false}};
    }
  }

  static Future<MessModel?> getMessById(String id) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('mess').doc(id).get();
      if (doc.exists) {
        return MessModel.fromJson({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==================== EVENTS ====================
  static Future<Map<String, dynamic>> getEvents({int page = 1, int limit = 20}) async {
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
        'pagination': {'currentPage': page, 'hasMore': snapshot.docs.length == limit}
      };
    } catch (e) {
      return {'data': <EventModel>[], 'pagination': {'currentPage': page, 'hasMore': false}};
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
          .map((doc) => UtilityModel.fromJson({...(doc.data() as Map<String, dynamic>), 'id': doc.id}))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<UtilityModel>> getUtilitiesByCategory(String category) async {
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
          .map((doc) => UtilityModel.fromJson({...(doc.data() as Map<String, dynamic>), 'id': doc.id}))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<UtilityModel?> getUtility(String id) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('utilities').doc(id).get();
      if (doc.exists) {
        return UtilityModel.fromJson({...(doc.data() as Map<String, dynamic>), 'id': doc.id});
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
      final updates = <String, dynamic>{'updatedAt': DateTime.now().toIso8601String()};
      
      if (name != null) updates['name'] = name;
      if (category != null) updates['category'] = category;
      if (description != null) updates['description'] = description;
      if (address != null) updates['location.address'] = address;
      if (contact != null) updates['contact'] = contact;
      if (phone != null) updates['contact.phone'] = phone;
      if (latitude != null) updates['location.coordinates'] = [longitude ?? 0.0, latitude];
      
      await FirebaseFirestore.instance.collection('utilities').doc(id).update(updates);
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
          .map((doc) => UtilityModel.fromJson({...(doc.data() as Map<String, dynamic>), 'id': doc.id}))
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

  static Future<UtilityModel?> rejectUtility(String utilityId, {String? reason}) async {
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
      final doc = await FirebaseFirestore.instance.collection('universities').doc(id).get();
      if (doc.exists) {
        return UniversityModel.fromJson({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Fake Dio class for compatibility
class _FakeDio {
  Future<_FakeResponse> get(String path) async {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final collection = parts[0];
      final docId = parts[1];
      final doc = await FirebaseFirestore.instance.collection(collection).doc(docId).get();
      return _FakeResponse(
        data: doc.exists ? {...doc.data()!, 'id': doc.id} : null,
        statusCode: doc.exists ? 200 : 404,
      );
    }
    return _FakeResponse(data: null, statusCode: 404);
  }

  Future<_FakeResponse> post(String path, {dynamic data}) async {
    return _FakeResponse(data: {'success': true}, statusCode: 201);
  }
}

class _FakeResponse {
  final dynamic data;
  final int statusCode;
  _FakeResponse({required this.data, required this.statusCode});
}
