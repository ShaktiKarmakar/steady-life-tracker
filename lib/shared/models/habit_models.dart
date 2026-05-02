import 'package:flutter/material.dart';

/// How a habit is measured and logged.
enum HabitMeasureKind {
  /// Simple done / not done.
  checkbox,

  /// Integer goal (e.g. vitamins 1/day).
  countUp,

  /// Additive amount (e.g. ml water).
  quantity,

  /// Elapsed time counting up toward a duration goal.
  timerStopwatch,

  /// Count down from goal duration.
  timerCountdown,
}

/// Preferred time bucket for filtering (not enforcement).
enum HabitTimeOfDay {
  anytime,
  morning,
  afternoon,
  evening,
}

/// Single log line for "Done today" and memo trail.
class HabitLogEvent {
  HabitLogEvent({
    required this.at,
    this.delta,
    this.memo,
  });

  final DateTime at;
  final double? delta;
  final String? memo;

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'delta': delta,
        'memo': memo,
      };

  factory HabitLogEvent.fromJson(Map<String, dynamic> json) => HabitLogEvent(
        at: DateTime.parse(json['at'] as String),
        delta: (json['delta'] as num?)?.toDouble(),
        memo: json['memo'] as String?,
      );
}

/// Aggregated progress for one habit on one calendar day (local).
class HabitDayProgress {
  HabitDayProgress({
    required this.habitId,
    required this.dateKey,
    required this.amount,
    this.events = const [],
    this.memo,
  });

  final String habitId;

  /// yyyy-MM-dd in local time.
  final String dateKey;

  /// Interpretation depends on [Habit.kind]:
  /// checkbox: >= 1 means done
  /// countUp: count toward goal
  /// quantity: sum (e.g. ml)
  /// timers: accumulated seconds
  final double amount;

  final List<HabitLogEvent> events;
  final String? memo;

  Map<String, dynamic> toJson() => {
        'habitId': habitId,
        'dateKey': dateKey,
        'amount': amount,
        'events': events.map((e) => e.toJson()).toList(),
        'memo': memo,
      };

  factory HabitDayProgress.fromJson(Map<String, dynamic> json) =>
      HabitDayProgress(
        habitId: json['habitId'] as String,
        dateKey: json['dateKey'] as String,
        amount: (json['amount'] as num).toDouble(),
        events: (json['events'] as List<dynamic>? ?? [])
            .map((e) => HabitLogEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        memo: json['memo'] as String?,
      );

  HabitDayProgress copyWith({
    double? amount,
    List<HabitLogEvent>? events,
    String? memo,
  }) =>
      HabitDayProgress(
        habitId: habitId,
        dateKey: dateKey,
        amount: amount ?? this.amount,
        events: events ?? this.events,
        memo: memo ?? this.memo,
      );
}

class HabitUserProfile {
  const HabitUserProfile({
    this.displayName = 'You',
    this.weeklyMoods = const {},
    this.stressLevel,
  });

  final String displayName;

  /// dateKey -> emoji string
  final Map<String, String> weeklyMoods;

  /// 0–1 scale, optional
  final double? stressLevel;

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'weeklyMoods': weeklyMoods,
        'stressLevel': stressLevel,
      };

  factory HabitUserProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return HabitUserProfile();
    return HabitUserProfile(
      displayName: json['displayName'] as String? ?? 'You',
      weeklyMoods: (json['weeklyMoods'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as String)),
      stressLevel: (json['stressLevel'] as num?)?.toDouble(),
    );
  }

  HabitUserProfile copyWith({
    String? displayName,
    Map<String, String>? weeklyMoods,
    double? stressLevel,
  }) =>
      HabitUserProfile(
        displayName: displayName ?? this.displayName,
        weeklyMoods: weeklyMoods ?? this.weeklyMoods,
        stressLevel: stressLevel ?? this.stressLevel,
      );
}

class Habit {
  Habit({
    required this.id,
    required this.name,
    required this.emoji,
    this.kind = HabitMeasureKind.checkbox,
    this.goalSeconds = 0,
    this.goalCount = 1,
    this.goalAmount = 0,
    this.quantityIncrement = 1,
    this.unitLabel = '',
    this.accentColor = 0xFF7C6AF7,
    this.timeOfDay = HabitTimeOfDay.anytime,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCompleted,
    this.completionHistory = const [],
    this.aiNudge,
    this.isFavorite = false,
    this.note,
  });

  final String id;
  final String name;
  final String emoji;
  final HabitMeasureKind kind;

  /// Duration goal for [timerStopwatch] / [timerCountdown] (seconds).
  final int goalSeconds;

  /// Goal for [countUp].
  final int goalCount;

  /// Goal for [quantity] (e.g. 3000 ml).
  final double goalAmount;

  /// Default add increment for quantity habits.
  final double quantityIncrement;

  final String unitLabel;

  /// ARGB (e.g. 0xFF7C6AF7).
  final int accentColor;
  final HabitTimeOfDay timeOfDay;

  final int currentStreak;
  final int longestStreak;
  final DateTime? lastCompleted;
  final List<DateTime> completionHistory;
  final String? aiNudge;
  final bool isFavorite;
  final String? note;

  Color get accentColorValue => Color(accentColor);

  /// Goal as a single comparable amount for "met" checks.
  double get goalAsAmount {
    switch (kind) {
      case HabitMeasureKind.checkbox:
        return 1;
      case HabitMeasureKind.countUp:
        return goalCount.toDouble();
      case HabitMeasureKind.quantity:
        return goalAmount;
      case HabitMeasureKind.timerStopwatch:
      case HabitMeasureKind.timerCountdown:
        return goalSeconds.toDouble();
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'kind': kind.name,
        'goalSeconds': goalSeconds,
        'goalCount': goalCount,
        'goalAmount': goalAmount,
        'quantityIncrement': quantityIncrement,
        'unitLabel': unitLabel,
        'accentColor': accentColor,
        'timeOfDay': timeOfDay.name,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastCompleted': lastCompleted?.toIso8601String(),
        'completionHistory':
            completionHistory.map((d) => d.toIso8601String()).toList(),
        'aiNudge': aiNudge,
        'isFavorite': isFavorite,
        'note': note,
      };

  factory Habit.fromJson(Map<String, dynamic> json) {
    final kindStr = json['kind'] as String?;
    final kind = kindStr != null
        ? HabitMeasureKind.values.byName(kindStr)
        : HabitMeasureKind.checkbox;

    final td = json['timeOfDay'] as String?;
    final timeOfDay = td != null
        ? HabitTimeOfDay.values.byName(td)
        : HabitTimeOfDay.anytime;

    return Habit(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      kind: kind,
      goalSeconds: json['goalSeconds'] as int? ?? 0,
      goalCount: json['goalCount'] as int? ?? 1,
      goalAmount: (json['goalAmount'] as num?)?.toDouble() ?? 0,
      quantityIncrement: (json['quantityIncrement'] as num?)?.toDouble() ?? 1,
      unitLabel: json['unitLabel'] as String? ?? '',
      accentColor: json['accentColor'] as int? ?? 0xFF7C6AF7,
      timeOfDay: timeOfDay,
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      lastCompleted: json['lastCompleted'] == null
          ? null
          : DateTime.tryParse(json['lastCompleted'] as String),
      completionHistory: (json['completionHistory'] as List<dynamic>? ?? [])
          .map((e) => DateTime.parse(e as String))
          .toList(),
      aiNudge: json['aiNudge'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      note: json['note'] as String?,
    );
  }

  Habit copyWith({
    String? id,
    String? name,
    String? emoji,
    HabitMeasureKind? kind,
    int? goalSeconds,
    int? goalCount,
    double? goalAmount,
    double? quantityIncrement,
    String? unitLabel,
    int? accentColor,
    HabitTimeOfDay? timeOfDay,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastCompleted,
    List<DateTime>? completionHistory,
    String? aiNudge,
    bool? isFavorite,
    String? note,
  }) =>
      Habit(
        id: id ?? this.id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        kind: kind ?? this.kind,
        goalSeconds: goalSeconds ?? this.goalSeconds,
        goalCount: goalCount ?? this.goalCount,
        goalAmount: goalAmount ?? this.goalAmount,
        quantityIncrement: quantityIncrement ?? this.quantityIncrement,
        unitLabel: unitLabel ?? this.unitLabel,
        accentColor: accentColor ?? this.accentColor,
        timeOfDay: timeOfDay ?? this.timeOfDay,
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        lastCompleted: lastCompleted ?? this.lastCompleted,
        completionHistory: completionHistory ?? this.completionHistory,
        aiNudge: aiNudge ?? this.aiNudge,
        isFavorite: isFavorite ?? this.isFavorite,
        note: note ?? this.note,
      );
}

/// Full persisted bundle for the habit mini-app.
class HabitTrackerBundle {
  HabitTrackerBundle({
    this.version = 2,
    required this.habits,
    required this.dayProgress,
    this.profile = const HabitUserProfile(),
  });

  static const int currentVersion = 2;

  final int version;
  final List<Habit> habits;
  final List<HabitDayProgress> dayProgress;
  final HabitUserProfile profile;

  Map<String, dynamic> toJson() => {
        'version': version,
        'habits': habits.map((h) => h.toJson()).toList(),
        'dayProgress': dayProgress.map((p) => p.toJson()).toList(),
        'profile': profile.toJson(),
      };

  factory HabitTrackerBundle.fromJson(Map<String, dynamic> json) =>
      HabitTrackerBundle(
        version: json['version'] as int? ?? 2,
        habits: (json['habits'] as List<dynamic>)
            .map((e) => Habit.fromJson(e as Map<String, dynamic>))
            .toList(),
        dayProgress: (json['dayProgress'] as List<dynamic>? ?? [])
            .map((e) => HabitDayProgress.fromJson(e as Map<String, dynamic>))
            .toList(),
        profile: HabitUserProfile.fromJson(
          json['profile'] as Map<String, dynamic>?,
        ),
      );
}

String dateKeyFrom(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}
