import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/design_system/design_tokens.dart';

class AiBriefingStrip extends StatelessWidget {
  const AiBriefingStrip({
    super.key,
    required this.text,
    this.loading = false,
    this.onRefresh,
  });

  final String text;
  final bool loading;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DesignTokens.bgSurfaceDark : DesignTokens.bgSurfaceLight;
    final border = isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    final textSecondary = isDark ? DesignTokens.textSecondaryDark : DesignTokens.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          left: BorderSide(
            color: border,
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'AI BRIEFING',
                style: DesignTokens.sectionTitleLabel.copyWith(
                  color: textSecondary,
                ),
              ),
              if (loading) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: textSecondary,
                  ),
                ),
              ],
              if (onRefresh != null) ...[
                const Spacer(),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  color: textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text.isEmpty ? 'Generating your daily briefing...' : text,
            style: DesignTokens.body.copyWith(
              color: textMuted,
              height: 1.55,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
