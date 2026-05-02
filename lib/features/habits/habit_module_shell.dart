import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'home/today_home_screen.dart';
import 'list/habit_library_screen.dart';
import 'profile/habit_profile_screen.dart';
import 'settings/habit_settings_screen.dart';
import 'statistics/habit_statistics_screen.dart';

class HabitModuleShell extends ConsumerStatefulWidget {
  const HabitModuleShell({super.key});

  @override
  ConsumerState<HabitModuleShell> createState() => _HabitModuleShellState();
}

class _HabitModuleShellState extends ConsumerState<HabitModuleShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: IndexedStack(
        index: _index,
        children: [
          TodayHomeScreen(
            onOpenProfile: () => setState(() => _index = 2),
          ),
          const HabitStatisticsScreen(),
          const HabitProfileScreen(),
          const HabitLibraryScreen(),
          const HabitSettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        backgroundColor: AppColors.bgSecondary.withValues(alpha: 0.95),
        indicatorColor: AppColors.accentPurple.withValues(alpha: 0.25),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Statistics',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'List',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
