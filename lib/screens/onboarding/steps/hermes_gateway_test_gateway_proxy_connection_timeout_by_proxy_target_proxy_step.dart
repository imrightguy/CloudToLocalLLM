import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger(
    'HermesGatewayTestGatewayProxyConnectionTimeoutByProxyTargetProxyStep');

class HermesGatewayTestGatewayProxyConnectionTimeoutByProxyTargetProxyStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionTimeoutByProxyTargetProxyStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionTimeoutByProxyTargetProxyStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionTimeoutByProxyTargetProxyState();
}

class _HermesGatewayTestGatewayProxyConnectionTimeoutByProxyTargetProxyState
    extends State<
        HermesGatewayTestGatewayProxyConnectionTimeoutByProxyTargetProxyStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.timer, color: Colors.orange, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Target Proxy Connection Timeout',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The proxy server\'s target proxy timed out while connecting. This may be due to network issues or proxy overload.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target proxy connection timeout - checking network...');
          },
          icon: const Icon(Icons.network_check),
          label: const Text('Check Network Connection'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target proxy connection timeout - checking proxy load...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.show_chart),
          label: const Text('Check Target Proxy Server Load'),
        ),
      ],
    );
  }
}
