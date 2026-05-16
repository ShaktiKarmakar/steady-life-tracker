import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../shared/models/food_models.dart';

final nutritionGoalsProvider = Provider<NutritionGoals>((ref) {
  final db = ref.watch(databaseProvider);
  return db.loadNutritionGoals();
});

final dailyGoalsProvider = Provider.family<NutritionGoals, DateTime>((ref, date) {
  final db = ref.watch(databaseProvider);
  final key = _dateKey(date);
  return db.loadGoalsForDate(key);
});

final nutritionGoalsNotifierProvider =
    AsyncNotifierProvider<NutritionGoalsNotifier, NutritionGoals>(
  NutritionGoalsNotifier.new,
);

class NutritionGoalsNotifier extends AsyncNotifier<NutritionGoals> {
  late LocalDatabase _db;

  @override
  Future<NutritionGoals> build() async {
    _db = ref.read(databaseProvider);
    return _db.loadNutritionGoals();
  }

  Future<void> updateGoals(NutritionGoals goals) async {
    state = const AsyncLoading();
    await _db.saveNutritionGoals(goals);
    state = AsyncData(goals);
  }

  Future<void> resetToDefaults() async {
    await updateGoals(NutritionGoals.defaults());
  }

  Future<void> overrideForDate(DateTime date, NutritionGoals goals) async {
    await _db.setGoalOverride(_dateKey(date), goals);
    // Refresh state so listeners pick up the change
    final current = _db.loadNutritionGoals();
    state = AsyncData(current);
  }

  Future<void> clearOverrideForDate(DateTime date) async {
    await _db.clearGoalOverride(_dateKey(date));
    final current = _db.loadNutritionGoals();
    state = AsyncData(current);
  }
}

String _dateKey(DateTime dt) {
  return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
