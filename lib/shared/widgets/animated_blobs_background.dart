import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AnimatedBlobsBackground extends StatelessWidget {
  const AnimatedBlobsBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        _Blob(
          alignment: Alignment(-1.2, -1.1),
          size: 340,
          color: AppColors.accentPurple,
        ),
        _Blob(
          alignment: Alignment(1.1, -0.1),
          size: 280,
          color: AppColors.accentPink,
        ),
        _Blob(
          alignment: Alignment(-0.2, 1.0),
          size: 260,
          color: AppColors.accentTeal,
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.alignment,
    required this.size,
    required this.color,
  });

  final Alignment alignment;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}
