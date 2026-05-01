import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayStartingFailedStep');

class HermesGatewayTestGatewayStartingFailedStep extends StatefulWidget {
  const HermesGatewayTestGatewayStartingFailedStep({super.key});

  @override
  State<HermesGatewayTestGatewayStartingFailedStep> createState() =>
      _HermesGatewayTestGatewayStartingFailedState();
}

class _HermesGatewayTestGatewayStartingFailedState
    extends State<HermesGatewayTestGatewayStartingFailedStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.play_circle, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Starting Failed',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway failed to start. Please check the logs for more information.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway start failed - checking logs...');
          },
          icon: const Icon(Icons.archive),
          label: const Text('View Start Logs'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway start failed - checking dependencies...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.download),
          label: const Text('Check Dependencies'),
        ),
      ],
    );
  }
}
