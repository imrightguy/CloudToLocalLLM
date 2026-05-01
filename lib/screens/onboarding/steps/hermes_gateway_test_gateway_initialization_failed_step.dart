import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayInitializationFailedStep');

class HermesGatewayTestGatewayInitializationFailedStep extends StatefulWidget {
  const HermesGatewayTestGatewayInitializationFailedStep({super.key});

  @override
  State<HermesGatewayTestGatewayInitializationFailedStep> createState() =>
      _HermesGatewayTestGatewayInitializationFailedState();
}

class _HermesGatewayTestGatewayInitializationFailedState
    extends State<HermesGatewayTestGatewayInitializationFailedStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.play_circle, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Initialization Failed',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway failed to initialize. Please check the logs for more information.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway init failed - checking logs...');
          },
          icon: const Icon(Icons.archive),
          label: const Text('View Initialization Logs'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway init failed - reinstalling...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.download),
          label: const Text('Reinstall Hermes Gateway'),
        ),
      ],
    );
  }
}
