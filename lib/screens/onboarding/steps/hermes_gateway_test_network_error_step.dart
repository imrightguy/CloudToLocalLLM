import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestNetworkErrorStep');

class HermesGatewayTestNetworkErrorStep extends StatefulWidget {
  const HermesGatewayTestNetworkErrorStep({super.key});

  @override
  State<HermesGatewayTestNetworkErrorStep> createState() =>
      _HermesGatewayTestNetworkErrorState();
}

class _HermesGatewayTestNetworkErrorState
    extends State<HermesGatewayTestNetworkErrorStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.wifi_off, color: Colors.orange, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Network Error',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Cannot connect to Hermes gateway. Please check your network connection.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Network error - retrying...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry Connection'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Network error - checking network...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.network_check),
          label: const Text('Check Network'),
        ),
      ],
    );
  }
}
