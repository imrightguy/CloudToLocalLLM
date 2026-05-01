import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayStoppingStep');

class HermesGatewayTestGatewayStoppingStep extends StatefulWidget {
  const HermesGatewayTestGatewayStoppingStep({super.key});

  @override
  State<HermesGatewayTestGatewayStoppingStep> createState() =>
      _HermesGatewayTestGatewayStoppingState();
}

class _HermesGatewayTestGatewayStoppingState
    extends State<HermesGatewayTestGatewayStoppingStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.stop, color: Colors.orange, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Stopping',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway is currently stopping. Please wait for it to stop completely and try again.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway stopping - waiting...');
          },
          icon: const Icon(Icons.timer),
          label: const Text('Wait and Retry'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway stopping - checking status...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.info),
          label: const Text('Check Gateway Status'),
        ),
      ],
    );
  }
}
