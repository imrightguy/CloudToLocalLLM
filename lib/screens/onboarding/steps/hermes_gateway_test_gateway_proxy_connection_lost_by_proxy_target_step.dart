import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionLostByProxyTargetStep');

class HermesGatewayTestGatewayProxyConnectionLostByProxyTargetStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionLostByProxyTargetStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionLostByProxyTargetStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionLostByProxyTargetState();
}

class _HermesGatewayTestGatewayProxyConnectionLostByProxyTargetState
    extends State<
        HermesGatewayTestGatewayProxyConnectionLostByProxyTargetStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cloud_off, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Target Connection Lost',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The connection to the proxy server\'s target (Hermes gateway) was lost. Please check your network connection and Hermes gateway.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy target connection lost - checking network...');
          },
          icon: const Icon(Icons.wifi),
          label: const Text('Check Network Connection'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target connection lost - restarting Hermes gateway...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Hermes Gateway'),
        ),
      ],
    );
  }
}
