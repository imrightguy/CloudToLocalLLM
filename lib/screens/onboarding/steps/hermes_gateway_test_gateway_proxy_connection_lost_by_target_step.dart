import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionLostByTargetStep');

class HermesGatewayTestGatewayProxyConnectionLostByTargetStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionLostByTargetStep({super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionLostByTargetStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionLostByTargetState();
}

class _HermesGatewayTestGatewayProxyConnectionLostByTargetState
    extends State<HermesGatewayTestGatewayProxyConnectionLostByTargetStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cloud_off, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Target Connection Lost',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The connection to the target server (Hermes gateway) through the proxy was lost. Please check your network connection and Hermes gateway.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Target connection lost - checking network...');
          },
          icon: const Icon(Icons.wifi),
          label: const Text('Check Network Connection'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Target connection lost - restarting Hermes gateway...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Hermes Gateway'),
        ),
      ],
    );
  }
}
