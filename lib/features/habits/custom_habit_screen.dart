import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/models.dart';
import 'habit_tracker_notifier.dart';

class CustomHabitScreen extends ConsumerStatefulWidget {
  const CustomHabitScreen({super.key});

  @override
  ConsumerState<CustomHabitScreen> createState() => _CustomHabitScreenState();
}

class _CustomHabitScreenState extends ConsumerState<CustomHabitScreen> {
  final _name = TextEditingController();
  final _emoji = TextEditingController(text: '✨');
  HabitMeasureKind _kind = HabitMeasureKind.checkbox;
  final _goalSec = TextEditingController(text: '1800');
  final _goalCount = TextEditingController(text: '1');
  final _goalAmt = TextEditingController(text: '2000');
  final _increment = TextEditingController(text: '250');
  final _unit = TextEditingController(text: 'ml');
  HabitTimeOfDay _when = HabitTimeOfDay.anytime;
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    _goalSec.dispose();
    _goalCount.dispose();
    _goalAmt.dispose();
    _increment.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    final emoji = _emoji.text.trim().isEmpty ? '✅' : _emoji.text.trim();
    final sec = int.tryParse(_goalSec.text) ?? 1800;
    final gc = int.tryParse(_goalCount.text) ?? 1;
    final ga = double.tryParse(_goalAmt.text) ?? 2000;
    final inc = double.tryParse(_increment.text) ?? 1;

    final reminderTime = _reminderEnabled
        ? '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}'
        : null;

    final habit = Habit(
      id: '',
      name: name,
      emoji: emoji,
      kind: _kind,
      goalSeconds: sec,
      goalCount: gc,
      goalAmount: ga,
      quantityIncrement: inc,
      unitLabel: _unit.text.trim(),
      timeOfDay: _when,
      accentColor: 0xFF7C6AF7,
      reminderEnabled: _reminderEnabled,
      reminderTime: reminderTime,
    );

    await ref.read(habitTrackerProvider.notifier).addHabit(habit);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom habit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          Row(
            children: [
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _emoji,
                  decoration: const InputDecoration(labelText: 'Emoji'),
                  inputFormatters: [LengthLimitingTextInputFormatter(4)],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<HabitMeasureKind>(
                  // ignore: deprecated_member_use — controlled rebuild via setState
                  value: _kind,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: HabitMeasureKind.checkbox, child: Text('Check-off')),
                    DropdownMenuItem(value: HabitMeasureKind.countUp, child: Text('Count')),
                    DropdownMenuItem(value: HabitMeasureKind.quantity, child: Text('Quantity / liquid')),
                    DropdownMenuItem(value: HabitMeasureKind.timerStopwatch, child: Text('Timer (stopwatch)')),
                    DropdownMenuItem(value: HabitMeasureKind.timerCountdown, child: Text('Countdown')),
                  ],
                  onChanged: (v) => setState(() => _kind = v ?? _kind),
                ),
              ),
            ],
          ),
          if (_kind == HabitMeasureKind.timerStopwatch ||
              _kind == HabitMeasureKind.timerCountdown)
            TextField(
              controller: _goalSec,
              decoration: const InputDecoration(labelText: 'Goal (seconds)'),
              keyboardType: TextInputType.number,
            ),
          if (_kind == HabitMeasureKind.countUp)
            TextField(
              controller: _goalCount,
              decoration: const InputDecoration(labelText: 'Goal count'),
              keyboardType: TextInputType.number,
            ),
          if (_kind == HabitMeasureKind.quantity) ...[
            TextField(
              controller: _goalAmt,
              decoration: const InputDecoration(labelText: 'Goal amount'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _increment,
              decoration: const InputDecoration(labelText: 'Add increment'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _unit,
              decoration: const InputDecoration(labelText: 'Unit (ml, cups, …)'),
            ),
          ],
          DropdownButtonFormField<HabitTimeOfDay>(
            // ignore: deprecated_member_use
            value: _when,
            decoration: const InputDecoration(labelText: 'Time of day (filter)'),
            items: const [
              DropdownMenuItem(value: HabitTimeOfDay.anytime, child: Text('Anytime')),
              DropdownMenuItem(value: HabitTimeOfDay.morning, child: Text('Morning')),
              DropdownMenuItem(value: HabitTimeOfDay.afternoon, child: Text('Afternoon')),
              DropdownMenuItem(value: HabitTimeOfDay.evening, child: Text('Evening')),
            ],
            onChanged: (v) => setState(() => _when = v ?? _when),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Daily reminder'),
            subtitle: Text(_reminderEnabled
                ? 'At ${_reminderTime.format(context)}'
                : 'Off'),
            value: _reminderEnabled,
            onChanged: (v) => setState(() => _reminderEnabled = v),
          ),
          if (_reminderEnabled)
            ListTile(
              title: const Text('Reminder time'),
              trailing: Text(_reminderTime.format(context)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _reminderTime,
                );
                if (picked != null) {
                  setState(() => _reminderTime = picked);
                }
              },
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: const Text('Create habit'),
          ),
        ],
      ),
    );
  }
}
