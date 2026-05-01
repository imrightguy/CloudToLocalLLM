import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewaySynchronizationFailedStep');

class HermesGatewayTestGatewaySynchronizationFailedStep extends StatefulWidget {
  const HermesGatewayTestGatewaySynchronizationFailedStep({super.key});

  @override
  State<HermesGatewayTestGatewaySynchronizationFailedStep> createState() =>
      _HermesGatewayTestGatewaySynchronizationFailedState();
}

class _HermesGatewayTestGatewaySynchronizationFailedState
    extends State<HermesGatewayTestGatewaySynchronizationFailedStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.sync_alt, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Synchronization Failed',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway synchronization failed. Please check your network connection and try again.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway sync failed - checking connection...');
          },
          icon: const Icon(Icons.wifi),
          label: const Text('Check Network Connection'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway sync failed - manual sync...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.sync_alt),
          label: const Text('Manual Synchronization'),
        ),
      ],
    );
  }
}
