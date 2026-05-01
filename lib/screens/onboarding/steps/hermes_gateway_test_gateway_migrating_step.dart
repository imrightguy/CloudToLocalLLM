import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayMigratingStep');

class HermesGatewayTestGatewayMigratingStep extends StatefulWidget {
  const HermesGatewayTestGatewayMigratingStep({super.key});

  @override
  State<HermesGatewayTestGatewayMigratingStep> createState() =>
      _HermesGatewayTestGatewayMigratingState();
}

class _HermesGatewayTestGatewayMigratingState
    extends State<HermesGatewayTestGatewayMigratingStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.sync, color: Colors.orange, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Migrating',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway is currently migrating data. Please wait for the migration to complete and try again.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway migrating - waiting...');
          },
          icon: const Icon(Icons.timer),
          label: const Text('Wait and Retry'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway migrating - checking progress...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.sync),
          label: const Text('Check Migration Progress'),
        ),
      ],
    );
  }
}
