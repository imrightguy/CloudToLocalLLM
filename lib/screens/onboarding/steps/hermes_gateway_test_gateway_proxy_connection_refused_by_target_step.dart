import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionRefusedByTargetStep');

class HermesGatewayTestGatewayProxyConnectionRefusedByTargetStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionRefusedByTargetStep({super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionRefusedByTargetStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionRefusedByTargetState();
}

class _HermesGatewayTestGatewayProxyConnectionRefusedByTargetState
    extends State<HermesGatewayTestGatewayProxyConnectionRefusedByTargetStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.block, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Target Connection Refused',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The target server (Hermes gateway) refused the connection through the proxy. Please ensure Hermes gateway is running on the specified address and port.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Target connection refused - checking Hermes gateway...');
          },
          icon: const Icon(Icons.play_circle),
          label: const Text('Check Hermes Gateway Status'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Target connection refused - starting Hermes gateway...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Hermes Gateway'),
        ),
      ],
    );
  }
}
