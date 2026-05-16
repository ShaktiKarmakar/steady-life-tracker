import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/design_system/design_tokens.dart';

class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.habitScore,
    required this.nutritionScore,
    this.size = 80,
  });

  final double habitScore; // 0.0 to 1.0
  final double nutritionScore; // 0.0 to 1.0
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ScoreRingPainter(
          habitScore: habitScore,
          nutritionScore: nutritionScore,
          isDarkMode: Theme.of(context).brightness == Brightness.dark,
        ),
        child: Center(
          child: Text(
            '${((habitScore + nutritionScore) / 2 * 100).round()}',
            style: DesignTokens.sectionHeading.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  _ScoreRingPainter({
    required this.habitScore,
    required this.nutritionScore,
    required this.isDarkMode,
  });

  final double habitScore;
  final double nutritionScore;
  final bool isDarkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4.5;
    const strokeWidth = 4.5;
    const startAngle = -pi / 2;

    final trackPaint = Paint()
      ..color = isDarkMode ? DesignTokens.bgSurfaceDark : DesignTokens.bgSurfaceLight
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (habitScore > 0) {
      final habitPaint = Paint()
        ..color = isDarkMode ? DesignTokens.textSecondaryDark : DesignTokens.textSecondaryLight
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final habitAngle = 2 * pi * habitScore;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        habitAngle,
        false,
        habitPaint,
      );
    }

    if (nutritionScore > 0) {
      final nutritionPaint = Paint()
        ..color = isDarkMode ? DesignTokens.textMutedDark : DesignTokens.textMutedLight
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final nutritionAngle = 2 * pi * nutritionScore;
      final nutritionStart = startAngle + (2 * pi * habitScore);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        nutritionStart,
        nutritionAngle,
        false,
        nutritionPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) {
    return oldDelegate.habitScore != habitScore ||
        oldDelegate.nutritionScore != nutritionScore ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}
