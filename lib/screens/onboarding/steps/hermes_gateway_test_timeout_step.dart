import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestTimeoutStep');

class HermesGatewayTestTimeoutStep extends StatefulWidget {
  const HermesGatewayTestTimeoutStep({super.key});

  @override
  State<HermesGatewayTestTimeoutStep> createState() =>
      _HermesGatewayTestTimeoutStepState();
}

class _HermesGatewayTestTimeoutStepState
    extends State<HermesGatewayTestTimeoutStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.timer, color: Colors.orange, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Test Timed Out',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The connection to Hermes gateway timed out. Please check your network connection and Hermes gateway status.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Test timed out - retrying...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry Test'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Test timed out - skipping...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.skip_next),
          label: const Text('Skip Test'),
        ),
      ],
    );
  }
}
