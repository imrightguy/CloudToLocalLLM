import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayBusyStep');

class HermesGatewayTestGatewayBusyStep extends StatefulWidget {
  const HermesGatewayTestGatewayBusyStep({super.key});

  @override
  State<HermesGatewayTestGatewayBusyStep> createState() =>
      _HermesGatewayTestGatewayBusyState();
}

class _HermesGatewayTestGatewayBusyState
    extends State<HermesGatewayTestGatewayBusyStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.hourglass_full, color: Colors.orange, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Busy',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway is currently busy and cannot handle more requests. Please try again later.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway busy - waiting and retrying...');
          },
          icon: const Icon(Icons.timer),
          label: const Text('Wait and Retry'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway busy - checking queue...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.queue),
          label: const Text('Check Request Queue'),
        ),
      ],
    );
  }
}
