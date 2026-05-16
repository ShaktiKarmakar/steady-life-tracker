import 'package:flutter/material.dart';

import '../../core/design_system/design_tokens.dart';

class AnimatedBlobsBackground extends StatefulWidget {
  const AnimatedBlobsBackground({super.key});

  @override
  State<AnimatedBlobsBackground> createState() => _AnimatedBlobsBackgroundState();
}

class _AnimatedBlobsBackgroundState extends State<AnimatedBlobsBackground>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        duration: Duration(seconds: 8 + i * 4),
        vsync: this,
      )..repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blobColor = isDark
        ? DesignTokens.accentActiveDark
        : DesignTokens.accentActiveLight;

    final configs = [
      (_BlobConfig(alignment: const Alignment(-1.2, -1.1), size: 340, dx: 20, dy: 30), _controllers[0]),
      (_BlobConfig(alignment: const Alignment(1.1, -0.1), size: 280, dx: -15, dy: 25), _controllers[1]),
      (_BlobConfig(alignment: const Alignment(-0.2, 1.0), size: 260, dx: 25, dy: -20), _controllers[2]),
    ];

    return Stack(
      children: configs.map((e) {
        return _AnimatedBlob(
          config: e.$1,
          controller: e.$2,
          color: blobColor,
        );
      }).toList(),
    );
  }
}

class _BlobConfig {
  const _BlobConfig({
    required this.alignment,
    required this.size,
    required this.dx,
    required this.dy,
  });

  final Alignment alignment;
  final double size;
  final double dx;
  final double dy;
}

class _AnimatedBlob extends StatelessWidget {
  const _AnimatedBlob({
    required this.config,
    required this.controller,
    required this.color,
  });

  final _BlobConfig config;
  final AnimationController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final dx = config.dx * (controller.value - 0.5) * 2;
        final dy = config.dy * (controller.value - 0.5) * 2;
        return Align(
          alignment: config.alignment,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: child,
          ),
        );
      },
      child: Container(
        width: config.size,
        height: config.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.08),
        ),
      ),
    );
  }
}
