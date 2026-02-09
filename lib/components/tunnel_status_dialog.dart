import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../services/tunnel_service.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../config/theme.dart';

class TunnelStatusDialog extends StatelessWidget {
  const TunnelStatusDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isAuthenticated = authService.isAuthenticated.value;

    return Consumer<TunnelService>(
      builder: (context, tunnelService, child) {
        final state = tunnelService.state;
        return AlertDialog(
          title: const Text('Tunnel Connection Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isAuthenticated) ...[
                const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Cloud Relay & Tunnels require a cloud connection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please connect to Cloud Relay to enable secure tunneling.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Row(
                  children: [
                    Icon(
                      state.isConnected ? Icons.gpp_good : Icons.gpp_bad,
                      color: state.isConnected
                          ? Colors.green
                          : AppTheme.dangerColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      state.isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        color: state.isConnected
                            ? Colors.green
                            : AppTheme.dangerColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 8),
                  Text('Error: ${state.error}',
                      style: TextStyle(color: AppTheme.dangerColor)),
                ],
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if (!isAuthenticated)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/login');
                },
                child: const Text('Connect to Cloud'),
              )
            else ...[
              if (!state.isConnected)
                ElevatedButton(
                  onPressed: () => tunnelService.connect(),
                  child: const Text('Connect'),
                ),
              if (state.isConnected)
                ElevatedButton(
                  onPressed: () => tunnelService.disconnect(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.dangerColor),
                  child: const Text('Disconnect'),
                ),
            ],
            TextButton(
              onPressed: _downloadDesktopClient,
              child: const Text('Download Client'),
            ),
          ],
        );
      },
    );
  }

  void _downloadDesktopClient() async {
    final url = Uri.parse('${AppConfig.homepageUrl}/download');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
