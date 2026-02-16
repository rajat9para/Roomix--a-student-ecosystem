import 'dart:math';
import 'package:flutter/foundation.dart';

class OtpService {
  static final OtpService _instance = OtpService._internal();
  factory OtpService() => _instance;
  OtpService._internal();

  // Store OTPs temporarily in memory: {email: {otp: "123456", expiry: DateTime}}
  final Map<String, Map<String, dynamic>> _otpStore = {};
  
  // Admin email to validate against
  static const String _adminEmail = 'rajatsinghrawat182@gmail.com';

  String? get adminEmail => _adminEmail;

  /// Generate and "send" OTP
  Future<bool> sendOtp(String email) async {
    // 1. Validate email
    if (email.trim() != _adminEmail) {
      throw Exception('Access denied. $email is not an authorized admin email.');
    }

    // 2. Generate 6-digit OTP
    final otp = _generateOtpCode();
    
    // 3. Store OTP with expiry (10 minutes)
    _otpStore[email] = {
      'otp': otp,
      'expiry': DateTime.now().add(const Duration(minutes: 10)),
    };

    // 4. "Send" the OTP
    // In a real app with SMTP credentials, we would use the 'mailer' package here.
    // For now, we log it to the console as requested/implied fall-back.
    debugPrint('==================================================');
    debugPrint('🔐 ADMIN OTP GENERATED');
    debugPrint('📧 To: $email');
    debugPrint('🔑 Code: $otp');
    debugPrint('==================================================');

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    return true;
  }

  /// Verify the provided OTP
  bool verifyOtp(String email, String otp) {
    if (email.trim() != _adminEmail) return false;

    final storedData = _otpStore[email];
    if (storedData == null) return false;

    final storedOtp = storedData['otp'];
    final expiry = storedData['expiry'] as DateTime;

    if (DateTime.now().isAfter(expiry)) {
      _otpStore.remove(email); // Expired
      return false;
    }

    if (storedOtp == otp) {
      _otpStore.remove(email); // Consumed
      return true;
    }

    return false;
  }

  String _generateOtpCode() {
    final random = Random();
    // Generate a number between 100000 and 999999
    return (100000 + random.nextInt(900000)).toString();
  }
}
