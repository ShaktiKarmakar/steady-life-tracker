import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_tokens.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/gradient_ring.dart';
import '../habit_formatters.dart';
import '../habit_tracker_notifier.dart';
import 'quantity_glass.dart';

class HabitDetailScreen extends ConsumerStatefulWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final String habitId;

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  final _memo = TextEditingController();

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(habitTrackerProvider);
    Habit? habit;
    for (final h in state.habits) {
      if (h.id == widget.habitId) habit = h;
    }
    if (habit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Habit')),
        body: const Center(child: Text('Not found')),
      );
    }
    final selected = ref.watch(habitSelectedDateProvider);
    final notifier = ref.read(habitTrackerProvider.notifier);
    final amount = notifier.progressFor(habit.id, dateKeyFrom(selected));
    final met = notifier.isMetOnDay(habit, dateKeyFrom(selected));

    return Scaffold(
      appBar: AppBar(
        title: Text('${habit.emoji} ${habit.name}'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            (Theme.of(context).brightness == Brightness.dark
                ? DesignTokens.bgSurfaceDark
                : DesignTokens.bgSurfaceLight),
      ),
      body: switch (habit.kind) {
        HabitMeasureKind.checkbox => _CheckboxBody(
            habit: habit,
            day: selected,
            met: met,
            memo: _memo,
          ),
        HabitMeasureKind.countUp => _CountBody(
            habit: habit,
            day: selected,
            amount: amount,
            memo: _memo,
          ),
        HabitMeasureKind.quantity => _QuantityBody(
            habit: habit,
            day: selected,
            amount: amount,
            met: met,
            memo: _memo,
          ),
        HabitMeasureKind.timerStopwatch => _StopwatchBody(
            habit: habit,
            day: selected,
            amount: amount,
            memo: _memo,
          ),
        HabitMeasureKind.timerCountdown => _CountdownBody(
            habit: habit,
            day: selected,
            amount: amount,
            memo: _memo,
          ),
      },
    );
  }
}

class _MemoBar extends ConsumerWidget {
  const _MemoBar({required this.habit, required this.day, required this.controller});

  final Habit habit;
  final DateTime day;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Memo',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () async {
            final t = controller.text.trim();
            if (t.isEmpty) return;
            await ref.read(habitTrackerProvider.notifier).appendMemo(habit, day, t);
            if (context.mounted) {
              controller.clear();
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Memo saved')));
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// --- Checkbox ---

class _CheckboxBody extends ConsumerWidget {
  const _CheckboxBody({
    required this.habit,
    required this.day,
    required this.met,
    required this.memo,
  });

  final Habit habit;
  final DateTime day;
  final bool met;
  final TextEditingController memo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Spacer(),
          SizedBox(
            width: 200,
            height: 200,
            child: Material(
              color: habit.accentColorValue.withValues(alpha: 0.2),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => ref
                    .read(habitTrackerProvider.notifier)
                    .setCheckboxDone(habit, day, !met),
                child: Icon(
                  met ? Icons.check : Icons.radio_button_unchecked,
                  size: 100,
                  color: met
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? DesignTokens.okTextDark
                          : DesignTokens.okTextLight)
                      : (Theme.of(context).brightness == Brightness.dark
                          ? DesignTokens.textMutedDark
                          : DesignTokens.textMutedLight),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            met ? 'Done for this day' : 'Tap to mark complete',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (habit.note != null && habit.note!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(habit.note!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          ],
          const Spacer(),
          _MemoBar(habit: habit, day: day, controller: memo),
        ],
      ),
    );
  }
}

// --- Count ---

class _CountBody extends ConsumerStatefulWidget {
  const _CountBody({
    required this.habit,
    required this.day,
    required this.amount,
    required this.memo,
  });

  final Habit habit;
  final DateTime day;
  final double amount;
  final TextEditingController memo;

  @override
  ConsumerState<_CountBody> createState() => _CountBodyState();
}

class _CountBodyState extends ConsumerState<_CountBody> {
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.amount.toInt();
  }

  @override
  void didUpdateWidget(covariant _CountBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount) {
      _count = widget.amount.toInt();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.habit.goalCount;
    final frac = (_count / g).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Spacer(),
          SizedBox(
            width: 200,
            height: 200,
            child: GradientRing(
              value: frac,
              label: '$_count',
              gradient: LinearGradient(
                colors: [
                  widget.habit.accentColorValue,
                  Theme.of(context).brightness == Brightness.dark
                      ? DesignTokens.textSecondaryDark
                      : DesignTokens.textSecondaryLight
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed:
                    _count > 0 ? () => setState(() => _count--) : null,
                icon: const Icon(Icons.remove_circle_outline, size: 36),
              ),
              Text('$g goal',
                  style: const TextStyle(fontSize: 14, color: Colors.white54)),
              IconButton(
                onPressed: () => setState(() => _count++),
                icon: const Icon(Icons.add_circle_outline, size: 36),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _count = 0),
                child: const Text('Reset'),
              ),
              FilledButton(
                onPressed: () => ref
                    .read(habitTrackerProvider.notifier)
                    .setCount(widget.habit, widget.day, _count),
                child: const Text('Log count'),
              ),
              FilledButton.tonal(
                onPressed: () => ref
                    .read(habitTrackerProvider.notifier)
                    .setCount(widget.habit, widget.day, g),
                child: const Icon(Icons.check),
              ),
            ],
          ),
          if (widget.habit.note != null) ...[
            const SizedBox(height: 12),
            Text(widget.habit.note!, textAlign: TextAlign.center),
          ],
          const Spacer(),
          _MemoBar(habit: widget.habit, day: widget.day, controller: widget.memo),
        ],
      ),
    );
  }
}

// --- Quantity / glass ---

class _QuantityBody extends ConsumerWidget {
  const _QuantityBody({
    required this.habit,
    required this.day,
    required this.amount,
    required this.met,
    required this.memo,
  });

  final Habit habit;
  final DateTime day;
  final double amount;
  final bool met;
  final TextEditingController memo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = habit.goalAmount;
    final frac = g > 0 ? (amount / g).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Spacer(),
          SizedBox(
            height: 220,
            child: WaterGlass(
              fill: frac,
              color: habit.accentColorValue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            habitProgressLabel(habit, amount, met: met),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
            onPressed: () => ref
                .read(habitTrackerProvider.notifier)
                .quickLogPlus(habit, day),
            child: Text('Add +${habit.quantityIncrement.toInt()}${habit.unitLabel.isEmpty ? '' : ' ${habit.unitLabel}'}'),
          ),
          const Spacer(),
          _MemoBar(habit: habit, day: day, controller: memo),
        ],
      ),
    );
  }
}

// --- Stopwatch ---

class _StopwatchBody extends ConsumerStatefulWidget {
  const _StopwatchBody({
    required this.habit,
    required this.day,
    required this.amount,
    required this.memo,
  });

  final Habit habit;
  final DateTime day;
  final double amount;
  final TextEditingController memo;

  @override
  ConsumerState<_StopwatchBody> createState() => _StopwatchBodyState();
}

class _StopwatchBodyState extends ConsumerState<_StopwatchBody> {
  TimerSessionState get _timer =>
      ref.read(habitTimerProvider.select((m) => m[widget.habit.id])) ??
      const TimerSessionState();

  @override
  void dispose() {
    final notifier = ref.read(habitTimerProvider.notifier);
    final elapsed = notifier.flushAndReset(widget.habit.id);
    if (elapsed > 0) {
      unawaited(
        ref.read(habitTrackerProvider.notifier)
            .addTimerSeconds(widget.habit, widget.day, elapsed),
      );
    }
    super.dispose();
  }

  void _toggle() {
    final notifier = ref.read(habitTimerProvider.notifier);
    if (_timer.running) {
      notifier.pause(widget.habit.id);
      final elapsed = notifier.flushAndReset(widget.habit.id);
      if (elapsed > 0) {
        unawaited(
          ref.read(habitTrackerProvider.notifier)
              .addTimerSeconds(widget.habit, widget.day, elapsed),
        );
      }
    } else {
      notifier.start(widget.habit.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(
          habitTimerProvider.select((m) => m[widget.habit.id]),
        ) ??
        const TimerSessionState();
    final goal = widget.habit.goalSeconds.toDouble();
    final elapsed = timer.elapsedSec;
    final total = widget.amount + elapsed;
    final frac = goal > 0 ? (total / goal).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Spacer(),
          GradientRing(
            value: frac,
            label: formatDurationSeconds(total),
            gradient: LinearGradient(
              colors: [
                widget.habit.accentColorValue,
                Theme.of(context).brightness == Brightness.dark
                    ? DesignTokens.textSecondaryDark
                    : DesignTokens.textSecondaryLight
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Goal ${formatDurationSeconds(goal)}',
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _toggle,
                icon: Icon(timer.running ? Icons.pause : Icons.play_arrow),
                label: Text(timer.running ? 'Pause' : 'Start'),
              ),
            ],
          ),
          const Spacer(),
          _MemoBar(habit: widget.habit, day: widget.day, controller: widget.memo),
        ],
      ),
    );
  }
}

// --- Countdown ---

class _CountdownBody extends ConsumerStatefulWidget {
  const _CountdownBody({
    required this.habit,
    required this.day,
    required this.amount,
    required this.memo,
  });

  final Habit habit;
  final DateTime day;
  final double amount;
  final TextEditingController memo;

  @override
  ConsumerState<_CountdownBody> createState() => _CountdownBodyState();
}

class _CountdownBodyState extends ConsumerState<_CountdownBody> {
  @override
  void dispose() {
    final notifier = ref.read(habitTimerProvider.notifier);
    final elapsed = notifier.flushAndReset(widget.habit.id);
    final goal = widget.habit.goalSeconds.toDouble();
    if (elapsed > 0) {
      unawaited(
        ref.read(habitTrackerProvider.notifier)
            .addTimerSeconds(widget.habit, widget.day, elapsed.clamp(0, goal)),
      );
    }
    super.dispose();
  }

  void _start() {
    final notifier = ref.read(habitTimerProvider.notifier);
    notifier.reset(widget.habit.id);
    notifier.start(widget.habit.id);
  }

  void _reset() {
    ref.read(habitTimerProvider.notifier).reset(widget.habit.id);
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(
          habitTimerProvider.select((m) => m[widget.habit.id]),
        ) ??
        const TimerSessionState();
    final goal = widget.habit.goalSeconds.toDouble();
    final elapsed = timer.elapsedSec;
    final remaining = (goal - elapsed).clamp(0.0, goal);
    final frac = goal > 0 ? (elapsed / goal).clamp(0.0, 1.0) : 0.0;
    final dayTotal = widget.amount;

    // Auto-complete when countdown reaches zero.
    if (timer.running && elapsed >= goal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(habitTimerProvider.notifier);
        final logged = notifier.flushAndReset(widget.habit.id);
        if (logged > 0) {
          unawaited(
            ref.read(habitTrackerProvider.notifier)
                .addTimerSeconds(widget.habit, widget.day, logged.clamp(0, goal)),
          );
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Spacer(),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                  painter: _LapDotsPainter(),
                ),
              ),
              GradientRing(
                value: frac,
                label: formatDurationSeconds(remaining),
                gradient: LinearGradient(
                  colors: [
                  widget.habit.accentColorValue,
                  Theme.of(context).brightness == Brightness.dark
                      ? DesignTokens.textSecondaryDark
                      : DesignTokens.textSecondaryLight
                ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Today logged: ${formatDurationSeconds(dayTotal)} / ${formatDurationSeconds(goal)}',
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(onPressed: _reset, child: const Text('Reset')),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: timer.running ? null : _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
            ],
          ),
          const Spacer(),
          _MemoBar(habit: widget.habit, day: widget.day, controller: widget.memo),
        ],
      ),
    );
  }
}

class _LapDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    final p = Paint()..color = Colors.white24;
    for (final a in [0.4, 2.1]) {
      final x = c.dx + r * math.cos(a) * 0.92;
      final y = c.dy + r * math.sin(a) * 0.92;
      canvas.drawCircle(Offset(x, y), 5, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
