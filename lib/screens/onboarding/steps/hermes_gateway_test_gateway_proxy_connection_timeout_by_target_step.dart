import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionTimeoutByTargetStep');

class HermesGatewayTestGatewayProxyConnectionTimeoutByTargetStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionTimeoutByTargetStep({super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionTimeoutByTargetStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionTimeoutByTargetState();
}

class _HermesGatewayTestGatewayProxyConnectionTimeoutByTargetState
    extends State<HermesGatewayTestGatewayProxyConnectionTimeoutByTargetStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.timer, color: Colors.orange, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Target Connection Timeout',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The target server (Hermes gateway) timed out while connecting through the proxy. This may be due to network issues or gateway overload.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Target connection timeout - checking network...');
          },
          icon: const Icon(Icons.network_check),
          label: const Text('Check Network Connection'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Target connection timeout - checking gateway load...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.show_chart),
          label: const Text('Check Gateway Load'),
        ),
      ],
    );
  }
}
