import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionTimeoutStep');

class HermesGatewayTestGatewayProxyConnectionTimeoutStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionTimeoutStep({super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionTimeoutStep> createState() =>
      _HermesGatewayTestGatewayProxyConnectionTimeoutState();
}

class _HermesGatewayTestGatewayProxyConnectionTimeoutState
    extends State<HermesGatewayTestGatewayProxyConnectionTimeoutStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.timer, color: Colors.orange, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Connection Timeout',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The proxy server timed out while connecting to Hermes gateway. Please check your proxy settings and network connection.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy connection timeout - checking proxy settings...');
          },
          icon: const Icon(Icons.settings),
          label: const Text('Check Proxy Settings'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy connection timeout - checking network...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.network_check),
          label: const Text('Check Network Connection'),
        ),
      ],
    );
  }
}
