import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayConnectionErrorStep');

class HermesGatewayTestGatewayConnectionErrorStep extends StatefulWidget {
  const HermesGatewayTestGatewayConnectionErrorStep({super.key});

  @override
  State<HermesGatewayTestGatewayConnectionErrorStep> createState() =>
      _HermesGatewayTestGatewayConnectionErrorState();
}

class _HermesGatewayTestGatewayConnectionErrorState
    extends State<HermesGatewayTestGatewayConnectionErrorStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Connection Error',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'An error occurred while connecting to Hermes gateway. Please check your network and gateway settings.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Connection error - checking network...');
          },
          icon: const Icon(Icons.wifi),
          label: const Text('Check Network Connection'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Connection error - checking gateway...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.settings),
          label: const Text('Check Gateway Settings'),
        ),
      ],
    );
  }
}
