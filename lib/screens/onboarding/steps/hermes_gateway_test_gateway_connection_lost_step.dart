import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayConnectionLostStep');

class HermesGatewayTestGatewayConnectionLostStep extends StatefulWidget {
  const HermesGatewayTestGatewayConnectionLostStep({super.key});

  @override
  State<HermesGatewayTestGatewayConnectionLostStep> createState() =>
      _HermesGatewayTestGatewayConnectionLostState();
}

class _HermesGatewayTestGatewayConnectionLostState
    extends State<HermesGatewayTestGatewayConnectionLostStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cloud_off, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Connection Lost',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The connection to Hermes gateway was lost. Please check your network connection and try again.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Connection lost - checking network...');
          },
          icon: const Icon(Icons.wifi),
          label: const Text('Check Network Connection'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Connection lost - restarting gateway...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Gateway'),
        ),
      ],
    );
  }
}
