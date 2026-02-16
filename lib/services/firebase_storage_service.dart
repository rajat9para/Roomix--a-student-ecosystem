import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Firebase Storage Service for image uploads
class FirebaseStorageService {
  static final FirebaseStorageService _instance = FirebaseStorageService._internal();
  factory FirebaseStorageService() => _instance;
  FirebaseStorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload image file to Firebase Storage
  /// Returns the download URL
  Future<String> uploadImage({
    required File file,
    required String folder,
    String? fileName,
  }) async {
    try {
      final String uniqueFileName =
          fileName ?? '${DateTime.now().millisecondsSinceEpoch}.jpg';

      final Reference ref = _storage.ref().child('$folder/$uniqueFileName');

      // 🔥 READ BYTES INSTEAD OF FILE (fixes Android cancel + object-not-found)
      final bytes = await file.readAsBytes();

      final TaskSnapshot snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final String downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint("✅ UPLOADED URL => $downloadUrl");

      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Upload failed: $e');
      throw Exception('Failed to upload image');
    }
  }

  /// Upload image from XFile (from image_picker)
  Future<String> uploadXFile({
    required XFile xFile,
    required String folder,
  }) async {
    try {
      final File file = File(xFile.path);
      return await uploadImage(
        file: file,
        folder: folder,
        fileName: xFile.name,
      );
    } catch (e) {
      debugPrint('Error uploading XFile: $e');
      throw Exception('Failed to upload image');
    }
  }

  /// Upload profile picture
  Future<String> uploadProfilePicture({
    required File file,
    required String userId,
  }) async {
    return await uploadImage(
      file: file,
      folder: 'profile_pictures',
      fileName: '${userId}_profile.jpg',
    );
  }

  /// Upload profile image from path (for AuthProvider compatibility)
  Future<String?> uploadProfileImage({
    required String userId,
    required String imagePath,
  }) async {
    try {
      final File file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Image file not found');
      }
      return await uploadProfilePicture(
        file: file,
        userId: userId,
      );
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      return null;
    }
  }

  /// Upload room image
  Future<String> uploadRoomImage({
    required File file,
    String? roomId,
  }) async {
    return await uploadImage(
      file: file,
      folder: 'room_images',
      fileName: roomId != null ? '${roomId}_room.jpg' : null,
    );
  }

  /// Upload mess image
  Future<String> uploadMessImage({
    required File file,
    String? messId,
  }) async {
    return await uploadImage(
      file: file,
      folder: 'mess_images',
      fileName: messId != null ? '${messId}_mess.jpg' : null,
    );
  }

  /// Upload roommate profile image
  Future<String> uploadRoommateImage({
    required File file,
    required String userId,
  }) async {
    return await uploadImage(
      file: file,
      folder: 'roommate_images',
      fileName: '${userId}_roommate.jpg',
    );
  }

  /// Upload utility image
  Future<String> uploadUtilityImage({
    required File file,
    String? utilityId,
  }) async {
    return await uploadImage(
      file: file,
      folder: 'utility_images',
      fileName: utilityId != null ? '${utilityId}_utility.jpg' : null,
    );
  }

  /// Delete image by URL
  Future<void> deleteImage(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting image: $e');
      throw Exception('Failed to delete image');
    }
  }

  /// Delete image by path
  Future<void> deleteImageByPath(String path) async {
    try {
      final Reference ref = _storage.ref().child(path);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting image by path: $e');
      throw Exception('Failed to delete image');
    }
  }

  /// Get download URL for a storage path
  Future<String> getDownloadUrl(String path) async {
    try {
      final Reference ref = _storage.ref().child(path);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error getting download URL: $e');
      throw Exception('Failed to get download URL');
    }
  }

  /// Check if file exists
  Future<bool> fileExists(String path) async {
    try {
      final Reference ref = _storage.ref().child(path);
      await ref.getMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Pick and upload image in one operation
  Future<String?> pickAndUploadImage({
    required ImageSource source,
    required String folder,
    String? fileName,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      final File file = File(pickedFile.path);
      return await uploadImage(
        file: file,
        folder: folder,
        fileName: fileName ?? pickedFile.name,
      );
    } catch (e) {
      debugPrint('Error picking and uploading image: $e');
      throw Exception('Failed to upload image');
    }
  }
}
