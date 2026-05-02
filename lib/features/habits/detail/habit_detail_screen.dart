import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
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
        backgroundColor: AppColors.bgSecondary,
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
                  color: met ? AppColors.accentTeal : Colors.white54,
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
                colors: [widget.habit.accentColorValue, AppColors.accentPink],
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
  bool _running = false;
  Ticker? _ticker;
  Duration _session = Duration.zero;
  DateTime? _startedAt;

  @override
  void dispose() {
    if (_running && _startedAt != null) {
      _session += DateTime.now().difference(_startedAt!);
    }
    _ticker?.dispose();
    final sec = _session.inMilliseconds / 1000.0;
    if (sec > 0) {
      final n = ref.read(habitTrackerProvider.notifier);
      unawaited(n.addTimerSeconds(widget.habit, widget.day, sec));
    }
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _ticker?.dispose();
      _ticker = null;
      if (_startedAt != null) {
        _session += DateTime.now().difference(_startedAt!);
      }
      _running = false;
      _startedAt = null;
      unawaited(_flushSession());
    } else {
      _running = true;
      _startedAt = DateTime.now();
      _ticker = Ticker((_) => setState(() {}))..start();
    }
    setState(() {});
  }

  Future<void> _flushSession() async {
    if (_session.inMilliseconds <= 0) return;
    final sec = _session.inMilliseconds / 1000.0;
    await ref.read(habitTrackerProvider.notifier).addTimerSeconds(widget.habit, widget.day, sec);
    _session = Duration.zero;
  }

  Duration get _displayElapsed {
    var d = _session;
    if (_running && _startedAt != null) {
      d += DateTime.now().difference(_startedAt!);
    }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.habit.goalSeconds.toDouble();
    final total = widget.amount + _displayElapsed.inMilliseconds / 1000.0;
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
              colors: [widget.habit.accentColorValue, AppColors.accentPink],
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
                icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                label: Text(_running ? 'Pause' : 'Start'),
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
  bool _running = false;
  Timer? _timer;
  int _remainingSec = 0;
  late int _initialGoal;

  @override
  void initState() {
    super.initState();
    _initialGoal = widget.habit.goalSeconds;
    _remainingSec = _initialGoal;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    if (_running) return;
    setState(() {
      _remainingSec = _initialGoal;
      _running = true;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSec <= 1) {
        t.cancel();
        setState(() {
          _running = false;
          _remainingSec = _initialGoal;
        });
        unawaited(_onSessionComplete());
        return;
      }
      setState(() => _remainingSec--);
    });
  }

  Future<void> _onSessionComplete() async {
    await ref
        .read(habitTrackerProvider.notifier)
        .addTimerSeconds(widget.habit, widget.day, _initialGoal.toDouble());
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _running = false;
      _remainingSec = _initialGoal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.habit.goalSeconds.toDouble();
    final dayTotal = widget.amount;
    final frac = goal > 0 ? (dayTotal / goal).clamp(0.0, 1.0) : 0.0;
    final ringFrac = _running
        ? ((_initialGoal - _remainingSec) / _initialGoal).clamp(0.0, 1.0)
        : frac;
    final centerLabel = _running
        ? _remainingSec.toDouble()
        : dayTotal;

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
                value: ringFrac,
                label: formatDurationSeconds(centerLabel),
                gradient: LinearGradient(
                  colors: [widget.habit.accentColorValue, AppColors.accentTeal],
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
                onPressed: _running ? null : _start,
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
