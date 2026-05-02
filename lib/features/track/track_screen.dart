import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/widgets/glass_card.dart';

class TrackScreen extends ConsumerStatefulWidget {
  const TrackScreen({super.key});

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _foodDesc = TextEditingController();
  final _workoutType = TextEditingController(text: 'Run');
  final _workoutMin = TextEditingController(text: '30');
  final _workoutCal = TextEditingController(text: '200');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _foodDesc.dispose();
    _workoutType.dispose();
    _workoutMin.dispose();
    _workoutCal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Body Tracker'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentTeal,
          labelColor: AppColors.accentTeal,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant), text: 'Food'),
            Tab(icon: Icon(Icons.fitness_center), text: 'Workouts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FoodTab(controller: _foodDesc),
          _WorkoutTab(
            typeCtrl: _workoutType,
            minCtrl: _workoutMin,
            calCtrl: _workoutCal,
          ),
        ],
      ),
    );
  }
}

class _FoodTab extends ConsumerWidget {
  const _FoodTab({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(caloriesProvider);
    final todayEntries = entries.where((e) {
      final now = DateTime.now();
      return e.timestamp.year == now.year &&
          e.timestamp.month == now.month &&
          e.timestamp.day == now.day;
    }).toList();
    final total = todayEntries.fold<int>(0, (s, e) => s + e.calories);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Describe your meal',
                  hintText: 'Chicken rice with salad',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (controller.text.trim().isEmpty) return;
                    await ref.read(caloriesProvider.notifier)
                        .logWithAi(controller.text.trim());
                    controller.clear();
                  },
                  child: const Text('Analyze with AI'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Today: $total / 2,000 kcal',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: (total / 2000).clamp(0.0, 1.0),
                  color: AppColors.accentAmber,
                  backgroundColor: Colors.white10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (todayEntries.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No meals logged today. Add one above!'),
            ),
          )
        else
          ...todayEntries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.description),
                    subtitle: Text(
                      'P ${entry.protein}g • C ${entry.carbs}g • F ${entry.fat}g',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${entry.calories} kcal',
                            style: const TextStyle(color: AppColors.accentAmber)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => ref
                              .read(caloriesProvider.notifier)
                              .deleteEntry(entry.id),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
      ],
    );
  }
}

class _WorkoutTab extends ConsumerWidget {
  const _WorkoutTab({
    required this.typeCtrl,
    required this.minCtrl,
    required this.calCtrl,
  });
  final TextEditingController typeCtrl;
  final TextEditingController minCtrl;
  final TextEditingController calCtrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(workoutsProvider);
    final todayWorkouts = workouts.where((e) {
      final now = DateTime.now();
      return e.timestamp.year == now.year &&
          e.timestamp.month == now.month &&
          e.timestamp.day == now.day;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: typeCtrl,
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: minCtrl,
                      decoration: const InputDecoration(labelText: 'Min'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: calCtrl,
                      decoration: const InputDecoration(labelText: 'Kcal'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final mins = int.tryParse(minCtrl.text) ?? 0;
                    final cals = int.tryParse(calCtrl.text) ?? 0;
                    if (typeCtrl.text.trim().isEmpty || mins <= 0) return;
                    ref.read(workoutsProvider.notifier).addWorkout(
                          typeCtrl.text.trim(),
                          mins,
                          cals,
                        );
                    typeCtrl.clear();
                    minCtrl.text = '30';
                    calCtrl.text = '200';
                  },
                  child: const Text('Add Workout'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (todayWorkouts.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No workouts today. Move your body!'),
            ),
          )
        else
          ...todayWorkouts.map((workout) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(workout.type),
                    subtitle: Text(
                      '${workout.durationMin} mins • ${workout.source}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${workout.calories} kcal',
                            style: const TextStyle(color: AppColors.accentTeal)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => ref
                              .read(workoutsProvider.notifier)
                              .deleteEntry(workout.id),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
      ],
    );
  }
}
