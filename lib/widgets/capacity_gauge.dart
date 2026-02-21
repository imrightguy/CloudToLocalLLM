import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rate_limit_manager.dart';
import '../database/drift_local_brain.dart';

/// A widget that displays the current capacity and usage of LLM models
class CapacityGaugeWidget extends StatelessWidget {
  const CapacityGaugeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final rateLimitManager = context.watch<RateLimitManager>();
    final theme = Theme.of(context);

    return StreamBuilder<List<ModelCapacityData>>(
      stream: rateLimitManager.watchCapacities(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final capacities = snapshot.data!;

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Model Capacity (Live)',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Icon(Icons.speed, size: 20, color: Colors.blueGrey),
                  ],
                ),
                const SizedBox(height: 16),
                ...capacities.map((model) => _buildModelBar(context, model)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModelBar(BuildContext context, ModelCapacityData model) {
    final theme = Theme.of(context);
    final usageRatio = model.concurrentUsed / model.concurrentLimit;

    Color progressColor = Colors.green;
    if (usageRatio > 0.8) {
      progressColor = Colors.red;
    } else if (usageRatio > 0.5) {
      progressColor = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                model.displayName ?? model.modelId,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '${model.concurrentUsed}/${model.concurrentLimit}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: progressColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usageRatio.clamp(0.0, 1.0),
              backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
