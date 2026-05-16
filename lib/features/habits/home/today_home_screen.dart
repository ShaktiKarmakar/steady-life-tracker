import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/design_system/animations.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/animated_list_item.dart';
import '../habit_tracker_notifier.dart';
import '../navigation/habit_navigation.dart';
import '../widgets/habit_progress_card.dart';

class TodayHomeScreen extends ConsumerWidget {
  const TodayHomeScreen({
    super.key,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenProfile;

  static DateTime _mondayOf(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  void _showFilters(BuildContext context, WidgetRef ref) {
    final tracker = ref.read(habitTrackerProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? DesignTokens.bgSurfaceDark
          : DesignTokens.bgSurfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<HabitFilterStatus>(
              segments: const [
                ButtonSegment(value: HabitFilterStatus.all, label: Text('All')),
                ButtonSegment(value: HabitFilterStatus.unmet, label: Text('Unmet')),
                ButtonSegment(value: HabitFilterStatus.met, label: Text('Met')),
              ],
              selected: {tracker.filterStatus},
              onSelectionChanged: (s) {
                ref.read(habitTrackerProvider.notifier).setFilterStatus(s.first);
              },
            ),
            const SizedBox(height: 20),
            const Text('Time of day', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: HabitFilterTime.values.map((t) {
                final label = switch (t) {
                  HabitFilterTime.all => 'All',
                  HabitFilterTime.now => 'Now',
                  HabitFilterTime.anytime => 'Anytime',
                  HabitFilterTime.morning => 'Morning',
                  HabitFilterTime.afternoon => 'Afternoon',
                  HabitFilterTime.evening => 'Evening',
                };
                final sel = tracker.filterTime == t;
                return FilterChip(
                  label: Text(label),
                  selected: sel,
                  onSelected: (_) {
                    ref.read(habitTrackerProvider.notifier).setFilterTime(t);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(habitSelectedDateProvider);
    final notifier = ref.watch(habitTrackerProvider.notifier);
    final habits = notifier.filteredHabitsForDay(selectedDay);
    final weekStart = _mondayOf(selectedDay);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    final border = isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight;
    final activeBg = isDark
        ? DesignTokens.accentActiveDark.withValues(alpha: 0.4)
        : DesignTokens.accentActiveLight.withValues(alpha: 0.7);

    return Stack(
      children: [
        Container(color: Theme.of(context).scaffoldBackgroundColor),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    _AnimatedIconButton(
                      icon: LucideIcons.slidersHorizontal,
                      onPressed: () => _showFilters(context, ref),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, MMM d').format(selectedDay),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    _AnimatedIconButton(
                      icon: LucideIcons.user,
                      isCircle: true,
                      onPressed: onOpenProfile,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 76,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: 7,
                  itemBuilder: (context, i) {
                    final day = weekStart.add(Duration(days: i));
                    final isSel = dateKeyFrom(day) == dateKeyFrom(selectedDay);
                    final isToday = dateKeyFrom(day) == dateKeyFrom(DateTime.now());
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _DayPill(
                        day: day,
                        isSelected: isSel,
                        isToday: isToday,
                        activeBg: activeBg,
                        border: border,
                        textMuted: textMuted,
                        onTap: () =>
                            ref.read(habitSelectedDateProvider.notifier).setDay(day),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: habits.isEmpty
                    ? Center(
                        child: AnimatedOpacity(
                          opacity: 1,
                          duration: SteadyAnimations.slow,
                          child: Text(
                            'No habits match filters.\nTry adjusting filters or add a habit.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textMuted),
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(
                          decelerationRate: ScrollDecelerationRate.fast,
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: habits.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final habit = habits[i];
                          return AnimatedListItem(
                            index: i,
                            slideOffset: const Offset(0, 16),
                            child: HabitProgressCard(
                              habit: habit,
                              day: selectedDay,
                              onTap: () => openHabitDetail(context, habit.id),
                              onQuickAdd: () => ref
                                  .read(habitTrackerProvider.notifier)
                                  .quickLogPlus(habit, selectedDay),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 20,
          bottom: 24,
          child: _AnimatedFAB(
            heroTag: 'habit_fab',
            backgroundColor: isDark ? DesignTokens.textPrimaryDark : DesignTokens.textPrimaryLight,
            foregroundColor: isDark ? DesignTokens.bgBaseDark : DesignTokens.bgBaseLight,
            onPressed: () => openNewHabitPicker(context),
            child: const Icon(LucideIcons.plus),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 24,
          child: _AnimatedFAB(
            heroTag: 'habit_avatar',
            backgroundColor: isDark ? DesignTokens.bgSurfaceDark : DesignTokens.bgSurfaceLight,
            onPressed: onOpenProfile,
            child: const Icon(LucideIcons.user),
          ),
        ),
      ],
    );
  }
}

class _DayPill extends StatefulWidget {
  const _DayPill({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.activeBg,
    required this.border,
    required this.textMuted,
    required this.onTap,
  });

  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final Color activeBg;
  final Color border;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  State<_DayPill> createState() => _DayPillState();
}

class _DayPillState extends State<_DayPill> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: SteadyAnimations.fast,
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              width: 52,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? widget.activeBg
                    : (isDark ? DesignTokens.bgSurfaceDark : DesignTokens.bgSurfaceLight),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                border: Border.all(
                  color: widget.isToday
                      ? (isDark ? DesignTokens.textSecondaryDark : DesignTokens.textSecondaryLight)
                      : widget.border,
                ),
              ),
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('EEE').format(widget.day),
              style: TextStyle(fontSize: 11, color: widget.textMuted),
            ),
            Text(
              '${widget.day.day}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: widget.isSelected
                    ? Theme.of(context).textTheme.titleMedium?.color
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedIconButton extends StatefulWidget {
  const _AnimatedIconButton({
    required this.icon,
    required this.onPressed,
    this.isCircle = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isCircle;

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: SteadyAnimations.fast,
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: child,
          );
        },
        child: widget.isCircle
            ? CircleAvatar(
                radius: 18,
                backgroundColor: isDark
                    ? DesignTokens.accentActiveDark
                    : DesignTokens.accentActiveLight,
                child: Icon(widget.icon, size: 18),
              )
            : IconButton(
                icon: Icon(widget.icon),
                onPressed: widget.onPressed,
              ),
      ),
    );
  }
}

class _AnimatedFAB extends StatefulWidget {
  const _AnimatedFAB({
    required this.heroTag,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String heroTag;
  final VoidCallback onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  State<_AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<_AnimatedFAB>
    with SingleTickerProviderStateMixin {
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
      onTap: widget.onPressed,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: child,
          );
        },
        child: FloatingActionButton(
          heroTag: widget.heroTag,
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.foregroundColor,
          onPressed: widget.onPressed,
          child: widget.child,
        ),
      ),
    );
  }
}
