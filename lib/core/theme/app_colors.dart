import 'package:flutter/material.dart';

/// Theme type enum
enum ThemeType { light, dark }

/// App colors - const values for dark theme (primary theme)
/// Light theme is handled via ThemeData in app_theme.dart
class AppColors {
  // Primary palette from design (#13EC5B)
  static const Color background = Color(0xFF0D1F17);
  static const Color surface = Color(0xFF132B1E);
  static const Color surfaceLight = Color(0xFF1A3D28);
  static const Color primary = Color(0xFF13EC5B);
  static const Color primaryDark = Color(0xFF0FBF4A);
  static const Color primaryLight = Color(0xFF5CF28A);

  // Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // Letter tile colors
  static const Color letterCorrect = Color(0xFF13EC5B);
  static const Color letterWrongPosition = Color(0xFFFACC15);
  static const Color letterWrong = Color(0xFF4A5568);
  static const Color letterEmpty = Color(0xFF1F2937);
  static const Color letterBorder = Color(0xFF374151);

  // Alias
  static const Color correct = letterCorrect;

  // Status colors
  static const Color success = Color(0xFF13EC5B);
  static const Color warning = Color(0xFFFACC15);
  static const Color error = Color(0xFFEF4444);

  // Glass / Glow colors
  static const Color glassBorder = Color(0x33FFFFFF);       // 20% white
  static const Color glassBackground = Color(0x0DFFFFFF);   // 5% white
  static const Color glowPrimary = Color(0x4013EC5B);       // 25% primary

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [background, Color(0xFF081410)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    colors: [backgroundLight, Color(0xFFE8F5E9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient getBackgroundGradient(Brightness brightness) {
    return brightness == Brightness.dark ? darkBackgroundGradient : lightBackgroundGradient;
  }

  // Glass decoration helper
  static BoxDecoration glassDecoration({
    double borderRadius = 20,
    Color? borderColor,
    Color? bgColor,
  }) {
    return BoxDecoration(
      color: bgColor ?? const Color(0x15132B1E),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? glassBorder,
        width: 1,
      ),
    );
  }

  // Light theme colors (for reference)
  static const Color backgroundLight = Color(0xFFF5F7F6);
  static const Color surfaceWhite = Colors.white;
  static const Color surfaceLightGreen = Color(0xFFE8F5E9);
  static const Color textPrimaryDark = Color(0xFF1A1A1A);
  static const Color letterWrongLight = Color(0xFFCBD5E0);
  static const Color letterEmptyLight = Color(0xFFE2E8F0);
  static const Color letterBorderLight = Color(0xFFD1D5DB);
}
