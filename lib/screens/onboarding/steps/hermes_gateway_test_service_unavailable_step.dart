import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestServiceUnavailableStep');

class HermesGatewayTestServiceUnavailableStep extends StatefulWidget {
  const HermesGatewayTestServiceUnavailableStep({super.key});

  @override
  State<HermesGatewayTestServiceUnavailableStep> createState() =>
      _HermesGatewayTestServiceUnavailableState();
}

class _HermesGatewayTestServiceUnavailableState
    extends State<HermesGatewayTestServiceUnavailableStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cloud_off, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Service Unavailable',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway is currently unavailable. Please try again later.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Service unavailable - retrying...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry Connection'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Service unavailable - checking status...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.info),
          label: const Text('Check Service Status'),
        ),
      ],
    );
  }
}
