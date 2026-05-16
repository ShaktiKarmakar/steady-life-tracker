import 'package:flutter/material.dart';
import '../../core/design_system/animations.dart';
import '../../core/design_system/design_tokens.dart';

class SteadyCard extends StatelessWidget {
  const SteadyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 14,
    this.color,
    this.borderColor,
    this.onTap,
    this.animated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final cardContent = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ??
            (isDarkMode
                ? DesignTokens.bgSurfaceDark
                : DesignTokens.bgSurfaceLight),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ??
              (isDarkMode
                  ? DesignTokens.borderDefaultDark
                  : DesignTokens.borderDefaultLight),
          width: DesignTokens.borderWidthDefault,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return cardContent;

    if (!animated) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: cardContent,
      );
    }

    return _AnimatedCardTap(
      onTap: onTap!,
      child: cardContent,
    );
  }
}

class _AnimatedCardTap extends StatefulWidget {
  const _AnimatedCardTap({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_AnimatedCardTap> createState() => _AnimatedCardTapState();
}

class _AnimatedCardTapState extends State<_AnimatedCardTap>
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
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
