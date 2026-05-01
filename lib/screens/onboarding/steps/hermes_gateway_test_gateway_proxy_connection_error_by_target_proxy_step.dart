import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionErrorByTargetProxyStep');

class HermesGatewayTestGatewayProxyConnectionErrorByTargetProxyStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionErrorByTargetProxyStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionErrorByTargetProxyStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionErrorByTargetProxyState();
}

class _HermesGatewayTestGatewayProxyConnectionErrorByTargetProxyState
    extends State<
        HermesGatewayTestGatewayProxyConnectionErrorByTargetProxyStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Target Proxy Connection Error',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'An error occurred while connecting to the target proxy server. Please check your proxy server settings.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Target proxy connection error - checking proxy server settings...');
          },
          icon: const Icon(Icons.settings),
          label: const Text('Check Proxy Server Settings'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Target proxy connection error - checking network...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.network_check),
          label: const Text('Check Network Connection'),
        ),
      ],
    );
  }
}
