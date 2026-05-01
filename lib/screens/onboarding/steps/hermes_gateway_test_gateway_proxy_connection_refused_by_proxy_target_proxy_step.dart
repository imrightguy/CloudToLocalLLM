import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger(
    'HermesGatewayTestGatewayProxyConnectionRefusedByProxyTargetProxyStep');

class HermesGatewayTestGatewayProxyConnectionRefusedByProxyTargetProxyStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionRefusedByProxyTargetProxyStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionRefusedByProxyTargetProxyStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionRefusedByProxyTargetProxyState();
}

class _HermesGatewayTestGatewayProxyConnectionRefusedByProxyTargetProxyState
    extends State<
        HermesGatewayTestGatewayProxyConnectionRefusedByProxyTargetProxyStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.block, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Target Proxy Connection Refused',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The proxy server\'s target proxy refused the connection. Please ensure the target proxy server is running on the specified address and port.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target proxy connection refused - checking target proxy server...');
          },
          icon: const Icon(Icons.play_circle),
          label: const Text('Check Target Proxy Server Status'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target proxy connection refused - starting target proxy server...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Target Proxy Server'),
        ),
      ],
    );
  }
}
