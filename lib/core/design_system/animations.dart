import 'package:flutter/material.dart';

/// Notion-inspired animation system.
/// Smooth, subtle, and purposeful. No bouncy or playful curves.
class SteadyAnimations {
  SteadyAnimations._();

  // ---------------------------------------------------------------------------
  // Durations
  // ---------------------------------------------------------------------------
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration page = Duration(milliseconds: 300);
  static const Duration stagger = Duration(milliseconds: 50);

  // ---------------------------------------------------------------------------
  // Curves
  // ---------------------------------------------------------------------------
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeIn = Curves.easeInCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve spring = Curves.fastOutSlowIn;
  static const Curve decelerate = Curves.decelerate;

  // ---------------------------------------------------------------------------
  // Page transitions
  // ---------------------------------------------------------------------------
  static Widget fadeSlidePage(Widget child, Animation<double> animation) {
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: easeOut),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0.0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: animation, curve: easeOut),
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }

  static Widget fadePage(Widget child, Animation<double> animation) {
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: easeOut),
    );
    return FadeTransition(opacity: fade, child: child);
  }

  static Widget scaleFadePage(Widget child, Animation<double> animation) {
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: easeOut),
    );
    final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: easeOut),
    );
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(scale: scale, child: child),
    );
  }

  // ---------------------------------------------------------------------------
  // Stagger helpers
  // ---------------------------------------------------------------------------
  static Animation<double> staggeredFade(
    Animation<double> parent, {
    required int index,
    required int total,
    Duration step = stagger,
  }) {
    final totalDuration = step * total;
    final start = (step * index).inMilliseconds / totalDuration.inMilliseconds;
    final end = start + (normal.inMilliseconds / totalDuration.inMilliseconds);

    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: parent,
        curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0), curve: easeOut),
      ),
    );
  }
}
