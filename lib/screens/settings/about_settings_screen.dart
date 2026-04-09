import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';

/// About Settings Screen - App information and upgrade options
class AboutSettingsScreen extends StatelessWidget {
  const AboutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        elevation: 0,
        leading: BackButton(
          onPressed: () {
            context.go('/');
          },
        ),
      ),
      body: Column(
        children: [
          const AutoBreadcrumbBar(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(spacing.l),
              children: [
                Text('About', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),
                const Text('CloudToLocalLLM - AI Agent Manager'),
                const SizedBox(height: 8),
                const Text('Version: 1.0.0'),
                const SizedBox(height: 32),

                // Upgrade to Pro
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud),
                    title: const Text('Upgrade to Pro'),
                    subtitle: const Text('Unlock additional features'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/upgrade'),
                  ),
                ),
                const SizedBox(height: 8),

                // Documentation
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.description),
                    title: const Text('Documentation'),
                    subtitle: const Text('View user documentation'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/docs'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
