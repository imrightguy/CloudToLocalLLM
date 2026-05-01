import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayProxyErrorStep');

class HermesGatewayTestGatewayProxyErrorStep extends StatefulWidget {
  const HermesGatewayTestGatewayProxyErrorStep({super.key});

  @override
  State<HermesGatewayTestGatewayProxyErrorStep> createState() =>
      _HermesGatewayTestGatewayProxyErrorState();
}

class _HermesGatewayTestGatewayProxyErrorState
    extends State<HermesGatewayTestGatewayProxyErrorStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cloud, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Error',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'An error occurred with the proxy server while connecting to Hermes gateway. Please check your proxy settings.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy error - checking proxy settings...');
          },
          icon: const Icon(Icons.settings),
          label: const Text('Check Proxy Settings'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy error - bypassing proxy...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.directions),
          label: const Text('Bypass Proxy'),
        ),
      ],
    );
  }
}
