import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/design_system/animations.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/glass_card.dart';
import '../habit_formatters.dart';
import '../habit_tracker_notifier.dart';

class HabitProgressCard extends ConsumerStatefulWidget {
  const HabitProgressCard({
    super.key,
    required this.habit,
    required this.day,
    required this.onTap,
    required this.onQuickAdd,
  });

  final Habit habit;
  final DateTime day;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;

  @override
  ConsumerState<HabitProgressCard> createState() => _HabitProgressCardState();
}

class _HabitProgressCardState extends ConsumerState<HabitProgressCard>
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
    _scale = Tween<double>(begin: 1.0, end: 0.98).animate(
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
    // Watch the provider so the card rebuilds when this habit's progress changes.
    ref.watch(habitTrackerProvider);
    final notifier = ref.read(habitTrackerProvider.notifier);
    final key = dateKeyFrom(widget.day);
    final amount = notifier.progressFor(widget.habit.id, key);
    final met = notifier.isMetOnDay(widget.habit, key);
    final frac = habitProgressFraction(widget.habit, amount);
    final label = habitProgressLabel(widget.habit, amount, met: met);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final okColor = isDark ? DesignTokens.okTextDark : DesignTokens.okTextLight;
    final textSecondary = isDark ? DesignTokens.textSecondaryDark : DesignTokens.textSecondaryLight;

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
            child: child,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          child: Stack(
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: frac.clamp(0.0, 1.0)),
                  duration: SteadyAnimations.slow,
                  curve: SteadyAnimations.easeOut,
                  builder: (context, animatedFrac, _) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: animatedFrac,
                      child: Container(
                        color: (isDark
                                ? DesignTokens.accentActiveDark
                                : DesignTokens.accentActiveLight)
                            .withValues(alpha: met ? 0.5 : 0.25),
                      ),
                    );
                  },
                ),
              ),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Text(widget.habit.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.habit.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          if (met && widget.habit.currentStreak > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${widget.habit.currentStreak} ${widget.habit.currentStreak == 1 ? 'day' : 'days'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: okColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (met)
                      Icon(LucideIcons.checkCircle2, color: okColor, size: 26)
                    else
                      _AnimatedQuickAdd(
                        onPressed: widget.onQuickAdd,
                        color: textSecondary,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedQuickAdd extends StatefulWidget {
  const _AnimatedQuickAdd({required this.onPressed, required this.color});

  final VoidCallback onPressed;
  final Color color;

  @override
  State<_AnimatedQuickAdd> createState() => _AnimatedQuickAddState();
}

class _AnimatedQuickAddState extends State<_AnimatedQuickAdd>
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
    _scale = Tween<double>(begin: 1.0, end: 0.8).animate(
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
        child: IconButton(
          onPressed: widget.onPressed,
          icon: const Icon(LucideIcons.plusCircle),
          color: widget.color,
        ),
      ),
    );
  }
}
