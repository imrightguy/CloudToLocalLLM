import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestFinalStep');

class HermesGatewayTestFinalStep extends StatefulWidget {
  const HermesGatewayTestFinalStep({super.key});

  @override
  State<HermesGatewayTestFinalStep> createState() =>
      _HermesGatewayTestFinalStepState();
}

class _HermesGatewayTestFinalStepState
    extends State<HermesGatewayTestFinalStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Hermes Gateway Tests Complete!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'All tests passed. Hermes gateway is configured and working correctly.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Tests complete - moving to home screen');
          },
          icon: const Icon(Icons.done_all),
          label: const Text('Continue to Home Screen'),
        ),
      ],
    );
  }
}
