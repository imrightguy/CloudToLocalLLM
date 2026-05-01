import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayConnectionRefusedStep');

class HermesGatewayTestGatewayConnectionRefusedStep extends StatefulWidget {
  const HermesGatewayTestGatewayConnectionRefusedStep({super.key});

  @override
  State<HermesGatewayTestGatewayConnectionRefusedStep> createState() =>
      _HermesGatewayTestGatewayConnectionRefusedState();
}

class _HermesGatewayTestGatewayConnectionRefusedState
    extends State<HermesGatewayTestGatewayConnectionRefusedStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.block, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Connection Refused',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway actively refused the connection. Please ensure the gateway is running on the specified address and port.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Connection refused - checking if gateway is running...');
          },
          icon: const Icon(Icons.play_circle),
          label: const Text('Check Gateway Status'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Connection refused - starting gateway...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Gateway'),
        ),
      ],
    );
  }
}
