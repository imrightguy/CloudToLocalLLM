import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayUpdatingStep');

class HermesGatewayTestGatewayUpdatingStep extends StatefulWidget {
  const HermesGatewayTestGatewayUpdatingStep({super.key});

  @override
  State<HermesGatewayTestGatewayUpdatingStep> createState() =>
      _HermesGatewayTestGatewayUpdatingState();
}

class _HermesGatewayTestGatewayUpdatingState
    extends State<HermesGatewayTestGatewayUpdatingStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cloud_download, color: Colors.orange, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Updating',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway is currently updating. Please wait for the update to complete and try again.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway updating - waiting...');
          },
          icon: const Icon(Icons.timer),
          label: const Text('Wait and Retry'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway updating - checking progress...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.cloud_download),
          label: const Text('Check Update Progress'),
        ),
      ],
    );
  }
}
