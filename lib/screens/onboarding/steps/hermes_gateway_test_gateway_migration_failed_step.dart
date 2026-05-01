import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayMigrationFailedStep');

class HermesGatewayTestGatewayMigrationFailedStep extends StatefulWidget {
  const HermesGatewayTestGatewayMigrationFailedStep({super.key});

  @override
  State<HermesGatewayTestGatewayMigrationFailedStep> createState() =>
      _HermesGatewayTestGatewayMigrationFailedState();
}

class _HermesGatewayTestGatewayMigrationFailedState
    extends State<HermesGatewayTestGatewayMigrationFailedStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.sync, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Migration Failed',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway migration failed. Please check the logs for more information.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway migration failed - checking logs...');
          },
          icon: const Icon(Icons.archive),
          label: const Text('View Migration Logs'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway migration failed - retrying...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.sync),
          label: const Text('Retry Migration'),
        ),
      ],
    );
  }
}
