import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';

/// Connection Settings Screen - Network and tunnel configuration
class ConnectionSettingsScreen extends StatelessWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Settings'),
        elevation: 0,
        leading: BackButton(
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(spacing.l),
        children: [
          Text('Connection',
              style: theme.textTheme.headlineMedium),
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
        ],
      ),
    );
  }
}
