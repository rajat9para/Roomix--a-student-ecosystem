import 'package:flutter/material.dart';

/// Professional Theme Colors - Based on Stitch Design System
/// Primary: #0a66c2 (Professional Blue)
/// Background Light: #f5f7f8
/// Background Dark: #101922
class AppColors {
  // Primary Colors - Professional Blue
  static const Color primary = Color(0xFF0a66c2);
  static const Color primaryColor = Color(0xFF0a66c2);
  static const Color primaryDark = Color(0xFF0850a0);
  static const Color primaryLight = Color(0xFFE8F3FC);
  static const Color primaryAccent = Color(0xFF0e63be); // Added for utility screens
  
  // Secondary Colors
  static const Color secondary = Color(0xFF10B981); // Success Green
  static const Color accent = Color(0xFFF59E0B); // Warning Orange
  static const Color tertiary = Color(0xFFEC4899); // Pink accent
  
  // Text Colors
  static const Color textDark = Color(0xFF111418);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF60758a);
  static const Color textSubtle = Color(0xFF9CA3AF);
  static const Color textPrimary = Color(0xFF111418);
  
  // Background Colors - Light Theme (Default)
  static const Color background = Color(0xFFf5f7f8);
  static const Color backgroundLight = Color(0xFFf5f7f8);
  static const Color backgroundDark = Color(0xFF101922);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color scaffoldBackground = Color(0xFFf5f7f8);
  
  // Dark Mode Backgrounds
  static const Color darkBackground = Color(0xFF101922);
  static const Color darkSurface = Color(0xFF1c2a38);
  
  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color info = Color(0xFF0a66c2);
  
  // Border Colors
  static const Color border = Color(0xFFdbe0e6);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color shadow = Color(0x1A000000);
  
  // Role Colors
  static const Color student = Color(0xFF0a66c2);
  static const Color owner = Color(0xFF10B981);
  static const Color admin = Color(0xFFF59E0B);

  // Rating Color
  static const Color starColor = Color(0xFFFFB800);

  // Gradient Presets
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0a66c2), Color(0xFF0850a0)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white, Color(0xFFf8fafc)],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFf5f7f8), Color(0xFFe8ecf1)],
  );

  // Legacy gradients for backward compatibility (Splash Screen, etc.)
  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFF59E0B), Color(0xFFEC4899)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFEC4899)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
  );

  // Card Decoration - Light Theme
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: const Color(0xFF0a66c2).withOpacity(0.08),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // Input Decoration
  static BoxDecoration get inputDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: const Color(0xFFdbe0e6),
      width: 1.5,
    ),
  );

  // Primary Button Decoration
  static BoxDecoration get primaryButtonDecoration => BoxDecoration(
    color: const Color(0xFF0a66c2),
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF0a66c2).withOpacity(0.3),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // Glass Effect for Dark Mode
  static BoxDecoration get glassDarkDecoration => BoxDecoration(
    color: const Color(0xFF1c2a38),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Colors.white.withOpacity(0.1),
      width: 1,
    ),
  );
}
