import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/animated_blobs_background.dart';
import '../habit_tracker_notifier.dart';
import '../navigation/habit_navigation.dart';

class HabitLibraryScreen extends ConsumerWidget {
  const HabitLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitTrackerProvider).habits;

    return Stack(
      children: [
        const Positioned.fill(child: AnimatedBlobsBackground()),
        SafeArea(
          child: habits.isEmpty
              ? const Center(child: Text('No habits yet'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: habits.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final h = habits[i];
                    return ListTile(
                      tileColor: AppColors.bgSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Text(h.emoji, style: const TextStyle(fontSize: 26)),
                      title: Text(h.name),
                      subtitle: Text(_subtitle(h)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => openHabitDetail(context, h.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Delete habit?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true && context.mounted) {
                                await ref
                                    .read(habitTrackerProvider.notifier)
                                    .deleteHabit(h.id);
                              }
                            },
                          ),
                        ],
                      ),
                      onTap: () => openHabitDetail(context, h.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _subtitle(Habit h) {
    switch (h.kind) {
      case HabitMeasureKind.checkbox:
        return 'Check-off';
      case HabitMeasureKind.countUp:
        return 'Count · goal ${h.goalCount}';
      case HabitMeasureKind.quantity:
        return 'Quantity · ${h.goalAmount.toInt()} ${h.unitLabel}';
      case HabitMeasureKind.timerStopwatch:
      case HabitMeasureKind.timerCountdown:
        return 'Timer · ${h.goalSeconds}s';
    }
  }
}
