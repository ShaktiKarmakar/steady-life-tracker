import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/ai/gemma_service.dart';
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
final caloriesProvider = NotifierProvider<CaloriesNotifier, List<CalorieEntry>>(CaloriesNotifier.new);
final workoutsProvider = NotifierProvider<WorkoutsNotifier, List<WorkoutEntry>>(WorkoutsNotifier.new);
final notesProvider = NotifierProvider<NotesNotifier, List<NoteItem>>(NotesNotifier.new);
final reelsProvider = NotifierProvider<ReelsNotifier, List<SavedReel>>(ReelsNotifier.new);
final plannerTasksProvider = NotifierProvider<PlannerTasksNotifier, List<String>>(PlannerTasksNotifier.new);

// ---------------------------------------------------------------------------
// Calories
// ---------------------------------------------------------------------------
class CaloriesNotifier extends Notifier<List<CalorieEntry>> {
  late LocalDatabase _db;

  @override
  List<CalorieEntry> build() {
    _db = ref.read(databaseProvider);
    return _db.loadCalories();
  }

  Future<void> _save() => _db.saveCalories(state);

  Future<void> logWithAi(String description) async {
    String jsonString;
    try {
      jsonString = await ref.read(gemmaServiceProvider).analyzeFood(description);
    } catch (e) {
      debugPrint('AI food analysis error: $e');
      jsonString = '{}';
    }
    final parsed = jsonDecode(jsonString) as Map<String, dynamic>? ?? {};
    state = [
      ...state,
      CalorieEntry(
        id: _uuid.v4(),
        description: description,
        calories: (parsed['calories'] as num?)?.toInt() ?? 0,
        protein: (parsed['protein_g'] as num?)?.toInt() ?? 0,
        carbs: (parsed['carbs_g'] as num?)?.toInt() ?? 0,
        fat: (parsed['fat_g'] as num?)?.toInt() ?? 0,
        timestamp: DateTime.now(),
      ),
    ];
    await _save();
  }

  Future<void> addManual(int calories, int protein, int carbs, int fat, String description) async {
    state = [...state, CalorieEntry(
      id: _uuid.v4(),
      description: description,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      timestamp: DateTime.now(),
    )];
    await _save();
  }

  Future<void> deleteEntry(String id) async {
    state = state.where((e) => e.id != id).toList();
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

// ---------------------------------------------------------------------------
// Notes
// ---------------------------------------------------------------------------
class NotesNotifier extends Notifier<List<NoteItem>> {
  late LocalDatabase _db;

  @override
  List<NoteItem> build() {
    _db = ref.read(databaseProvider);
    return _db.loadNotes();
  }

  Future<void> _save() => _db.saveNotes(state);

  Future<void> addNote(String title, String body) async {
    String? summary;
    try {
      summary = await ref.read(gemmaServiceProvider).ask('Summarize this note in one sentence: $body');
    } catch (e) {
      debugPrint('AI summary error: $e');
    }
    state = [...state, NoteItem(
      id: _uuid.v4(),
      title: title,
      body: body,
      aiSummary: summary,
      createdAt: DateTime.now(),
    )];
    await _save();
  }

  Future<void> deleteNote(String id) async {
    state = state.where((n) => n.id != id).toList();
    await _save();
  }
}

// ---------------------------------------------------------------------------
// Reels
// ---------------------------------------------------------------------------
class ReelsNotifier extends Notifier<List<SavedReel>> {
  late LocalDatabase _db;

  @override
  List<SavedReel> build() {
    _db = ref.read(databaseProvider);
    return _db.loadReels();
  }

  Future<void> _save() => _db.saveReels(state);

  Future<void> addReel(String url, String caption) async {
    List<String> tags = [];
    try {
      final tagsRaw = await ref.read(gemmaServiceProvider).tagReel(caption);
      final parsed = jsonDecode(tagsRaw);
      if (parsed is List) {
        tags = parsed.map((item) => item.toString()).toList();
      }
    } catch (e) {
      debugPrint('AI tagging error: $e');
      tags = ['inspo'];
    }
    state = [...state, SavedReel(
      id: _uuid.v4(),
      url: url,
      caption: caption,
      aiTags: tags,
      savedAt: DateTime.now(),
    )];
    await _save();
  }

  Future<void> deleteReel(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _save();
  }
}

// ---------------------------------------------------------------------------
// Planner Tasks
// ---------------------------------------------------------------------------
class PlannerTasksNotifier extends Notifier<List<String>> {
  late LocalDatabase _db;

  @override
  List<String> build() {
    _db = ref.read(databaseProvider);
    return _db.loadPlannerTasks();
  }

  Future<void> _save() => _db.savePlannerTasks(state);

  Future<void> addTask(String task) async {
    state = [...state, task];
    await _save();
  }

  Future<void> removeTask(String task) async {
    state = state.where((t) => t != task).toList();
    await _save();
  }
}
