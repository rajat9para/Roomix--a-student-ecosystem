import 'package:flutter/material.dart';

/// Professional Theme Colors — 60/30/10 Rule
/// Primary Blue (60%): Headers, buttons, highlights, active states
/// White/Light (30%): Backgrounds, cards, clean spacing
/// Accent Orange (10%): CTA buttons, back buttons, alerts, highlights
class AppColors {
  // ── Primary (60%) — Professional Blue ────────────────────────
  static const Color primary = Color(0xFF0A66C2);
  static const Color primaryColor = Color(0xFF0A66C2);
  static const Color primaryDark = Color(0xFF084E96);
  static const Color primaryLight = Color(0xFFE3F0FC);
  static const Color primaryAccent = Color(0xFF0E63BE);
  static const Color primarySurface = Color(0xFFF0F6FE); // subtle blue tint for surfaces

  // ── Accent (10%) — CTA Orange ────────────────────────────────
  static const Color accent = Color(0xFFFF6B35);
  static const Color accentLight = Color(0xFFFFF0E8);
  static const Color accentDark = Color(0xFFE55A2B);

  // ── Secondary Colors ─────────────────────────────────────────
  static const Color secondary = Color(0xFF10B981);
  static const Color tertiary = Color(0xFFEC4899);

  // ── Text Colors ──────────────────────────────────────────────
  static const Color textDark = Color(0xFF111418);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF60758A);
  static const Color textSubtle = Color(0xFF9CA3AF);
  static const Color textPrimary = Color(0xFF111418);

  // ── Background Colors — Light Theme (30% white) ──────────────
  static const Color background = Color(0xFFF0F4FA); // soft blue-tinted background
  static const Color backgroundLight = Color(0xFFF5F7F8);
  static const Color backgroundDark = Color(0xFF101922);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color scaffoldBackground = Color(0xFFF0F4FA);
  static const Color surfaceBlue = Color(0xFFE8F0FE); // blue-tinted surface

  // Dark Mode Backgrounds (unused — light only)
  static const Color darkBackground = Color(0xFF101922);
  static const Color darkSurface = Color(0xFF1C2A38);

  // ── Status Colors ────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color info = Color(0xFF0A66C2);

  // ── Border Colors ────────────────────────────────────────────
  static const Color border = Color(0xFFD2DCEA);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color shadow = Color(0x1A000000);

  // ── Role Colors ──────────────────────────────────────────────
  static const Color student = Color(0xFF0A66C2);
  static const Color owner = Color(0xFF10B981);
  static const Color admin = Color(0xFFF59E0B);

  // ── Rating ───────────────────────────────────────────────────
  static const Color starColor = Color(0xFFFFB800);

  // ── Gradient Presets ─────────────────────────────────────────

  /// Main header / app bar gradient — deep blue to medium blue
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A66C2), Color(0xFF1A8CFF)],
  );

  /// Primary gradient blue → lighter blue (buttons, highlights)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A66C2), Color(0xFF3B9AFF)],
  );

  /// Accent gradient for CTA buttons — orange tones
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B35), Color(0xFFFF8F5E)],
  );

  /// Card gradient — very subtle blue tint
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white, Color(0xFFF5F9FF)],
  );

  /// Background gradient — soft blue tint
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE8F0FE), Color(0xFFF0F4FA)],
  );

  /// Section gradient — slightly stronger blue tint
  static const LinearGradient sectionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0F6FE), Color(0xFFE3EFFC)],
  );

  // Legacy gradients for backward compat
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

  // ── Card Decoration ──────────────────────────────────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: const Color(0xFF0A66C2).withOpacity(0.10),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF0A66C2).withOpacity(0.08),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );

  /// Elevated card with stronger shadow
  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: const Color(0xFF0A66C2).withOpacity(0.12),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF0A66C2).withOpacity(0.12),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // Input Decoration
  static BoxDecoration get inputDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: const Color(0xFFD2DCEA),
      width: 1.5,
    ),
  );

  // Primary Button Decoration
  static BoxDecoration get primaryButtonDecoration => BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    gradient: primaryGradient,
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF0A66C2).withOpacity(0.35),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ],
  );

  /// Accent CTA Button Decoration
  static BoxDecoration get accentButtonDecoration => BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    gradient: accentGradient,
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFFF6B35).withOpacity(0.35),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ],
  );

  // Glass Effect for Dark Mode
  static BoxDecoration get glassDarkDecoration => BoxDecoration(
    color: const Color(0xFF1C2A38),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Colors.white.withOpacity(0.1),
      width: 1,
    ),
  );
}
