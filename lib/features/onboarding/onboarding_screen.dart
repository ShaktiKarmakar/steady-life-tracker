import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ai/gemma_service.dart';
import '../../core/db/database.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass_card.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  double _progress = 0;
  bool _downloading = false;
  String _status =
      'Tap download to add on-device AI. Wi‑Fi required (~2.6 GB).';
  bool _modelReady = false;

  @override
  void initState() {
    super.initState();
    _checkAlreadyDone();
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
    if (db.onboardingComplete &&
        (_modelReady || db.aiDownloadSkipped)) {
      context.go('/dashboard');
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
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Icon(Icons.auto_awesome, size: 56, color: Color(0xFF7C6AF7)),
              const SizedBox(height: 20),
              const Text(
                'Welcome to Steady',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your private second brain. AI runs on your device after a one-time download.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 28),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI model',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Download runs once over HTTPS and stays on this device. '
                      'Use Wi‑Fi and leave the app open until it finishes.',
                      style: TextStyle(fontSize: 13, height: 1.35, color: Colors.white70),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 8,
                        color: AppColors.accentPurple,
                        backgroundColor: Colors.white10,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${(_progress * 100).toInt()}% — $_status',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _downloading
                      ? null
                      : () => _finish(skippedAiDownload: true),
                  child: const Text('Skip for now'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
