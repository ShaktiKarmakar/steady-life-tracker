import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_hub/ai_hub_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/habits/habit_module_shell.dart';
import '../../features/life/life_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/track/track_screen.dart';

final initialLocationProvider = Provider<String>((ref) => '/onboarding');

final appRouterProvider = Provider<GoRouter>((ref) {
  final initial = ref.watch(initialLocationProvider);
  return GoRouter(
    initialLocation: initial,
    redirect: (context, state) {
      // If onboarding not complete, force onboarding
      // We'll handle this in the app startup; for now keep simple
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _MainShell(navigationShell: navigationShell),
        branches: [
          // 1. Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          // 2. Track (Food + Workouts)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/track',
                builder: (context, state) => const TrackScreen(),
              ),
            ],
          ),
          // 3. AI Hub (center control point)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai',
                builder: (context, state) => const AiHubScreen(),
              ),
            ],
          ),
          // 4. Habits
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/habits',
                builder: (context, state) => const HabitModuleShell(),
              ),
            ],
          ),
          // 5. Life (Planner + Notes + Reels)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/life',
                builder: (context, state) => const LifeScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _MainShell extends StatelessWidget {
  const _MainShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0A0A1A).withValues(alpha: 0.9),
        indicatorColor: const Color(0xFF7C6AF7).withValues(alpha: 0.3),
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Track',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist),
            label: 'Habits',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_view_day_outlined),
            label: 'Life',
          ),
        ],
      ),
    );
  }
}
