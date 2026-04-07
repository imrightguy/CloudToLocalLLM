import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../../services/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';

/// Appearance Settings Screen - Theme and visual customization
class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
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
                Text('Appearance Settings',
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),
                const Text('Customize the look and feel of the application.'),
                const SizedBox(height: 32),

                // Theme Mode
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.light_mode),
                        title: const Text('Theme Mode'),
                        subtitle: Text(
                          themeProvider.isDarkMode ? 'Dark' : 'Light',
                        ),
                      ),
                      OverflowBar(
                        children: [
                          TextButton(
                            onPressed: () =>
                                themeProvider.setThemeMode(ThemeMode.light),
                            child: const Text('Light'),
                          ),
                          TextButton(
                            onPressed: () =>
                                themeProvider.setThemeMode(ThemeMode.dark),
                            child: const Text('Dark'),
                          ),
                          TextButton(
                            onPressed: () =>
                                themeProvider.setThemeMode(ThemeMode.system),
                            child: const Text('System'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Accent Color
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.color_lens),
                    title: const Text('Accent Color'),
                    subtitle: const Text('Coming soon'),
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
