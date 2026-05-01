import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayRestartingFailedStep');

class HermesGatewayTestGatewayRestartingFailedStep extends StatefulWidget {
  const HermesGatewayTestGatewayRestartingFailedStep({super.key});

  @override
  State<HermesGatewayTestGatewayRestartingFailedStep> createState() =>
      _HermesGatewayTestGatewayRestartingFailedState();
}

class _HermesGatewayTestGatewayRestartingFailedState
    extends State<HermesGatewayTestGatewayRestartingFailedStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.refresh, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Restart Failed',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway failed to restart. Please check the logs for more information.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway restart failed - checking logs...');
          },
          icon: const Icon(Icons.archive),
          label: const Text('View Gateway Logs'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway restart failed - manual restart...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.power),
          label: const Text('Force Restart'),
        ),
      ],
    );
  }
}
