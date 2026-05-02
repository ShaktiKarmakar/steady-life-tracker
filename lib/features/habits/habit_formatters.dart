import '../../shared/models/models.dart';

String formatDurationSeconds(double seconds) {
  final s = seconds.floor();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
}

String habitProgressLabel(Habit habit, double amount, {required bool met}) {
  if (habit.kind == HabitMeasureKind.checkbox) {
    return met ? 'Complete' : 'Tap to complete';
  }
  if (habit.kind == HabitMeasureKind.countUp) {
    return '${amount.toInt()} / ${habit.goalCount}';
  }
  if (habit.kind == HabitMeasureKind.quantity) {
    final unit = habit.unitLabel.isEmpty ? '' : ' ${habit.unitLabel}';
    return '${amount.toInt()} / ${habit.goalAmount.toInt()}$unit';
  }
  final goal = habit.goalSeconds.toDouble();
  return '${formatDurationSeconds(amount)} / ${formatDurationSeconds(goal)}';
}

double habitProgressFraction(Habit habit, double amount) {
  final g = habit.goalAsAmount;
  if (g <= 0) return metFraction(habit, amount);
  return (amount / g).clamp(0.0, 1.0);
}

double metFraction(Habit habit, double amount) {
  if (habit.kind == HabitMeasureKind.checkbox) {
    return amount >= 1 ? 1.0 : 0.0;
  }
  return habitProgressFraction(habit, amount);
}
