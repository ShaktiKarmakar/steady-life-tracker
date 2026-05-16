import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/ai/gemma_service.dart';
import '../../core/db/database.dart';
import '../../core/design_system/animations.dart';
import '../../core/design_system/design_tokens.dart';
import '../../shared/widgets/animated_list_item.dart';
import '../../shared/widgets/steady_card.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  double _progress = 0;
  bool _downloading = false;
  String _status =
      'Tap download to add on-device AI. Wi‑Fi required (~2.6 GB).';
  bool _modelReady = false;

  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _checkAlreadyDone();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _checkAlreadyDone() async {
    final db = ref.read(databaseProvider);
    await db.initialize();
    try {
      final installed = await ref.read(gemmaServiceProvider).isModelInstalled();
      if (installed && mounted) {
        ref.read(aiModelUiTickProvider.notifier).bump();
        setState(() {
          _modelReady = true;
          _progress = 1;
          _status = 'Model already installed.';
        });
      }
    } catch (e) {
      debugPrint('Model check error: $e');
    }
    if (!mounted) return;
    if (db.onboardingComplete && (_modelReady || db.aiDownloadSkipped)) {
      context.go('/home');
    } else {
      _entranceController.forward();
    }
  }

  Future<void> _startDownload() async {
    if (!mounted) return;
    setState(() {
      _downloading = true;
      _status = 'Downloading… (~2.6 GB). Use Wi‑Fi; keep the app open.';
      _progress = 0.02;
    });
    try {
      await ref.read(gemmaServiceProvider).downloadModel(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p.clamp(0.02, 0.99));
        },
      );
      if (mounted) {
        ref.read(aiModelUiTickProvider.notifier).bump();
        setState(() {
          _downloading = false;
          _progress = 1;
          _modelReady = true;
          _status = 'Model ready! Your data stays on-device.';
        });
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        final msg = e.toString();
        final hint = msg.contains('401') || msg.contains('Authentication')
            ? ' Check the URL or use --dart-define=STEADY_MODEL_MIRROR_URL for a direct link.'
            : '';
        setState(() {
          _downloading = false;
          _status = 'Download failed.$hint Or skip and try again later.';
        });
      }
    }
  }

  Future<void> _finish({bool skippedAiDownload = false}) async {
    final db = ref.read(databaseProvider);
    await db.setOnboardingComplete(true);
    await db.setAiDownloadSkipped(skippedAiDownload);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    final textSecondary = isDark ? DesignTokens.textSecondaryDark : DesignTokens.textSecondaryLight;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: AnimatedBuilder(
            animation: _entranceController,
            builder: (context, child) {
              return Opacity(
                opacity: _entranceController.value,
                child: child,
              );
            },
            child: Column(
              children: [
                const SizedBox(height: 12),
                AnimatedListItem(
                  index: 0,
                  child: Icon(LucideIcons.sparkles, size: 56, color: textSecondary),
                ),
                const SizedBox(height: 20),
                AnimatedListItem(
                  index: 1,
                  child: Text(
                    'Welcome to Steady',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedListItem(
                  index: 2,
                  child: Text(
                    'Your private second brain. AI runs on your device after a one-time download.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textMuted),
                  ),
                ),
                const SizedBox(height: 28),
                AnimatedListItem(
                  index: 3,
                  child: SteadyCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI model',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Download runs once over HTTPS and stays on this device. '
                          'Use Wi‑Fi and leave the app open until it finishes.',
                          style: TextStyle(
                              fontSize: 13, height: 1.35, color: textSecondary),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: _progress),
                            duration: SteadyAnimations.normal,
                            curve: SteadyAnimations.easeOut,
                            builder: (context, value, _) {
                              return LinearProgressIndicator(
                                value: value,
                                minHeight: 8,
                                color: textSecondary,
                                backgroundColor: isDark
                                    ? DesignTokens.borderDefaultDark
                                    : DesignTokens.borderDefaultLight,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: SteadyAnimations.normal,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.2),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            '${(_progress * 100).toInt()}% — $_status',
                            key: ValueKey<String>(_status + _progress.toString()),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                AnimatedListItem(
                  index: 4,
                  child: SizedBox(
                    width: double.infinity,
                    child: _AnimatedButton(
                      onPressed: _downloading
                          ? null
                          : (_modelReady
                              ? () => _finish(skippedAiDownload: false)
                              : (_progress > 0 && _progress < 1
                                  ? null
                                  : _startDownload)),
                      child: _downloading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_modelReady
                              ? 'Enter Steady'
                              : (_progress == 0
                                  ? 'Download AI model'
                                  : 'Retry download')),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedListItem(
                  index: 5,
                  child: SizedBox(
                    width: double.infinity,
                    child: _AnimatedOutlinedButton(
                      onPressed: _downloading
                          ? null
                          : () => _finish(skippedAiDownload: true),
                      child: const Text('Skip for now'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedButton extends StatefulWidget {
  const _AnimatedButton({required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
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
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: SteadyAnimations.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed != null) _controller.forward();
  }

  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onPressed,
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: widget.onPressed == null
                ? (isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight)
                : (isDark ? DesignTokens.textPrimaryDark : DesignTokens.textPrimaryLight),
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          ),
          alignment: Alignment.center,
          child: DefaultTextStyle(
            style: TextStyle(
              color: widget.onPressed == null
                  ? (isDark ? DesignTokens.textFaintDark : DesignTokens.textFaintLight)
                  : (isDark ? DesignTokens.bgBaseDark : DesignTokens.bgBaseLight),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _AnimatedOutlinedButton extends StatefulWidget {
  const _AnimatedOutlinedButton({required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  State<_AnimatedOutlinedButton> createState() => _AnimatedOutlinedButtonState();
}

class _AnimatedOutlinedButtonState extends State<_AnimatedOutlinedButton>
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
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: SteadyAnimations.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed != null) _controller.forward();
  }

  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onPressed,
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            border: Border.all(
              color: widget.onPressed == null
                  ? (isDark ? DesignTokens.borderFaintDark : DesignTokens.borderFaintLight)
                  : (isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight),
              width: DesignTokens.borderWidthDefault,
            ),
          ),
          alignment: Alignment.center,
          child: DefaultTextStyle(
            style: TextStyle(
              color: widget.onPressed == null
                  ? (isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight)
                  : (isDark ? DesignTokens.textPrimaryDark : DesignTokens.textPrimaryLight),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
