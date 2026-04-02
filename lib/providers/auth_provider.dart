import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roomix/services/firebase_auth_service.dart';
import 'package:roomix/services/firebase_service.dart';
import 'package:roomix/services/cloudinary_upload_service.dart';
import 'package:roomix/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentUser;
  bool _initialized = false;
  bool get initialized => _initialized;
  // Temporary storage for password reset
  String? _resetEmail;
  String? _resetToken;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => firebaseUser != null;

  // Get Firebase current user
  User? get firebaseUser => _authService.currentUser;

  AuthProvider() {
    _initializeAuth();
  }

  String _normalizeRole(String? role) {
    final normalized = role?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return 'student';
    }
    return normalized;
  }

  String _cleanError(dynamic error) {
    var message = error.toString().trim();
    while (message.startsWith('Exception:')) {
      message = message.substring('Exception:'.length).trim();
    }
    return message;
  }

  String _cachedUserKey(String userId) => 'cached_user_$userId';

  Map<String, dynamic> _serializeUserForCache(UserModel user) {
    return {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'role': user.role,
      'phone': user.phone ?? '',
      'university': user.university ?? '',
      'createdat': user.createdat?.toIso8601String(),
      'profilePicture': user.profilePicture ?? '',
      'course': user.course ?? '',
      'year': user.year ?? '',
      'telegramPhone': user.telegramPhone ?? '',
      if (user.ownerType != null) 'ownerType': user.ownerType,
      if (user.description != null) 'description': user.description,
    };
  }

  Future<void> _cacheCurrentUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cachedUserKey(user.id),
        jsonEncode(_serializeUserForCache(user)),
      );
    } catch (_) {}
  }

  Future<UserModel?> _readCachedUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachedUserKey(userId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      decoded['id'] = decoded['id'] ?? userId;
      return UserModel.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearCachedUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedUserKey(userId));
    } catch (_) {}
  }

  Future<void> _ensureAdminProfileDocument({
    required User user,
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final fallbackName = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : 'Roomix Admin';

    Map<String, dynamic>? existing;
    try {
      existing = await _firebaseService.getUser(user.uid, forceServer: true);
    } catch (_) {
      existing = null;
    }

    if (existing == null) {
      try {
        await _firebaseService.createUser(
          userId: user.uid,
          email: normalizedEmail,
          name: fallbackName,
          role: 'admin',
        );
      } catch (_) {}
      return;
    }

    final existingRole = _normalizeRole(existing['role']?.toString());
    final existingEmail =
        existing['email']?.toString().trim().toLowerCase() ?? '';
    if (existingRole == 'admin' && existingEmail == normalizedEmail) {
      return;
    }

    final existingName = existing['name']?.toString().trim();
    try {
      await _firebaseService.updateUser(user.uid, {
        'role': 'admin',
        'email': normalizedEmail,
        'name': (existingName != null && existingName.isNotEmpty)
            ? existingName
            : fallbackName,
      });
    } catch (_) {}
  }

  void _initializeAuth() {
    // Only set _initialized = false on first launch, NOT on background resume
    if (!_initialized) {
      _initialized = false;
    }

    _authService.authStateChanges.listen((User? user) async {
      if (user == null) {
        _currentUser = null;
        _errorMessage = null;
        _initialized = true;
        notifyListeners();
        return;
      }

      // 🚨 CRITICAL: If a login/register/google-sign-in operation is in progress,
      // do NOT reload user data here. The calling method (login, register, signInWithGoogle)
      // will handle _loadUserData itself with the correct role and forceServer.
      // Without this guard, this listener races with the login flow and can
      // overwrite _currentUser or null it out, causing the user to stay on the login page.
      if (_isLoading) {
        debugPrint(
          '👤 Auth state changed but login/register in progress — skipping listener reload',
        );
        _initialized = true;
        notifyListeners();
        return;
      }

      // Skip re-loading if we already have this user's data loaded
      // (e.g. register() or login() already loaded it)
      if (_currentUser != null && _currentUser!.id == user.uid) {
        debugPrint(
          '👤 Auth state changed but user data already loaded — skipping reload',
        );
        _initialized = true;
        notifyListeners();
        return;
      }

      debugPrint('👤 Auth detected → loading Firestore profile');
      await _loadUserData(
        user.uid,
        email: user.email,
        displayName: user.displayName,
      );

      _initialized = true;
      notifyListeners();
    });
  }

  /// Loads user data from Firestore. Auto-creates document if missing.
  /// Set forceServer=true after writes to bypass Firestore cache.
  Future<void> _loadUserData(
    String userId, {
    String? email,
    String? displayName,
    String? role,
    bool forceServer = false,
  }) async {
    try {
      debugPrint(
        '💾 Loading user data for: $userId (forceServer=$forceServer)',
      );

      Map<String, dynamic>? userData;

      // Try server first if forceServer, fallback to cache on failure
      if (forceServer) {
        try {
          userData = await _firebaseService.getUser(userId, forceServer: true);
        } catch (e) {
          debugPrint('⚠️ Server fetch failed, trying cache: $e');
          try {
            userData = await _firebaseService.getUser(
              userId,
              forceServer: false,
            );
          } catch (_) {
            debugPrint('⚠️ Cache fetch also failed');
          }
        }
      } else {
        userData = await _firebaseService.getUser(userId, forceServer: false);
      }

      if (userData != null) {
        _currentUser = UserModel.fromJson(userData);
        await _cacheCurrentUser(_currentUser!);
        debugPrint(
          '✅ User data loaded: ${_currentUser?.name} (role: ${_currentUser?.role})',
        );
      } else {
        debugPrint('⚠️ No user data found in Firestore - auto-creating...');

        // Auto-create missing user document with the CORRECT role
        if (email != null) {
          try {
            await _firebaseService.createUser(
              userId: userId,
              email: email,
              name: displayName ?? email.split('@')[0],
              role: role ?? 'student',
            );

            // Retry loading (from cache is fine now since we just wrote)
            final retryData = await _firebaseService.getUser(userId);
            if (retryData != null) {
              _currentUser = UserModel.fromJson(retryData);
              await _cacheCurrentUser(_currentUser!);
              debugPrint(
                '✅ User document auto-created and loaded (role: ${role ?? 'student'})',
              );
            } else {
              final cachedUser = await _readCachedUser(userId);
              if (cachedUser != null) {
                _currentUser = cachedUser;
                debugPrint(
                  '⚠️ Using cached user after auto-create retry failed',
                );
              } else {
                _currentUser = null;
                debugPrint('❌ Failed to load after auto-create');
              }
            }
          } catch (e) {
            debugPrint('❌ Error during auto-create: $e');
            final cachedUser = await _readCachedUser(userId);
            if (cachedUser != null) {
              _currentUser = cachedUser;
              debugPrint('⚠️ Using cached user after auto-create error');
            } else {
              _currentUser = null;
            }
          }
        } else {
          final cachedUser = await _readCachedUser(userId);
          _currentUser = cachedUser;
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      final cachedUser = await _readCachedUser(userId);
      if (cachedUser != null) {
        _currentUser = cachedUser;
        debugPrint('⚠️ Restored cached user due load error');
      } else if (_currentUser == null) {
        debugPrint('⚠️ No existing user data to preserve — user stays null');
      } else {
        debugPrint('⚠️ Keeping existing user data despite load error');
      }
    }

    _initialized = true;
    notifyListeners();
  }

  // ==================== EMAIL/PASSWORD LOGIN ====================

  /// Standard email/password login (for regular users)
  Future<Map<String, dynamic>> login(
    String email,
    String password,
    String role,
  ) async {
    debugPrint('🔐 AuthProvider: Starting email login...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithEmail(
        email: email,
        password: password,
        role: role,
      );

      if (result['success'] == true) {
        final user = result['user'] as User;

        // Fetch user data directly with forceServer to ensure immediate load
        debugPrint('fetching direct user profile after email login');
        await _loadUserData(
          user.uid,
          email: user.email,
          displayName: user.displayName,
          role: role,
          forceServer: true,
        );

        // If still null, something is wrong
        if (_currentUser == null) {
          throw Exception(
            'Failed to load user profile. Please check your internet connection and try again.',
          );
        }

        // 🚨 block wrong role login
        final expectedRole = _normalizeRole(role);
        final actualRole = _normalizeRole(_currentUser!.role);
        if (actualRole != expectedRole) {
          await _authService.signOut();
          _currentUser = null;
          throw Exception(
            'This account is registered as $actualRole. Please select the correct role.',
          );
        }

        _isLoading = false;
        _errorMessage = null;
        notifyListeners();

        return {'success': true, 'role': actualRole};
      }

      _isLoading = false;
      notifyListeners();
      return {'success': false};
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ AuthProvider: Email login failed - $_errorMessage');
      throw Exception(_errorMessage);
    }
  }

  // ==================== GOOGLE SIGN-IN ====================

  /// Firebase Google Sign-In with comprehensive error handling
  Future<Map<String, dynamic>> signInWithGoogle(
    String role, {
    String? ownerType,
  }) async {
    debugPrint('🔵 AuthProvider: Starting Google Sign-In...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogle(
        role: role,
        ownerType: ownerType,
      );

      if (result['success'] == true) {
        final user = result['user'] as User;

        // Fetch user data directly with forceServer to ensure immediate load
        debugPrint('fetching direct user profile after google sign in');
        await _loadUserData(
          user.uid,
          email: user.email,
          displayName: user.displayName,
          role: role,
          forceServer: true,
        );

        // If still null, create the user document
        if (_currentUser == null) {
          debugPrint('⚠️ Creating missing user document for Google Sign-In');
          await _firebaseService.createUser(
            userId: user.uid,
            email: user.email ?? '',
            name: user.displayName ?? 'User',
            role: role,
            ownerType: ownerType,
          );
          await _loadUserData(
            user.uid,
            email: user.email,
            displayName: user.displayName,
            role: role,
          );
        }

        // 🚨 FINAL CHECK: if _currentUser is STILL null, we cannot proceed
        if (_currentUser == null) {
          throw Exception(
            'Failed to load your profile. Please check your internet connection and try again.',
          );
        }

        // Check role mismatch (only for existing users)
        final expectedRole = _normalizeRole(role);
        final actualRole = _normalizeRole(_currentUser!.role);
        if (actualRole != expectedRole && result['isNewUser'] != true) {
          await _authService.signOut();
          _currentUser = null;
          throw Exception(
            'This account is already registered as $actualRole. Please select the correct role.',
          );
        }

        final normalizedOwnerType = ownerType?.trim().toLowerCase();
        if (expectedRole == 'owner' &&
            normalizedOwnerType != null &&
            normalizedOwnerType.isNotEmpty &&
            (_currentUser!.ownerType == null ||
                _currentUser!.ownerType!.trim().toLowerCase() !=
                    normalizedOwnerType)) {
          await _firebaseService.updateUser(user.uid, {
            'ownerType': normalizedOwnerType,
          });
          await _loadUserData(
            user.uid,
            email: user.email,
            displayName: user.displayName,
            role: role,
            forceServer: true,
          );
        }

        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return {'success': true, 'isNewUser': result['isNewUser'] ?? false};
      }

      _isLoading = false;
      notifyListeners();
      return {'cancelled': true};
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ AuthProvider: Google Sign-In failed - $_errorMessage');
      throw Exception(_errorMessage);
    }
  }

  // ==================== REGISTRATION ====================

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String role, {
    String? phone,
    String? university,
    String? ownerType,
  }) async {
    debugPrint('📝 AuthProvider: Starting registration...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.registerWithEmail(
        name: name,
        email: email,
        password: password,
        role: role,
        phone: phone,
        university: university,
        ownerType: ownerType,
      );

      if (result['success'] == true) {
        final user = result['user'] as User;

        // Fetch user data directly with forceServer to ensure immediate load
        debugPrint('fetching direct user profile after registration');
        await _loadUserData(
          user.uid,
          email: user.email,
          displayName: name,
          role: role,
          forceServer: true,
        );

        // If still null, something is wrong
        if (_currentUser == null) {
          debugPrint(
            '⚠️ User document not created - attempting manual creation',
          );
          await _firebaseService.createUser(
            userId: user.uid,
            email: email,
            name: name,
            role: role,
            phone: phone,
            university: university,
            ownerType: ownerType,
          );
          await _loadUserData(user.uid, email: email, displayName: name);
        }

        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        debugPrint('✅ AuthProvider: Registration successful');

        return {'success': true, 'role': role};
      }

      _isLoading = false;
      notifyListeners();
      return {'success': false};
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ AuthProvider: Registration failed - $_errorMessage');
      throw Exception(_errorMessage);
    }
  }

  // ==================== ADMIN LOGIN (OTP) ====================

  /// Request OTP for admin login
  Future<void> requestAdminOtp(String email) async {
    debugPrint('AuthProvider: Requesting admin OTP');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.requestAdminOtp(email);
      _isLoading = false;
      notifyListeners();
      debugPrint('AuthProvider: Admin OTP dispatched');
    } catch (e) {
      _errorMessage = _cleanError(e);
      _isLoading = false;
      notifyListeners();
      debugPrint('AuthProvider: Admin OTP request failed');
      throw Exception(_errorMessage);
    }
  }

  /// Verify Admin OTP and Login
  Future<void> verifyAdminOtpAndLogin(String email, String otp) async {
    debugPrint('AuthProvider: Verifying admin OTP...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.verifyAdminOtpAndLogin(
        email: email,
        otp: otp,
      );

      final user = result['user'] as User?;
      if (user == null) {
        throw Exception('Admin authentication failed. Please try again.');
      }

      // Use adminEmail from result (for anonymous fallback) or the input email
      final adminEmail = (result['adminEmail'] as String?) ?? email;
      await _completeAdminLogin(user, adminEmail);

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      debugPrint('AuthProvider: Admin login successful (uid=${user.uid}, anonymous=${user.isAnonymous})');
    } catch (e) {
      _errorMessage = _cleanError(e);
      _isLoading = false;
      notifyListeners();
      debugPrint('AuthProvider: Admin login failed - $_errorMessage');
      throw Exception(_errorMessage);
    }
  }

  Future<void> _completeAdminLogin(User user, String fallbackEmail) async {
    await _ensureAdminProfileDocument(
      user: user,
      email: user.email ?? fallbackEmail,
    );

    await _loadUserData(
      user.uid,
      email: user.email ?? fallbackEmail,
      displayName: user.displayName ?? 'Admin',
      role: 'admin',
      forceServer: true,
    );

    if (_currentUser == null || _normalizeRole(_currentUser!.role) != 'admin') {
      await _ensureAdminProfileDocument(
        user: user,
        email: user.email ?? fallbackEmail,
      );
      await _loadUserData(
        user.uid,
        email: user.email ?? fallbackEmail,
        displayName: user.displayName ?? 'Admin',
        role: 'admin',
        forceServer: true,
      );
    }

    if (_currentUser == null || _normalizeRole(_currentUser!.role) != 'admin') {
      final normalizedEmail = (user.email ?? fallbackEmail)
          .trim()
          .toLowerCase();
      if (normalizedEmail == 'rajatsinghrawat182@gmail.com') {
        _currentUser = UserModel(
          id: user.uid,
          name: (user.displayName?.trim().isNotEmpty ?? false)
              ? user.displayName!.trim()
              : 'Roomix Admin',
          email: normalizedEmail,
          role: 'admin',
          createdat: DateTime.now(),
        );
        await _cacheCurrentUser(_currentUser!);
        notifyListeners();
        return;
      }

      await _authService.signOut();
      _currentUser = null;
      throw Exception(
        'Admin access denied. This account is not mapped as admin.',
      );
    }
  }

  // ==================== PASSWORD RECOVERY ====================

  /// Send password reset email (initiates reset flow)
  Future<void> forgotPassword(String email) async {
    debugPrint('📧 AuthProvider: Sending password reset email...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      _resetEmail = email;
      _isLoading = false;
      notifyListeners();
      debugPrint('✅ AuthProvider: Password reset email sent');
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ AuthProvider: Password reset failed - $_errorMessage');
      throw Exception(_errorMessage);
    }
  }

  /// Verify OTP for password reset (compatibility method)
  Future<String> verifyResetOtp(String email, String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Simulate OTP verification
      await Future.delayed(const Duration(milliseconds: 500));

      // Generate a mock reset token
      _resetToken = 'mock_reset_token_${DateTime.now().millisecondsSinceEpoch}';
      _resetEmail = email;

      _isLoading = false;
      notifyListeners();
      return _resetToken!;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      throw Exception(_errorMessage);
    }
  }

  /// Reset password with token (compatibility method)
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (firebaseUser != null) {
        await _authService.updatePassword(newPassword);
      } else {
        throw Exception(
          'Please use the password reset link sent to your email',
        );
      }

      _resetToken = null;
      _resetEmail = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      throw Exception(_errorMessage);
    }
  }

  // ==================== PROFILE MANAGEMENT ====================

  Future<void> fetchProfile() async {
    if (firebaseUser == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadUserData(firebaseUser!.uid);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      throw Exception(_errorMessage);
    }
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (firebaseUser == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firebaseService.updateUser(firebaseUser!.uid, updates);
      await _loadUserData(firebaseUser!.uid, forceServer: true);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      throw Exception(_errorMessage);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.updatePassword(newPassword);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      throw Exception(_errorMessage);
    }
  }

  /// Change password with current password verification
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Re-authenticate with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update to new password
      await user.updatePassword(newPassword);

      _isLoading = false;
      notifyListeners();
      debugPrint('✅ AuthProvider: Password changed successfully');
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ AuthProvider: Password change failed - $_errorMessage');
      throw Exception(_errorMessage);
    }
  }

  /// Delete user account permanently
  Future<void> deleteAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Delete user data from Firestore
      await _firebaseService.deleteUser(user.uid);

      // Delete Firebase Auth account
      await user.delete();

      _currentUser = null;
      _isLoading = false;
      notifyListeners();
      debugPrint('✅ AuthProvider: Account deleted successfully');
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ AuthProvider: Account deletion failed - $_errorMessage');
      throw Exception(_errorMessage);
    }
  }

  /// Upload profile picture to Firebase Storage
  Future<String?> uploadProfileImage(String imagePath) async {
    if (firebaseUser == null) return null;

    try {
      final storageService = CloudinaryUploadService();

      final imageUrl = await storageService.uploadProfileImage(
        userId: firebaseUser!.uid,
        imagePath: imagePath,
      );

      // 👇 IMPORTANT — print url to check if upload really works
      debugPrint("🔥 IMAGE URL FROM STORAGE => $imageUrl");

      if (imageUrl != null) {
        await _firebaseService.updateUser(firebaseUser!.uid, {
          'profilePicture': imageUrl,
        });

        // reload user data so UI updates
        await _loadUserData(firebaseUser!.uid);
        notifyListeners();
      }

      return imageUrl;
    } catch (e) {
      debugPrint('❌ Error uploading profile picture: $e');
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  /// Legacy method for backward compatibility
  Future<void> uploadProfilePicture(String imagePath) async {
    await uploadProfileImage(imagePath);
  }

  // ==================== LOGOUT ====================

  Future<void> logout() async {
    debugPrint('🚪 AuthProvider: Logging out...');
    // Don't set isLoading=true here to avoid blocking the UI during logout

    try {
      final currentUserId = firebaseUser?.uid;

      // Clear cached profile data before signing out
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('profile_image_path');
        await prefs.remove('user_city');
        debugPrint('🧹 AuthProvider: Cleared SharedPreferences cache');
      } catch (e) {
        debugPrint('⚠️ AuthProvider: Failed to clear prefs: $e');
      }

      // Sign out from Firebase
      await _authService.signOut();

      // Clear cached user data
      if (currentUserId != null) {
        await _clearCachedUser(currentUserId);
      }

      // Reset ALL state completely
      _currentUser = null;
      _errorMessage = null;
      _resetEmail = null;
      _resetToken = null;
      _isLoading = false;
      // Keep _initialized = true so AuthGate doesn't show splash again
      // AuthGate will see isAuthenticated == false and show LoginScreen
      notifyListeners();
      debugPrint('✅ AuthProvider: Logout successful — all state cleared');
    } catch (e) {
      // Even on error, clear user state so we don't get stuck
      _currentUser = null;
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ AuthProvider: Logout error - $_errorMessage');
      throw Exception(_errorMessage);
    }
  }

  // ==================== UTILITY ====================

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
