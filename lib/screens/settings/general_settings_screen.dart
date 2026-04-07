import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';

/// General Settings Screen - Application preferences and configuration
class GeneralSettingsScreen extends StatelessWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('General Settings'),
        elevation: 0,
        leading: BackButton(
          onPressed: () {
            context.go('/');
          },
        ),
      ),
      body: Column(
        children: [
          // Breadcrumb navigation
          const AutoBreadcrumbBar(),

          Expanded(
            child: ListView(
              padding: EdgeInsets.all(spacing.l),
              children: [
                Text('General Settings', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),
                const Text('Application preferences and configuration.'),
                const SizedBox(height: 32),

                // Theme Setting
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('Appearance Settings'),
                    subtitle: const Text('Customize the look and feel'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/appearance'),
                  ),
                ),
                const SizedBox(height: 8),

                // Downloads
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('Downloads'),
                    subtitle: const Text('Manage download settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/downloads'),
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
