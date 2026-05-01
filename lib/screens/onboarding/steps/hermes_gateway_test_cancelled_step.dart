import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestCancelledStep');

class HermesGatewayTestCancelledStep extends StatefulWidget {
  const HermesGatewayTestCancelledStep({super.key});

  @override
  State<HermesGatewayTestCancelledStep> createState() =>
      _HermesGatewayTestCancelledStepState();
}

class _HermesGatewayTestCancelledStepState
    extends State<HermesGatewayTestCancelledStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cancel, color: Colors.grey, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Testing Cancelled',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway testing was cancelled. You can test later from settings.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Testing cancelled - moving to home screen');
          },
          icon: const Icon(Icons.home),
          label: const Text('Go to Home Screen'),
        ),
      ],
    );
  }
}
