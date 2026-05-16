import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/models/models.dart';

final databaseProvider = Provider<LocalDatabase>((ref) => LocalDatabase());

/// File-based database with in-memory caching and debounced writes.
/// Replaces SharedPreferences for structured data storage.
class LocalDatabase {
  Directory? _docsDir;
  final _cache = <String, dynamic>{};
  final _pendingSaves = <String, Timer>{};
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _docsDir = await getApplicationDocumentsDirectory();
    await _loadAll();
    _initialized = true;
  }

  Future<void> _loadAll() async {
    if (_docsDir == null) return;
    final files = await _docsDir!.list().toList();
    for (final file in files.whereType<File>()) {
      final name = file.path.split(Platform.pathSeparator).last;
      if (name.endsWith('.json')) {
        try {
          final content = await file.readAsString();
          final key = name.replaceAll('.json', '');
          _cache[key] = jsonDecode(content);
        } catch (e) {
          debugPrint('[LocalDatabase] Failed to load ${file.path}: $e');
        }
      }
    }
  }

  dynamic _read(String key) => _cache[key];

  void _write(String key, dynamic value) {
    _cache[key] = value;
    _debouncedSave(key);
  }

  void _debouncedSave(String key) {
    _pendingSaves[key]?.cancel();
    _pendingSaves[key] = Timer(const Duration(milliseconds: 500), () {
      _flush(key);
    });
  }

  Future<void> _flush(String key) async {
    if (_docsDir == null) return;
    final file = File('${_docsDir!.path}/$key.json');
    try {
      final value = _cache[key];
      if (value == null) {
        if (await file.exists()) await file.delete();
        return;
      }
      await file.writeAsString(
        jsonEncode(value),
        flush: true,
      );
    } catch (e) {
      debugPrint('[LocalDatabase] Failed to save $key: $e');
    }
  }

  Future<void> flushAll() async {
    for (final key in _cache.keys.toList()) {
      await _flush(key);
    }
  }

  // ---------------------------------------------------------------------------
  // Habit Tracker
  // ---------------------------------------------------------------------------
  static const _habitTrackerKey = 'habit_tracker_bundle';

  HabitTrackerBundle loadHabitTracker() {
    final raw = _read(_habitTrackerKey);
    if (raw != null && raw is Map<String, dynamic>) {
      return HabitTrackerBundle.fromJson(raw);
    }

    // Legacy migration from old SharedPreferences format
    // (handled once, then overwritten by file format)
    return HabitTrackerBundle(
      habits: [],
      dayProgress: [],
      profile: const HabitUserProfile(),
    );
  }

  Future<void> saveHabitTracker(HabitTrackerBundle bundle) async {
    _write(_habitTrackerKey, bundle.toJson());
  }

  // ---------------------------------------------------------------------------
  // Food Entries (replaces flat Calories)
  // ---------------------------------------------------------------------------
  static const _foodEntriesKey = 'food_entries';
  static const _legacyCaloriesKey = 'calories';

  List<FoodEntry> loadFoodEntries() {
    final raw = _read(_foodEntriesKey);
    if (raw is List) {
      return raw.map((r) => FoodEntry.fromJson(r as Map<String, dynamic>)).toList();
    }
    // Migration: try to load legacy flat CalorieEntry format
    final legacyRaw = _read(_legacyCaloriesKey);
    if (legacyRaw is List) {
      final migrated = _migrateLegacyCalories(legacyRaw);
      // Save migrated so next load uses new key
      _write(_foodEntriesKey, migrated.map((e) => e.toJson()).toList());
      return migrated;
    }
    return [];
  }

  Future<void> saveFoodEntries(List<FoodEntry> items) async {
    _write(_foodEntriesKey, items.map((e) => e.toJson()).toList());
  }

  /// Converts legacy flat CalorieEntry records into structured FoodEntries.
  /// Users can later re-categorize meal types via the UI.
  List<FoodEntry> _migrateLegacyCalories(List<dynamic> raw) {
    return raw.map((json) {
      final map = json as Map<String, dynamic>;
      // Detect old CalorieEntry format: has 'description' but no 'items'
      if (map.containsKey('description') && !map.containsKey('items')) {
        final ts = DateTime.parse(map['timestamp'] as String);
        return FoodEntry(
          id: map['id'] as String? ?? '',
          mealType: _inferMealTypeFromTime(ts),
          photoPath: null,
          totalCalories: (map['calories'] as num?)?.toInt() ?? 0,
          totalProteinG: (map['protein'] as num?)?.toDouble() ?? 0,
          totalCarbsG: (map['carbs'] as num?)?.toDouble() ?? 0,
          totalFatG: (map['fat'] as num?)?.toDouble() ?? 0,
          overallConfidence: ConfidenceLevel.low,
          confidenceNote: 'Migrated from manual entry',
          items: [
            FoodItem(
              name: map['description'] as String? ?? 'Unknown',
              estimatedWeightG: 0,
              calories: (map['calories'] as num?)?.toInt() ?? 0,
              proteinG: (map['protein'] as num?)?.toDouble() ?? 0,
              carbsG: (map['carbs'] as num?)?.toDouble() ?? 0,
              fatG: (map['fat'] as num?)?.toDouble() ?? 0,
              confidence: ConfidenceLevel.low,
              cookingMethod: 'unknown',
              portionReference: 'migrated',
            ),
          ],
          timestamp: ts,
          isManuallyEntered: true,
        );
      }
      // Already new format
      return FoodEntry.fromJson(map);
    }).toList();
  }

  static MealType _inferMealTypeFromTime(DateTime dt) {
    final hour = dt.hour;
    if (hour >= 4 && hour < 11) return MealType.breakfast;
    if (hour >= 11 && hour < 15) return MealType.lunch;
    if (hour >= 15 && hour < 18) return MealType.snack;
    return MealType.dinner;
  }

  // ---------------------------------------------------------------------------
  // Workouts
  // ---------------------------------------------------------------------------
  static const _workoutsKey = 'workouts';

  List<WorkoutEntry> loadWorkouts() {
    final raw = _read(_workoutsKey);
    if (raw is! List) return [];
    return raw.map((r) => WorkoutEntry.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> saveWorkouts(List<WorkoutEntry> items) async {
    _write(_workoutsKey, items.map((e) => e.toJson()).toList());
  }

  // ---------------------------------------------------------------------------
  // Nutrition Goals
  // ---------------------------------------------------------------------------
  static const _nutritionGoalsKey = 'nutrition_goals';
  static const _dailyGoalOverridesKey = 'daily_goal_overrides';

  NutritionGoals loadNutritionGoals() {
    final raw = _read(_nutritionGoalsKey);
    if (raw is Map<String, dynamic>) {
      return NutritionGoals.fromJson(raw);
    }
    return NutritionGoals.defaults();
  }

  Future<void> saveNutritionGoals(NutritionGoals goals) async {
    _write(_nutritionGoalsKey, goals.toJson());
  }

  /// Returns daily override if one exists for [dateKey] (yyyy-MM-dd),
  /// otherwise falls back to default goals.
  NutritionGoals loadGoalsForDate(String dateKey) {
    final overrides = _read(_dailyGoalOverridesKey);
    if (overrides is Map<String, dynamic>) {
      final day = overrides[dateKey];
      if (day is Map<String, dynamic>) {
        return NutritionGoals.fromJson(day);
      }
    }
    return loadNutritionGoals();
  }

  Future<void> setGoalOverride(String dateKey, NutritionGoals goals) async {
    final current = _read(_dailyGoalOverridesKey) as Map<String, dynamic>? ?? {};
    _write(_dailyGoalOverridesKey, {...current, dateKey: goals.toJson()});
  }

  Future<void> clearGoalOverride(String dateKey) async {
    final current = _read(_dailyGoalOverridesKey) as Map<String, dynamic>? ?? {};
    final updated = Map<String, dynamic>.from(current)..remove(dateKey);
    _write(_dailyGoalOverridesKey, updated);
  }

  // ---------------------------------------------------------------------------
  // Onboarding flag
  // ---------------------------------------------------------------------------
  static const _onboardingKey = 'onboarding_state';

  bool get onboardingComplete {
    final raw = _read(_onboardingKey);
    if (raw is Map<String, dynamic>) {
      return raw['complete'] == true;
    }
    return false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    final current = _read(_onboardingKey) as Map<String, dynamic>? ?? {};
    _write(_onboardingKey, {...current, 'complete': value});
  }

  bool get aiDownloadSkipped {
    final raw = _read(_onboardingKey);
    if (raw is Map<String, dynamic>) {
      return raw['aiSkipped'] == true;
    }
    return false;
  }

  Future<void> setAiDownloadSkipped(bool value) async {
    final current = _read(_onboardingKey) as Map<String, dynamic>? ?? {};
    _write(_onboardingKey, {...current, 'aiSkipped': value});
  }

  // ---------------------------------------------------------------------------
  // Theme mode
  // ---------------------------------------------------------------------------
  static const _themeKey = 'theme_mode';

  ThemeMode get themeMode {
    final raw = _read(_themeKey);
    if (raw is String) {
      return ThemeMode.values.byName(raw);
    }
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _write(_themeKey, mode.name);
  }

  // ---------------------------------------------------------------------------
  // Health sync toggle
  // ---------------------------------------------------------------------------
  static const _healthSyncKey = 'health_sync_enabled';

  bool get healthSyncEnabled {
    final raw = _read(_healthSyncKey);
    return raw == true;
  }

  Future<void> setHealthSyncEnabled(bool value) async {
    _write(_healthSyncKey, value);
  }

  // ---------------------------------------------------------------------------
  // Last background health sync date
  // ---------------------------------------------------------------------------
  static const _lastHealthSyncKey = 'last_health_sync';

  String? get lastHealthSyncDate {
    final raw = _read(_lastHealthSyncKey);
    if (raw is String) return raw;
    return null;
  }

  Future<void> setLastHealthSyncDate(String dateKey) async {
    _write(_lastHealthSyncKey, dateKey);
  }
}
