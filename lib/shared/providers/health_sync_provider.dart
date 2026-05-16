import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/health/health_sync_service.dart';
import 'app_state.dart';

// ---------------------------------------------------------------------------
// Toggle
// ---------------------------------------------------------------------------
final healthSyncEnabledProvider = NotifierProvider<HealthSyncToggleNotifier, bool>(
  HealthSyncToggleNotifier.new,
);

class HealthSyncToggleNotifier extends Notifier<bool> {
  late LocalDatabase _db;

  @override
  bool build() {
    _db = ref.read(databaseProvider);
    return _db.healthSyncEnabled;
  }

  Future<void> toggle() async {
    final next = !state;
    state = next;
    await _db.setHealthSyncEnabled(next);
    if (next) {
      // Pre-request permissions when enabling so the first sync is instant.
      await HealthSyncService().requestPermissions();
    }
  }
}

// ---------------------------------------------------------------------------
// One-shot sync action (returns number of imported workouts)
// ---------------------------------------------------------------------------
final healthSyncProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = HealthSyncService();
  final ok = await service.requestPermissions();
  if (!ok) return 0;

  final workouts = await service.fetchWorkouts(days: 7);
  if (workouts.isEmpty) return 0;

  final notifier = ref.read(workoutsProvider.notifier);
  var imported = 0;
  for (final w in workouts) {
    // Avoid duplicates by checking if a workout of the same type
    // started within the last minute already exists.
    final existing = ref.read(workoutsProvider).any(
          (e) =>
              e.type == w.type &&
              DateTime.now().difference(e.timestamp).inDays <= 7,
        );
    if (existing) continue;

    await notifier.addWorkout(
      w.type,
      w.durationMin,
      w.calories ?? 0,
      source: 'health_kit',
    );
    imported++;
  }
  return imported;
});
