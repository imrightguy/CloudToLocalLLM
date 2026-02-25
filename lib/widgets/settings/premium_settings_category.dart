import 'package:flutter/material.dart';
import '../../models/settings_category.dart';

class PremiumSettingsCategory extends StatelessWidget {
  final String categoryId;
  final bool isActive;

  const PremiumSettingsCategory({
    super.key,
    required this.categoryId,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          SettingsCategoryMetadata.getTitle(categoryId),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          SettingsCategoryMetadata.getDescription(categoryId),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 32),

        // Premium Features Placeholder
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.star_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Unlock Premium Power',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Take your local LLM experience to the next level with enterprise-grade features.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),

              // Feature List
              _buildFeatureRow(context, 'Advanced Model Management',
                  'Access and manage larger, more complex models with ease.'),
              const SizedBox(height: 16),
              _buildFeatureRow(context, 'Priority Processing',
                  'Get dedicated resources for faster inference and response times.'),
              const SizedBox(height: 16),
              _buildFeatureRow(context, 'Cloud Sync & Backup',
                  'Seamlessly sync your conversations and settings across all devices.'),
              const SizedBox(height: 16),
              _buildFeatureRow(context, 'Enterprise Security',
                  'Enhanced security features including SSO and audit logs.'),

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      // In a real app, this would open a web page
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Contact Sales'),
                          content: const Text(
                              'Please email sales@CloudToLocalLLM.com to discuss enterprise options.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Contact Sales'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: () {
                      // In a real app, this would start a checkout flow
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Start Free Trial'),
                          content: const Text(
                              'Your 14-day free trial of Premium features has been activated!'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Awesome!'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Start Free Trial'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(
      BuildContext context, String title, String description) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check,
            size: 16,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
