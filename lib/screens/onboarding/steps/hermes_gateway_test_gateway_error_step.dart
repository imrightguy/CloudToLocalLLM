import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayErrorStep');

class HermesGatewayTestGatewayErrorStep extends StatefulWidget {
  const HermesGatewayTestGatewayErrorStep({super.key});

  @override
  State<HermesGatewayTestGatewayErrorStep> createState() =>
      _HermesGatewayTestGatewayErrorState();
}

class _HermesGatewayTestGatewayErrorState
    extends State<HermesGatewayTestGatewayErrorStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.router, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Error',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway is not responding. Please check if the gateway is running and try again.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway error - restarting gateway...');
          },
          icon: const Icon(Icons.restart_alt),
          label: const Text('Restart Gateway'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway error - going to gateway settings...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.settings),
          label: const Text('Gateway Settings'),
        ),
      ],
    );
  }
}
