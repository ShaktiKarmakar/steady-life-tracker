import 'package:flutter/material.dart';

import '../../core/design_system/design_tokens.dart';

enum PillType { ok, warn, neutral }

class SteadyPill extends StatelessWidget {
  const SteadyPill({
    super.key,
    required this.label,
    this.type = PillType.neutral,
    this.backgroundColor,
    this.textColor,
  });

  final String label;
  final PillType type;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    Color bg;
    Color text;
    
    if (backgroundColor != null && textColor != null) {
      bg = backgroundColor!;
      text = textColor!;
    } else {
      switch (type) {
        case PillType.ok:
          bg = isDarkMode
              ? DesignTokens.okTextDark.withValues(alpha: 0.15)
              : DesignTokens.okTextLight.withValues(alpha: 0.12);
          text = isDarkMode ? DesignTokens.okTextDark : DesignTokens.okTextLight;
          break;
        case PillType.warn:
          bg = isDarkMode
              ? DesignTokens.warnTextDark.withValues(alpha: 0.15)
              : DesignTokens.warnTextLight.withValues(alpha: 0.12);
          text = isDarkMode ? DesignTokens.warnTextDark : DesignTokens.warnTextLight;
          break;
        case PillType.neutral:
          bg = isDarkMode
              ? DesignTokens.accentActiveDark.withValues(alpha: 0.4)
              : DesignTokens.accentActiveLight.withValues(alpha: 0.6);
          text = isDarkMode
              ? DesignTokens.textSecondaryDark
              : DesignTokens.textSecondaryLight;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
      ),
      child: Text(
        label,
        style: DesignTokens.labelMeta.copyWith(
          color: text,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
