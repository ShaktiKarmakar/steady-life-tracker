import 'package:flutter/material.dart';

/// Notion-inspired design tokens.
/// Neutral, functional, no flashy accents.
/// People come here to organize their life, not to look at colors.
class DesignTokens {
  // ---------------------------------------------------------------------------
  // Core neutrals (Dark)
  // ---------------------------------------------------------------------------
  static const Color bgBaseDark = Color(0xFF191919);      // main bg
  static const Color bgSurfaceDark = Color(0xFF202020);   // cards, sheets
  static const Color bgRaisedDark = Color(0xFF252525);    // hover/raised
  static const Color bgSubtleDark = Color(0xFF1A1A1A);    // subtle bg
  static const Color bgOverlayDark = Color(0xFF171717);   // bottom bar, overlays

  static const Color borderDefaultDark = Color(0xFF2F2F2F);
  static const Color borderFaintDark = Color(0xFF262626);

  static const Color textPrimaryDark = Color(0xFFD4D4D4);   // headings, primary text
  static const Color textSecondaryDark = Color(0xFF888888); // body
  static const Color textMutedDark = Color(0xFF6B6B6B);   // hints, disabled
  static const Color textFaintDark = Color(0xFF444444);     // dividers, ghost text
  static const Color textGhostDark = Color(0xFF2A2A2A);

  // ---------------------------------------------------------------------------
  // Core neutrals (Light)
  // ---------------------------------------------------------------------------
  static const Color bgBaseLight = Color(0xFFFFFFFF);
  static const Color bgSurfaceLight = Color(0xFFF7F7F5);  // Notion's light gray
  static const Color bgRaisedLight = Color(0xFFFFFFFF);
  static const Color bgSubtleLight = Color(0xFFFAFAFA);
  static const Color bgOverlayLight = Color(0xFFFFFFFF);

  static const Color borderDefaultLight = Color(0xFFE3E2E0);
  static const Color borderFaintLight = Color(0xFFEEECEA);

  static const Color textPrimaryLight = Color(0xFF37352F);   // Notion's near-black
  static const Color textSecondaryLight = Color(0xFF6B6B6B);
  static const Color textMutedLight = Color(0xFF9A9A9A);
  static const Color textFaintLight = Color(0xFFC0C0C0);
  static const Color textGhostLight = Color(0xFFDDDDE0);

  // ---------------------------------------------------------------------------
  // Single functional accent — just a slightly lighter/darker gray for active
  // states. No purple, teal, amber, or other decorative colors.
  // ---------------------------------------------------------------------------
  static const Color accentActiveDark = Color(0xFF3A3A3A);
  static const Color accentActiveLight = Color(0xFFEAEAEA);

  /// Success / done — still neutral, just a slightly lighter gray-green
  static const Color okTextDark = Color(0xFF7A8B7A);
  static const Color okTextLight = Color(0xFF4A5A4A);

  /// Warning / error — muted red-gray, not bright orange
  static const Color warnTextDark = Color(0xFF9B6B6B);
  static const Color warnTextLight = Color(0xFF8B4A4A);

  // ---------------------------------------------------------------------------
  // Typography
  // ---------------------------------------------------------------------------
  static const TextStyle heroNumber = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
  );

  static const TextStyle sectionHeading = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const TextStyle body = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle labelMeta = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const TextStyle micro = TextStyle(
    fontSize: 8,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle sectionTitleLabel = TextStyle(
    fontSize: 8,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  // ---------------------------------------------------------------------------
  // Spacing (4px base unit)
  // ---------------------------------------------------------------------------
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 12.0;
  static const double spaceLg = 16.0;
  static const double spaceXl = 20.0;

  // ---------------------------------------------------------------------------
  // Border Radius
  // ---------------------------------------------------------------------------
  static const double radiusXs = 6.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusPill = 20.0;
  static const double radiusPhone = 40.0;

  // ---------------------------------------------------------------------------
  // Borders
  // ---------------------------------------------------------------------------
  static const double borderWidthDefault = 0.5;
  static const double borderWidthFeatured = 1.0;
  static const double progressBarHeightMini = 2.0;
  static const double progressBarHeightCalorie = 3.0;
  static const double progressBarBorderRadius = 2.0;
  static const double progressBarBorderRadiusCalorie = 3.0;

  // ---------------------------------------------------------------------------
  // Icon Sizes
  // ---------------------------------------------------------------------------
  static const double iconSizeNav = 16.0;
  static const double iconSizeMiniCard = 12.0;
  static const double iconSizeInsideMiniCard = 11.0;
}
