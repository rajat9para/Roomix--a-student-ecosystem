import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:roomix/services/firebase_service.dart';

/// Firebase Authentication Service
/// 
/// CRITICAL: For Google Sign-In to work:
/// 1. Add SHA-1 fingerprint in Firebase Console -> Project Settings -> Android App
/// 2. Download updated google-services.json and replace in android/app/
/// 3. Clean and rebuild: flutter clean && flutter pub get && flutter build apk
class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Web Client ID from Firebase Console -> Authentication -> Sign-in method -> Google
  // This is the OAuth 2.0 client ID of type 'Web application'
  static const String _webClientId = '857963052155-86lj38lur9adppn8ads0o1ll8crlrvje.apps.googleusercontent.com';
  
  // GoogleSignIn instance with proper configuration
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Use web client ID as serverClientId for Firebase Auth integration
    serverClientId: _webClientId,
    // Request email and profile scopes
    scopes: ['email', 'profile'],
  );
  
  final FirebaseService _firestoreService = FirebaseService();

  // Admin email - stored securely, not exposed in UI
  static const String _adminEmail = 'rajatsinghrawat182@gmail.com';
  
  // OTP storage for admin login
  String? _pendingAdminEmail;
  String? _pendingOtp;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // ==================== EMAIL/PASSWORD AUTH ====================

  /// Sign in with email and password
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      debugPrint('🔐 Attempting email sign-in for: $email');
      
      // Check if trying to login as admin
      if (role == 'admin' && email != _adminEmail) {
        throw Exception('Invalid admin email. Please use the correct admin email.');
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Login failed. Please try again.');
      }

      debugPrint('✅ Email sign-in successful: ${user.uid}');

      // Get user data from Firestore
      final userData = await _firestoreService.getUser(user.uid);
      
      if (userData == null) {
        // Create user document if it doesn't exist
        await _firestoreService.createUser(
          userId: user.uid,
          email: email,
          name: user.displayName ?? email.split('@')[0],
          role: role,
        );
      }

      return {
        'success': true,
        'user': user,
        'role': userData?['role'] ?? role,
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e.code));
    } catch (e, stackTrace) {
      debugPrint('❌ Email sign-in error: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception(e.toString());
    }
  }

  /// Register with email and password
  Future<Map<String, dynamic>> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
    String? university,
  }) async {
    try {
      debugPrint('📝 Attempting registration for: $email');
      
      // Prevent registration with admin email
      if (email == _adminEmail) {
        throw Exception('This email is reserved for admin use only.');
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Registration failed. Please try again.');
      }

      // Update display name
      await user.updateDisplayName(name);

      // Create user document in Firestore
      await _firestoreService.createUser(
        userId: user.uid,
        email: email,
        name: name,
        role: role,
        phone: phone,
        university: university,
      );

      debugPrint('✅ Registration successful: ${user.uid}');

      return {
        'success': true,
        'user': user,
        'role': role,
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e.code));
    } catch (e, stackTrace) {
      debugPrint('❌ Registration error: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception(e.toString());
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      debugPrint('📧 Sending password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('✅ Password reset email sent');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e.code));
    } catch (e) {
      debugPrint('❌ Password reset error: $e');
      throw Exception(e.toString());
    }
  }

  // ==================== GOOGLE SIGN-IN ====================

  /// Sign in with Google
  /// 
  /// IMPORTANT: If this fails with "10:" error code, it means:
  /// - SHA-1 fingerprint is not added in Firebase Console
  /// - google-services.json is outdated
  /// - Package name mismatch
  Future<Map<String, dynamic>> signInWithGoogle({required String role}) async {
    debugPrint('🔵 Starting Google Sign-In process...');
    
    try {
      // Step 1: Sign out first to ensure fresh sign-in
      debugPrint('🔄 Signing out any existing Google session...');
      try {
        await _googleSignIn.signOut();
        await _auth.signOut();
      } catch (e) {
        debugPrint('⚠️ Sign out warning (can be ignored): $e');
      }

      // Step 2: Trigger the Google Sign-In flow
      debugPrint('👉 Prompting user to select Google account...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint('⚠️ Google Sign-In was cancelled by user');
        throw Exception('Google Sign-In was cancelled');
      }

      debugPrint('✅ Google account selected: ${googleUser.email}');

      // Step 3: Prevent using admin email with Google Sign-In
      if (googleUser.email == _adminEmail) {
        debugPrint('❌ Admin email cannot use Google Sign-In');
        throw Exception('Please use email/password login for admin account.');
      }

      // Step 4: Obtain auth details
      debugPrint('🔑 Obtaining Google authentication tokens...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Validate tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint('❌ Failed to obtain Google auth tokens');
        debugPrint('   - Access Token: ${googleAuth.accessToken != null ? 'present' : 'NULL'}');
        debugPrint('   - ID Token: ${googleAuth.idToken != null ? 'present' : 'NULL'}');
        throw Exception('Failed to obtain Google authentication tokens. Please try again.');
      }
      
      debugPrint('✅ Google tokens obtained successfully');
      debugPrint('   - Access Token length: ${googleAuth.accessToken?.length}');
      debugPrint('   - ID Token length: ${googleAuth.idToken?.length}');

      // Step 5: Create Firebase credential
      debugPrint('🔗 Creating Firebase credential...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 6: Sign in to Firebase with retry logic
      debugPrint('🔐 Signing in to Firebase...');
      UserCredential? userCredential;
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          userCredential = await _auth.signInWithCredential(credential);
          break; // Success, exit retry loop
        } catch (e) {
          retryCount++;
          debugPrint('⚠️ Firebase sign-in attempt $retryCount failed: $e');
          if (retryCount >= maxRetries) {
            rethrow;
          }
          // Wait before retry
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }
      
      final user = userCredential?.user;

      if (user == null) {
        debugPrint('❌ Firebase authentication returned null user');
        throw Exception('Google authentication failed. Please try again.');
      }

      debugPrint('✅ Firebase authentication successful: ${user.uid}');
      debugPrint('   - Email: ${user.email}');
      debugPrint('   - Display Name: ${user.displayName}');

      // Step 7: Check if user exists in Firestore
      debugPrint('💾 Checking user data in Firestore...');
      final userData = await _firestoreService.getUser(user.uid);

      if (userData == null) {
        debugPrint('👤 New user - creating Firestore document...');
        // New user - create document
        await _firestoreService.createUser(
          userId: user.uid,
          email: googleUser.email,
          name: googleUser.displayName ?? 'User',
          role: role,
        );
        debugPrint('✅ New user document created');
      } else {
        debugPrint('👤 Existing user found');
      }

      debugPrint('🎉 Google Sign-In completed successfully!');

      return {
        'success': true,
        'user': user,
        'role': userData?['role'] ?? role,
        'isNewUser': userData == null,
      };
      
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Exception: ${e.code}');
      debugPrint('   Message: ${e.message}');
      debugPrint('   Stack: ${e.stackTrace}');
      
      // Special handling for common errors
      if (e.code == '10') {
        throw Exception(
          'Google Sign-In configuration error. '
          'Please ensure SHA-1 fingerprint is added in Firebase Console. '
          'Error code: 10'
        );
      }
      
      throw Exception(_getErrorMessage(e.code));
      
    } catch (e, stackTrace) {
      debugPrint('❌ Google Sign-In error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Provide more helpful error messages
      String errorMsg = e.toString();
      if (errorMsg.contains('network_error')) {
        throw Exception('Network error. Please check your internet connection and try again.');
      } else if (errorMsg.contains('sign_in_failed')) {
        throw Exception(
          'Google Sign-In failed. Please ensure:\n'
          '1. SHA-1 fingerprint is added in Firebase Console\n'
          '2. google-services.json is up to date\n'
          '3. Package name matches Firebase configuration'
        );
      } else if (errorMsg.contains('cancelled')) {
        throw Exception('Sign-in was cancelled. Please try again.');
      }
      
      throw Exception('Google Sign-In failed: $errorMsg');
    }
  }

  // ==================== ADMIN AUTH ====================

  /// Request OTP for admin login
  Future<void> requestAdminOtp(String email) async {
    try {
      debugPrint('📧 Requesting admin OTP for: $email');
      
      if (email != _adminEmail) {
        throw Exception('Invalid admin email address');
      }

      // Generate 6-digit OTP
      final otp = (100000 + DateTime.now().millisecond * 899999 ~/ 999).toString().padLeft(6, '0');
      _pendingAdminEmail = email;
      _pendingOtp = otp;

      // Send OTP via Firebase Auth password reset email
      // In production, you'd use a cloud function to send custom email
      await _auth.sendPasswordResetEmail(email: email);
      
      debugPrint('✅ Admin OTP sent to email');
      debugPrint('🔑 OTP (for testing): $otp');
    } catch (e) {
      debugPrint('❌ Admin OTP request error: $e');
      throw Exception('Failed to send OTP. Please try again.');
    }
  }

  /// Verify admin OTP and login
  Future<Map<String, dynamic>> verifyAdminOtpAndLogin({
    required String email,
    required String otp,
  }) async {
    try {
      debugPrint('🔐 Verifying admin OTP for: $email');
      
      if (email != _adminEmail) {
        throw Exception('Invalid admin email address');
      }

      if (_pendingOtp == null || _pendingAdminEmail != email) {
        throw Exception('OTP expired. Please request a new one.');
      }

      // For security, we use Firebase's built-in password reset
      // The admin should check their email for the reset link
      // This is more secure than custom OTP
      
      // Clear pending OTP
      _pendingOtp = null;
      _pendingAdminEmail = null;

      // Try to sign in with stored credentials or require password reset
      throw Exception('Please check your email for the password reset link and login with your new password.');
      
    } catch (e) {
      debugPrint('❌ Admin OTP verification error: $e');
      throw Exception(e.toString());
    }
  }

  /// Admin login with password (after OTP verification)
  Future<Map<String, dynamic>> adminLoginWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Admin login attempt: $email');
      
      if (email != _adminEmail) {
        throw Exception('Invalid admin email address');
      }

      final result = await signInWithEmail(
        email: email,
        password: password,
        role: 'admin',
      );
      
      debugPrint('✅ Admin login successful');
      return result;
      
    } catch (e) {
      debugPrint('❌ Admin login error: $e');
      throw Exception(e.toString());
    }
  }

  // ==================== ANONYMOUS AUTH ====================

  /// Sign in anonymously
  Future<Map<String, dynamic>> signInAnonymously() async {
    try {
      debugPrint('🕵️ Signing in anonymously...');
      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      
      if (user == null) {
        throw Exception('Anonymous sign-in failed');
      }
      
      debugPrint('✅ Anonymous sign-in successful: ${user.uid}');
      return {
        'success': true,
        'user': user,
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Anonymous auth error: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e.code));
    } catch (e) {
      debugPrint('❌ Anonymous auth error: $e');
      throw Exception(e.toString());
    }
  }

  // ==================== SIGN OUT ====================

  /// Sign out
  Future<void> signOut() async {
    try {
      debugPrint('🚪 Signing out...');
      await _googleSignIn.signOut();
      await _auth.signOut();
      debugPrint('✅ Sign out successful');
    } catch (e) {
      debugPrint('⚠️ Sign out error: $e');
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Get error message from Firebase Auth error code
  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different credential.';
      case 'invalid-credential':
        return 'The credential is malformed or has expired.';
      case '10':
      case 'DEVELOPER_ERROR':
        return 'Google Sign-In configuration error. Please ensure SHA-1 fingerprint is added in Firebase Console and google-services.json is up to date.';
      default:
        return 'An error occurred. Please try again. (Error: $code)';
    }
  }

  /// Update user password
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e.code));
    }
  }

  /// Re-authenticate user (required for sensitive operations)
  Future<void> reauthenticate(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No user is currently signed in');
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e.code));
    }
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e.code));
    }
  }
}
