import 'package:uuid/uuid.dart';

import '../../../shared/models/models.dart';

const _uuid = Uuid();

class HabitTemplate {
  const HabitTemplate({
    required this.name,
    required this.emoji,
    required this.kind,
    this.goalSeconds = 3600,
    this.goalCount = 1,
    this.goalAmount = 2000,
    this.quantityIncrement = 250,
    this.unitLabel = 'ml',
    this.timeOfDay = HabitTimeOfDay.anytime,
    this.accentColor = 0xFF7C6AF7,
  });

  final String name;
  final String emoji;
  final HabitMeasureKind kind;
  final int goalSeconds;
  final int goalCount;
  final double goalAmount;
  final double quantityIncrement;
  final String unitLabel;
  final HabitTimeOfDay timeOfDay;
  final int accentColor;

  Habit toHabit() => Habit(
        id: _uuid.v4(),
        name: name,
        emoji: emoji,
        kind: kind,
        goalSeconds: goalSeconds,
        goalCount: goalCount,
        goalAmount: goalAmount,
        quantityIncrement: quantityIncrement,
        unitLabel: unitLabel,
        timeOfDay: timeOfDay,
        accentColor: accentColor,
      );
}

/// Category id -> templates
final Map<String, List<HabitTemplate>> habitTemplatesByCategory = {
  'Popular': [
    const HabitTemplate(
      name: 'Drink water',
      emoji: '💧',
      kind: HabitMeasureKind.quantity,
      goalAmount: 3000,
      quantityIncrement: 500,
      unitLabel: 'ml',
      accentColor: 0xFF6AF7D4,
    ),
    const HabitTemplate(
      name: 'Read',
      emoji: '📖',
      kind: HabitMeasureKind.timerCountdown,
      goalSeconds: 30 * 60,
      timeOfDay: HabitTimeOfDay.evening,
      accentColor: 0xFFF7C26A,
    ),
    const HabitTemplate(
      name: 'Workout',
      emoji: '💪',
      kind: HabitMeasureKind.timerStopwatch,
      goalSeconds: 3600,
      timeOfDay: HabitTimeOfDay.morning,
      accentColor: 0xFFF76AC8,
    ),
    const HabitTemplate(
      name: 'Meditate',
      emoji: '🧘',
      kind: HabitMeasureKind.checkbox,
      accentColor: 0xFF7C6AF7,
    ),
  ],
  'Health': [
    const HabitTemplate(
      name: 'Vitamins',
      emoji: '💊',
      kind: HabitMeasureKind.countUp,
      goalCount: 1,
      accentColor: 0xFF7C6AF7,
    ),
    const HabitTemplate(
      name: 'Sleep by 11pm',
      emoji: '😴',
      kind: HabitMeasureKind.checkbox,
      timeOfDay: HabitTimeOfDay.evening,
      accentColor: 0xFF6AF7D4,
    ),
    const HabitTemplate(
      name: 'Stretch',
      emoji: '🤸',
      kind: HabitMeasureKind.timerCountdown,
      goalSeconds: 600,
      accentColor: 0xFFF76AC8,
    ),
  ],
  'Sports': [
    const HabitTemplate(
      name: 'Run',
      emoji: '🏃',
      kind: HabitMeasureKind.timerStopwatch,
      goalSeconds: 1800,
      accentColor: 0xFFF76AC8,
    ),
    const HabitTemplate(
      name: 'Steps goal',
      emoji: '🚶',
      kind: HabitMeasureKind.countUp,
      goalCount: 10000,
      unitLabel: 'steps',
      accentColor: 0xFF7C6AF7,
    ),
  ],
  'Lifestyle': [
    const HabitTemplate(
      name: 'Journal',
      emoji: '📝',
      kind: HabitMeasureKind.checkbox,
      timeOfDay: HabitTimeOfDay.evening,
      accentColor: 0xFFF7C26A,
    ),
    const HabitTemplate(
      name: 'Call family',
      emoji: '📞',
      kind: HabitMeasureKind.checkbox,
      accentColor: 0xFF6AF7D4,
    ),
  ],
  'Time': [
    const HabitTemplate(
      name: 'Deep work',
      emoji: '🎯',
      kind: HabitMeasureKind.timerStopwatch,
      goalSeconds: 2 * 3600,
      timeOfDay: HabitTimeOfDay.morning,
      accentColor: 0xFF7C6AF7,
    ),
    const HabitTemplate(
      name: 'Pomodoro',
      emoji: '🍅',
      kind: HabitMeasureKind.timerCountdown,
      goalSeconds: 25 * 60,
      accentColor: 0xFFF76AC8,
    ),
  ],
  'Quit': [
    const HabitTemplate(
      name: 'No smoking',
      emoji: '🚭',
      kind: HabitMeasureKind.checkbox,
      accentColor: 0xFF6AF7D4,
    ),
    const HabitTemplate(
      name: 'No junk food',
      emoji: '🥗',
      kind: HabitMeasureKind.checkbox,
      accentColor: 0xFFF7C26A,
    ),
  ],
};

final List<String> habitCategoryOrder = [
  'Popular',
  'Health',
  'Sports',
  'Lifestyle',
  'Time',
  'Quit',
];
