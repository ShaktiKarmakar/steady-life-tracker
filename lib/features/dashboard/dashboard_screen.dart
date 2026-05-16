import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/design_system/animations.dart';
import '../../core/design_system/design_tokens.dart';
import '../../features/habits/habit_tracker_notifier.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/providers/nutrition_goals_provider.dart';
import '../../shared/widgets/animated_list_item.dart';
import '../../shared/widgets/steady_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final todayCalories = ref.watch(todayCaloriesProvider);
    final workoutMins = ref.watch(todayWorkoutMinutesProvider);
    final goals = ref.watch(dailyGoalsProvider(DateTime.now()));
    final remaining = (goals.calories - todayCalories).clamp(0, goals.calories);
    final now = DateTime.now();
    final habitN = ref.read(habitTrackerProvider.notifier);
    final metHabits = habits.where((h) => habitN.isMetOnDate(h, now)).length;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            decelerationRate: ScrollDecelerationRate.fast,
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: AnimatedListItem(
                  index: 0,
                  child: _Header(
                    habitsMet: metHabits,
                    totalHabits: habits.length,
                  ),
                ),
              ),
            ),
            if (habits.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: AnimatedListItem(
                    index: 1,
                    child: _HabitSummary(
                      habits: habits,
                      metHabits: metHabits,
                      habitNotifier: habitN,
                      now: now,
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: AnimatedListItem(
                  index: 2,
                  child: _CalorieHeroCard(
                    remaining: remaining,
                    consumed: todayCalories,
                    goal: goals.calories,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: AnimatedListItem(
                  index: 3,
                  child: _MetricCard(
                    label: 'Movement',
                    value: '$workoutMins',
                    unit: 'min',
                    goal: 30,
                    progress: (workoutMins / 30).clamp(0.0, 1.0),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.habitsMet, required this.totalHabits});
  final int habitsMet;
  final int totalHabits;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    final okColor = isDark ? DesignTokens.okTextDark : DesignTokens.okTextLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good ${greeting()}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: textMuted,
                fontSize: 14,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Steady',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 32,
                letterSpacing: -1.5,
              ),
        ),
        if (totalHabits > 0) ...[
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: SteadyAnimations.normal,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              '$habitsMet of $totalHabits habits done',
              key: ValueKey<int>(habitsMet),
              style: TextStyle(
                color: habitsMet == totalHabits ? okColor : textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

class _HabitSummary extends StatelessWidget {
  const _HabitSummary({
    required this.habits,
    required this.metHabits,
    required this.habitNotifier,
    required this.now,
  });

  final List<Habit> habits;
  final int metHabits;
  final HabitTrackerNotifier habitNotifier;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight;
    final bg = isDark ? DesignTokens.bgSurfaceDark : DesignTokens.bgSurfaceLight;
    final okColor = isDark ? DesignTokens.okTextDark : DesignTokens.okTextLight;
    final textSecondary = isDark ? DesignTokens.textSecondaryDark : DesignTokens.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Habits',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: habits.take(6).toList().asMap().entries.map((entry) {
            final i = entry.key;
            final habit = entry.value;
            final met = habitNotifier.isMetOnDate(habit, now);
            return AnimatedListItem(
              index: i,
              slideOffset: const Offset(0, 8),
              child: GestureDetector(
                onTap: () {
                  // Navigate to habits tab
                },
                child: AnimatedContainer(
                  duration: SteadyAnimations.normal,
                  curve: SteadyAnimations.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: met
                        ? (isDark
                                ? DesignTokens.accentActiveDark
                                : DesignTokens.accentActiveLight)
                            .withValues(alpha: 0.3)
                        : bg,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    border: Border.all(
                      color: met
                          ? (isDark
                              ? DesignTokens.accentActiveDark
                              : DesignTokens.accentActiveLight)
                          : border,
                      width: DesignTokens.borderWidthDefault,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        habit.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        habit.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: met ? textSecondary : Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      if (met) ...[
                        const SizedBox(width: 6),
                        Icon(
                          LucideIcons.check,
                          size: 14,
                          color: okColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CalorieHeroCard extends StatelessWidget {
  const _CalorieHeroCard({
    required this.remaining,
    required this.consumed,
    required this.goal,
  });

  final int remaining;
  final int consumed;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? DesignTokens.textPrimaryDark : DesignTokens.textPrimaryLight;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    final accent = isDark ? DesignTokens.textSecondaryDark : DesignTokens.textSecondaryLight;
    final border = isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight;
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;

    return SteadyCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$remaining kcal',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'remaining',
            style: TextStyle(fontSize: 14, color: textMuted),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: SteadyAnimations.slow,
              curve: SteadyAnimations.easeOut,
              builder: (context, animatedProgress, _) {
                return LinearProgressIndicator(
                  minHeight: 10,
                  value: animatedProgress,
                  color: accent,
                  backgroundColor: border,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$consumed consumed',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              Text(
                '$goal goal',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.goal,
    required this.progress,
  });

  final String label;
  final String value;
  final String unit;
  final int goal;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? DesignTokens.textSecondaryDark : DesignTokens.textSecondaryLight;
    final border = isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight;

    return SteadyCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              Text(
                '$value / $goal $unit',
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: SteadyAnimations.slow,
            curve: SteadyAnimations.easeOut,
            builder: (context, animatedProgress, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.progressBarBorderRadiusCalorie),
                child: LinearProgressIndicator(
                  minHeight: DesignTokens.progressBarHeightCalorie,
                  value: animatedProgress,
                  color: isDark ? DesignTokens.textSecondaryDark : DesignTokens.textSecondaryLight,
                  backgroundColor: border,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
