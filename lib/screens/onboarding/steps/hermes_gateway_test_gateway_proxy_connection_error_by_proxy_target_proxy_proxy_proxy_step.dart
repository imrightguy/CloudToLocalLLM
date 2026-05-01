import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger(
    'HermesGatewayTestGatewayProxyConnectionErrorByProxyTargetProxyProxyProxyStep');

class HermesGatewayTestGatewayProxyConnectionErrorByProxyTargetProxyProxyProxyStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionErrorByProxyTargetProxyProxyProxyStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionErrorByProxyTargetProxyProxyProxyStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionErrorByProxyTargetProxyProxyProxyState();
}

class _HermesGatewayTestGatewayProxyConnectionErrorByProxyTargetProxyProxyProxyState
    extends State<
        HermesGatewayTestGatewayProxyConnectionErrorByProxyTargetProxyProxyProxyStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Target Proxy Connection Error',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'An error occurred while connecting to the proxy server\'s target proxy. Please check your target proxy server settings.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target proxy connection error - checking target proxy server settings...');
          },
          icon: const Icon(Icons.settings),
          label: const Text('Check Target Proxy Server Settings'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target proxy connection error - checking network...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.network_check),
          label: const Text('Check Network Connection'),
        ),
      ],
    );
  }
}
