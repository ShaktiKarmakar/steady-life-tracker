import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ai/gemma_service.dart';
import 'core/ai/huggingface_config.dart';
import 'core/ai/steady_tools.dart';
import 'core/db/database.dart';
import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/daily_health_sync_provider.dart';
import 'shared/providers/theme_provider.dart';

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

  // Register all AI-callable tools (habits, tracking, settings, etc.)
  registerAllSteadyTools();

  runApp(
    ProviderScope(
      overrides: [
        // Same instance as above — databaseProvider must not create a second
        // LocalDatabase that never had initialize() (would crash notifiers).
        databaseProvider.overrideWithValue(db),
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
    final themeMode = ref.watch(themeModeProvider);

    // Trigger silent daily Health sync once per day on app start.
    ref.watch(dailyHealthSyncProvider);

    return MaterialApp.router(
      title: 'Steady',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: SteadyTheme.lightTheme,
      darkTheme: SteadyTheme.darkTheme,
      routerConfig: router,
    );
  }
}
