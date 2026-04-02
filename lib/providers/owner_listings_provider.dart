import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:roomix/models/room_model.dart';
import 'package:roomix/models/mess_model.dart';
import 'package:roomix/services/firebase_service.dart';
import 'package:roomix/services/cloudinary_upload_service.dart';

/// Provider for managing owner listings (rooms and mess)
class OwnerListingsProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final CloudinaryUploadService _storageService = CloudinaryUploadService();

  List<RoomModel> _myRooms = [];
  List<MessModel> _myMess = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<RoomModel> get myRooms => _myRooms;
  List<MessModel> get myMess => _myMess;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Aliases for owner_dashboard_screen compatibility
  List<dynamic> get rooms => _myRooms;
  List<dynamic> get mess => _myMess;
  bool get loadingRooms => _isLoading;
  bool get loadingMess => _isLoading;

  // Edit room (alias for updateRoom)
  Future<bool> editRoom(String roomId, Map<String, dynamic> updates) async {
    return updateRoom(roomId, updates);
  }

  // Edit mess
  Future<bool> editMess(String messId, Map<String, dynamic> updates) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.updateMess(messId, updates);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update mess: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete mess
  Future<bool> deleteMess(String messId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.deleteMess(messId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete mess: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Fetch rooms (alias for loading data)
  Future<void> fetchRooms() async {
    // Data is already loaded via streams, just ensure loading state
    notifyListeners();
  }

  // Fetch mess (alias for loading data)
  Future<void> fetchMess() async {
    // Data is already loaded via streams, just ensure loading state
    notifyListeners();
  }

  // Fetch all listings
  Future<void> fetchAll() async {
    // Data is already loaded via streams, just ensure loading state
    notifyListeners();
  }

  StreamSubscription<List<RoomModel>>? _roomsSubscription;
  StreamSubscription<List<MessModel>>? _messSubscription;
  String? _activeOwnerId;

  /// Load owner listings with real-time updates
  void loadMyListings(String ownerId) {
    final normalizedOwnerId = ownerId.trim();
    if (normalizedOwnerId.isEmpty) {
      _cancelListingSubscriptions();
      _activeOwnerId = null;
      _isLoading = false;
      clearListings();
      return;
    }
    if (_activeOwnerId == normalizedOwnerId &&
        (_roomsSubscription != null || _messSubscription != null)) {
      return;
    }

    _cancelListingSubscriptions();
    _activeOwnerId = normalizedOwnerId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    _roomsSubscription = _firebaseService
        .getRoomsByOwner(normalizedOwnerId)
        .map((data) => data.map((json) => RoomModel.fromJson(json)).toList())
        .listen(
          (rooms) {
            _myRooms = rooms;
            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            _error = 'Failed to load rooms: $e';
            _isLoading = false;
            notifyListeners();
          },
        );

    _messSubscription = _firebaseService
        .getMessByOwner(normalizedOwnerId)
        .map((data) => data.map((json) => MessModel.fromJson(json)).toList())
        .listen(
          (messList) {
            _myMess = messList;
            notifyListeners();
          },
          onError: (e) {
            _error = 'Failed to load mess listings: $e';
            notifyListeners();
          },
        );
  }

  void _cancelListingSubscriptions() {
    _roomsSubscription?.cancel();
    _messSubscription?.cancel();
    _roomsSubscription = null;
    _messSubscription = null;
  }

  // ==================== ROOM OPERATIONS ====================

  /// Add a new room with already-uploaded image URLs
  Future<bool> addRoom({
    required String title,
    required String location,
    required double price,
    double? priceperperson,
    required String type,
    required String contact,
    required List<String> amenities,
    required String university,
    List<String> imageUrls = const [],
    String? ownerId,
    double? latitude,
    double? longitude,
    String? telegramContact,
  }) async {
    debugPrint('🏠 PROVIDER.addRoom: Starting...');
    debugPrint('🏠 PROVIDER.addRoom: title=$title, type=$type, price=$price');
    debugPrint(
      '🏠 PROVIDER.addRoom: imageUrls=${imageUrls.length} URLs: $imageUrls',
    );
    debugPrint(
      '🏠 PROVIDER.addRoom: university=$university, location=$location',
    );

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // First image is the cover
      final String primaryImageUrl = imageUrls.isNotEmpty
          ? imageUrls.first
          : '';
      debugPrint('🏠 PROVIDER.addRoom: primaryImageUrl=$primaryImageUrl');

      final docId = await _firebaseService.createRoomWithCoordinates(
        title: title,
        location: location,
        price: price,
        priceperperson: priceperperson,
        type: type,
        imageurl: primaryImageUrl,
        contact: contact,
        amenities: amenities,
        university: university,
        ownerid: ownerId,
        latitude: latitude,
        longitude: longitude,
        telegramPhone: telegramContact,
        images: imageUrls,
      );

      debugPrint('✅ PROVIDER.addRoom: Room created successfully! docId=$docId');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ PROVIDER.addRoom FAILED: $e');
      debugPrint('❌ PROVIDER.addRoom STACK: $stackTrace');
      _error = 'Failed to add room: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update room with Map
  Future<bool> updateRoom(String roomId, Map<String, dynamic> updates) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.updateRoom(roomId, updates);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update room: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update room with named parameters (for AddRoomScreen editing)
  Future<bool> updateRoomWithDetails({
    required String roomId,
    required String title,
    required String location,
    required double price,
    double? priceperperson,
    required String type,
    required String contact,
    required List<String> amenities,
    required String university,
    String? imageUrl,
    double? latitude,
    double? longitude,
    String? telegramContact,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updates = <String, dynamic>{
        'title': title,
        'location': location,
        'price': price,
        if (priceperperson != null) 'priceperperson': priceperperson,
        'type': type,
        'contact': contact,
        'amenities': amenities,
        'university': university,
        if (telegramContact != null && telegramContact.isNotEmpty)
          'telegramPhone': telegramContact,
        if (imageUrl != null) 'imageurl': imageUrl,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

      await _firebaseService.updateRoom(roomId, updates);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update room: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update room with new image
  Future<bool> updateRoomWithImage({
    required String roomId,
    required Map<String, dynamic> updates,
    File? newImageFile,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Upload new image if provided
      if (newImageFile != null) {
        final imageurl = await _storageService.uploadRoomImage(
          file: newImageFile,
          roomId: roomId,
        );
        updates['imageurl'] = imageurl;
      }

      await _firebaseService.updateRoom(roomId, updates);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update room: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete room
  Future<bool> deleteRoom(String roomId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.deleteRoom(roomId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete room: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ==================== MESS OPERATIONS ====================

  /// Add a new mess listing with image upload
  Future<bool> addMess({
    required String name,
    required String location,
    required double pricepermonth,
    int? mealsPerDay,
    required String foodtype,
    required String contact,
    required List<String> menu,
    String? timings,
    String? university,
    File? imageFile,
    String? ownerId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Upload image if provided
      String imageurl = '';
      if (imageFile != null) {
        imageurl = await _storageService.uploadMessImage(file: imageFile);
      }

      await _firebaseService.createMess(
        name: name,
        location: location,
        pricepermonth: pricepermonth,
        mealsPerDay: mealsPerDay,
        foodtype: foodtype,
        contact: contact,
        menu: menu,
        imageurl: imageurl,
        timings: timings,
        university: university,
        ownerid: ownerId,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to add mess: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ==================== UTILITY ====================

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearListings() {
    _myRooms = [];
    _myMess = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelListingSubscriptions();
    super.dispose();
  }
}
