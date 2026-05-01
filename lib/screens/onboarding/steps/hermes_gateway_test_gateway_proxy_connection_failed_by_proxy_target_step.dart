import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionFailedByProxyTargetStep');

class HermesGatewayTestGatewayProxyConnectionFailedByProxyTargetStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionFailedByProxyTargetStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionFailedByProxyTargetStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionFailedByProxyTargetState();
}

class _HermesGatewayTestGatewayProxyConnectionFailedByProxyTargetState
    extends State<
        HermesGatewayTestGatewayProxyConnectionFailedByProxyTargetStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Target Connection Failed',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Failed to establish a connection to the proxy server\'s target (Hermes gateway). Please check your Hermes gateway settings.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target connection failed - checking Hermes gateway settings...');
          },
          icon: const Icon(Icons.settings),
          label: const Text('Check Hermes Gateway Settings'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy target connection failed - checking network...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.network_check),
          label: const Text('Check Network Connection'),
        ),
      ],
    );
  }
}
