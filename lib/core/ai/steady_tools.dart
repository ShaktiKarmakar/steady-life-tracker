import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/mcp_core.dart';
import '../../core/design_system/habit_emoji_mapper.dart';
import '../../features/habits/habit_ai_command_executor.dart';
import '../../features/habits/habit_tracker_notifier.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/providers/health_sync_provider.dart';
import '../../shared/providers/theme_provider.dart';
import 'gemma_service.dart';

/// Registers every Steady feature as an MCP tool.
/// Call once at app startup (e.g. in main.dart after ProviderScope).
void registerAllSteadyTools() {
  final server = McpServer.instance;

  // ---------------------------------------------------------------------------
  // Habits
  // ---------------------------------------------------------------------------
  server.register(McpTool(
    schema: const McpToolSchema(
      name: 'list_habits',
      description: 'List all current habits and their streaks.',
      parameters: [],
    ),
    executor: (args, ref) async {
      final habits = ref.read(habitTrackerProvider).habits;
      if (habits.isEmpty) return McpResult.ok('You have no habits yet.');
      final lines = habits
          .map((h) => '${h.emoji} ${h.name} (streak ${h.currentStreak})')
          .join('\n');
      return McpResult.ok(lines);
    },
  ));

  server.register(McpTool(
    schema: const McpToolSchema(
      name: 'create_habit',
      description: 'Create a new habit.',
      parameters: [
        McpParameter(
          name: 'name',
          type: McpParameterType.string,
          description: 'Habit name',
        ),
        McpParameter(
          name: 'kind',
          type: McpParameterType.string,
          description: 'checkbox|count|quantity|stopwatch|countdown',
          required: false,
          defaultValue: 'checkbox',
        ),
        McpParameter(
          name: 'goal',
          type: McpParameterType.number,
          description: 'Goal amount/count/seconds',
          required: false,
          defaultValue: 1,
        ),
        McpParameter(
          name: 'unit',
          type: McpParameterType.string,
          description: 'Optional unit label (ml, min, etc.)',
          required: false,
        ),
        McpParameter(
          name: 'time_of_day',
          type: McpParameterType.string,
          description: 'morning|afternoon|evening|anytime',
          required: false,
          defaultValue: 'anytime',
        ),
      ],
    ),
    executor: (args, ref) async {
      final name = (args['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) {
        return McpResult.fail(
          "I'd be happy to create a new habit, but I need a name. What would you like to call it?",
        );
      }

      // Prevent duplicates
      final existing = ref.read(habitTrackerProvider).habits
          .where((h) => h.name.toLowerCase() == name.toLowerCase())
          .firstOrNull;
      if (existing != null) {
        return McpResult.ok('You already have a habit called "$name".');
      }

      final kind = _parseKind(args['kind'] as String?);
      final goal = _parseNum(args['goal']) ?? 1;
      final unit = (args['unit'] as String?) ?? '';
      final tod = _parseTimeOfDay(args['time_of_day'] as String?);
      final emoji = HabitEmojiMapper.emojiForHabit(name);

      final habit = Habit(
        id: '',
        name: name,
        emoji: emoji,
        kind: kind,
        goalCount: kind == HabitMeasureKind.countUp ? goal.toInt() : 1,
        goalAmount: kind == HabitMeasureKind.quantity ? goal : 0,
        goalSeconds:
            (kind == HabitMeasureKind.timerStopwatch || kind == HabitMeasureKind.timerCountdown)
                ? goal.toInt()
                : 0,
        quantityIncrement: kind == HabitMeasureKind.quantity ? 250 : 1,
        unitLabel: unit,
        timeOfDay: tod,
      );
      await ref.read(habitTrackerProvider.notifier).addHabit(habit);
      return McpResult.ok('Created habit "$name" $emoji.');
    },
  ));

  server.register(McpTool(
    schema: const McpToolSchema(
      name: 'mark_habit_done',
      description: 'Mark a habit as complete for today.',
      parameters: [
        McpParameter(
          name: 'habit_name',
          type: McpParameterType.string,
          description: 'Name of the habit',
        ),
      ],
    ),
    executor: (args, ref) async {
      final name = (args['habit_name'] as String?)?.trim() ?? '';
      final habit = _findHabitByName(ref, name);
      if (habit == null) return McpResult.fail('Could not find habit "$name".');
      final cmd = HabitAiCommand(action: 'mark_habit_done', habitName: habit.name);
      final msg = await HabitAiCommandExecutor.execute(
        ref.read(habitTrackerProvider.notifier),
        cmd,
      );
      return McpResult.ok(msg);
    },
  ));

  server.register(McpTool(
    schema: const McpToolSchema(
      name: 'log_habit_progress',
      description: 'Log progress for a quantity or count habit.',
      parameters: [
        McpParameter(
          name: 'habit_name',
          type: McpParameterType.string,
          description: 'Name of the habit',
        ),
        McpParameter(
          name: 'amount',
          type: McpParameterType.number,
          description: 'Amount to add (ml, reps, minutes, etc.)',
        ),
      ],
    ),
    executor: (args, ref) async {
      final name = (args['habit_name'] as String?)?.trim() ?? '';
      final amount = _parseNum(args['amount']);
      final habit = _findHabitByName(ref, name);
      if (habit == null) return McpResult.fail('Could not find habit "$name".');
      if (amount == null) {
        return McpResult.fail('How much did you log? Please include an amount.');
      }
      final cmd = HabitAiCommand(
        action: 'log_habit_progress',
        habitName: habit.name,
        goalAmount: amount,
      );
      final msg = await HabitAiCommandExecutor.execute(
        ref.read(habitTrackerProvider.notifier),
        cmd,
      );
      return McpResult.ok(msg);
    },
  ));

  server.register(McpTool(
    schema: const McpToolSchema(
      name: 'delete_habit',
      description: 'Delete (remove, get rid of) a habit permanently.',
      parameters: [
        McpParameter(
          name: 'habit_name',
          type: McpParameterType.string,
          description: 'Name of the habit to delete',
        ),
      ],
    ),
    executor: (args, ref) async {
      final name = (args['habit_name'] as String?)?.trim() ?? '';
      final habit = _findHabitByName(ref, name);
      if (habit == null) return McpResult.fail('Could not find habit "$name".');
      await ref.read(habitTrackerProvider.notifier).deleteHabit(habit.id);
      return McpResult.ok('Deleted habit "${habit.name}".');
    },
  ));

  server.register(McpTool(
    schema: const McpToolSchema(
      name: 'delete_all_habits',
      description: 'Delete ALL habits at once. Use when user says "remove all habits", "clear everything", etc.',
      parameters: [],
    ),
    executor: (args, ref) async {
      final habits = ref.read(habitTrackerProvider).habits;
      final count = habits.length;
      if (count == 0) return McpResult.ok('You have no habits to delete.');
      final notifier = ref.read(habitTrackerProvider.notifier);
      for (final h in habits) {
        await notifier.deleteHabit(h.id);
      }
      return McpResult.ok('Deleted $count ${count == 1 ? 'habit' : 'habits'}.');
    },
  ));

  // ---------------------------------------------------------------------------
  // Tracking
  // ---------------------------------------------------------------------------
  server.register(McpTool(
    schema: const McpToolSchema(
      name: 'log_calories',
      description: 'Log calories with optional macros.',
      parameters: [
        McpParameter(
          name: 'description',
          type: McpParameterType.string,
          description: 'What you ate',
        ),
        McpParameter(
          name: 'calories',
          type: McpParameterType.integer,
          description: 'Total calories',
        ),
        McpParameter(
          name: 'protein',
          type: McpParameterType.integer,
          description: 'Protein in grams',
          required: false,
          defaultValue: 0,
        ),
        McpParameter(
          name: 'carbs',
          type: McpParameterType.integer,
          description: 'Carbs in grams',
          required: false,
          defaultValue: 0,
        ),
        McpParameter(
          name: 'fat',
          type: McpParameterType.integer,
          description: 'Fat in grams',
          required: false,
          defaultValue: 0,
        ),
      ],
    ),
    executor: (args, ref) async {
      final desc = (args['description'] as String?)?.trim() ?? 'Unknown';
      final cal = (_parseNum(args['calories']) ?? 0).toInt();
      final p = (_parseNum(args['protein']) ?? 0).toInt();
      final c = (_parseNum(args['carbs']) ?? 0).toInt();
      final f = (_parseNum(args['fat']) ?? 0).toInt();
      await ref.read(foodEntriesProvider.notifier).addManual(
        mealType: MealType.snack,
        description: desc,
        calories: cal,
        protein: p,
        carbs: c,
        fat: f,
      );
      return McpResult.ok('Logged $cal kcal for "$desc".');
    },
  ));

  server.register(McpTool(
    schema: const McpToolSchema(
      name: 'log_workout',
      description: 'Log a workout.',
      parameters: [
        McpParameter(
          name: 'type',
          type: McpParameterType.string,
          description: 'e.g. Run, Yoga, Weights',
        ),
        McpParameter(
          name: 'duration_min',
          type: McpParameterType.integer,
          description: 'Minutes',
        ),
        McpParameter(
          name: 'calories',
          type: McpParameterType.integer,
          description: 'Optional calories burned',
          required: false,
          defaultValue: 0,
        ),
      ],
    ),
    executor: (args, ref) async {
      final type = (args['type'] as String?)?.trim() ?? 'Workout';
      final min = (_parseNum(args['duration_min']) ?? 0).toInt();
      final cal = (_parseNum(args['calories']) ?? 0).toInt();
      if (min <= 0) return McpResult.fail('Error: duration must be > 0.');
      await ref.read(workoutsProvider.notifier).addWorkout(type, min, cal);
      return McpResult.ok('Logged $type for $min min (${cal}kcal).');
    },
  ));

  server.register(McpTool(
    schema: const McpToolSchema(
      name: 'list_today_tracking',
      description: "Show today's calories and workouts.",
      parameters: [],
    ),
    executor: (args, ref) async {
      final now = DateTime.now();
      final foods = ref.read(foodEntriesProvider).where((e) =>
          e.timestamp.year == now.year &&
          e.timestamp.month == now.month &&
          e.timestamp.day == now.day);
      final workouts = ref.read(workoutsProvider).where((e) =>
          e.timestamp.year == now.year &&
          e.timestamp.month == now.month &&
          e.timestamp.day == now.day);
      final totalCal = foods.fold<int>(0, (s, e) => s + e.totalCalories);
      final totalMin = workouts.fold<int>(0, (s, e) => s + e.durationMin);
      final calItems = foods.map((e) => '${e.items.map((i) => i.name).join(', ')}: ${e.totalCalories}kcal').join(', ');
      final woItems = workouts.map((e) => '${e.type}: ${e.durationMin}min').join(', ');
      return McpResult.ok(
        'Today: $totalCal kcal${calItems.isNotEmpty ? ' ($calItems)' : ''}, '
        '$totalMin min workout${woItems.isNotEmpty ? ' ($woItems)' : ''}.',
      );
    },
  ));

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------
  server.register(McpTool(
    schema: const McpToolSchema(
      name: 'toggle_theme',
      description: 'Toggle between light, dark, and system theme.',
      parameters: [],
    ),
    executor: (args, ref) async {
      final mode = ref.read(themeModeProvider);
      await ref.read(themeModeProvider.notifier).toggle();
      final next = ref.read(themeModeProvider);
      return McpResult.ok('Theme changed from ${mode.name} to ${next.name}.');
    },
  ));

  server.register(McpTool(
    schema: const McpToolSchema(
      name: 'sync_health',
      description: 'Import workouts from Apple Health / Google Fit.',
      parameters: [],
    ),
    executor: (args, ref) async {
      final imported = await ref.read(healthSyncProvider.future);
      return McpResult.ok(
        imported == 0
            ? 'No new workouts found in Health.'
            : 'Imported $imported workouts from Health.',
      );
    },
  ));

  // ---------------------------------------------------------------------------
  // Info
  // ---------------------------------------------------------------------------
  server.register(McpTool(
    schema: const McpToolSchema(
      name: 'get_stats',
      description: 'Show habit statistics: completion rate, best streak, etc.',
      parameters: [],
    ),
    executor: (args, ref) async {
      final tracker = ref.read(habitTrackerProvider);
      if (tracker.habits.isEmpty) return McpResult.ok('No habits to report on.');
      final best = tracker.habits.reduce((a, b) => a.longestStreak > b.longestStreak ? a : b);
      final totalDone = tracker.dayProgress.where((p) {
        final h = tracker.habits.where((h) => h.id == p.habitId).firstOrNull;
        if (h == null) return false;
        final g = h.goalAsAmount;
        if (g <= 0) return p.amount >= 1;
        return p.amount >= g - 1e-6;
      }).length;
      return McpResult.ok(
        'Best streak: ${best.name} (${best.longestStreak} days). '
        'Total habit completions: $totalDone.',
      );
    },
  ));

  server.register(McpTool(
    schema: const McpToolSchema(
      name: 'get_daily_briefing',
      description: 'Generate an AI daily wellness briefing.',
      parameters: [],
    ),
    executor: (args, ref) async {
      final habits = ref.read(habitTrackerProvider).habits;
      final foods = ref.read(foodEntriesProvider);
      final workouts = ref.read(workoutsProvider);
      final briefing = await ref.read(gemmaServiceProvider).generateDailyBriefing(
        habits, foods, workouts,
      );
      return McpResult.ok(briefing);
    },
  ));
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Habit? _findHabitByName(WidgetRef ref, String name) {
  final habits = ref.read(habitTrackerProvider).habits;
  final lower = name.toLowerCase().trim();
  if (lower.isEmpty) return null;

  // Exact match
  for (final h in habits) {
    if (h.name.toLowerCase() == lower) return h;
  }

  // Contains: habit name contains search term
  for (final h in habits) {
    if (h.name.toLowerCase().contains(lower)) return h;
  }

  // Reverse contains: search term contains habit name
  for (final h in habits) {
    final habitLower = h.name.toLowerCase();
    if (lower.contains(habitLower)) return h;
  }

  // Token match
  final tokens = lower.split(RegExp(r'\s+'));
  for (final h in habits) {
    final habitTokens = h.name.toLowerCase().split(RegExp(r'\s+'));
    final matches = tokens.where((t) => habitTokens.contains(t)).length;
    if (matches >= 1 && tokens.length <= 3) return h;
  }

  return null;
}

HabitMeasureKind _parseKind(String? raw) {
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

HabitTimeOfDay _parseTimeOfDay(String? raw) {
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

/// Parses a JSON value that may be a String, int, double, or null into a double.
double? _parseNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}
