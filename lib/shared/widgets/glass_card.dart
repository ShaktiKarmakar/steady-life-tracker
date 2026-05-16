import 'package:flutter/material.dart';

import '../../core/design_system/design_tokens.dart';

/// Simple card without glassmorphism blur.
/// Glassmorphism is overused in AI-generated designs.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: DesignTokens.bgSurfaceDark,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(
          color: DesignTokens.borderDefaultDark,
          width: DesignTokens.borderWidthDefault,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
