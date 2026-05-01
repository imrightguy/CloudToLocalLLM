import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestConfigurationErrorStep');

class HermesGatewayTestConfigurationErrorStep extends StatefulWidget {
  const HermesGatewayTestConfigurationErrorStep({super.key});

  @override
  State<HermesGatewayTestConfigurationErrorStep> createState() =>
      _HermesGatewayTestConfigurationErrorState();
}

class _HermesGatewayTestConfigurationErrorState
    extends State<HermesGatewayTestConfigurationErrorStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.settings, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Configuration Error',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway configuration is invalid or incomplete. Please check your settings.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Configuration error - checking settings...');
          },
          icon: const Icon(Icons.settings),
          label: const Text('Check Configuration'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Configuration error - resetting to defaults...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.settings_backup_restore),
          label: const Text('Reset to Defaults'),
        ),
      ],
    );
  }
}
