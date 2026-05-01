import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayConnectionTimeoutStep');

class HermesGatewayTestGatewayConnectionTimeoutStep extends StatefulWidget {
  const HermesGatewayTestGatewayConnectionTimeoutStep({super.key});

  @override
  State<HermesGatewayTestGatewayConnectionTimeoutStep> createState() =>
      _HermesGatewayTestGatewayConnectionTimeoutState();
}

class _HermesGatewayTestGatewayConnectionTimeoutState
    extends State<HermesGatewayTestGatewayConnectionTimeoutStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.timer, color: Colors.orange, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Connection Timeout',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The connection to Hermes gateway timed out. This may be due to network issues or gateway overload.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Connection timeout - retrying with longer timeout...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry with Longer Timeout'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Connection timeout - checking network...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.network_check),
          label: const Text('Check Network Connection'),
        ),
      ],
    );
  }
}
