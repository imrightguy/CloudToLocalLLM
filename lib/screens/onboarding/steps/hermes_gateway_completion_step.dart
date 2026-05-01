import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayCompletionStep');

class HermesGatewayCompletionStep extends StatefulWidget {
  const HermesGatewayCompletionStep({super.key});

  @override
  State<HermesGatewayCompletionStep> createState() =>
      _HermesGatewayCompletionStepState();
}

class _HermesGatewayCompletionStepState
    extends State<HermesGatewayCompletionStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Hermes Gateway Setup Complete!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'You have successfully configured the Hermes gateway. You can now use it as a backend for chat completions.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            // Finish onboarding and go to home screen
            _log.info('Onboarding complete - moving to home screen');
          },
          icon: const Icon(Icons.done_all),
          label: const Text('Continue to Home Screen'),
        ),
      ],
    );
  }
}
