import 'package:flutter/material.dart';
import '../../core/design_system/animations.dart';
import '../../core/design_system/design_tokens.dart';

/// A card that subtly scales down on press and animates its elevation.
/// Monochromatic only — no shadows, no colors beyond tokens.
class AnimatedCard extends StatefulWidget {
  const AnimatedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 14,
    this.color,
    this.borderColor,
    this.onTap,
    this.duration = SteadyAnimations.normal,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final Duration duration;

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: SteadyAnimations.fast,
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: SteadyAnimations.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.color ??
        (isDark ? DesignTokens.bgSurfaceDark : DesignTokens.bgSurfaceLight);
    final border = widget.borderColor ??
        (isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight);

    final child = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            margin: widget.margin,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: border,
                width: DesignTokens.borderWidthDefault,
              ),
            ),
            child: Padding(padding: widget.padding, child: child),
          ),
        );
      },
      child: widget.child,
    );

    if (widget.onTap == null) return child;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
