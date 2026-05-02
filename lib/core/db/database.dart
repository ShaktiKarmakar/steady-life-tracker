import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/models.dart';

final databaseProvider = Provider<LocalDatabase>((ref) => LocalDatabase());

class LocalDatabase {
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _store {
    if (_prefs == null) throw StateError('LocalDatabase not initialized');
    return _prefs!;
  }

  static const _habitTrackerKey = 'habit_tracker_bundle';
  static const _legacyHabitsKey = 'habits';

  /// Full habit mini-app state (v2). Migrates legacy `habits` string list on first read.
  HabitTrackerBundle loadHabitTracker() {
    final rawBundle = _store.getString(_habitTrackerKey);
    if (rawBundle != null && rawBundle.isNotEmpty) {
      final decoded = jsonDecode(rawBundle) as Map<String, dynamic>;
      return HabitTrackerBundle.fromJson(decoded);
    }

    final legacy = _store.getStringList(_legacyHabitsKey) ?? [];
    if (legacy.isEmpty) {
      return HabitTrackerBundle(habits: [], dayProgress: []);
    }

    final habits = legacy
        .map((r) => Habit.fromJson(jsonDecode(r) as Map<String, dynamic>))
        .toList();

    final merged = <String, HabitDayProgress>{};
    for (final h in habits) {
      for (final d in h.completionHistory) {
        final key = '${h.id}|${dateKeyFrom(d)}';
        final goalAmt = h.goalAsAmount;
        final existing = merged[key];
        if (existing == null || existing.amount < goalAmt) {
          merged[key] = HabitDayProgress(
            habitId: h.id,
            dateKey: dateKeyFrom(d),
            amount: goalAmt,
            events: [HabitLogEvent(at: d, delta: goalAmt)],
          );
        }
      }
    }

    final bundle = HabitTrackerBundle(
      version: HabitTrackerBundle.currentVersion,
      habits: habits,
      dayProgress: merged.values.toList(),
      profile: const HabitUserProfile(),
    );
    // Persist migrated bundle once (best-effort; ignore sync errors in tests).
    unawaited(saveHabitTracker(bundle)); // persist migration
    return bundle;
  }

  Future<void> saveHabitTracker(HabitTrackerBundle bundle) async {
    await _store.setString(_habitTrackerKey, jsonEncode(bundle.toJson()));
  }

  // Calories
  List<CalorieEntry> loadCalories() {
    final raw = _store.getStringList('calories') ?? [];
    return raw.map((r) => CalorieEntry.fromJson(jsonDecode(r))).toList();
  }

  Future<void> saveCalories(List<CalorieEntry> items) async {
    final raw = items.map((e) => jsonEncode(e.toJson())).toList();
    await _store.setStringList('calories', raw);
  }

  // Workouts
  List<WorkoutEntry> loadWorkouts() {
    final raw = _store.getStringList('workouts') ?? [];
    return raw.map((r) => WorkoutEntry.fromJson(jsonDecode(r))).toList();
  }

  Future<void> saveWorkouts(List<WorkoutEntry> items) async {
    final raw = items.map((e) => jsonEncode(e.toJson())).toList();
    await _store.setStringList('workouts', raw);
  }

  // Notes
  List<NoteItem> loadNotes() {
    final raw = _store.getStringList('notes') ?? [];
    return raw.map((r) => NoteItem.fromJson(jsonDecode(r))).toList();
  }

  Future<void> saveNotes(List<NoteItem> items) async {
    final raw = items.map((e) => jsonEncode(e.toJson())).toList();
    await _store.setStringList('notes', raw);
  }

  // Reels
  List<SavedReel> loadReels() {
    final raw = _store.getStringList('reels') ?? [];
    return raw.map((r) => SavedReel.fromJson(jsonDecode(r))).toList();
  }

  Future<void> saveReels(List<SavedReel> items) async {
    final raw = items.map((e) => jsonEncode(e.toJson())).toList();
    await _store.setStringList('reels', raw);
  }

  // Planner tasks
  List<String> loadPlannerTasks() {
    return _store.getStringList('planner_tasks') ?? ['Morning review', 'Workout', 'Email responses'];
  }

  Future<void> savePlannerTasks(List<String> tasks) async {
    await _store.setStringList('planner_tasks', tasks);
  }

  // Onboarding flag
  bool get onboardingComplete => _store.getBool('onboarding_complete') ?? false;

  Future<void> setOnboardingComplete(bool value) async {
    await _store.setBool('onboarding_complete', value);
  }

  /// User tapped "Skip for now" on the AI download step — don't force onboarding for model.
  bool get aiDownloadSkipped => _store.getBool('ai_download_skipped') ?? false;

  Future<void> setAiDownloadSkipped(bool value) async {
    await _store.setBool('ai_download_skipped', value);
  }
}
