import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/animated_blobs_background.dart';
import '../../../shared/widgets/gradient_ring.dart';
import '../habit_formatters.dart';
import '../habit_tracker_notifier.dart';

class HabitStatisticsScreen extends ConsumerStatefulWidget {
  const HabitStatisticsScreen({super.key});

  @override
  ConsumerState<HabitStatisticsScreen> createState() => _HabitStatisticsScreenState();
}

class _HabitStatisticsScreenState extends ConsumerState<HabitStatisticsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  @override
  Widget build(BuildContext context) {
    final tracker = ref.watch(habitTrackerProvider);
    final filterId = ref.watch(habitStatsFilterIdProvider);
    final habits = tracker.habits;
    final filteredHabits =
        filterId == null ? habits : habits.where((h) => h.id == filterId).toList();

    final monthStart = DateTime(_month.year, _month.month);
    final monthEnd = DateTime(_month.year, _month.month + 1, 0);
    final daysInMonth = monthEnd.day;

    final monthlyRate = _monthlyCompletionRate(
      tracker.dayProgress,
      filteredHabits,
      monthStart,
      monthEnd,
    );
    final bestStreak = filteredHabits.fold<int>(
      0,
      (m, h) => h.longestStreak > m ? h.longestStreak : m,
    );
    final perfectDays = _perfectDaysCount(
      tracker.dayProgress,
      filteredHabits,
      monthStart,
      monthEnd,
    );
    final totalDone = _totalLogsCount(
      tracker.dayProgress,
      filteredHabits,
      monthStart,
      monthEnd,
    );
    final dailyAvg = filteredHabits.isEmpty
        ? 0.0
        : totalDone / daysInMonth / filteredHabits.length;

    final todayKey = dateKeyFrom(DateTime.now());
    final doneToday = _doneTodayList(tracker, filterId, todayKey);

    return Stack(
      children: [
        const Positioned.fill(child: AnimatedBlobsBackground()),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChipCircle(
                      label: 'All',
                      selected: filterId == null,
                      onTap: () =>
                          ref.read(habitStatsFilterIdProvider.notifier).setId(null),
                    ),
                    ...habits.map(
                      (h) => _FilterChipCircle(
                        label: h.emoji,
                        selected: filterId == h.id,
                        onTap: () =>
                            ref.read(habitStatsFilterIdProvider.notifier).setId(h.id),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() {
                      _month = DateTime(_month.year, _month.month - 1);
                    }),
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_month),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() {
                      _month = DateTime(_month.year, _month.month + 1);
                    }),
                  ),
                ],
              ),
              _MonthDotsGrid(
                monthStart: monthStart,
                daysInMonth: daysInMonth,
                habits: filteredHabits,
                progress: tracker.dayProgress,
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    GradientRing(
                      value: monthlyRate,
                      label: '${(monthlyRate * 100).round()}%',
                      gradient: const LinearGradient(
                        colors: [AppColors.accentPurple, AppColors.accentPink],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Monthly completion rate'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatTile('Best streak', '$bestStreak days'),
                  _StatTile('Perfect days', '$perfectDays'),
                  _StatTile('Habits done', '$totalDone'),
                  _StatTile('Daily avg', dailyAvg.toStringAsFixed(1)),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Done today',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              if (doneToday.isEmpty)
                const Text('Nothing logged yet today', style: TextStyle(color: Colors.white54))
              else
                ...doneToday.map(
                  (e) => ListTile(
                    dense: true,
                    leading: Text(e.$1.emoji, style: const TextStyle(fontSize: 22)),
                    title: Text(e.$1.name),
                    subtitle: Text(
                      '${DateFormat.Hm().format(e.$2)} · ${e.$3}',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChipCircle extends StatelessWidget {
  const _FilterChipCircle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.accentPurple : AppColors.glassBorder,
              width: selected ? 2 : 1,
            ),
            color: AppColors.bgSecondary,
          ),
          child: Text(label, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}

class _MonthDotsGrid extends StatelessWidget {
  const _MonthDotsGrid({
    required this.monthStart,
    required this.daysInMonth,
    required this.habits,
    required this.progress,
  });

  final DateTime monthStart;
  final int daysInMonth;
  final List<Habit> habits;
  final List<HabitDayProgress> progress;

  @override
  Widget build(BuildContext context) {
    final firstWeekday = monthStart.weekday;
    final leading = firstWeekday - 1;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d, style: const TextStyle(fontSize: 11, color: Colors.white38)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: _DayDot(
                    dayIndex: r * 7 + c - leading,
                    daysInMonth: daysInMonth,
                    monthStart: monthStart,
                    habits: habits,
                    progress: progress,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.dayIndex,
    required this.daysInMonth,
    required this.monthStart,
    required this.habits,
    required this.progress,
  });

  final int dayIndex;
  final int daysInMonth;
  final DateTime monthStart;
  final List<Habit> habits;
  final List<HabitDayProgress> progress;

  @override
  Widget build(BuildContext context) {
    if (dayIndex < 0 || dayIndex >= daysInMonth) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox());
    }
    final day = DateTime(monthStart.year, monthStart.month, dayIndex + 1);
    final key = dateKeyFrom(day);
    var metAny = false;
    if (habits.isNotEmpty) {
      metAny = habits.every((h) {
        final p = progress.where((e) => e.habitId == h.id && e.dateKey == key);
        if (p.isEmpty) return false;
        final amt = p.first.amount;
        return _metAmount(h, amt);
      });
    }
    return AspectRatio(
      aspectRatio: 1,
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: metAny ? AppColors.accentTeal : Colors.white12,
          ),
        ),
      ),
    );
  }
}

bool _metAmount(Habit h, double amount) {
  if (h.kind == HabitMeasureKind.checkbox) return amount >= 1;
  final g = h.goalAsAmount;
  if (g <= 0) return amount >= 1;
  return amount >= g - 1e-6;
}

double _monthlyCompletionRate(
  List<HabitDayProgress> progress,
  List<Habit> habits,
  DateTime monthStart,
  DateTime monthEnd,
) {
  if (habits.isEmpty) return 0;
  var slots = 0;
  var met = 0;
  for (var d = monthStart;
      !d.isAfter(monthEnd);
      d = d.add(const Duration(days: 1))) {
    final key = dateKeyFrom(d);
    for (final h in habits) {
      slots++;
      final p = progress.where((e) => e.habitId == h.id && e.dateKey == key);
      final amt = p.isEmpty ? 0.0 : p.first.amount;
      if (_metAmount(h, amt)) met++;
    }
  }
  if (slots == 0) return 0;
  return met / slots;
}

int _perfectDaysCount(
  List<HabitDayProgress> progress,
  List<Habit> habits,
  DateTime monthStart,
  DateTime monthEnd,
) {
  if (habits.isEmpty) return 0;
  var perfect = 0;
  for (var d = monthStart;
      !d.isAfter(monthEnd);
      d = d.add(const Duration(days: 1))) {
    final key = dateKeyFrom(d);
    var all = true;
    for (final h in habits) {
      final p = progress.where((e) => e.habitId == h.id && e.dateKey == key);
      final amt = p.isEmpty ? 0.0 : p.first.amount;
      if (!_metAmount(h, amt)) all = false;
    }
    if (all) perfect++;
  }
  return perfect;
}

int _totalLogsCount(
  List<HabitDayProgress> progress,
  List<Habit> habits,
  DateTime monthStart,
  DateTime monthEnd,
) {
  var n = 0;
  for (final h in habits) {
    for (var d = monthStart;
        !d.isAfter(monthEnd);
        d = d.add(const Duration(days: 1))) {
      final key = dateKeyFrom(d);
      final p = progress.where((e) => e.habitId == h.id && e.dateKey == key);
      if (p.isEmpty) continue;
      if (_metAmount(h, p.first.amount)) n++;
    }
  }
  return n;
}

List<(Habit, DateTime, String)> _doneTodayList(
  HabitTrackerState tracker,
  String? filterId,
  String todayKey,
) {
  final out = <(Habit, DateTime, String)>[];
  final habits = filterId == null
      ? tracker.habits
      : tracker.habits.where((h) => h.id == filterId).toList();
  for (final h in habits) {
    final prog = tracker.dayProgress.where(
      (p) => p.habitId == h.id && p.dateKey == todayKey,
    );
    if (prog.isEmpty) continue;
    final p = prog.first;
    for (final ev in p.events) {
      out.add((
        h,
        ev.at,
        _eventLabel(h, ev.delta ?? 0),
      ));
    }
    if (p.events.isEmpty && _metAmount(h, p.amount)) {
      out.add((h, DateTime.now(), habitProgressLabel(h, p.amount, met: true)));
    }
  }
  out.sort((a, b) => b.$2.compareTo(a.$2));
  return out;
}

String _eventLabel(Habit h, double delta) {
  if (h.kind == HabitMeasureKind.quantity) {
    return '+${delta.toInt()} ${h.unitLabel}'.trim();
  }
  if (h.kind == HabitMeasureKind.countUp) {
    return 'count +${delta.toInt()}';
  }
  if (h.kind == HabitMeasureKind.checkbox) {
    return 'completed';
  }
  return '+${formatDurationSeconds(delta)}';
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.title, this.value);

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        color: AppColors.bgSecondary,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}
