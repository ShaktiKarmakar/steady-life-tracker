import '../../shared/models/models.dart';
import 'habit_tracker_notifier.dart';

class HabitAiCommand {
  HabitAiCommand({
    required this.action,
    this.habitName,
    this.emoji,
    this.kind,
    this.goalCount,
    this.goalAmount,
    this.goalSeconds,
    this.quantityIncrement,
    this.unitLabel,
    this.timeOfDay,
    this.newName,
  });

  final String action;
  final String? habitName;
  final String? emoji;
  final String? kind;
  final int? goalCount;
  final double? goalAmount;
  final int? goalSeconds;
  final double? quantityIncrement;
  final String? unitLabel;
  final String? timeOfDay;
  final String? newName;

  factory HabitAiCommand.fromJson(Map<String, dynamic> json) => HabitAiCommand(
        action: (json['action'] as String? ?? '').trim(),
        habitName: json['habitName'] as String?,
        emoji: json['emoji'] as String?,
        kind: json['kind'] as String?,
        goalCount: (json['goalCount'] as num?)?.toInt(),
        goalAmount: (json['goalAmount'] as num?)?.toDouble(),
        goalSeconds: (json['goalSeconds'] as num?)?.toInt(),
        quantityIncrement: (json['quantityIncrement'] as num?)?.toDouble(),
        unitLabel: json['unitLabel'] as String?,
        timeOfDay: json['timeOfDay'] as String?,
        newName: json['newName'] as String?,
      );
}

class HabitAiCommandExecutor {
  static Future<String> execute(
    HabitTrackerNotifier notifier,
    HabitAiCommand cmd,
  ) async {
    final action = cmd.action.toLowerCase();
    switch (action) {
      case 'create_habit':
        return _create(notifier, cmd);
      case 'update_habit':
        return _update(notifier, cmd);
      case 'mark_habit_done':
        return _markDone(notifier, cmd);
      case 'log_habit_progress':
        return _logProgress(notifier, cmd);
      default:
        return '';
    }
  }

  static Habit? _findByName(HabitTrackerNotifier notifier, String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final needle = name.trim().toLowerCase();
    for (final h in notifier.habitsSnapshot) {
      if (h.name.toLowerCase() == needle) return h;
    }
    for (final h in notifier.habitsSnapshot) {
      if (h.name.toLowerCase().contains(needle)) return h;
    }
    return null;
  }

  static HabitMeasureKind _kindFrom(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'count':
      case 'countup':
        return HabitMeasureKind.countUp;
      case 'quantity':
      case 'liquid':
        return HabitMeasureKind.quantity;
      case 'timer':
      case 'stopwatch':
      case 'timerstopwatch':
        return HabitMeasureKind.timerStopwatch;
      case 'countdown':
      case 'timercountdown':
        return HabitMeasureKind.timerCountdown;
      default:
        return HabitMeasureKind.checkbox;
    }
  }

  static HabitTimeOfDay _timeFrom(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'morning':
        return HabitTimeOfDay.morning;
      case 'afternoon':
        return HabitTimeOfDay.afternoon;
      case 'evening':
        return HabitTimeOfDay.evening;
      default:
        return HabitTimeOfDay.anytime;
    }
  }

  static Future<String> _create(
    HabitTrackerNotifier notifier,
    HabitAiCommand cmd,
  ) async {
    final name = cmd.habitName?.trim() ?? '';
    if (name.isEmpty) return 'I need a habit name to create one.';
    final kind = _kindFrom(cmd.kind);
    final habit = Habit(
      id: '',
      name: name,
      emoji: (cmd.emoji?.trim().isNotEmpty ?? false) ? cmd.emoji!.trim() : '✅',
      kind: kind,
      goalCount: cmd.goalCount ?? 1,
      goalAmount: cmd.goalAmount ?? (kind == HabitMeasureKind.quantity ? 2000 : 0),
      goalSeconds: cmd.goalSeconds ?? (kind == HabitMeasureKind.timerCountdown ? 1800 : 3600),
      quantityIncrement: cmd.quantityIncrement ?? 250,
      unitLabel: cmd.unitLabel ?? (kind == HabitMeasureKind.quantity ? 'ml' : ''),
      timeOfDay: _timeFrom(cmd.timeOfDay),
    );
    await notifier.addHabit(habit);
    return 'Added habit "$name".';
  }

  static Future<String> _update(
    HabitTrackerNotifier notifier,
    HabitAiCommand cmd,
  ) async {
    final existing = _findByName(notifier, cmd.habitName);
    if (existing == null) return 'I could not find that habit to update.';
    final updated = existing.copyWith(
      name: (cmd.newName?.trim().isNotEmpty ?? false) ? cmd.newName!.trim() : null,
      kind: cmd.kind == null ? null : _kindFrom(cmd.kind),
      goalCount: cmd.goalCount,
      goalAmount: cmd.goalAmount,
      goalSeconds: cmd.goalSeconds,
      quantityIncrement: cmd.quantityIncrement,
      unitLabel: cmd.unitLabel,
      timeOfDay: cmd.timeOfDay == null ? null : _timeFrom(cmd.timeOfDay),
      emoji: (cmd.emoji?.trim().isNotEmpty ?? false) ? cmd.emoji!.trim() : null,
    );
    await notifier.updateHabit(updated);
    return 'Updated habit "${existing.name}".';
  }

  static Future<String> _markDone(
    HabitTrackerNotifier notifier,
    HabitAiCommand cmd,
  ) async {
    final habit = _findByName(notifier, cmd.habitName);
    if (habit == null) return 'I could not find that habit.';
    switch (habit.kind) {
      case HabitMeasureKind.checkbox:
        await notifier.setCheckboxDone(habit, DateTime.now(), true);
      case HabitMeasureKind.countUp:
        await notifier.setCount(habit, DateTime.now(), habit.goalCount);
      case HabitMeasureKind.quantity:
        await notifier.addQuantityAmount(
          habit,
          DateTime.now(),
          (habit.goalAmount -
                  notifier.progressFor(habit.id, dateKeyFrom(DateTime.now())))
              .clamp(0, habit.goalAmount),
        );
      case HabitMeasureKind.timerStopwatch:
      case HabitMeasureKind.timerCountdown:
        await notifier.addTimerSeconds(
          habit,
          DateTime.now(),
          (habit.goalSeconds -
                  notifier.progressFor(habit.id, dateKeyFrom(DateTime.now())))
              .clamp(0, habit.goalSeconds.toDouble()),
        );
    }
    return 'Marked "${habit.name}" done for today.';
  }

  static Future<String> _logProgress(
    HabitTrackerNotifier notifier,
    HabitAiCommand cmd,
  ) async {
    final habit = _findByName(notifier, cmd.habitName);
    if (habit == null) return 'I could not find that habit.';
    switch (habit.kind) {
      case HabitMeasureKind.checkbox:
        await notifier.setCheckboxDone(habit, DateTime.now(), true);
      case HabitMeasureKind.countUp:
        final current =
            notifier.progressFor(habit.id, dateKeyFrom(DateTime.now())).toInt();
        final target = cmd.goalCount ?? (current + 1);
        await notifier.setCount(habit, DateTime.now(), target);
      case HabitMeasureKind.quantity:
        final delta = cmd.goalAmount ?? cmd.quantityIncrement ?? habit.quantityIncrement;
        await notifier.addQuantityAmount(habit, DateTime.now(), delta);
      case HabitMeasureKind.timerStopwatch:
      case HabitMeasureKind.timerCountdown:
        await notifier.addTimerSeconds(
          habit,
          DateTime.now(),
          (cmd.goalSeconds ?? 60).toDouble(),
        );
    }
    return 'Logged progress for "${habit.name}".';
  }
}

