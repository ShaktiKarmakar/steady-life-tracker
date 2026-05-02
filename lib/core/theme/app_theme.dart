import 'package:flutter/material.dart';

class AppColors {
  static const bgPrimary = Color(0xFF0A0A1A);
  static const bgSecondary = Color(0xFF12112B);
  static const accentPurple = Color(0xFF7C6AF7);
  static const accentPink = Color(0xFFF76AC8);
  static const accentTeal = Color(0xFF6AF7D4);
  static const accentAmber = Color(0xFFF7C26A);
  static const glass = Color.fromRGBO(255, 255, 255, 0.06);
  static const glassBorder = Color.fromRGBO(255, 255, 255, 0.12);
}

class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgPrimary,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accentPurple,
        secondary: AppColors.accentPink,
        surface: AppColors.bgSecondary,
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        titleMedium: const TextStyle(fontWeight: FontWeight.w600),
        bodyMedium: const TextStyle(color: Color(0xFFD9D7E8)),
      ),
    );
  }
}
