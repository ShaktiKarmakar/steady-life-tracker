import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/ai/gemma_service.dart';
import '../../core/db/database.dart';
import '../../shared/models/models.dart';

final _uuid = Uuid();

enum HabitFilterStatus { all, unmet, met }

enum HabitFilterTime { all, now, anytime, morning, afternoon, evening }

class HabitTrackerState {
  const HabitTrackerState({
    required this.habits,
    required this.dayProgress,
    required this.profile,
    this.filterStatus = HabitFilterStatus.all,
    this.filterTime = HabitFilterTime.all,
  });

  final List<Habit> habits;
  final List<HabitDayProgress> dayProgress;
  final HabitUserProfile profile;
  final HabitFilterStatus filterStatus;
  final HabitFilterTime filterTime;

  HabitTrackerState copyWith({
    List<Habit>? habits,
    List<HabitDayProgress>? dayProgress,
    HabitUserProfile? profile,
    HabitFilterStatus? filterStatus,
    HabitFilterTime? filterTime,
  }) =>
      HabitTrackerState(
        habits: habits ?? this.habits,
        dayProgress: dayProgress ?? this.dayProgress,
        profile: profile ?? this.profile,
        filterStatus: filterStatus ?? this.filterStatus,
        filterTime: filterTime ?? this.filterTime,
      );
}

/// Selected calendar day for Today home (local date).
class HabitSelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void setDay(DateTime d) =>
      state = DateTime(d.year, d.month, d.day);
}

final habitSelectedDateProvider =
    NotifierProvider<HabitSelectedDateNotifier, DateTime>(
  HabitSelectedDateNotifier.new,
);

/// Statistics screen: when non-null, filter stats to this habit.
class HabitStatsFilterIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setId(String? id) => state = id;
}

final habitStatsFilterIdProvider =
    NotifierProvider<HabitStatsFilterIdNotifier, String?>(
  HabitStatsFilterIdNotifier.new,
);

final habitTrackerProvider =
    NotifierProvider<HabitTrackerNotifier, HabitTrackerState>(
  HabitTrackerNotifier.new,
);

class HabitTrackerNotifier extends Notifier<HabitTrackerState> {
  late LocalDatabase _db;

  @override
  HabitTrackerState build() {
    _db = ref.read(databaseProvider);
    var bundle = _db.loadHabitTracker();

    if (bundle.habits.isEmpty) {
      bundle = HabitTrackerBundle(
        version: HabitTrackerBundle.currentVersion,
        habits: [
          Habit(
            id: _uuid.v4(),
            name: 'Meditate',
            emoji: '🧘',
            kind: HabitMeasureKind.checkbox,
            accentColor: 0xFF7C6AF7,
            currentStreak: 0,
          ),
          Habit(
            id: _uuid.v4(),
            name: 'Hydrate',
            emoji: '💧',
            kind: HabitMeasureKind.quantity,
            goalAmount: 2000,
            quantityIncrement: 250,
            unitLabel: 'ml',
            accentColor: 0xFF6AF7D4,
            timeOfDay: HabitTimeOfDay.anytime,
            currentStreak: 0,
          ),
        ],
        dayProgress: [],
        profile: bundle.profile,
      );
      unawaited(_db.saveHabitTracker(bundle));
    } else {
      final recomputed = _recomputeAllStreaks(bundle.habits, bundle.dayProgress);
      if (!_sameStreaks(bundle.habits, recomputed)) {
        bundle = HabitTrackerBundle(
          version: bundle.version,
          habits: recomputed,
          dayProgress: bundle.dayProgress,
          profile: bundle.profile,
        );
        unawaited(_db.saveHabitTracker(bundle));
      }
    }

    return HabitTrackerState(
      habits: bundle.habits,
      dayProgress: bundle.dayProgress,
      profile: bundle.profile,
    );
  }

  List<Habit> get habitsSnapshot => List.unmodifiable(state.habits);

  bool _sameStreaks(List<Habit> a, List<Habit> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
      if (a[i].currentStreak != b[i].currentStreak ||
          a[i].longestStreak != b[i].longestStreak) {
        return false;
      }
    }
    return true;
  }

  Future<void> _save() async {
    await _db.saveHabitTracker(
      HabitTrackerBundle(
        version: HabitTrackerBundle.currentVersion,
        habits: state.habits,
        dayProgress: state.dayProgress,
        profile: state.profile,
      ),
    );
  }

  void setFilterStatus(HabitFilterStatus v) {
    state = state.copyWith(filterStatus: v);
  }

  void setFilterTime(HabitFilterTime v) {
    state = state.copyWith(filterTime: v);
  }

  double progressFor(String habitId, String dateKey) {
    final p = state.dayProgress.where(
      (e) => e.habitId == habitId && e.dateKey == dateKey,
    );
    if (p.isEmpty) return 0;
    return p.first.amount;
  }

  bool isMetOnDay(Habit habit, String dateKey) {
    final g = habit.goalAsAmount;
    if (g <= 0) return progressFor(habit.id, dateKey) >= 1;
    return progressFor(habit.id, dateKey) >= g - 1e-6;
  }

  bool isMetOnDate(Habit habit, DateTime day) =>
      isMetOnDay(habit, dateKeyFrom(day));

  /// Habits visible on Today for [day] after filters.
  List<Habit> filteredHabitsForDay(DateTime day) {
    final key = dateKeyFrom(day);
    return state.habits.where((h) {
      if (_filterTimeExclude(h)) return false;
      switch (state.filterStatus) {
        case HabitFilterStatus.all:
          return true;
        case HabitFilterStatus.met:
          return isMetOnDay(h, key);
        case HabitFilterStatus.unmet:
          return !isMetOnDay(h, key);
      }
    }).toList();
  }

  bool _filterTimeExclude(Habit h) {
    switch (state.filterTime) {
      case HabitFilterTime.all:
        return false;
      case HabitFilterTime.anytime:
        return h.timeOfDay != HabitTimeOfDay.anytime;
      case HabitFilterTime.morning:
        return h.timeOfDay != HabitTimeOfDay.morning;
      case HabitFilterTime.afternoon:
        return h.timeOfDay != HabitTimeOfDay.afternoon;
      case HabitFilterTime.evening:
        return h.timeOfDay != HabitTimeOfDay.evening;
      case HabitFilterTime.now:
        return !_matchesNowSlot(h);
    }
  }

  bool _matchesNowSlot(Habit h) {
    if (h.timeOfDay == HabitTimeOfDay.anytime) return true;
    final hour = DateTime.now().hour;
    return switch (h.timeOfDay) {
      HabitTimeOfDay.morning => hour >= 5 && hour < 12,
      HabitTimeOfDay.afternoon => hour >= 12 && hour < 17,
      HabitTimeOfDay.evening => hour >= 17 && hour < 24,
      HabitTimeOfDay.anytime => true,
    };
  }

  Future<void> addHabit(Habit habit) async {
    final h =
        habit.id.isEmpty ? habit.copyWith(id: _uuid.v4()) : habit;
    state = state.copyWith(habits: [...state.habits, h]);
    await _save();
  }

  Future<void> updateHabit(Habit habit) async {
    state = state.copyWith(
      habits: [
        for (final h in state.habits)
          if (h.id == habit.id) habit else h,
      ],
    );
    await _save();
  }

  Future<void> deleteHabit(String id) async {
    state = state.copyWith(
      habits: state.habits.where((h) => h.id != id).toList(),
      dayProgress: state.dayProgress.where((p) => p.habitId != id).toList(),
    );
    await _save();
  }

  Future<void> setProfile(HabitUserProfile profile) async {
    state = state.copyWith(profile: profile);
    await _save();
  }

  Future<void> setMoodForDay(String dateKey, String emoji) async {
    final next = Map<String, String>.from(state.profile.weeklyMoods);
    next[dateKey] = emoji;
    state = state.copyWith(profile: state.profile.copyWith(weeklyMoods: next));
    await _save();
  }

  Future<void> _applyProgress(
    Habit habit,
    String dateKey,
    double newAmount, {
    double? delta,
    String? memo,
    bool requestNudgeIfNewlyMet = true,
  }) async {
    final wasMet = isMetOnDay(habit, dateKey);
    final g = habit.goalAsAmount;
    final cap = g > 0 ? g * 2 : double.infinity;

    final trimmed = switch (habit.kind) {
      HabitMeasureKind.checkbox => newAmount >= 1 ? 1.0 : 0.0,
      _ => newAmount.clamp(0, cap).toDouble(),
    };

    final others =
        state.dayProgress.where((p) => !(p.habitId == habit.id && p.dateKey == dateKey)).toList();

    HabitDayProgress? existing;
    for (final p in state.dayProgress) {
      if (p.habitId == habit.id && p.dateKey == dateKey) {
        existing = p;
        break;
      }
    }

    final events = [...?existing?.events];
    if (delta != null || memo != null) {
      events.add(
        HabitLogEvent(
          at: DateTime.now(),
          delta: delta,
          memo: memo,
        ),
      );
    }

    others.add(
      HabitDayProgress(
        habitId: habit.id,
        dateKey: dateKey,
        amount: trimmed,
        events: events,
        memo: memo ?? existing?.memo,
      ),
    );

    final nextHabits = [
      for (final h in state.habits)
        if (h.id == habit.id)
          () {
            final s = _streaksForHabit(h, others);
            return h.copyWith(
              currentStreak: s.$1,
              longestStreak: s.$2,
              lastCompleted: s.$3,
            );
          }()
        else
          h,
    ];

    state = state.copyWith(dayProgress: others, habits: nextHabits);
    await _save();

    final nowMet = isMetOnDay(habit, dateKey);
    if (requestNudgeIfNewlyMet && !wasMet && nowMet) {
      await _maybeNudge(habit);
    }
  }

  Future<void> _maybeNudge(Habit habit) async {
    try {
      final nudge = await ref
          .read(gemmaServiceProvider)
          .generateHabitNudge(habit.name, habit.currentStreak);
      final next = [
        for (final h in state.habits)
          if (h.id == habit.id) h.copyWith(aiNudge: nudge) else h,
      ];
      state = state.copyWith(habits: next);
      await _save();
    } catch (e) {
      debugPrint('Habit nudge: $e');
    }
  }

  Future<void> quickLogPlus(Habit habit, DateTime day) async {
    final key = dateKeyFrom(day);
    final cur = progressFor(habit.id, key);
    switch (habit.kind) {
      case HabitMeasureKind.checkbox:
        await _applyProgress(habit, key, 1, delta: 1);
      case HabitMeasureKind.countUp:
        await _applyProgress(habit, key, cur + 1, delta: 1);
      case HabitMeasureKind.quantity:
        await _applyProgress(
          habit,
          key,
          cur + habit.quantityIncrement,
          delta: habit.quantityIncrement,
        );
      case HabitMeasureKind.timerStopwatch:
      case HabitMeasureKind.timerCountdown:
        const chunkSec = 60.0;
        await _applyProgress(habit, key, cur + chunkSec, delta: chunkSec);
    }
  }

  Future<void> setCheckboxDone(Habit habit, DateTime day, bool done) async {
    final key = dateKeyFrom(day);
    await _applyProgress(habit, key, done ? 1 : 0, delta: done ? 1 : null);
  }

  Future<void> setCount(Habit habit, DateTime day, int count) async {
    final key = dateKeyFrom(day);
    await _applyProgress(
      habit,
      key,
      count.toDouble(),
      requestNudgeIfNewlyMet: true,
    );
  }

  Future<void> addTimerSeconds(Habit habit, DateTime day, double seconds) async {
    final key = dateKeyFrom(day);
    final cur = progressFor(habit.id, key);
    await _applyProgress(habit, key, cur + seconds, delta: seconds);
  }

  Future<void> addQuantityAmount(Habit habit, DateTime day, double amount) async {
    final key = dateKeyFrom(day);
    final cur = progressFor(habit.id, key);
    await _applyProgress(habit, key, cur + amount, delta: amount);
  }

  Future<void> appendMemo(Habit habit, DateTime day, String memo) async {
    final key = dateKeyFrom(day);
    final cur = progressFor(habit.id, key);
    await _applyProgress(habit, key, cur, memo: memo);
  }

  /// Replace streak fields from day progress (public for migration).
  List<Habit> _recomputeAllStreaks(
    List<Habit> habits,
    List<HabitDayProgress> progress,
  ) {
    return [
      for (final h in habits)
        () {
          final s = _streaksForHabit(h, progress);
          return h.copyWith(
            currentStreak: s.$1,
            longestStreak: s.$2,
            lastCompleted: s.$3,
          );
        }(),
    ];
  }

  (int current, int longest, DateTime?) _streaksForHabit(
    Habit habit,
    List<HabitDayProgress> progress,
  ) {
    final byDay = <String, double>{};
    for (final p in progress.where((e) => e.habitId == habit.id)) {
      byDay[p.dateKey] = p.amount;
    }

    bool metKey(String key) {
      final g = habit.goalAsAmount;
      final a = byDay[key] ?? 0;
      if (habit.kind == HabitMeasureKind.checkbox) return a >= 1;
      if (g <= 0) return a >= 1;
      return a >= g - 1e-6;
    }

    final metDates = <DateTime>[];
    for (final e in byDay.entries) {
      if (metKey(e.key)) {
        metDates.add(parseDateKey(e.key));
      }
    }
    metDates.sort((a, b) => a.compareTo(b));

    var longestRun = 0;
    if (metDates.isNotEmpty) {
      var run = 1;
      longestRun = 1;
      for (var i = 1; i < metDates.length; i++) {
        final prev = metDates[i - 1];
        final cur = metDates[i];
        if (cur.difference(prev).inDays == 1) {
          run++;
          if (run > longestRun) longestRun = run;
        } else if (cur.difference(prev).inDays > 1) {
          run = 1;
        }
      }
    }

    var current = 0;
    var d = _stripTime(DateTime.now());
    if (!metKey(dateKeyFrom(d))) {
      d = d.subtract(const Duration(days: 1));
    }
    while (metKey(dateKeyFrom(d))) {
      current++;
      d = d.subtract(const Duration(days: 1));
    }

    final lastComp = metDates.isEmpty ? null : metDates.last;

    return (current, longestRun, lastComp);
  }

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);
}
