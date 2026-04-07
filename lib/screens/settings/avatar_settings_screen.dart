import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';

/// Avatar Settings Screen - Avatar personality and evolution configuration
class AvatarSettingsScreen extends StatelessWidget {
  const AvatarSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avatar Settings'),
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
                Text('Avatar', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),
                const Text('Configure avatar personality and evolution.'),
                const SizedBox(height: 32),

                // Avatar Customization
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.face),
                    title: const Text('Avatar Customization'),
                    subtitle: const Text('Customize avatar appearance'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/avatar/customization'),
                  ),
                ),
                const SizedBox(height: 8),

                // Achievements
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.emoji_events),
                    title: const Text('Achievements'),
                    subtitle: const Text('View avatar achievements'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/achievements'),
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
