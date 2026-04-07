import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';
import '../../services/setup_status_service.dart';
import '../../services/auth_service.dart';

/// Connection Settings Screen - Network and tunnel configuration
class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  State<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);
    final setupStatusService = context.watch<SetupStatusService>();
    final authService = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Settings'),
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
                Text('Connection', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),
                const Text('Manage tunnel and daemon connections.'),
                const SizedBox(height: 32),

                // Tunnel Settings
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.vpn_key),
                    title: const Text('Tunnel Settings'),
                    subtitle: const Text('Configure SSH tunnel settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/tunnel'),
                  ),
                ),
                const SizedBox(height: 8),

                // Daemon Settings
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.settings_ethernet),
                    title: const Text('Daemon Settings'),
                    subtitle: const Text('Configure system tray daemon'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/daemon'),
                  ),
                ),
                const SizedBox(height: 8),

                // Connection Status
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.link),
                    title: const Text('Connection Status'),
                    subtitle: const Text('View current connection status'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/connection-status'),
                  ),
                ),
                const SizedBox(height: 8),

                // Re-run Setup Wizard
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: const Text('Re-run Setup Wizard'),
                    subtitle: const Text('Configure gateway connection again'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      // Confirm before clearing setup
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Re-run Setup Wizard'),
                          content: const Text(
                            'This will clear your saved setup configuration and restart the setup wizard. You will need to reconfigure your gateway connection.\n\nContinue?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                              child: const Text('Clear & Re-run'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && mounted) {
                        try {
                          // Get user ID before async operations
                          final userId = authService.currentUser?.id ?? 'local';

                          // Clear all setup data
                          await setupStatusService.clearAllSetupData();

                          // Also reset gateway token
                          await setupStatusService.resetSetupStatus(userId);

                          if (mounted) {
                            // Navigate to setup wizard
                            if (!context.mounted) return;
                            context.go('/setup');
                          }
                        } catch (e) {
                          if (mounted) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to clear setup data: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
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
