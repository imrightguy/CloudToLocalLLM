import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionRefusedStep');

class HermesGatewayTestGatewayProxyConnectionRefusedStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionRefusedStep({super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionRefusedStep> createState() =>
      _HermesGatewayTestGatewayProxyConnectionRefusedState();
}

class _HermesGatewayTestGatewayProxyConnectionRefusedState
    extends State<HermesGatewayTestGatewayProxyConnectionRefusedStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.block, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Connection Refused',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The proxy server refused the connection to Hermes gateway. Please check your proxy settings and ensure the proxy is running.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy connection refused - checking proxy status...');
          },
          icon: const Icon(Icons.play_circle),
          label: const Text('Check Proxy Status'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy connection refused - restarting proxy...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Proxy'),
        ),
      ],
    );
  }
}
