import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/design_system/design_tokens.dart';
import '../../shared/models/food_models.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/providers/nutrition_goals_provider.dart';
import '../../shared/widgets/steady_card.dart';

class TrackScreen extends ConsumerStatefulWidget {
  const TrackScreen({super.key});

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DesignTokens.textSecondaryDark : DesignTokens.textSecondaryLight;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accent,
          labelColor: accent,
          unselectedLabelColor: textMuted,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Food'),
            Tab(text: 'Workout'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _FoodTab(),
          _WorkoutTab(),
        ],
      ),
    );
  }
}

class _FoodTab extends ConsumerWidget {
  const _FoodTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(todayFoodEntriesProvider);
    final goals = ref.watch(dailyGoalsProvider(DateTime.now()));
    final totalCal = ref.watch(todayCaloriesProvider);
    final totalProt = ref.watch(todayProteinProvider);
    final totalCarbs = ref.watch(todayCarbsProvider);
    final totalFat = ref.watch(todayFatProvider);
    final remaining = goals.calories - totalCal;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    final textPrimary = isDark ? DesignTokens.textPrimaryDark : DesignTokens.textPrimaryLight;

    // Group by meal type
    final byMeal = <MealType, List<FoodEntry>>{};
    for (final e in entries) {
      byMeal.putIfAbsent(e.mealType, () => []).add(e);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Hero: calories remaining
        SteadyCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$remaining kcal',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                Text(
                  'remaining of ${goals.calories} kcal goal',
                  style: TextStyle(fontSize: 13, color: textMuted),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (totalCal / goals.calories).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: isDark
                        ? DesignTokens.borderDefaultDark
                        : DesignTokens.borderDefaultLight,
                  ),
                ),
                const SizedBox(height: 16),
                _MacroRow(label: 'Protein', current: totalProt, goal: goals.protein.toDouble()),
                const SizedBox(height: 8),
                _MacroRow(label: 'Carbs', current: totalCarbs, goal: goals.carbs.toDouble()),
                const SizedBox(height: 8),
                _MacroRow(label: 'Fat', current: totalFat, goal: goals.fat.toDouble()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Meal sections
        for (final type in MealType.values)
          if (byMeal.containsKey(type) && byMeal[type]!.isNotEmpty) ...[
            _MealSectionHeader(type: type, entries: byMeal[type]!),
            const SizedBox(height: 8),
            ...byMeal[type]!.map((e) => _FoodEntryCard(entry: e)),
            const SizedBox(height: 16),
          ],

        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                children: [
                  Icon(LucideIcons.utensils, size: 48, color: textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'No meals logged today',
                    style: TextStyle(color: textMuted, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Go to AI tab to scan or describe your food',
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.label, required this.current, required this.goal});
  final String label;
  final double current;
  final double goal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    final textPrimary = isDark ? DesignTokens.textPrimaryDark : DesignTokens.textPrimaryLight;
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark
                  ? DesignTokens.borderDefaultDark
                  : DesignTokens.borderDefaultLight,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${current.toStringAsFixed(0)}/${goal.toStringAsFixed(0)}g',
          style: TextStyle(fontSize: 11, color: textPrimary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _MealSectionHeader extends StatelessWidget {
  const _MealSectionHeader({required this.type, required this.entries});
  final MealType type;
  final List<FoodEntry> entries;

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<int>(0, (s, e) => s + e.totalCalories);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    final textPrimary = isDark ? DesignTokens.textPrimaryDark : DesignTokens.textPrimaryLight;

    return Row(
      children: [
        Text(
          type.label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        Text(
          '$total kcal',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
        ),
      ],
    );
  }
}

class _FoodEntryCard extends ConsumerWidget {
  const _FoodEntryCard({required this.entry});
  final FoodEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    final textPrimary = isDark ? DesignTokens.textPrimaryDark : DesignTokens.textPrimaryLight;

    return SteadyCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          if (entry.photoPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Image.file(
                  File(entry.photoPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(LucideIcons.imageOff, color: textMuted),
                ),
              ),
            )
          else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? DesignTokens.bgBaseDark
                    : DesignTokens.bgBaseLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(LucideIcons.utensils, size: 20, color: textMuted),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.items.map((i) => i.name).join(', '),
                  style: TextStyle(fontWeight: FontWeight.w500, color: textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'P ${entry.totalProteinG.toStringAsFixed(0)}g · C ${entry.totalCarbsG.toStringAsFixed(0)}g · F ${entry.totalFatG.toStringAsFixed(0)}g',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
            ),
          ),
          Text(
            '${entry.totalCalories}',
            style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
          ),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 16),
            color: textMuted,
            onPressed: () => ref.read(foodEntriesProvider.notifier).deleteEntry(entry.id),
          ),
        ],
      ),
    );
  }
}

class _WorkoutTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(workoutsProvider);
    final now = DateTime.now();
    final todayWorkouts = workouts.where((e) {
      return e.timestamp.year == now.year &&
          e.timestamp.month == now.month &&
          e.timestamp.day == now.day;
    }).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;

    final typeCtrl = TextEditingController(text: 'Run');
    final minCtrl = TextEditingController(text: '30');
    final calCtrl = TextEditingController(text: '200');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SteadyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: typeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: minCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: calCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kcal',
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark
                        ? DesignTokens.textPrimaryDark
                        : DesignTokens.textPrimaryLight,
                    foregroundColor: isDark
                        ? DesignTokens.bgBaseDark
                        : DesignTokens.bgBaseLight,
                  ),
                  onPressed: () {
                    final mins = int.tryParse(minCtrl.text) ?? 0;
                    final cals = int.tryParse(calCtrl.text) ?? 0;
                    if (typeCtrl.text.trim().isEmpty || mins <= 0) return;
                    ref.read(workoutsProvider.notifier).addWorkout(
                      typeCtrl.text.trim(),
                      mins,
                      cals,
                    );
                    typeCtrl.clear();
                    minCtrl.text = '30';
                    calCtrl.text = '200';
                  },
                  child: const Text('Add Workout'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Today',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${todayWorkouts.fold<int>(0, (s, e) => s + e.durationMin)} min',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (todayWorkouts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No workouts yet',
                style: TextStyle(color: textMuted),
              ),
            ),
          )
        else
          ...todayWorkouts.map((workout) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SteadyCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workout.type,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${workout.durationMin} mins',
                              style: TextStyle(
                                fontSize: 12,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${workout.calories}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        color: textMuted,
                        onPressed: () => ref
                            .read(workoutsProvider.notifier)
                            .deleteEntry(workout.id),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}
