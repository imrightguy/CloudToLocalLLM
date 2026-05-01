import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionErrorByTargetStep');

class HermesGatewayTestGatewayProxyConnectionErrorByTargetStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionErrorByTargetStep({super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionErrorByTargetStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionErrorByTargetState();
}

class _HermesGatewayTestGatewayProxyConnectionErrorByTargetState
    extends State<HermesGatewayTestGatewayProxyConnectionErrorByTargetStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Target Connection Error',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'An error occurred while connecting to the target server (Hermes gateway) through the proxy. Please check your Hermes gateway settings.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Target connection error - checking Hermes gateway settings...');
          },
          icon: const Icon(Icons.settings),
          label: const Text('Check Hermes Gateway Settings'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Target connection error - checking network...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.network_check),
          label: const Text('Check Network Connection'),
        ),
      ],
    );
  }
}
