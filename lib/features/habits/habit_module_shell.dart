import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_tokens.dart';
import 'home/today_home_screen.dart';
import 'statistics/habit_statistics_screen.dart';

class HabitModuleShell extends ConsumerStatefulWidget {
  const HabitModuleShell({super.key});

  @override
  ConsumerState<HabitModuleShell> createState() => _HabitModuleShellState();
}

class _HabitModuleShellState extends ConsumerState<HabitModuleShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DesignTokens.bgSurfaceDark : DesignTokens.bgSurfaceLight;
    final border = isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    final textActive = isDark ? DesignTokens.textSecondaryDark : DesignTokens.textSecondaryLight;
    final activeBg = isDark
        ? DesignTokens.accentActiveDark.withValues(alpha: 0.5)
        : DesignTokens.accentActiveLight.withValues(alpha: 0.8);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              border: Border.all(
                color: border,
                width: DesignTokens.borderWidthDefault,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: activeBg,
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              ),
              labelColor: textActive,
              unselectedLabelColor: textMuted,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Today'),
                Tab(text: 'Stats'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                TodayHomeScreen(
                  onOpenProfile: () {},
                ),
                const HabitStatisticsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
