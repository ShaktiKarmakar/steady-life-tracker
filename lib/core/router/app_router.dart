import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/db/database.dart';
import '../../core/design_system/animations.dart';
import '../../core/design_system/design_tokens.dart';
import '../../features/ai_hub/ai_hub_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/habits/habit_module_shell.dart';
import '../../features/habits/profile/habit_profile_screen.dart';
import '../../features/habits/settings/habit_settings_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/track/track_screen.dart';
import '../../shared/widgets/page_transition.dart';

final initialLocationProvider = Provider<String>((ref) {
  final db = ref.watch(databaseProvider);
  if (!db.onboardingComplete) return '/onboarding';
  return '/home';
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final initial = ref.watch(initialLocationProvider);
  return GoRouter(
    initialLocation: initial,
    redirect: (context, state) {
      final path = state.matchedLocation;

      // Redirect to onboarding if not complete
      if ((path == '/home' ||
              path == '/habits' ||
              path == '/ai' ||
              path == '/track' ||
              path.startsWith('/you')) &&
          !ref.read(databaseProvider).onboardingComplete) {
        return '/onboarding';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => SteadyTransitionPage(
          key: state.pageKey,
          type: SteadyTransitionType.fadeSlide,
          child: const OnboardingScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _MainShell(navigationShell: navigationShell),
        branches: [
          // 1. Today (Home)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) => SteadyTransitionPage(
                  key: state.pageKey,
                  type: SteadyTransitionType.fade,
                  child: const DashboardScreen(),
                ),
              ),
            ],
          ),
          // 2. Habits
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/habits',
                pageBuilder: (context, state) => SteadyTransitionPage(
                  key: state.pageKey,
                  type: SteadyTransitionType.fade,
                  child: const HabitModuleShell(),
                ),
              ),
            ],
          ),
          // 3. AI Hub
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai',
                pageBuilder: (context, state) => SteadyTransitionPage(
                  key: state.pageKey,
                  type: SteadyTransitionType.fade,
                  child: const AiHubScreen(),
                ),
              ),
            ],
          ),
          // 4. Track (Health)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/track',
                pageBuilder: (context, state) => SteadyTransitionPage(
                  key: state.pageKey,
                  type: SteadyTransitionType.fade,
                  child: const TrackScreen(),
                ),
              ),
            ],
          ),
          // 5. You (Profile & Settings)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/you',
                pageBuilder: (context, state) => SteadyTransitionPage(
                  key: state.pageKey,
                  type: SteadyTransitionType.fade,
                  child: const HabitProfileScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'settings',
                    pageBuilder: (context, state) => SteadyTransitionPage(
                      key: state.pageKey,
                      type: SteadyTransitionType.fadeSlide,
                      child: const HabitSettingsScreen(),
                    ),
                  ),
                ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DesignTokens.bgOverlayDark : DesignTokens.bgOverlayLight;
    final border = isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    final textActive = isDark ? DesignTokens.textPrimaryDark : DesignTokens.textPrimaryLight;
    final activeBg = isDark
        ? DesignTokens.accentActiveDark.withValues(alpha: 0.5)
        : DesignTokens.accentActiveLight.withValues(alpha: 0.8);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(
              color: border,
              width: DesignTokens.borderWidthDefault,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: LucideIcons.calendarDays,
                  label: 'Today',
                  isActive: navigationShell.currentIndex == 0,
                  onTap: () => navigationShell.goBranch(0),
                  activeColor: textActive,
                  inactiveColor: textMuted,
                  activeBg: activeBg,
                ),
                _NavItem(
                  icon: LucideIcons.checkCircle,
                  label: 'Habits',
                  isActive: navigationShell.currentIndex == 1,
                  onTap: () => navigationShell.goBranch(1),
                  activeColor: textActive,
                  inactiveColor: textMuted,
                  activeBg: activeBg,
                ),
                _NavItem(
                  icon: LucideIcons.sparkles,
                  label: 'AI',
                  isActive: navigationShell.currentIndex == 2,
                  onTap: () => navigationShell.goBranch(2),
                  activeColor: textActive,
                  inactiveColor: textMuted,
                  activeBg: activeBg,
                ),
                _NavItem(
                  icon: LucideIcons.heart,
                  label: 'Track',
                  isActive: navigationShell.currentIndex == 3,
                  onTap: () => navigationShell.goBranch(3),
                  activeColor: textActive,
                  inactiveColor: textMuted,
                  activeBg: activeBg,
                ),
                _NavItem(
                  icon: LucideIcons.user,
                  label: 'You',
                  isActive: navigationShell.currentIndex == 4,
                  onTap: () => navigationShell.goBranch(4),
                  activeColor: textActive,
                  inactiveColor: textMuted,
                  activeBg: activeBg,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
    required this.activeBg,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;
  final Color activeBg;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: SteadyAnimations.fast,
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: SteadyAnimations.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: AnimatedContainer(
              duration: SteadyAnimations.normal,
              curve: SteadyAnimations.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isActive ? widget.activeBg : Colors.transparent,
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              ),
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: SteadyAnimations.normal,
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Icon(
                widget.icon,
                key: ValueKey<bool>(widget.isActive),
                size: DesignTokens.iconSizeNav + 2,
                color: widget.isActive ? widget.activeColor : widget.inactiveColor,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: SteadyAnimations.normal,
              curve: SteadyAnimations.easeOut,
              style: TextStyle(
                fontSize: 10,
                fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                color: widget.isActive ? widget.activeColor : widget.inactiveColor,
              ),
              child: Text(widget.label),
            ),
          ],
        ),
      ),
    );
  }
}
