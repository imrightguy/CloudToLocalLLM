import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayConnectionResetStep');

class HermesGatewayTestGatewayConnectionResetStep extends StatefulWidget {
  const HermesGatewayTestGatewayConnectionResetStep({super.key});

  @override
  State<HermesGatewayTestGatewayConnectionResetStep> createState() =>
      _HermesGatewayTestGatewayConnectionResetState();
}

class _HermesGatewayTestGatewayConnectionResetState
    extends State<HermesGatewayTestGatewayConnectionResetStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.refresh, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Connection Reset',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The connection to Hermes gateway was reset. This may be due to a network issue or gateway crash.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Connection reset - restarting gateway...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Gateway'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Connection reset - checking logs...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.archive),
          label: const Text('View Gateway Logs'),
        ),
      ],
    );
  }
}
