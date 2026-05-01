import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayConnectionFailedStep');

class HermesGatewayTestGatewayConnectionFailedStep extends StatefulWidget {
  const HermesGatewayTestGatewayConnectionFailedStep({super.key});

  @override
  State<HermesGatewayTestGatewayConnectionFailedStep> createState() =>
      _HermesGatewayTestGatewayConnectionFailedState();
}

class _HermesGatewayTestGatewayConnectionFailedState
    extends State<HermesGatewayTestGatewayConnectionFailedStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Connection Failed',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Failed to establish a connection to Hermes gateway. Please check your network and gateway settings.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Connection failed - checking network...');
          },
          icon: const Icon(Icons.wifi),
          label: const Text('Check Network Connection'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Connection failed - checking gateway...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.settings),
          label: const Text('Check Gateway Settings'),
        ),
      ],
    );
  }
}
