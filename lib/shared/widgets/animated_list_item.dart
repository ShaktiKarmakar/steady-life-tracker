import 'package:flutter/material.dart';
import '../../core/design_system/animations.dart';

/// Wraps a child with a staggered fade + slide entrance animation.
/// Use inside a ListView or Column where items should appear sequentially.
class AnimatedListItem extends StatelessWidget {
  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.duration = SteadyAnimations.normal,
    this.slideOffset = const Offset(0, 12),
  });

  final Widget child;
  final int index;
  final Duration duration;
  final Offset slideOffset;

  @override
  Widget build(BuildContext context) {
    return _AnimatedListItemWrapper(
      index: index,
      duration: duration,
      slideOffset: slideOffset,
      child: child,
    );
  }
}

class _AnimatedListItemWrapper extends StatefulWidget {
  const _AnimatedListItemWrapper({
    required this.child,
    required this.index,
    required this.duration,
    required this.slideOffset,
  });

  final Widget child;
  final int index;
  final Duration duration;
  final Offset slideOffset;

  @override
  State<_AnimatedListItemWrapper> createState() => _AnimatedListItemWrapperState();
}

class _AnimatedListItemWrapperState extends State<_AnimatedListItemWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    final delay = Duration(
      milliseconds: widget.index * SteadyAnimations.stagger.inMilliseconds,
    );

    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: SteadyAnimations.easeOut),
    );

    _slide = Tween<Offset>(
      begin: widget.slideOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: SteadyAnimations.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
