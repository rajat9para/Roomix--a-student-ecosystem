import 'dart:io';
import 'package:flutter/material.dart';
import 'package:roomix/models/room_model.dart';
import 'package:roomix/models/mess_model.dart';
import 'package:roomix/services/firebase_service.dart';
import 'package:roomix/services/firebase_storage_service.dart';

/// Provider for managing owner listings (rooms and mess)
class OwnerListingsProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseStorageService _storageService = FirebaseStorageService();

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

  // Stream subscriptions
  Stream<List<RoomModel>>? _roomsStream;
  Stream<List<MessModel>>? _messStream;

  /// Load owner listings with real-time updates
  void loadMyListings(String ownerId) {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Listen to rooms
    _roomsStream = _firebaseService.getRoomsByOwner(ownerId).map((data) {
      return data.map((json) => RoomModel.fromJson(json)).toList();
    });

    _roomsStream?.listen(
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

    // Listen to mess
    _messStream = _firebaseService.getMessByOwner(ownerId).map((data) {
      return data.map((json) => MessModel.fromJson(json)).toList();
    });

    _messStream?.listen(
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

  // ==================== ROOM OPERATIONS ====================

  /// Add a new room with image upload
  Future<bool> addRoom({
    required String title,
    required String location,
    required double price,
    required String type,
    required String contact,
    required List<String> amenities,
    required String university,
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
        imageurl = await _storageService.uploadRoomImage(file: imageFile);
      }

      await _firebaseService.createRoom(
        title: title,
        location: location,
        price: price,
        type: type,
        imageurl: imageurl,
        contact: contact,
        amenities: amenities,
        university: university,
        ownerid: ownerId,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to add room: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update room
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
}
