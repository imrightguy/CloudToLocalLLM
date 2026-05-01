import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewaySynchronizingStep');

class HermesGatewayTestGatewaySynchronizingStep extends StatefulWidget {
  const HermesGatewayTestGatewaySynchronizingStep({super.key});

  @override
  State<HermesGatewayTestGatewaySynchronizingStep> createState() =>
      _HermesGatewayTestGatewaySynchronizingState();
}

class _HermesGatewayTestGatewaySynchronizingState
    extends State<HermesGatewayTestGatewaySynchronizingStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.sync_alt, color: Colors.orange, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Synchronizing',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway is currently synchronizing data. Please wait for synchronization to complete and try again.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway synchronizing - waiting...');
          },
          icon: const Icon(Icons.timer),
          label: const Text('Wait and Retry'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway synchronizing - checking progress...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.sync_alt),
          label: const Text('Check Synchronization Progress'),
        ),
      ],
    );
  }
}
