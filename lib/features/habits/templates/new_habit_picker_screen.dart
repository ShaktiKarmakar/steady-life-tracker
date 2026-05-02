import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/habit_templates.dart';
import '../habit_tracker_notifier.dart';
import '../navigation/habit_navigation.dart';

class NewHabitPickerScreen extends ConsumerStatefulWidget {
  const NewHabitPickerScreen({super.key});

  @override
  ConsumerState<NewHabitPickerScreen> createState() => _NewHabitPickerScreenState();
}

class _NewHabitPickerScreenState extends ConsumerState<NewHabitPickerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: habitCategoryOrder.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ids = ref.watch(habitTrackerProvider).habits.map((h) => h.name).toSet();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('New habit'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [for (final c in habitCategoryOrder) Tab(text: c)],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final cat in habitCategoryOrder)
            _TemplateList(
              category: cat,
              existingNames: ids,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openCustomHabit(context),
        backgroundColor: AppColors.accentPurple,
        icon: const Icon(Icons.edit_note),
        label: const Text('Custom habit'),
      ),
    );
  }
}

class _TemplateList extends ConsumerWidget {
  const _TemplateList({
    required this.category,
    required this.existingNames,
  });

  final String category;
  final Set<String> existingNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = habitTemplatesByCategory[category] ?? [];
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final t = list[i];
        final exists = existingNames.contains(t.name);
        return ListTile(
          tileColor: AppColors.bgSecondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: Text(t.emoji, style: const TextStyle(fontSize: 28)),
          title: Text(t.name),
          trailing: IconButton(
            icon: Icon(exists ? Icons.add : Icons.add_circle_outline),
            onPressed: () async {
              await ref.read(habitTrackerProvider.notifier).addHabit(t.toHabit());
              if (context.mounted) Navigator.pop(context);
            },
          ),
        );
      },
    );
  }
}
