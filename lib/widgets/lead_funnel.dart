import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class LeadFunnelCard extends StatelessWidget {
  const LeadFunnelCard({super.key, required this.funnelData});

  final Map<String, int> funnelData;

  static const _stageOrder = [
    LeadStage.nouveau,
    LeadStage.contacte,
    LeadStage.qualifie,
    LeadStage.visitePlanifiee,
    LeadStage.offreEnvoyee,
    LeadStage.negociation,
    LeadStage.bailSigne,
  ];

  static const _stageColors = [
    AppColors.funnelNouveau,
    AppColors.funnelContacte,
    AppColors.funnelVisitePlanifiee,
    AppColors.funnelVisiteCompletee,
    AppColors.funnelApplication,
    AppColors.funnelApprouve,
    AppColors.funnelBailSigne,
  ];

  Color _stageColor(LeadStage stage) {
    final idx = _stageOrder.indexOf(stage);
    if (idx >= 0 && idx < _stageColors.length) return _stageColors[idx];
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final orderedStages = _stageOrder.where((s) {
      final count = funnelData[s.name] ?? 0;
      return count > 0;
    }).toList();

    if (orderedStages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: AppSpacing.cardDecoration(),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Entonnoir de conversion', style: AppTypography.sectionHeader),
            SizedBox(height: AppSpacing.md),
            Center(
              child: Text('Aucune donnée de pipeline', style: AppTypography.caption),
            ),
          ],
        ),
      );
    }

    final maxCount = orderedStages.fold<int>(
      0,
      (max, stage) {
        final c = funnelData[stage.name] ?? 0;
        return c > max ? c : max;
      },
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppSpacing.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Entonnoir de conversion', style: AppTypography.sectionHeader),
          const SizedBox(height: AppSpacing.md),
          ...orderedStages.asMap().entries.map((entry) {
            final index = entry.key;
            final stage = entry.value;
            final count = funnelData[stage.name] ?? 0;
            final color = _stageColor(stage);
            final widthFactor = maxCount > 0 ? count / maxCount : 0.0;

            int? nextCount;
            if (index + 1 < orderedStages.length) {
              nextCount = funnelData[orderedStages[index + 1].name] ?? 0;
            }
            final conversionRate = (nextCount != null && count > 0)
                ? (nextCount / count * 100).toStringAsFixed(0)
                : null;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Semantics(
                label: '${stage.label}: $count',
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: widthFactor,
                              alignment: Alignment.centerLeft,
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 400 + index * 50),
                                curve: Curves.easeOutCubic,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            Center(
                              child: Text(
                                '${stage.label} — $count',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: widthFactor > 0.4 ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (conversionRate != null) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '$conversionRate% ↓',
                          textAlign: TextAlign.end,
                          style: AppTypography.caption,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
