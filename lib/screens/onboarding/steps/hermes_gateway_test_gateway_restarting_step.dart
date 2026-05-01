import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayRestartingStep');

class HermesGatewayTestGatewayRestartingStep extends StatefulWidget {
  const HermesGatewayTestGatewayRestartingStep({super.key});

  @override
  State<HermesGatewayTestGatewayRestartingStep> createState() =>
      _HermesGatewayTestGatewayRestartingState();
}

class _HermesGatewayTestGatewayRestartingState
    extends State<HermesGatewayTestGatewayRestartingStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.refresh, color: Colors.orange, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Restarting',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway is currently restarting. Please wait a moment and try again.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway restarting - waiting...');
          },
          icon: const Icon(Icons.timer),
          label: const Text('Wait and Retry'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway restarting - checking status...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.info),
          label: const Text('Check Gateway Status'),
        ),
      ],
    );
  }
}
