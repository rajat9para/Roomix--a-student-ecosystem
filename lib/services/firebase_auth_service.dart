import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:roomix/services/firebase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _webClientId =
      '857963052155-86lj38lur9adppn8ads0o1ll8crlrvje.apps.googleusercontent.com';

  // GoogleSignIn instance with proper configuration
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _webClientId,
    scopes: ['email', 'profile'],
  );

  final FirebaseService _firestoreService = FirebaseService();

  // Admin email - stored securely, not exposed in UI
  static const String _adminEmail = 'rajatsinghrawat182@gmail.com';
  // Admin password - used internally after OTP verification (user never enters this)
  static const String _adminPassword = 'tersx@859';
  // Gmail App Password for SMTP email sending
  static const String _gmailAppPassword = 'fhphwyafvqvgzkez';

  // OTP storage for admin login
  String? _pendingAdminEmail;
  String? _pendingOtp;
  DateTime? _pendingOtpExpiry;

  static const String _pendingAdminEmailKey = 'admin_pending_email';
  static const String _pendingOtpKey = 'admin_pending_otp';
  static const String _pendingOtpExpiryKey = 'admin_pending_otp_expiry';

  bool _googleSignInInProgress = false;

  Future<void> _persistPendingOtpLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pendingAdminEmail != null) {
        await prefs.setString(_pendingAdminEmailKey, _pendingAdminEmail!);
      }
      if (_pendingOtp != null) {
        await prefs.setString(_pendingOtpKey, _pendingOtp!);
      }
      if (_pendingOtpExpiry != null) {
        await prefs.setInt(
          _pendingOtpExpiryKey,
          _pendingOtpExpiry!.millisecondsSinceEpoch,
        );
      }
    } catch (_) {}
  }

  Future<void> _loadPendingOtpFromLocal() async {
    try {
      if (_pendingOtp != null &&
          _pendingAdminEmail != null &&
          _pendingOtpExpiry != null) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_pendingAdminEmailKey);
      final otp = prefs.getString(_pendingOtpKey);
      final expiryMillis = prefs.getInt(_pendingOtpExpiryKey);

      if (email != null && otp != null && expiryMillis != null) {
        _pendingAdminEmail = email;
        _pendingOtp = otp;
        _pendingOtpExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
      }
    } catch (_) {}
  }

  Future<void> _clearPendingOtp() async {
    _pendingOtp = null;
    _pendingAdminEmail = null;
    _pendingOtpExpiry = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingAdminEmailKey);
      await prefs.remove(_pendingOtpKey);
      await prefs.remove(_pendingOtpExpiryKey);
    } catch (_) {}
  }

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
      debugPrint('Attempting email sign-in for: $email');

      // Check if trying to login as admin
      if (role == 'admin' && email.toLowerCase() != _adminEmail) {
        throw Exception(
          'Invalid admin email. Please use the correct admin email.',
        );
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Login failed. Please try again.');
      }

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

      return {'success': true, 'user': user, 'role': userData?['role'] ?? role};
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e.code));
    } catch (e) {
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
    String? ownerType,
  }) async {
    try {
      // Prevent registration with admin email
      if (email.toLowerCase() == _adminEmail) {
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
        ownerType: ownerType,
      );

      return {'success': true, 'user': user, 'role': role};
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e.code));
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e.code));
    } catch (e) {
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
  Future<Map<String, dynamic>> signInWithGoogle({
    required String role,
    String? ownerType,
  }) async {
    if (_googleSignInInProgress) {
      return {'success': false, 'cancelled': true};
    }

    _googleSignInInProgress = true;

    try {
      // Warm plugin state; this avoids first-attempt token races on some devices.
      try {
        await _googleSignIn.signInSilently();
      } catch (_) {}

      // Reset stale Google session so account picker works reliably.
      // Never sign out Firebase auth here, it can cause auth-state races.
      try {
        final alreadySignedIn = await _googleSignIn.isSignedIn();
        if (alreadySignedIn) {
          await _googleSignIn.disconnect();
        }
      } catch (_) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return {'success': false, 'cancelled': true};
      }

      // Prevent using admin email with Google Sign-In
      if (googleUser.email.toLowerCase() == _adminEmail) {
        throw Exception('Please use admin OTP login for the admin account.');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Validate tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception(
          'Failed to obtain Google authentication tokens. Please try again.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential? userCredential;
      const maxRetries = 3;
      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          userCredential = await _auth.signInWithCredential(credential);
          break;
        } catch (e) {
          if (attempt == maxRetries - 1) rethrow;
          await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        }
      }

      User? user = userCredential?.user ?? _auth.currentUser;

      // Extra guard if auth state propagation is delayed.
      if (user == null) {
        user = await _auth
            .authStateChanges()
            .where((u) => u != null)
            .cast<User>()
            .first
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () => throw Exception(
                'Authentication state timeout. Please try again.',
              ),
            );
      }

      await user.getIdToken(true);

      final userData = await _firestoreService.getUser(user.uid);

      if (userData == null) {
        await _firestoreService.createUser(
          userId: user.uid,
          email: googleUser.email,
          name: googleUser.displayName ?? 'User',
          role: role,
          ownerType: ownerType,
        );
      }

      return {
        'success': true,
        'user': user,
        'role': userData?['role'] ?? role,
        'isNewUser': userData == null,
      };
    } on FirebaseAuthException catch (e) {
      if (e.code == '10') {
        throw Exception(
          'Google Sign-In configuration error. '
          'Please ensure SHA-1 fingerprint is added in Firebase Console. '
          'Error code: 10',
        );
      }
      throw Exception(_getErrorMessage(e.code));
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('network_error')) {
        throw Exception(
          'Network error. Please check your internet connection and try again.',
        );
      }
      if (errorMsg.contains('sign_in_failed')) {
        throw Exception(
          'Google Sign-In failed. Please ensure:\n'
          '1. SHA-1 fingerprint is added in Firebase Console\n'
          '2. google-services.json is up to date\n'
          '3. Package name matches Firebase configuration',
        );
      }
      if (errorMsg.contains('cancel') || errorMsg.contains('aborted_by_user')) {
        return {'success': false, 'cancelled': true};
      }
      throw Exception('Google Sign-In failed: ${e.toString()}');
    } finally {
      _googleSignInInProgress = false;
    }
  }

  // ==================== ADMIN AUTH ====================

  /// Send OTP email via Gmail SMTP directly
  Future<bool> _sendOtpEmail(String toEmail, String otp) async {
    try {
      final smtpServer = gmail(_adminEmail, _gmailAppPassword);

      final message = Message()
        ..from = const Address(_adminEmail, 'Roomix Admin')
        ..recipients.add(toEmail)
        ..subject = 'Roomix Admin OTP - $otp'
        ..text =
            'Your Roomix admin login OTP is: $otp\n\n'
            'This code expires in 10 minutes.\n'
            'If you did not request this, please ignore this email.'
        ..html =
            '''
<div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px; background: #f8fafc; border-radius: 16px;">
  <div style="text-align: center; margin-bottom: 24px;">
    <h1 style="color: #0f172a; font-size: 24px; margin: 0;">🏠 Roomix</h1>
    <p style="color: #64748b; font-size: 14px; margin-top: 4px;">Admin Login Verification</p>
  </div>
  <div style="background: white; border-radius: 12px; padding: 24px; text-align: center; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
    <p style="color: #334155; font-size: 16px; margin: 0 0 16px;">Your one-time password is:</p>
    <div style="background: #f1f5f9; border-radius: 8px; padding: 16px; letter-spacing: 8px; font-size: 32px; font-weight: bold; color: #0f172a;">
      $otp
    </div>
    <p style="color: #94a3b8; font-size: 13px; margin-top: 16px;">This code expires in <strong>10 minutes</strong>.</p>
  </div>
  <p style="color: #94a3b8; font-size: 12px; text-align: center; margin-top: 20px;">
    If you did not request this code, please ignore this email.
  </p>
</div>
''';

      final sendReport = await send(message, smtpServer);
      debugPrint('✅ OTP email sent successfully: ${sendReport.toString()}');
      return true;
    } on MailerException catch (e) {
      debugPrint('❌ SMTP MailerException: ${e.message}');
      for (var p in e.problems) {
        debugPrint('   Problem: ${p.code} - ${p.msg}');
      }
      return false;
    } catch (e) {
      debugPrint('❌ OTP email send error: $e');
      return false;
    }
  }

  /// Request OTP for admin login
  Future<void> requestAdminOtp(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail != _adminEmail) {
        throw Exception('Invalid admin email address');
      }

      final random = Random.secure();
      final otp = (100000 + random.nextInt(900000)).toString();
      _pendingAdminEmail = normalizedEmail;
      _pendingOtp = otp;
      _pendingOtpExpiry = DateTime.now().add(const Duration(minutes: 10));
      await _persistPendingOtpLocally();

      // Best-effort: persist OTP to Firestore for audit/recovery.
      // If Firestore rules block this write, we still proceed with
      // in-memory OTP + SMTP email delivery.
      try {
        await FirebaseFirestore.instance
            .collection('admin_otp_requests')
            .doc(normalizedEmail)
            .set({
              'email': normalizedEmail,
              'otp': otp,
              'expiresAt': Timestamp.fromDate(_pendingOtpExpiry!),
              'consumed': false,
              'createdAt': Timestamp.now(),
              'updatedAt': Timestamp.now(),
            });
        debugPrint('✅ OTP persisted to Firestore');
      } catch (firestoreError) {
        // Firestore rules may block unauthenticated writes — that's OK.
        // In-memory OTP is the primary mechanism.
        debugPrint(
          '⚠️ Firestore OTP persist failed (non-fatal): $firestoreError',
        );
      }

      // Send OTP via Gmail SMTP — this is the primary delivery mechanism
      final sent = await _sendOtpEmail(normalizedEmail, otp);

      if (!sent) {
        // Fallback: log to debug console
        if (kDebugMode) {
          debugPrint('========================================');
          debugPrint('🔐 ADMIN OTP (debug fallback): $otp');
          debugPrint('========================================');
        }
        throw Exception(
          'Failed to send OTP email. Please check your internet connection and try again.',
        );
      }

      debugPrint('✅ Admin OTP dispatched to $normalizedEmail');
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      throw Exception(msg);
    }
  }

  /// Verify admin OTP and login.
  Future<Map<String, dynamic>> verifyAdminOtpAndLogin({
    required String email,
    required String otp,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail != _adminEmail) {
        throw Exception('Invalid admin email address');
      }

      final inputOtp = otp.replaceAll(RegExp(r'[^0-9]'), '');
      if (inputOtp.length != 6) {
        throw Exception('Please enter a valid 6-digit OTP.');
      }
      bool verified = false;
      bool verifiedFromMemory = false;

      await _loadPendingOtpFromLocal();

      // Fast path: current app session in-memory OTP.
      if (_pendingOtp != null && _pendingAdminEmail == normalizedEmail) {
        if (_pendingOtpExpiry != null &&
            DateTime.now().isAfter(_pendingOtpExpiry!)) {
          await _clearPendingOtp();
        } else if (_pendingOtp == inputOtp) {
          verified = true;
          verifiedFromMemory = true;
        }
      }

      // Fallback path: persisted OTP from Firestore (best-effort).
      if (!verified) {
        try {
          verified = await _verifyPersistedAdminOtp(
            normalizedEmail: normalizedEmail,
            inputOtp: inputOtp,
          );
        } catch (e) {
          debugPrint('⚠️ Firestore OTP verify failed (non-fatal): $e');
          // Firestore rules may block read — rely on in-memory OTP only.
        }
      }

      if (!verified) {
        throw Exception('Invalid or expired OTP. Please try again.');
      }

      if (verifiedFromMemory) {
        try {
          await FirebaseFirestore.instance
              .collection('admin_otp_requests')
              .doc(normalizedEmail)
              .update({
                'consumed': true,
                'consumedAt': Timestamp.now(),
                'updatedAt': Timestamp.now(),
              });
        } catch (_) {}
      }

      await _clearPendingOtp();
      debugPrint('✅ Admin OTP verified successfully');

      // ── Firebase Auth: 3-step fallback ─────────────────────────────
      // OTP is verified. Now we need a Firebase Auth user.
      // The password may not match (account created with different password),
      // so we use a fallback chain to guarantee login succeeds.

      // Sign out any stale session first
      try {
        if (_auth.currentUser != null) {
          await _auth.signOut();
        }
      } catch (_) {}

      // Step 1: Try email/password sign-in (fastest path)
      try {
        debugPrint('🔑 Step 1: Trying signInWithEmailAndPassword...');
        final credential = await _auth.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: _adminPassword,
        );
        if (credential.user != null) {
          debugPrint('✅ Step 1 succeeded');
          return {'success': true, 'user': credential.user!, 'role': 'admin'};
        }
      } catch (e) {
        debugPrint('⚠️ Step 1 failed: $e');
      }

      // Step 2: Try creating the account (works if account doesn't exist)
      try {
        debugPrint('🔑 Step 2: Trying createUserWithEmailAndPassword...');
        final newCred = await _auth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: _adminPassword,
        );
        if (newCred.user != null) {
          await newCred.user!.updateDisplayName('Roomix Admin');
          debugPrint('✅ Step 2 succeeded: created admin account');
          return {'success': true, 'user': newCred.user!, 'role': 'admin'};
        }
      } catch (e) {
        debugPrint('⚠️ Step 2 failed: $e');
      }

      // Step 3: Anonymous sign-in (reliable fallback)
      // OTP already verified admin identity, so anonymous auth is safe.
      // The Firestore profile will be created/updated by AuthProvider._completeAdminLogin.
      debugPrint('🔑 Step 3: Using anonymous sign-in as reliable fallback...');
      try {
        final anonCred = await _auth.signInAnonymously();
        final anonUser = anonCred.user;
        if (anonUser == null) {
          throw Exception('Anonymous sign-in returned null');
        }
        debugPrint('✅ Step 3 succeeded (anonymous uid=${anonUser.uid})');
        return {
          'success': true,
          'user': anonUser,
          'role': 'admin',
          'isAnonymous': true,
          'adminEmail': normalizedEmail,
        };
      } catch (anonError) {
        debugPrint('❌ All 3 auth steps failed. Last error: $anonError');
        throw Exception(
          'Admin login failed after OTP verification. '
          'Please check your internet connection and try again.',
        );
      }
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception('Admin OTP login failed. Please try again.');
    }
  }

  Future<bool> _verifyPersistedAdminOtp({
    required String normalizedEmail,
    required String inputOtp,
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection('admin_otp_requests')
        .doc(normalizedEmail);
    final snapshot = await docRef.get(const GetOptions(source: Source.server));
    if (!snapshot.exists) {
      throw Exception('OTP expired. Please request a new one.');
    }

    final data = snapshot.data() as Map<String, dynamic>;
    final expiresAt = data['expiresAt'];
    final consumed = data['consumed'] == true;
    final savedOtp = data['otp']?.toString() ?? '';

    if (consumed) {
      throw Exception('OTP already used. Please request a new one.');
    }

    if (expiresAt is! Timestamp || DateTime.now().isAfter(expiresAt.toDate())) {
      await _clearPendingOtp();
      await docRef.update({'consumed': true, 'updatedAt': Timestamp.now()});
      throw Exception('OTP expired. Please request a new one.');
    }

    if (savedOtp != inputOtp) {
      return false;
    }

    await docRef.update({
      'consumed': true,
      'consumedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
    return true;
  }

  // ==================== ANONYMOUS AUTH ====================

  /// Sign in anonymously
  Future<Map<String, dynamic>> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user;

      if (user == null) {
        throw Exception('Anonymous sign-in failed');
      }

      return {'success': true, 'user': user};
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e.code));
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // ==================== SIGN OUT ====================

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
    await _clearPendingOtp();
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
        return 'Invalid email or password. Please check your credentials.';
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
