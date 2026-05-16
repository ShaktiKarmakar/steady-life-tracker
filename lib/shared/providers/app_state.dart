import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../features/habits/habit_tracker_notifier.dart';
import '../models/models.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------
final habitsProvider = Provider<List<Habit>>(
  (ref) => ref.watch(habitTrackerProvider).habits,
);

final foodEntriesProvider =
    NotifierProvider<FoodNotifier, List<FoodEntry>>(FoodNotifier.new);

final workoutsProvider =
    NotifierProvider<WorkoutsNotifier, List<WorkoutEntry>>(WorkoutsNotifier.new);

// Select-based providers so DashboardScreen rebuilds only when today's values change.
final todayFoodEntriesProvider = Provider<List<FoodEntry>>((ref) {
  final now = DateTime.now();
  return ref.watch(foodEntriesProvider).where((e) {
    return e.timestamp.year == now.year &&
        e.timestamp.month == now.month &&
        e.timestamp.day == now.day;
  }).toList();
});

final todayCaloriesProvider = Provider<int>((ref) {
  return ref.watch(todayFoodEntriesProvider)
      .fold<int>(0, (s, e) => s + e.totalCalories);
});

final todayProteinProvider = Provider<double>((ref) {
  return ref.watch(todayFoodEntriesProvider)
      .fold<double>(0, (s, e) => s + e.totalProteinG);
});

final todayCarbsProvider = Provider<double>((ref) {
  return ref.watch(todayFoodEntriesProvider)
      .fold<double>(0, (s, e) => s + e.totalCarbsG);
});

final todayFatProvider = Provider<double>((ref) {
  return ref.watch(todayFoodEntriesProvider)
      .fold<double>(0, (s, e) => s + e.totalFatG);
});

final todayWorkoutMinutesProvider = Provider<int>((ref) {
  final now = DateTime.now();
  return ref.watch(workoutsProvider)
      .where((e) =>
          e.timestamp.year == now.year &&
          e.timestamp.month == now.month &&
          e.timestamp.day == now.day)
      .fold<int>(0, (s, e) => s + e.durationMin);
});

// ---------------------------------------------------------------------------
// Food Entries
// ---------------------------------------------------------------------------
class FoodNotifier extends Notifier<List<FoodEntry>> {
  late LocalDatabase _db;

  @override
  List<FoodEntry> build() {
    _db = ref.read(databaseProvider);
    return _db.loadFoodEntries();
  }

  Future<void> _save() => _db.saveFoodEntries(state);

  Future<void> logEntry(FoodEntry entry) async {
    state = [...state, entry];
    await _save();
  }

  Future<void> logWithAi(FoodAnalysisResult result, {
    required MealType mealType,
    String? photoPath,
  }) async {
    final entry = result.toFoodEntry(
      id: _uuid.v4(),
      mealType: mealType,
      photoPath: photoPath,
      timestamp: DateTime.now(),
    );
    state = [...state, entry];
    await _save();
  }

  Future<void> addManual({
    required MealType mealType,
    required String description,
    required int calories,
    int protein = 0,
    int carbs = 0,
    int fat = 0,
  }) async {
    final entry = FoodEntry(
      id: _uuid.v4(),
      mealType: mealType,
      photoPath: null,
      totalCalories: calories,
      totalProteinG: protein.toDouble(),
      totalCarbsG: carbs.toDouble(),
      totalFatG: fat.toDouble(),
      overallConfidence: ConfidenceLevel.high,
      confidenceNote: null,
      items: [
        FoodItem(
          name: description,
          estimatedWeightG: 0,
          calories: calories,
          proteinG: protein.toDouble(),
          carbsG: carbs.toDouble(),
          fatG: fat.toDouble(),
          confidence: ConfidenceLevel.high,
          cookingMethod: 'unknown',
          portionReference: 'manual entry',
        ),
      ],
      timestamp: DateTime.now(),
      isManuallyEntered: true,
    );
    state = [...state, entry];
    await _save();
  }

  Future<void> deleteEntry(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _save();
  }

  Future<void> updateEntry(FoodEntry entry) async {
    state = state.map((e) => e.id == entry.id ? entry : e).toList();
    await _save();
  }

  Future<void> updateMealType(String entryId, MealType newType) async {
    final index = state.indexWhere((e) => e.id == entryId);
    if (index == -1) return;
    final updated = state[index].copyWith(mealType: newType);
    state = [...state.sublist(0, index), updated, ...state.sublist(index + 1)];
    await _save();
  }
}

// ---------------------------------------------------------------------------
// Workouts
// ---------------------------------------------------------------------------
class WorkoutsNotifier extends Notifier<List<WorkoutEntry>> {
  late LocalDatabase _db;

  @override
  List<WorkoutEntry> build() {
    _db = ref.read(databaseProvider);
    return _db.loadWorkouts();
  }

  Future<void> _save() => _db.saveWorkouts(state);

  Future<void> addWorkout(String type, int durationMin, int calories, {String source = 'manual'}) async {
    state = [...state, WorkoutEntry(
      id: _uuid.v4(),
      type: type,
      durationMin: durationMin,
      calories: calories,
      source: source,
      timestamp: DateTime.now(),
    )];
    await _save();
  }

  Future<void> deleteEntry(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _save();
  }
}
