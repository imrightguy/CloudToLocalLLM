import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayProxyConnectionResetStep');

class HermesGatewayTestGatewayProxyConnectionResetStep extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionResetStep({super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionResetStep> createState() =>
      _HermesGatewayTestGatewayProxyConnectionResetState();
}

class _HermesGatewayTestGatewayProxyConnectionResetState
    extends State<HermesGatewayTestGatewayProxyConnectionResetStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.refresh, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Connection Reset',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The proxy server reset the connection to Hermes gateway. This may be due to a network issue or proxy crash.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy connection reset - restarting proxy...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Proxy'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy connection reset - checking logs...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.archive),
          label: const Text('View Proxy Logs'),
        ),
      ],
    );
  }
}
