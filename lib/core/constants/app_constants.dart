import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'SHEGUARD AI';
  static const String appTagline = 'Real-Time Women Distress Detection System';

  // Paddings
  static const double paddingXS = 8.0;
  static const double paddingS = 12.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;
  static const double paddingXXL = 48.0;

  // BorderRadius
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusXXL = 32.0;

  // Animation Durations
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationNormal = Duration(milliseconds: 350);
  static const Duration durationSlow = Duration(milliseconds: 600);
  static const Duration durationPulse = Duration(milliseconds: 1500);
}

class AppColors {
  // Brand Color Palette (Futuristic Dark Cyber Security Theme)
  static const Color scaffoldBg = Color(0xFF0F172A); // Deep Midnight Blue
  static const Color primaryPurple = Color(0xFF7C3AED); // Royal Purple
  static const Color neonViolet = Color(0xFF8B5CF6); // Neon Violet
  static const Color softPink = Color(0xFFEC4899); // Soft Pink
  static const Color neonPink = Color(0xFFF43F5E); // Neon Alert Pink/Rose
  static const Color neonGreen = Color(0xFF10B981); // Safety Armed Green
  static const Color cardBg = Color(0xFF1E293B); // Charcoal / Slate Card
  
  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC); // Slate white
  static const Color textSecondary = Color(0xFF94A3B8); // Slate grey

  // Gradients
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient alertGradient = LinearGradient(
    colors: [Color(0xFFF43F5E), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient darkGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Gradient neonVioletGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
