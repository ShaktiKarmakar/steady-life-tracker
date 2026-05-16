import 'package:flutter/material.dart';

import '../../core/design_system/design_tokens.dart';
import 'score_ring.dart';

class SteadyScoreCard extends StatelessWidget {
  const SteadyScoreCard({
    super.key,
    required this.lifeScore,
    this.habitScore = 0.0,
    this.nutritionScore = 0.0,
    this.pills = const [],
  });

  final double lifeScore; // 0.0 to 1.0
  final double habitScore;
  final double nutritionScore;
  final List<Widget> pills;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? DesignTokens.bgRaisedDark
            : DesignTokens.bgRaisedLight,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl), // 22px
      ),
      child: Row(
        children: [
          ScoreRing(
            habitScore: habitScore,
            nutritionScore: nutritionScore,
            size: 80,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'STEADY SCORE',
                  style: DesignTokens.sectionTitleLabel.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? DesignTokens.textFaintDark
                        : DesignTokens.textFaintLight,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${(lifeScore * 100).round()}',
                      style: DesignTokens.heroNumber.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? DesignTokens.textPrimaryDark
                            : DesignTokens.textPrimaryLight,
                      ),
                    ),
                    Text(
                      '/100',
                      style: DesignTokens.body.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? DesignTokens.textFaintDark
                            : DesignTokens.textFaintLight,
                      ),
                    ),
                  ],
                ),
                if (pills.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: pills,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
