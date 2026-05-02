import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_blobs_background.dart';

class HabitSettingsScreen extends StatefulWidget {
  const HabitSettingsScreen({super.key});

  @override
  State<HabitSettingsScreen> createState() => _HabitSettingsScreenState();
}

class _HabitSettingsScreenState extends State<HabitSettingsScreen> {
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

    return Stack(
      children: [
        const Positioned.fill(child: AnimatedBlobsBackground()),
        SafeArea(
          child: ListView(
            children: [
              const _SectionTitle('Habit mini-app'),
              _tile(context, 'Habit manager', 'Reorder & edit from the Habit List tab'),
              _tile(context, 'Widget theme', 'Home screen widgets coming later'),
              _tile(context, 'Theme', 'Uses app-wide dark theme'),
              const _SectionTitle('About'),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: const Text('Usage tips'),
                subtitle: const Text('Use filters on Today to focus on what matters now.'),
                onTap: () => _snack(context, 'Tips: quick + logs one increment without opening detail.'),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('FAQs'),
                onTap: () => _snack(context, 'Track streaks by hitting your daily goal.'),
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Contact us'),
                onTap: () => _snack(context, 'hello@steady.app (placeholder)'),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share'),
                onTap: () async {
                  await Clipboard.setData(const ClipboardData(text: 'https://steady.app'));
                  if (!context.mounted) return;
                  _snack(context, 'Link copied');
                },
              ),
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Review & support'),
                subtitle: Text('Version $version'),
                onTap: () => _snack(context, 'Thanks for trying Steady!'),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Our Apps · Steady suite',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _tile(BuildContext context, String title, String sub) {
    return ListTile(
      title: Text(title),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Colors.white54)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: () => _snack(context, '$title · coming soon'),
    );
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.accentPurple,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
