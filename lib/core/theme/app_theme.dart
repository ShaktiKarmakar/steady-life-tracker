import 'package:flutter/material.dart';
import '../design_system/design_tokens.dart';

// Deprecated: Use DesignTokens instead
@Deprecated('Use DesignTokens from design_system/design_tokens.dart')
class AppColors {
  static const bgPrimary = DesignTokens.bgBaseDark;
  static const bgSecondary = DesignTokens.bgSurfaceDark;
  static const accentPurple = DesignTokens.accentActiveDark;
  static const accentPink = DesignTokens.accentActiveDark;
  static const accentTeal = DesignTokens.accentActiveDark;
  static const accentAmber = DesignTokens.warnTextDark;
  static const glass = DesignTokens.bgSurfaceDark;
  static const glassBorder = DesignTokens.borderDefaultDark;
}

class SteadyTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: DesignTokens.bgBaseDark,
      colorScheme: ColorScheme.dark(
        brightness: Brightness.dark,
        primary: DesignTokens.accentActiveDark,
        secondary: DesignTokens.textSecondaryDark,
        surface: DesignTokens.bgSurfaceDark,
        error: DesignTokens.warnTextDark,
      ),
      textTheme: TextTheme(
        headlineSmall: DesignTokens.heroNumber.copyWith(
          color: DesignTokens.textPrimaryDark,
        ),
        titleMedium: DesignTokens.sectionHeading.copyWith(
          color: DesignTokens.textPrimaryDark,
        ),
        titleSmall: DesignTokens.cardTitle.copyWith(
          color: DesignTokens.textPrimaryDark,
        ),
        bodyMedium: DesignTokens.body.copyWith(
          color: DesignTokens.textSecondaryDark,
        ),
        bodySmall: DesignTokens.labelMeta.copyWith(
          color: DesignTokens.textFaintDark,
        ),
        labelSmall: DesignTokens.micro.copyWith(
          color: DesignTokens.textFaintDark,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: DesignTokens.borderFaintDark,
        thickness: DesignTokens.borderWidthDefault,
      ),
      cardTheme: CardThemeData(
        color: DesignTokens.bgSurfaceDark,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          side: BorderSide(
            color: DesignTokens.borderDefaultDark,
            width: DesignTokens.borderWidthDefault,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.bgSurfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          borderSide: BorderSide(
            color: DesignTokens.borderDefaultDark,
            width: DesignTokens.borderWidthDefault,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          borderSide: BorderSide(
            color: DesignTokens.borderDefaultDark,
            width: DesignTokens.borderWidthDefault,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          borderSide: BorderSide(
            color: DesignTokens.textSecondaryDark,
            width: DesignTokens.borderWidthDefault,
          ),
        ),
        labelStyle: DesignTokens.labelMeta.copyWith(
          color: DesignTokens.textFaintDark,
        ),
        hintStyle: DesignTokens.body.copyWith(
          color: DesignTokens.textMutedDark,
        ),
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData.light(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: DesignTokens.bgBaseLight,
      colorScheme: ColorScheme.light(
        brightness: Brightness.light,
        primary: DesignTokens.accentActiveLight,
        secondary: DesignTokens.textSecondaryLight,
        surface: DesignTokens.bgSurfaceLight,
        error: DesignTokens.warnTextLight,
      ),
      textTheme: TextTheme(
        headlineSmall: DesignTokens.heroNumber.copyWith(
          color: DesignTokens.textPrimaryLight,
        ),
        titleMedium: DesignTokens.sectionHeading.copyWith(
          color: DesignTokens.textPrimaryLight,
        ),
        titleSmall: DesignTokens.cardTitle.copyWith(
          color: DesignTokens.textPrimaryLight,
        ),
        bodyMedium: DesignTokens.body.copyWith(
          color: DesignTokens.textSecondaryLight,
        ),
        bodySmall: DesignTokens.labelMeta.copyWith(
          color: DesignTokens.textFaintLight,
        ),
        labelSmall: DesignTokens.micro.copyWith(
          color: DesignTokens.textFaintLight,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: DesignTokens.borderFaintLight,
        thickness: DesignTokens.borderWidthDefault,
      ),
      cardTheme: CardThemeData(
        color: DesignTokens.bgSurfaceLight,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          side: BorderSide(
            color: DesignTokens.borderDefaultLight,
            width: DesignTokens.borderWidthDefault,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.bgSurfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          borderSide: BorderSide(
            color: DesignTokens.borderDefaultLight,
            width: DesignTokens.borderWidthDefault,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          borderSide: BorderSide(
            color: DesignTokens.borderDefaultLight,
            width: DesignTokens.borderWidthDefault,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          borderSide: BorderSide(
            color: DesignTokens.textSecondaryLight,
            width: DesignTokens.borderWidthDefault,
          ),
        ),
        labelStyle: DesignTokens.labelMeta.copyWith(
          color: DesignTokens.textFaintLight,
        ),
        hintStyle: DesignTokens.body.copyWith(
          color: DesignTokens.textMutedLight,
        ),
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
