import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/design_system/animations.dart';

/// Smooth page transitions for GoRouter.
/// Usage: wrap any screen in this widget as the route builder.
class SteadyPageTransition extends StatelessWidget {
  const SteadyPageTransition({
    super.key,
    required this.child,
    this.type = SteadyTransitionType.fadeSlide,
  });

  final Widget child;
  final SteadyTransitionType type;

  @override
  Widget build(BuildContext context) => child;
}

enum SteadyTransitionType { fade, fadeSlide, scaleFade }

/// Custom transition page for GoRouter.
class SteadyTransitionPage extends CustomTransitionPage<void> {
  SteadyTransitionPage({
    required super.child,
    super.name,
    super.arguments,
    super.restorationId,
    super.key,
    SteadyTransitionType type = SteadyTransitionType.fadeSlide,
  }) : super(
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return switch (type) {
              SteadyTransitionType.fade =>
                SteadyAnimations.fadePage(child, animation),
              SteadyTransitionType.fadeSlide =>
                SteadyAnimations.fadeSlidePage(child, animation),
              SteadyTransitionType.scaleFade =>
                SteadyAnimations.scaleFadePage(child, animation),
            };
          },
          transitionDuration: SteadyAnimations.page,
          reverseTransitionDuration: SteadyAnimations.fast,
        );
}
