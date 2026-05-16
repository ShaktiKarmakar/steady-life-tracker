import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/design_system/design_tokens.dart';
import '../../../shared/models/models.dart';
import '../habit_tracker_notifier.dart';

class HabitProfileScreen extends ConsumerStatefulWidget {
  const HabitProfileScreen({super.key});

  @override
  ConsumerState<HabitProfileScreen> createState() => _HabitProfileScreenState();
}

class _HabitProfileScreenState extends ConsumerState<HabitProfileScreen> {
  final _nameController = TextEditingController();

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

    final habits = ref.watch(habitTrackerProvider).habits;
    final totalStreak = habits.fold<int>(0, (sum, h) => sum + h.currentStreak);
    final longestStreak = habits.isEmpty
        ? 0
        : habits.map((h) => h.longestStreak).reduce((a, b) => a > b ? a : b);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark
        ? DesignTokens.accentActiveDark.withValues(alpha: 0.4)
        : DesignTokens.accentActiveLight.withValues(alpha: 0.7);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: activeBg,
                          child: const Icon(
                            LucideIcons.user,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                            onSubmitted: (v) => ref
                                .read(habitTrackerProvider.notifier)
                                .setProfile(profile.copyWith(displayName: v.trim())),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: _StatBox(
                            label: 'Active habits',
                            value: '${habits.length}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatBox(
                            label: 'Total streaks',
                            value: '$totalStreak',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatBox(
                            label: 'Best streak',
                            value: '$longestStreak',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Mood this week',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _MoodRow(profile: profile),
                    const SizedBox(height: 32),
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _SettingsTile(
                      icon: LucideIcons.settings,
                      label: 'App settings',
                      onTap: () => context.go('/you/settings'),
                    ),
                    const SizedBox(height: 8),
                    _SettingsTile(
                      icon: LucideIcons.info,
                      label: 'About Steady',
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'Steady',
                          applicationVersion: '1.0.0',
                          applicationLegalese: 'Your data stays on your device.',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight;
    final bg = isDark ? DesignTokens.bgSurfaceDark : DesignTokens.bgSurfaceLight;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(
          color: border,
          width: DesignTokens.borderWidthDefault,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodRow extends ConsumerWidget {
  const _MoodRow({required this.profile});
  final HabitUserProfile profile;

  static DateTime _mondayOf(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = _mondayOf(DateTime.now());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight;
    final bg = isDark ? DesignTokens.bgSurfaceDark : DesignTokens.bgSurfaceLight;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    final textSecondary = isDark ? DesignTokens.textSecondaryDark : DesignTokens.textSecondaryLight;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = weekStart.add(Duration(days: i));
        final key = dateKeyFrom(day);
        final mood = profile.weeklyMoods[key];
        final isToday = key == dateKeyFrom(DateTime.now());
        return GestureDetector(
          onTap: () => _pickMood(context, ref, key),
          child: Column(
            children: [
              Text(
                ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                style: TextStyle(
                  fontSize: 11,
                  color: isToday ? textSecondary : textMuted,
                  fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                  border: Border.all(
                    color: isToday
                        ? (isDark ? DesignTokens.textSecondaryDark : DesignTokens.textSecondaryLight)
                        : border,
                    width: isToday ? 1.5 : DesignTokens.borderWidthDefault,
                  ),
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
    );
  }

  Future<void> _pickMood(BuildContext context, WidgetRef ref, String key) async {
    const moods = ['😀', '🙂', '😐', '😟', '😢'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DesignTokens.bgSurfaceDark : DesignTokens.bgSurfaceLight;
    final sheetBg = isDark ? DesignTokens.bgBaseDark : DesignTokens.bgBaseLight;

    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            children: [
              for (final m in moods)
                GestureDetector(
                  onTap: () => Navigator.pop(c, m),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: sheetBg,
                      borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                    ),
                    child: Text(m, style: const TextStyle(fontSize: 32)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (pick != null) {
      await ref.read(habitTrackerProvider.notifier).setMoodForDay(key, pick);
    }
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight;
    final bg = isDark ? DesignTokens.bgSurfaceDark : DesignTokens.bgSurfaceLight;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;

    return ListTile(
      leading: Icon(icon, color: textMuted, size: 20),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: Icon(LucideIcons.chevronRight, size: 18, color: textMuted),
      tileColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        side: BorderSide(color: border, width: 0.5),
      ),
      onTap: onTap,
    );
  }
}
