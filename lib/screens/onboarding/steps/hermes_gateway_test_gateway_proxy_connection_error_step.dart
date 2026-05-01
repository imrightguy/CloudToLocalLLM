import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayProxyConnectionErrorStep');

class HermesGatewayTestGatewayProxyConnectionErrorStep extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionErrorStep({super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionErrorStep> createState() =>
      _HermesGatewayTestGatewayProxyConnectionErrorState();
}

class _HermesGatewayTestGatewayProxyConnectionErrorState
    extends State<HermesGatewayTestGatewayProxyConnectionErrorStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Connection Error',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'An error occurred while connecting to Hermes gateway through the proxy server. Please check your proxy settings.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy connection error - checking proxy settings...');
          },
          icon: const Icon(Icons.settings),
          label: const Text('Check Proxy Settings'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy connection error - checking network...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.network_check),
          label: const Text('Check Network Connection'),
        ),
      ],
    );
  }
}
