import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayTimeoutStep');

class HermesGatewayTestGatewayTimeoutStep extends StatefulWidget {
  const HermesGatewayTestGatewayTimeoutStep({super.key});

  @override
  State<HermesGatewayTestGatewayTimeoutStep> createState() =>
      _HermesGatewayTestGatewayTimeoutState();
}

class _HermesGatewayTestGatewayTimeoutState
    extends State<HermesGatewayTestGatewayTimeoutStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.timer, color: Colors.orange, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Timeout',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway is taking too long to respond. This may be due to high load or network issues.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway timeout - retrying with longer timeout...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry with Longer Timeout'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway timeout - checking gateway load...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.show_chart),
          label: const Text('Check Gateway Load'),
        ),
      ],
    );
  }
}
