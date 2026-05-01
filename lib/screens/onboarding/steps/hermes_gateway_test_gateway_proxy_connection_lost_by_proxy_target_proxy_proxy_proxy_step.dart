import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger(
    'HermesGatewayTestGatewayProxyConnectionLostByProxyTargetProxyProxyProxyStep');

class HermesGatewayTestGatewayProxyConnectionLostByProxyTargetProxyProxyProxyStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionLostByProxyTargetProxyProxyProxyStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionLostByProxyTargetProxyProxyProxyStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionLostByProxyTargetProxyProxyProxyState();
}

class _HermesGatewayTestGatewayProxyConnectionLostByProxyTargetProxyProxyProxyState
    extends State<
        HermesGatewayTestGatewayProxyConnectionLostByProxyTargetProxyProxyProxyStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cloud_off, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Target Proxy Connection Lost',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The connection to the proxy server\'s target proxy was lost. Please check your network connection and target proxy server.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target proxy connection lost - checking network...');
          },
          icon: const Icon(Icons.wifi),
          label: const Text('Check Network Connection'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target proxy connection lost - restarting target proxy server...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Target Proxy Server'),
        ),
      ],
    );
  }
}
