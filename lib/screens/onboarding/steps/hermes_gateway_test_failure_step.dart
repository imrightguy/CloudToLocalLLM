import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestFailureStep');

class HermesGatewayTestFailureStep extends StatefulWidget {
  final String? errorMessage;

  const HermesGatewayTestFailureStep({super.key, this.errorMessage});

  @override
  State<HermesGatewayTestFailureStep> createState() =>
      _HermesGatewayTestFailureStepState();
}

class _HermesGatewayTestFailureStepState
    extends State<HermesGatewayTestFailureStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Test Failed',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (widget.errorMessage != null)
          Text(
            widget.errorMessage!,
            style: const TextStyle(color: Colors.red),
          ),
        const SizedBox(height: 16),
        const Text(
          'Please check your configuration and try again.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Retrying Hermes gateway tests');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry Tests'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Skipping tests - moving to home screen');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.skip_next),
          label: const Text('Skip Tests'),
        ),
      ],
    );
  }
}
