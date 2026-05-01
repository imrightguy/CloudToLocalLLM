import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestIntroStep');

class HermesGatewayTestIntroStep extends StatefulWidget {
  const HermesGatewayTestIntroStep({super.key});

  @override
  State<HermesGatewayTestIntroStep> createState() =>
      _HermesGatewayTestIntroStepState();
}

class _HermesGatewayTestIntroStepState
    extends State<HermesGatewayTestIntroStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Test Hermes Gateway',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        const Text(
          'Before using Hermes, let\'s verify that it\'s working correctly. We\'ll test the connection, messaging, and streaming capabilities.',
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            _log.info('Starting Hermes gateway tests');
          },
          child: const Text('Start Tests'),
        ),
      ],
    );
  }
}
