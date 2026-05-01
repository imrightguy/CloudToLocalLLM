import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionRefusedByProxyTargetStep');

class HermesGatewayTestGatewayProxyConnectionRefusedByProxyTargetStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionRefusedByProxyTargetStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionRefusedByProxyTargetStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionRefusedByProxyTargetState();
}

class _HermesGatewayTestGatewayProxyConnectionRefusedByProxyTargetState
    extends State<
        HermesGatewayTestGatewayProxyConnectionRefusedByProxyTargetStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.block, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Target Connection Refused',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The proxy server\'s target (Hermes gateway) refused the connection. Please ensure Hermes gateway is running on the specified address and port.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target connection refused - checking Hermes gateway...');
          },
          icon: const Icon(Icons.play_circle),
          label: const Text('Check Hermes Gateway Status'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target connection refused - starting Hermes gateway...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Hermes Gateway'),
        ),
      ],
    );
  }
}
