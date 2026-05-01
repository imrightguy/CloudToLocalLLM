import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayInitializingStep');

class HermesGatewayTestGatewayInitializingStep extends StatefulWidget {
  const HermesGatewayTestGatewayInitializingStep({super.key});

  @override
  State<HermesGatewayTestGatewayInitializingStep> createState() =>
      _HermesGatewayTestGatewayInitializingState();
}

class _HermesGatewayTestGatewayInitializingState
    extends State<HermesGatewayTestGatewayInitializingStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.play_circle, color: Colors.orange, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Initializing',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway is currently initializing. Please wait a moment and try again.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway initializing - waiting...');
          },
          icon: const Icon(Icons.timer),
          label: const Text('Wait and Retry'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway initializing - checking status...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.info),
          label: const Text('Check Gateway Status'),
        ),
      ],
    );
  }
}
