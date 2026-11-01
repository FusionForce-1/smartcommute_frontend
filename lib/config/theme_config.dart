// lib/config/theme_config.dart
//
// Emae Emehhhh — E1. Visual Style Guide
// Source: SmartCommute_System_Layout.docx §E1 (config/theme_config.dart + css/main.css)
//
// This file is the single source of truth for color, type, radius, spacing and
// elevation across the Flutter app. Screens and widgets should reference
// AppColors / AppRadius / AppSpacing / AppTheme rather than hard-coding values.

import 'package:flutter/material.dart';

/// E1 color tokens.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1A3C6E); // Deep Navy
  static const Color secondary = Color(0xFF2E86AB); // Teal Blue
  static const Color accent = Color(0xFFF5A623); // Amber
  static const Color success = Color(0xFF27AE60);
  static const Color error = Color(0xFFE74C3C);

  static const Color backgroundIceBlue = Color(0xFFEBF4FA);
  static const Color backgroundWhite = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF555555);

  // Convenience derived tones used across the auth screens (banner + card shadow).
  static const Color bannerTeal = secondary;
  static const Color inputBorder = secondary;
  static const Color errorBackground = Color(0xFFFCE4E4);

  // Commuter dashboard (same palette as the web portal's admin/operator UI).
  static const Color brandTeal = Color(0xFF3B8A9E);
  static const Color headerSky = Color(0xFFD3EDFB);
  static const Color divider = Color(0xFFDCE2E8);
  static const Color navInactive = Color(0xFF8A8F98);
  static const Color infoBlue = Color(0xFF1E63C6); // "Info" transit alerts

  // Driver dashboard.
  static const Color shiftGreen = Color(0xFF0E7C4F); // On Shift, On-Route
  static const Color shiftGreenTint = Color(0xFFEEF7F1); // On Shift card
  static const Color panelGrey = Color(0xFFF2F1EE); // Crowd slider track and badge
}

/// E1 corner-radius tokens.
///
/// NOTE: the documented spec lists 12px (cards) / 8px (buttons) / 24px (chips).
/// The finalized Login/Register/Forgot-Password/OTP mockups actually render
/// buttons and pill-style text fields with a much larger, stadium-style radius.
/// This file follows the mockups (source of truth per the latest design hand-off)
/// and keeps [button] at a larger value than the original doc — flag this to the
/// team so §E1 in the system layout doc can be updated to match, or the mockups
/// revised, whichever is intended to be canonical.
class AppRadius {
  AppRadius._();

  static const double card = 12;
  static const double chip = 24;

  /// Stadium/pill radius used by primary + secondary buttons in the mockups.
  static const double button = 28;

  /// Pill radius used by the Forgot Password / Verify OTP text fields.
  static const double inputPill = 28;

  /// Slightly less rounded radius used by the Login / Register text fields.
  static const double inputField = 14;

  /// Radius of the curved bottom edge on the teal header banner.
  static const double bannerCurve = 32;
}

/// E1 spacing tokens — 8px grid system.
class AppSpacing {
  AppSpacing._();

  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
}

/// E1 elevation / shadow token: `0 2px 8px rgba(0,0,0,0.12)`.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      offset: const Offset(0, 2),
      blurRadius: 8,
    ),
  ];
}

class AppTheme {
  AppTheme._();

  static const String _fontFamily = 'Poppins';

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    // Poppins is bundled locally (assets/fonts/) and declared under
    // flutter.fonts in pubspec.yaml — no google_fonts package/runtime
    // download involved. `.apply(fontFamily: ...)` stamps every default
    // Material text style with our font while keeping their sizes/weights.
    final textTheme = base.textTheme.apply(fontFamily: _fontFamily).copyWith(
      headlineLarge: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.15,
      ),
      headlineMedium: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleLarge: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyMedium: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      labelLarge: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundIceBlue,
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.backgroundWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.secondary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.secondary, width: 1.4),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: TextStyle(fontFamily: _fontFamily, color: Colors.grey.shade500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.inputField),
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.inputField),
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.inputField),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.secondary
              : Colors.white,
        ),
      ),
    );
  }
}
