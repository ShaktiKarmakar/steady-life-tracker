import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ai/gemma_service.dart';
import '../../core/theme/app_theme.dart';
import '../../features/habits/habit_tracker_notifier.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/widgets/animated_blobs_background.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_ring.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _aiBriefing = '';
  bool _briefingLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateBriefing());
  }

  Future<void> _generateBriefing() async {
    if (!mounted) return;
    setState(() => _briefingLoading = true);
    try {
      final habits = ref.read(habitsProvider);
      final calories = ref.read(caloriesProvider);
      final workouts = ref.read(workoutsProvider);
      final briefing = await ref.read(gemmaServiceProvider)
          .generateDailyBriefing(habits, calories, workouts);
      if (mounted) setState(() => _aiBriefing = briefing);
    } catch (e) {
      debugPrint('Briefing error: $e');
      if (mounted) {
        setState(() => _aiBriefing =
            'Welcome back! Track your habits, meals, and workouts to get personalized insights.');
      }
    } finally {
      if (mounted) setState(() => _briefingLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiUi = ref.watch(aiModelUiStatusProvider);
    final habits = ref.watch(habitsProvider);
    final calorieEntries = ref.watch(caloriesProvider);
    final workouts = ref.watch(workoutsProvider);
    final notes = ref.watch(notesProvider);
    final reels = ref.watch(reelsProvider);

    final now = DateTime.now();
    final todayCalories = calorieEntries
        .where((e) =>
            e.timestamp.year == now.year &&
            e.timestamp.month == now.month &&
            e.timestamp.day == now.day)
        .fold<int>(0, (s, e) => s + e.calories);
    final todayWorkouts = workouts.where((e) =>
        e.timestamp.year == now.year &&
        e.timestamp.month == now.month &&
        e.timestamp.day == now.day);
    final workoutMins = todayWorkouts.fold<int>(0, (s, e) => s + e.durationMin);
    // Simple heuristic life score: habits + calories progress + workout
    final calProgress = (todayCalories / 2000).clamp(0.0, 1.0);
    final habitN = ref.read(habitTrackerProvider.notifier);
    final habitScore = habits.isEmpty
        ? 0.0
        : habits.where((h) => habitN.isMetOnDate(h, now)).length / habits.length;
    final workoutScore = (workoutMins / 30).clamp(0.0, 1.0);
    final lifeScore = ((calProgress + habitScore + workoutScore) / 3)
        .clamp(0.0, 1.0);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBlobsBackground()),
          RefreshIndicator(
            onRefresh: () async => _generateBriefing(),
            color: AppColors.accentPurple,
            backgroundColor: AppColors.bgSecondary,
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _Header(),
                  const SizedBox(height: 12),
                  _AiModelLine(
                    aiUi,
                    onRefresh: () =>
                        ref.read(aiModelUiTickProvider.notifier).bump(),
                    onRepairDownload: () async {
                      await ref
                          .read(gemmaServiceProvider)
                          .removeLocalModelForReinstall();
                      ref.read(aiModelUiTickProvider.notifier).bump();
                      if (context.mounted) context.go('/onboarding');
                    },
                  ),
                  const SizedBox(height: 12),
                  _AiBriefingCard(
                    text: _aiBriefing,
                    loading: _briefingLoading,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GlassCard(
                          child: Column(
                            children: [
                              GradientRing(
                                value: lifeScore,
                                label: '${(lifeScore * 100).toInt()}',
                              ),
                              const SizedBox(height: 8),
                              const Text('Life score'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassCard(
                          child: Column(
                            children: [
                              GradientRing(
                                value: calProgress,
                                label: '${(calProgress * 100).toInt()}%',
                                gradient: const LinearGradient(
                                  colors: [AppColors.accentAmber, AppColors.accentPink],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text('Food today'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _SectionTitle('Today\'s habits'),
                  const SizedBox(height: 8),
                  if (habits.isEmpty)
                    const _EmptyHint('No habits yet. Add them in the Habits tab!')
                  else
                    _HabitRow(
                      habits: habits,
                      metToday: (h) =>
                          ref.read(habitTrackerProvider.notifier).isMetOnDate(h, now),
                    ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Calories',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            Text('+ Log food',
                                style: TextStyle(color: AppColors.accentAmber)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$todayCalories',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text('of 2,000 kcal'),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: calProgress,
                            color: AppColors.accentAmber,
                            backgroundColor: Colors.white10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _SectionTitle('Quick access'),
                  const SizedBox(height: 8),
                  _QuickAccessGrid(
                    noteCount: notes.length,
                    taskCount: ref.watch(plannerTasksProvider).length,
                    workoutMins: workoutMins,
                    reelCount: reels.length,
                  ),
                  const SizedBox(height: 12),
                  const _SectionTitle('Saved reels'),
                  const SizedBox(height: 8),
                  if (reels.isEmpty)
                    const _EmptyHint('No reels saved yet. Save one in the Life tab!')
                  else
                    _ReelRow(reels: reels.take(6).toList()),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good ${greeting()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color.fromRGBO(240, 238, 255, 0.55),
                  ),
            ),
            const SizedBox(height: 4),
            Text('Steady', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        const CircleAvatar(
          backgroundColor: AppColors.accentPurple,
          child: Icon(Icons.person, color: Colors.white),
        ),
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

class _AiBriefingCard extends StatelessWidget {
  const _AiBriefingCard({required this.text, required this.loading});
  final String text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 14, color: AppColors.accentPurple),
              const SizedBox(width: 6),
              const Text(
                'STEADY AI · Daily briefing',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: AppColors.accentPurple,
                ),
              ),
              if (loading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(text.isEmpty ? 'Generating your daily briefing...' : text),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({required this.habits, required this.metToday});
  final List<Habit> habits;
  final bool Function(Habit) metToday;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: habits.map((habit) {
          final completedToday = metToday(habit);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Text('${habit.emoji} ${habit.name}'),
                  const SizedBox(width: 6),
                  Text(
                    '${habit.currentStreak}🔥',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accentAmber,
                    ),
                  ),
                  if (completedToday)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.check_circle,
                          size: 14, color: AppColors.accentTeal),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid({
    required this.noteCount,
    required this.taskCount,
    required this.workoutMins,
    required this.reelCount,
  });
  final int noteCount;
  final int taskCount;
  final int workoutMins;
  final int reelCount;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Notes', '$noteCount saved'),
      ('Workout', '$workoutMins min today'),
      ('Planner', '$taskCount tasks'),
      ('Reels', '$reelCount saved'),
    ];
    return GridView.builder(
      itemCount: cards.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final card = cards[index];
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(card.$1,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 14)),
              const SizedBox(height: 6),
              Text(card.$2,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}

class _ReelRow extends StatelessWidget {
  const _ReelRow({required this.reels});
  final List<SavedReel> reels;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: reels.map((reel) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.play_arrow, color: AppColors.accentPink),
                    const SizedBox(height: 4),
                    Text(
                      reel.caption.isEmpty ? 'Reel' : reel.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: reel.aiTags
                          .take(2)
                          .map((t) => Chip(
                                label: Text(t, style: const TextStyle(fontSize: 10)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                backgroundColor:
                                    AppColors.accentPink.withValues(alpha: 0.15),
                                side: BorderSide.none,
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AiModelLine extends StatelessWidget {
  const _AiModelLine(
    this.async, {
    required this.onRefresh,
    required this.onRepairDownload,
  });

  final AsyncValue<AiModelUiStatus> async;
  final VoidCallback onRefresh;
  final VoidCallback onRepairDownload;

  @override
  Widget build(BuildContext context) {
    return async.when(
      data: (s) => GlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    s.readyToRun
                        ? Icons.smart_toy_outlined
                        : Icons.cloud_off_outlined,
                    size: 20,
                    color: s.readyToRun
                        ? Colors.greenAccent
                        : Colors.amberAccent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.subtitle,
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh model status',
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: onRefresh,
                  ),
                ],
              ),
              if (!s.readyToRun) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onRepairDownload,
                    icon: const Icon(Icons.downloading, size: 18),
                    label: const Text(
                      'Clear install & open download (~2.6 GB)',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: const TextStyle(color: Colors.white54)),
      ),
    );
  }
}
