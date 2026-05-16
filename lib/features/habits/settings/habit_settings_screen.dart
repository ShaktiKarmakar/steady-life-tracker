import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/ai/gemma_service.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../shared/models/food_models.dart';
import '../../../shared/providers/health_sync_provider.dart';
import '../../../shared/providers/nutrition_goals_provider.dart';
import '../../../shared/providers/theme_provider.dart';

class HabitSettingsScreen extends ConsumerStatefulWidget {
  const HabitSettingsScreen({super.key});

  @override
  ConsumerState<HabitSettingsScreen> createState() => _HabitSettingsScreenState();
}

class _HabitSettingsScreenState extends ConsumerState<HabitSettingsScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _info = i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final version = _info == null ? '…' : '${_info!.version} (${_info!.buildNumber})';
    final themeMode = ref.watch(themeModeProvider);
    final themeLabel = switch (themeMode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };
    final healthEnabled = ref.watch(healthSyncEnabledProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;

    return Stack(
      children: [
        Container(color: Theme.of(context).scaffoldBackgroundColor),
        SafeArea(
          child: ListView(
            children: [
              const _SectionTitle('Appearance'),
              ListTile(
                leading: const Icon(LucideIcons.moon),
                title: const Text('Theme'),
                subtitle: Text(themeLabel),
                trailing: Icon(LucideIcons.chevronRight, size: 18, color: textMuted),
                onTap: () => ref.read(themeModeProvider.notifier).toggle(),
              ),
              const _SectionTitle('AI Model'),
              _AiModelTile(),
              const _SectionTitle('Habit mini-app'),
              _tile(context, 'Habit manager', 'Reorder & edit from the Habit List tab'),
              _tile(context, 'Widget theme', 'Home screen widgets coming later'),
              const _SectionTitle('Health'),
              ListTile(
                leading: const Icon(LucideIcons.heart),
                title: const Text('Auto-import workouts'),
                subtitle: Text(healthEnabled ? 'Enabled' : 'Disabled'),
                trailing: Switch(
                  value: healthEnabled,
                  onChanged: (v) => ref.read(healthSyncEnabledProvider.notifier).toggle(),
                ),
              ),
              ListTile(
                leading: const Icon(LucideIcons.refreshCw),
                title: const Text('Sync now'),
                onTap: () async {
                  final imported = await ref.read(healthSyncProvider.future);
                  if (!context.mounted) return;
                  _snack(context, imported == 0
                      ? 'No new workouts found.'
                      : 'Imported $imported workouts.');
                },
              ),
              const _SectionTitle('Nutrition Goals'),
              _NutritionGoalsTile(),
              const _SectionTitle('AI Analysis'),
              ListTile(
                leading: const Icon(LucideIcons.brain),
                title: const Text('Detailed analysis mode'),
                subtitle: const Text('Slower but more accurate food estimates'),
                trailing: Switch(
                  value: false, // TODO: wire to a provider
                  onChanged: (v) {},
                ),
              ),
              const _SectionTitle('About'),
              ListTile(
                leading: const Icon(LucideIcons.lightbulb),
                title: const Text('Usage tips'),
                subtitle: const Text('Use filters on Today to focus on what matters now.'),
                onTap: () => _snack(context, 'Tips: quick + logs one increment without opening detail.'),
              ),
              ListTile(
                leading: const Icon(LucideIcons.helpCircle),
                title: const Text('FAQs'),
                onTap: () => _snack(context, 'Track streaks by hitting your daily goal.'),
              ),
              ListTile(
                leading: const Icon(LucideIcons.mail),
                title: const Text('Contact us'),
                onTap: () => _snack(context, 'hello@steady.app (placeholder)'),
              ),
              ListTile(
                leading: const Icon(LucideIcons.share2),
                title: const Text('Share'),
                onTap: () async {
                  await Clipboard.setData(const ClipboardData(text: 'https://steady.app'));
                  if (!context.mounted) return;
                  _snack(context, 'Link copied');
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.star),
                title: const Text('Review & support'),
                subtitle: Text('Version $version'),
                onTap: () => _snack(context, 'Thanks for trying Steady!'),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Our Apps · Steady suite',
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _tile(BuildContext context, String title, String sub) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    return ListTile(
      title: Text(title),
      subtitle: Text(sub, style: TextStyle(fontSize: 12, color: textMuted)),
      trailing: Icon(LucideIcons.chevronRight, size: 18, color: textMuted),
      onTap: () => _snack(context, '$title · coming soon'),
    );
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _AiModelTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AiModelTile> createState() => _AiModelTileState();
}

class _AiModelTileState extends ConsumerState<_AiModelTile> {
  bool _downloading = false;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(aiModelUiStatusProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final okColor = isDark ? DesignTokens.okTextDark : DesignTokens.okTextLight;
    final warnColor = isDark ? DesignTokens.warnTextDark : DesignTokens.warnTextLight;

    return statusAsync.when(
      data: (status) {
        final isReady = status.inferenceReady;
        final gemma = ref.read(gemmaServiceProvider);
        final error = gemma.lastError;

        return Column(
          children: [
            ListTile(
              leading: Icon(
                isReady ? LucideIcons.checkCircle2 : LucideIcons.download,
                color: isReady ? okColor : warnColor,
              ),
              title: Text(isReady ? 'AI model loaded' : 'AI model not loaded'),
              subtitle: Text(error ?? status.subtitle),
              trailing: isReady
                  ? Icon(LucideIcons.check, color: okColor, size: 20)
                  : _downloading
                      ? SizedBox(
                          width: 40,
                          child: Text('${_progress.toInt()}%',
                              style: const TextStyle(fontSize: 12)),
                        )
                      : Icon(LucideIcons.download, color: warnColor, size: 20),
              onTap: isReady || _downloading ? null : () => _startDownload(),
            ),
            if (!isReady && !_downloading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _retry(context),
                        icon: const Icon(LucideIcons.refreshCw, size: 16),
                        label: const Text('Retry load'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _purgeAndReinstall(context),
                        icon: const Icon(LucideIcons.trash2, size: 16),
                        label: const Text('Purge & reinstall'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
      loading: () => const ListTile(
        leading: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text('Checking AI model...'),
      ),
      error: (e, _) => ListTile(
        leading: Icon(LucideIcons.alertCircle, color: warnColor),
        title: Text('AI model error: $e'),
        trailing: const Icon(LucideIcons.refreshCw),
        onTap: () => ref.refresh(aiModelUiStatusProvider),
      ),
    );
  }

  Future<void> _retry(BuildContext context) async {
    final gemma = ref.read(gemmaServiceProvider);
    gemma.resetFallback();
    ref.read(aiModelUiTickProvider.notifier).bump();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Retrying model initialization...')),
    );
  }

  Future<void> _purgeAndReinstall(BuildContext context) async {
    final gemma = ref.read(gemmaServiceProvider);
    final scaffold = ScaffoldMessenger.of(context);

    scaffold.showSnackBar(
      const SnackBar(content: Text('Purging old model files...')),
    );

    try {
      await gemma.removeLocalModelForReinstall();
      if (!mounted) return;
      scaffold.showSnackBar(
        const SnackBar(content: Text('Old model purged. Starting fresh download...')),
      );
      await _startDownload();
    } catch (e) {
      if (!mounted) return;
      scaffold.showSnackBar(
        SnackBar(content: Text('Purge failed: $e')),
      );
    }
  }

  Future<void> _startDownload() async {
    final gemma = ref.read(gemmaServiceProvider);

    if (!mounted) return;
    setState(() {
      _downloading = true;
      _progress = 0;
    });

    try {
      await gemma.downloadModel(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p * 100);
        },
      );
      gemma.resetFallback();
      ref.read(aiModelUiTickProvider.notifier).bump();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI model downloaded and ready!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }
}

class _NutritionGoalsTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_NutritionGoalsTile> createState() => _NutritionGoalsTileState();
}

class _NutritionGoalsTileState extends ConsumerState<_NutritionGoalsTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(nutritionGoalsNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;

    return goalsAsync.when(
      data: (goals) {
        return Column(
          children: [
            ListTile(
              leading: const Icon(LucideIcons.target),
              title: const Text('Daily calorie goal'),
              subtitle: Text('${goals.calories} kcal · P ${goals.protein}g · C ${goals.carbs}g · F ${goals.fat}g'),
              trailing: Icon(
                _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                size: 18,
                color: textMuted,
              ),
              onTap: () => setState(() => _expanded = !_expanded),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _NutritionGoalsEditor(
                  goals: goals,
                  onSave: (g) => ref.read(nutritionGoalsNotifierProvider.notifier).updateGoals(g),
                ),
              ),
          ],
        );
      },
      loading: () => const ListTile(
        leading: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text('Loading goals...'),
      ),
      error: (e, _) => ListTile(
        leading: const Icon(LucideIcons.alertCircle),
        title: Text('Error: $e'),
      ),
    );
  }
}

class _NutritionGoalsEditor extends StatefulWidget {
  const _NutritionGoalsEditor({required this.goals, required this.onSave});
  final NutritionGoals goals;
  final ValueChanged<NutritionGoals> onSave;

  @override
  State<_NutritionGoalsEditor> createState() => _NutritionGoalsEditorState();
}

class _NutritionGoalsEditorState extends State<_NutritionGoalsEditor> {
  late final TextEditingController _calCtrl;
  late final TextEditingController _protCtrl;
  late final TextEditingController _carbCtrl;
  late final TextEditingController _fatCtrl;

  @override
  void initState() {
    super.initState();
    _calCtrl = TextEditingController(text: widget.goals.calories.toString());
    _protCtrl = TextEditingController(text: widget.goals.protein.toString());
    _carbCtrl = TextEditingController(text: widget.goals.carbs.toString());
    _fatCtrl = TextEditingController(text: widget.goals.fat.toString());
  }

  @override
  void dispose() {
    _calCtrl.dispose();
    _protCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: Column(
        children: [
          _GoalField(label: 'Calories', ctrl: _calCtrl, unit: 'kcal'),
          const SizedBox(height: 12),
          _GoalField(label: 'Protein', ctrl: _protCtrl, unit: 'g'),
          const SizedBox(height: 12),
          _GoalField(label: 'Carbs', ctrl: _carbCtrl, unit: 'g'),
          const SizedBox(height: 12),
          _GoalField(label: 'Fat', ctrl: _fatCtrl, unit: 'g'),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton(
                onPressed: () {
                  widget.onSave(NutritionGoals.defaults());
                },
                child: const Text('Reset'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  widget.onSave(NutritionGoals(
                    calories: int.tryParse(_calCtrl.text) ?? 2000,
                    protein: int.tryParse(_protCtrl.text) ?? 120,
                    carbs: int.tryParse(_carbCtrl.text) ?? 200,
                    fat: int.tryParse(_fatCtrl.text) ?? 65,
                  ));
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalField extends StatelessWidget {
  const _GoalField({required this.label, required this.ctrl, required this.unit});
  final String label;
  final TextEditingController ctrl;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label)),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              suffixText: unit,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          color: textMuted,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
