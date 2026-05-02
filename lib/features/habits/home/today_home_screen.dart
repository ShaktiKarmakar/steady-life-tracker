import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/animated_blobs_background.dart';
import '../habit_tracker_notifier.dart';
import '../navigation/habit_navigation.dart';
import '../widgets/habit_progress_card.dart';

class TodayHomeScreen extends ConsumerWidget {
  const TodayHomeScreen({
    super.key,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenProfile;

  static DateTime _mondayOf(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  void _showFilters(BuildContext context, WidgetRef ref) {
    final tracker = ref.read(habitTrackerProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<HabitFilterStatus>(
              segments: const [
                ButtonSegment(value: HabitFilterStatus.all, label: Text('All')),
                ButtonSegment(value: HabitFilterStatus.unmet, label: Text('Unmet')),
                ButtonSegment(value: HabitFilterStatus.met, label: Text('Met')),
              ],
              selected: {tracker.filterStatus},
              onSelectionChanged: (s) {
                ref.read(habitTrackerProvider.notifier).setFilterStatus(s.first);
              },
            ),
            const SizedBox(height: 20),
            const Text('Time of day', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: HabitFilterTime.values.map((t) {
                final label = switch (t) {
                  HabitFilterTime.all => 'All',
                  HabitFilterTime.now => 'Now',
                  HabitFilterTime.anytime => 'Anytime',
                  HabitFilterTime.morning => 'Morning',
                  HabitFilterTime.afternoon => 'Afternoon',
                  HabitFilterTime.evening => 'Evening',
                };
                final sel = tracker.filterTime == t;
                return FilterChip(
                  label: Text(label),
                  selected: sel,
                  onSelected: (_) {
                    ref.read(habitTrackerProvider.notifier).setFilterTime(t);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(habitSelectedDateProvider);
    final notifier = ref.watch(habitTrackerProvider.notifier);
    final habits = notifier.filteredHabitsForDay(selectedDay);
    final weekStart = _mondayOf(selectedDay);

    return Stack(
      children: [
        const Positioned.fill(child: AnimatedBlobsBackground()),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: () => _showFilters(context, ref),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, MMM d').format(selectedDay),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.accentPurple,
                        child: Icon(Icons.person_outline, size: 20),
                      ),
                      onPressed: onOpenProfile,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 72,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: 7,
                  itemBuilder: (context, i) {
                    final day = weekStart.add(Duration(days: i));
                    final isSel = dateKeyFrom(day) == dateKeyFrom(selectedDay);
                    final isToday = dateKeyFrom(day) == dateKeyFrom(DateTime.now());
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () =>
                            ref.read(habitSelectedDateProvider.notifier).setDay(day),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 52,
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppColors.accentPurple.withValues(alpha: 0.35)
                                : AppColors.glass,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isToday
                                  ? AppColors.accentTeal.withValues(alpha: 0.6)
                                  : AppColors.glassBorder,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('EEE').format(day),
                                style: const TextStyle(fontSize: 11, color: Colors.white54),
                              ),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: isSel ? Colors.white : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: habits.isEmpty
                    ? const Center(
                        child: Text(
                          'No habits match filters.\nTry adjusting filters or add a habit.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: habits.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final habit = habits[i];
                          return HabitProgressCard(
                            habit: habit,
                            day: selectedDay,
                            onTap: () => openHabitDetail(context, habit.id),
                            onQuickAdd: () => ref
                                .read(habitTrackerProvider.notifier)
                                .quickLogPlus(habit, selectedDay),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 20,
          bottom: 24,
          child: FloatingActionButton(
            heroTag: 'habit_fab',
            backgroundColor: AppColors.accentPurple,
            onPressed: () => openNewHabitPicker(context),
            child: const Icon(Icons.add),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 24,
          child: FloatingActionButton.small(
            heroTag: 'habit_avatar',
            backgroundColor: AppColors.bgSecondary,
            onPressed: onOpenProfile,
            child: const Icon(Icons.face_retouching_natural_outlined),
          ),
        ),
      ],
    );
  }
}
