import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ai/gemma_service.dart';
import 'core/ai/huggingface_config.dart';
import 'core/db/database.dart';
import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  final db = LocalDatabase();
  await db.initialize();

  // Initializes FlutterGemma (required before installModel / isModelInstalled).
  // Applies optional HUGGINGFACE_TOKEN / prefs token for gated URLs.
  await HuggingFaceConfig.applyToFlutterGemma();

  final gemmaProbe = GemmaService();
  await gemmaProbe.initialize();
  var modelInstalled = false;
  try {
    modelInstalled = await gemmaProbe.isModelInstalled();
  } catch (_) {}

  final onboardingDone = db.onboardingComplete;
  final skippedAiDownload = db.aiDownloadSkipped;

  // First launch → onboarding. Returning users without a model (who didn't skip) → onboarding
  // so the AI download step is reachable (see OnboardingScreen._checkAlreadyDone).
  final initialLocation = !onboardingDone
      ? '/onboarding'
      : (!modelInstalled && !skippedAiDownload)
          ? '/onboarding'
          : '/dashboard';

  // Note: Weights + flutter_gemma metadata live in the app container. A full
  // reinstall (new bundle id, `flutter install`, deleting the app, or some CI
  // clean builds) wipes that — only hot reload / normal `flutter run` keeps data.
  runApp(
    ProviderScope(
      overrides: [
        // Same instance as above — databaseProvider must not create a second
        // LocalDatabase that never had initialize() (would crash notifiers).
        databaseProvider.overrideWithValue(db),
        initialLocationProvider.overrideWithValue(initialLocation),
      ],
      child: const SteadyApp(),
    ),
  );
}

class SteadyApp extends ConsumerWidget {
  const SteadyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Steady',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
