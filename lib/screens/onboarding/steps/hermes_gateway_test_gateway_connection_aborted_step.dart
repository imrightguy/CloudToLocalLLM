import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayConnectionAbortedStep');

class HermesGatewayTestGatewayConnectionAbortedStep extends StatefulWidget {
  const HermesGatewayTestGatewayConnectionAbortedStep({super.key});

  @override
  State<HermesGatewayTestGatewayConnectionAbortedStep> createState() =>
      _HermesGatewayTestGatewayConnectionAbortedState();
}

class _HermesGatewayTestGatewayConnectionAbortedState
    extends State<HermesGatewayTestGatewayConnectionAbortedStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cancel, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Connection Aborted',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The connection to Hermes gateway was aborted. This may be due to a network issue or gateway termination.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Connection aborted - restarting gateway...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Gateway'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Connection aborted - checking logs...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.archive),
          label: const Text('View Gateway Logs'),
        ),
      ],
    );
  }
}
