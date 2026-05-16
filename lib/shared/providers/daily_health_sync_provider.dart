import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/health/health_sync_service.dart';
import '../models/models.dart';
import 'app_state.dart';

/// Runs a silent Health sync once per day when the app starts.
/// Returns the number of newly imported workouts.
final dailyHealthSyncProvider = FutureProvider.autoDispose<int>((ref) async {
  final db = ref.read(databaseProvider);

  // Only run if the user has enabled auto-import.
  if (!db.healthSyncEnabled) return 0;

  // Only run once per calendar day.
  final todayKey = dateKeyFrom(DateTime.now());
  if (db.lastHealthSyncDate == todayKey) return 0;

  final service = HealthSyncService();
  final authorized = await service.requestPermissions();
  if (!authorized) return 0;

  final workouts = await service.fetchWorkouts(days: 7);
  if (workouts.isEmpty) {
    await db.setLastHealthSyncDate(todayKey);
    return 0;
  }

  final notifier = ref.read(workoutsProvider.notifier);
  final existing = ref.read(workoutsProvider);
  var imported = 0;

  for (final w in workouts) {
    // Skip duplicates: same type within last 7 days.
    final isDup = existing.any((e) =>
        e.type == w.type &&
        DateTime.now().difference(e.timestamp).inDays <= 7 &&
        (e.durationMin - w.durationMin).abs() <= 2);
    if (isDup) continue;

    await notifier.addWorkout(w.type, w.durationMin, w.calories ?? 0, source: 'health_kit');
    imported++;
  }

  await db.setLastHealthSyncDate(todayKey);
  debugPrint('[DailyHealthSync] Imported $imported workouts.');
  return imported;
});
