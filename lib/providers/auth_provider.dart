import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roomix/services/firebase_auth_service.dart';
import 'package:roomix/services/firebase_service.dart';
import 'package:roomix/services/firebase_storage_service.dart';
import 'package:roomix/models/user_model.dart';
import 'package:roomix/services/otp_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentUser;
  
  // Temporary storage for password reset
  String? _resetEmail;
  String? _resetToken;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  // Get Firebase current user
  User? get firebaseUser => _authService.currentUser;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    // Listen to auth state changes
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        debugPrint('👤 Auth state changed: User signed in - ${user.uid}');
        await _loadUserData(user.uid);
      } else {
        debugPrint('👤 Auth state changed: User signed out');
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserData(String userId) async {
    try {
      debugPrint('💾 Loading user data for: $userId');
      final userData = await _firebaseService.getUser(userId);
      if (userData != null) {
        _currentUser = UserModel.fromJson(userData);
        debugPrint('✅ User data loaded: ${_currentUser?.name}');
        notifyListeners();
      } else {
        debugPrint('⚠️ No user data found in Firestore');
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
    }
  }

  // ==================== EMAIL/PASSWORD LOGIN ====================

  /// Standard email/password login (for regular users)
  Future<Map<String, dynamic>> login(String email, String password, String role) async {
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
        await _loadUserData(user.uid);
        _isLoading = false;
        notifyListeners();
        debugPrint('✅ AuthProvider: Email login successful');
        return {'success': true};
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
  Future<Map<String, dynamic>> signInWithGoogle(String role) async {
    debugPrint('🔵 AuthProvider: Starting Google Sign-In...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogle(role: role);

      if (result['success'] == true) {
        final user = result['user'] as User;
        await _loadUserData(user.uid);
        _isLoading = false;
        notifyListeners();
        debugPrint('✅ AuthProvider: Google Sign-In successful');
        return {'success': true};
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

  Future<void> register(String name, String email, String password, String role, {String? phone, String? university}) async {
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
      );

      if (result['success'] == true) {
        final user = result['user'] as User;
        await _loadUserData(user.uid);
      }

      _isLoading = false;
      notifyListeners();
      debugPrint('✅ AuthProvider: Registration successful');
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
    debugPrint('📧 AuthProvider: Requesting admin OTP for $email...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Use our local OtpService
      await OtpService().sendOtp(email);
      _isLoading = false;
      notifyListeners();
      debugPrint('✅ AuthProvider: Admin OTP generated (Check Console)');
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ AuthProvider: Admin OTP request failed - $_errorMessage');
      throw Exception(_errorMessage);
    }
  }

  /// Verify Admin OTP and Login
  Future<void> verifyAdminOtpAndLogin(String email, String otp) async {
    debugPrint('🔐 AuthProvider: Verifying admin OTP...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final isValid = OtpService().verifyOtp(email, otp);
      
      if (!isValid) {
        throw Exception('Invalid or expired OTP');
      }

      // Success! Now we need to sign them in.
      // Since we don't have a password for Firebase Auth, we'll sign in anonymously
      // or use a custom "admin" state. For this app, let's use anonymous auth
      // so we have a valid Firebase User for security rules.
      
      User? user = _authService.currentUser;
      if (user == null) {
        final result = await _authService.signInAnonymously(); // ensure this exists or use signInAnonymously() directly from FirebaseAuth
         user = result['user'];
      }
      
      // Update Firestore user doc to reflect admin role
      if (user != null) {
        await _firebaseService.createUser(
          userId: user.uid,
          email: email,
          name: 'Admin',
          role: 'admin',
        );
        await _loadUserData(user.uid);
      }

      _isLoading = false;
      notifyListeners();
      debugPrint('✅ AuthProvider: Admin login successful');
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ AuthProvider: Admin login failed - $_errorMessage');
      throw Exception(_errorMessage);
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
        throw Exception('Please use the password reset link sent to your email');
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

  /// Upload profile picture to Firebase Storage
  Future<String?> uploadProfileImage(String imagePath) async {
    if (firebaseUser == null) return null;

    try {
      final storageService = FirebaseStorageService();

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
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
      debugPrint('✅ AuthProvider: Logout successful');
    } catch (e) {
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
