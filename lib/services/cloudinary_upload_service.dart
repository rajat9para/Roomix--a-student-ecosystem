import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cloudinary Image Upload Service (FREE — no Blaze plan needed)
/// Uses unsigned uploads via Cloudinary's REST API.
/// 
/// Setup: Create a free Cloudinary account at https://cloudinary.com
/// Then create an unsigned upload preset in Settings → Upload → Upload presets
class CloudinaryUploadService {
  static final CloudinaryUploadService _instance = CloudinaryUploadService._internal();
  factory CloudinaryUploadService() => _instance;
  CloudinaryUploadService._internal();

  // ==========================================
  // 🔧 CLOUDINARY ACCOUNT CREDENTIALS
  // ==========================================
  static const String _cloudName = 'dd7hewm85';
  static const String _uploadPreset = 'roomix-unsigned';
  // ==========================================

  static const String _baseUrl = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Upload image file to Cloudinary
  /// Returns the download URL
  Future<String> uploadImage({
    required File file,
    required String folder,
    String? fileName,
  }) async {
    try {
      final String uniqueFileName =
          fileName ?? '${DateTime.now().millisecondsSinceEpoch}.jpg';

      debugPrint('📤 CLOUDINARY: Uploading to $folder/$uniqueFileName');
      debugPrint('📤 CLOUDINARY: File path: ${file.path}');
      debugPrint('📤 CLOUDINARY: File exists: ${await file.exists()}');
      debugPrint('📤 CLOUDINARY: File size: ${await file.length()} bytes');

      // Read file bytes
      final bytes = await file.readAsBytes();

      debugPrint('📤 CLOUDINARY: Read ${bytes.length} bytes, uploading...');

      // Build multipart request
      final request = http.MultipartRequest('POST', Uri.parse(_baseUrl));
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = folder;
      request.fields['public_id'] = uniqueFileName.replaceAll('.jpg', '');
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: uniqueFileName,
        ),
      );

      // Send request
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📤 CLOUDINARY: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final String downloadUrl = jsonResponse['secure_url'] ?? jsonResponse['url'] ?? '';

        if (downloadUrl.isEmpty) {
          debugPrint('❌ CLOUDINARY: No URL in response: ${response.body}');
          throw Exception('Cloudinary returned empty URL');
        }

        debugPrint('✅ CLOUDINARY UPLOADED => $downloadUrl');
        return downloadUrl;
      } else {
        final errorBody = response.body;
        debugPrint('❌ CLOUDINARY Upload failed: status=${response.statusCode}, body=$errorBody');
        
        // Parse error message
        String errorMsg = 'Cloudinary upload failed (HTTP ${response.statusCode})';
        try {
          final errorJson = json.decode(errorBody);
          errorMsg = errorJson['error']?['message'] ?? errorMsg;
        } catch (_) {
          // JSON parsing failed, use default message
        }
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ CLOUDINARY Upload failed: $e');
      debugPrint('❌ CLOUDINARY Stack: $stackTrace');
      rethrow;
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
}
