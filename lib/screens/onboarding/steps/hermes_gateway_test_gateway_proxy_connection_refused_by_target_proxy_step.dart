import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionRefusedByTargetProxyStep');

class HermesGatewayTestGatewayProxyConnectionRefusedByTargetProxyStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionRefusedByTargetProxyStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionRefusedByTargetProxyStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionRefusedByTargetProxyState();
}

class _HermesGatewayTestGatewayProxyConnectionRefusedByTargetProxyState
    extends State<
        HermesGatewayTestGatewayProxyConnectionRefusedByTargetProxyStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.block, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Target Proxy Connection Refused',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The target proxy server refused the connection. Please ensure the proxy server is running on the specified address and port.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Target proxy connection refused - checking proxy server...');
          },
          icon: const Icon(Icons.play_circle),
          label: const Text('Check Proxy Server Status'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Target proxy connection refused - starting proxy server...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Proxy Server'),
        ),
      ],
    );
  }
}
