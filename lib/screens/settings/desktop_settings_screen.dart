import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';

/// Desktop Settings Screen - Desktop-specific settings and file operations
class DesktopSettingsScreen extends StatelessWidget {
  const DesktopSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Desktop Settings'),
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
                Text('Desktop', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),
                const Text('Desktop-specific settings and file operations.'),
                const SizedBox(height: 32),

                // File Operations
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.folder),
                    title: const Text('File Operations'),
                    subtitle:
                        const Text('Manage file operations and permissions'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/desktop/files'),
                  ),
                ),
                const SizedBox(height: 8),

                // GUI Automation
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.mouse),
                    title: const Text('GUI Automation'),
                    subtitle: const Text('Configure desktop automation'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/gui-automation'),
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
