import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/animated_blobs_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../habit_tracker_notifier.dart';

class HabitProfileScreen extends ConsumerStatefulWidget {
  const HabitProfileScreen({super.key});

  @override
  ConsumerState<HabitProfileScreen> createState() => _HabitProfileScreenState();
}

class _HabitProfileScreenState extends ConsumerState<HabitProfileScreen> {
  final _nameController = TextEditingController();

  static const _quotes = [
    'Small steps every day add up.',
    'Consistency beats intensity.',
    'Progress, not perfection.',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(habitTrackerProvider).profile;
    if (_nameController.text.isEmpty && profile.displayName.isNotEmpty) {
      _nameController.text = profile.displayName;
    }

    final weekStart = _mondayOf(DateTime.now());
    final quote = _quotes[DateTime.now().day % _quotes.length];

    return Stack(
      children: [
        const Positioned.fill(child: AnimatedBlobsBackground()),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.accentPurple,
                    child: Icon(Icons.person, size: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Display name',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (v) => ref
                              .read(habitTrackerProvider.notifier)
                              .setProfile(profile.copyWith(displayName: v.trim())),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.workspace_premium, color: AppColors.accentAmber),
                        const SizedBox(width: 8),
                        Text(
                          'Upgrade to Premium',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Unlock themes, insights, and more when available.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Moods (7 days)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final day = weekStart.add(Duration(days: i));
                  final key = dateKeyFrom(day);
                  final mood = profile.weeklyMoods[key];
                  return InkWell(
                    onTap: () => _pickMood(context, ref, key),
                    child: Column(
                      children: [
                        Text(
                          ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                          style: const TextStyle(fontSize: 11, color: Colors.white38),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.bgSecondary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            mood ?? '·',
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              const Text('Stress meter', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    profile.stressLevel == null
                        ? 'No data yet — log stress from settings later.'
                        : 'Level: ${(profile.stressLevel! * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Daily quote', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GlassCard(
                child: Text(
                  quote,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static DateTime _mondayOf(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  Future<void> _pickMood(BuildContext context, WidgetRef ref, String key) async {
    const moods = ['😀', '🙂', '😐', '😟', '😢'];
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      builder: (c) => SafeArea(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: [
            for (final m in moods)
              IconButton(
                icon: Text(m, style: const TextStyle(fontSize: 28)),
                onPressed: () => Navigator.pop(c, m),
              ),
          ],
        ),
      ),
    );
    if (pick != null) {
      await ref.read(habitTrackerProvider.notifier).setMoodForDay(key, pick);
    }
  }
}
