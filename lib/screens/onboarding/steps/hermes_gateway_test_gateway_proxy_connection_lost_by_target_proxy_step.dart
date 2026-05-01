import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionLostByTargetProxyStep');

class HermesGatewayTestGatewayProxyConnectionLostByTargetProxyStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionLostByTargetProxyStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionLostByTargetProxyStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionLostByTargetProxyState();
}

class _HermesGatewayTestGatewayProxyConnectionLostByTargetProxyState
    extends State<
        HermesGatewayTestGatewayProxyConnectionLostByTargetProxyStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cloud_off, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Target Proxy Connection Lost',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The connection to the target proxy server was lost. Please check your network connection and proxy server.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Target proxy connection lost - checking network...');
          },
          icon: const Icon(Icons.wifi),
          label: const Text('Check Network Connection'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Target proxy connection lost - restarting proxy server...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Proxy Server'),
        ),
      ],
    );
  }
}
