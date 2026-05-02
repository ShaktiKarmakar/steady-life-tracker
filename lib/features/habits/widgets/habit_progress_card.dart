import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/glass_card.dart';
import '../habit_formatters.dart';
import '../habit_tracker_notifier.dart';

class HabitProgressCard extends ConsumerWidget {
  const HabitProgressCard({
    super.key,
    required this.habit,
    required this.day,
    required this.onTap,
    required this.onQuickAdd,
  });

  final Habit habit;
  final DateTime day;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(habitTrackerProvider.notifier);
    final key = dateKeyFrom(day);
    final amount = notifier.progressFor(habit.id, key);
    final met = notifier.isMetOnDay(habit, key);
    final frac = habitProgressFraction(habit, amount);
    final label = habitProgressLabel(habit, amount, met: met);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: frac.clamp(0.0, 1.0),
                child: Container(color: habit.accentColorValue.withValues(alpha: met ? 0.55 : 0.35)),
              ),
            ),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Text(habit.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                        if (met && habit.currentStreak > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            '🔥 ${habit.currentStreak} ${habit.currentStreak == 1 ? 'Day' : 'Days'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accentAmber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (met)
                    const Icon(Icons.check_circle, color: AppColors.accentTeal, size: 26)
                  else
                    IconButton(
                      onPressed: onQuickAdd,
                      icon: const Icon(Icons.add_circle_outline),
                      color: Colors.white70,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
