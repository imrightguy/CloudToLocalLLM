import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayConnectionRefusedByProxyStep');

class HermesGatewayTestGatewayConnectionRefusedByProxyStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayConnectionRefusedByProxyStep({super.key});

  @override
  State<HermesGatewayTestGatewayConnectionRefusedByProxyStep> createState() =>
      _HermesGatewayTestGatewayConnectionRefusedByProxyState();
}

class _HermesGatewayTestGatewayConnectionRefusedByProxyState
    extends State<HermesGatewayTestGatewayConnectionRefusedByProxyStep> {
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
          'The proxy server refused the connection to Hermes gateway. Please check your proxy settings.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy connection refused - checking proxy settings...');
          },
          icon: const Icon(Icons.settings),
          label: const Text('Check Proxy Settings'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy connection refused - bypassing proxy...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.directions),
          label: const Text('Bypass Proxy'),
        ),
      ],
    );
  }
}
