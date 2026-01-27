import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/tunnel_service.dart';
import '../config/app_config.dart';
import '../config/theme.dart';

class TunnelStatusDialog extends StatelessWidget {
  const TunnelStatusDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TunnelService>(
      builder: (context, tunnelService, child) {
        final state = tunnelService.state;
        return AlertDialog(
          title: const Text('Tunnel Connection Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    state.isConnected ? Icons.gpp_good : Icons.gpp_bad,
                    color:
                        state.isConnected ? Colors.green : AppTheme.dangerColor,
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
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
