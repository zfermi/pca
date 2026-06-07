import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const primaryDark = Color(0xFF4A42D4);
  static const primaryLight = Color(0xFF8B83FF);
  static const accent = Color(0xFFFF6D00);
  static const accentLight = Color(0xFFFF9E40);

  static const backgroundDark = Color(0xFF0F0F1E);
  static const backgroundMid = Color(0xFF1A1A2E);
  static const surface = Color(0xFF252540);
  static const surfaceLight = Color(0xFF2D2D4A);
  static const cardBorder = Color(0xFF3A3A5C);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B0CC);
  static const textMuted = Color(0xFF7A7A99);

  static const error = Color(0xFFFF4C6A);
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);

  static const timerBackground = Color(0xFF0D1B2A);

  static const gradientStart = Color(0xFF0F0F1E);
  static const gradientEnd = Color(0xFF1E1E3A);

  static const avatarColors = [
    Color(0xFF6C63FF),
    Color(0xFF4ADE80),
    Color(0xFFFF6D00),
    Color(0xFFE040FB),
    Color(0xFFFF4C6A),
    Color(0xFF00BCD4),
  ];

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );

  // Keep old names as aliases for compatibility
  static const background = backgroundDark;
}
