import 'package:flutter/material.dart';

/// Simple "glass" fill for liquid-style quantity habits.
class WaterGlass extends StatelessWidget {
  const WaterGlass({
    super.key,
    required this.fill,
    required this.color,
  });

  final double fill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth * 0.5;
        final h = c.maxHeight;
        return Center(
          child: CustomPaint(
            size: Size(w, h),
            painter: _GlassPainter(
              fill: fill.clamp(0.0, 1.0),
              color: color,
            ),
          ),
        );
      },
    );
  }
}

class _GlassPainter extends CustomPainter {
  _GlassPainter({required this.fill, required this.color});

  final double fill;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = 12.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(r),
    );
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white30;
    final fillH = h * fill;
    final fillRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, h - fillH, w, fillH),
      bottomLeft: const Radius.circular(12),
      bottomRight: const Radius.circular(12),
    );
    final fillPaint = Paint()..color = color.withValues(alpha: 0.6);
    canvas.drawRRect(rect, border);
    if (fillH > 0) {
      canvas.drawRRect(fillRect, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlassPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.color != color;
}
