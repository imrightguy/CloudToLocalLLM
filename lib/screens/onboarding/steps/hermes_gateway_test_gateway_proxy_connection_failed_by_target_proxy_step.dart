import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionFailedByTargetProxyStep');

class HermesGatewayTestGatewayProxyConnectionFailedByTargetProxyStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionFailedByTargetProxyStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionFailedByTargetProxyStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionFailedByTargetProxyState();
}

class _HermesGatewayTestGatewayProxyConnectionFailedByTargetProxyState
    extends State<
        HermesGatewayTestGatewayProxyConnectionFailedByTargetProxyStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Target Proxy Connection Failed',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Failed to establish a connection to the target proxy server. Please check your proxy server settings.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Target proxy connection failed - checking proxy server settings...');
          },
          icon: const Icon(Icons.settings),
          label: const Text('Check Proxy Server Settings'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Target proxy connection failed - checking network...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.network_check),
          label: const Text('Check Network Connection'),
        ),
      ],
    );
  }
}
