import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayStoppingFailedStep');

class HermesGatewayTestGatewayStoppingFailedStep extends StatefulWidget {
  const HermesGatewayTestGatewayStoppingFailedStep({super.key});

  @override
  State<HermesGatewayTestGatewayStoppingFailedStep> createState() =>
      _HermesGatewayTestGatewayStoppingFailedState();
}

class _HermesGatewayTestGatewayStoppingFailedState
    extends State<HermesGatewayTestGatewayStoppingFailedStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.stop, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Stopping Failed',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway failed to stop. Please check the logs for more information.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway stop failed - checking logs...');
          },
          icon: const Icon(Icons.archive),
          label: const Text('View Stop Logs'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway stop failed - force stopping...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.power),
          label: const Text('Force Stop'),
        ),
      ],
    );
  }
}
