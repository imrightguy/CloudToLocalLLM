import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionResetByProxyTargetStep');

class HermesGatewayTestGatewayProxyConnectionResetByProxyTargetStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionResetByProxyTargetStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionResetByProxyTargetStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionResetByProxyTargetState();
}

class _HermesGatewayTestGatewayProxyConnectionResetByProxyTargetState
    extends State<
        HermesGatewayTestGatewayProxyConnectionResetByProxyTargetStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.refresh, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Target Connection Reset',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The proxy server\'s target (Hermes gateway) reset the connection. This may be due to a network issue or gateway crash.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target connection reset - restarting Hermes gateway...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Hermes Gateway'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy target connection reset - checking logs...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.archive),
          label: const Text('View Hermes Gateway Logs'),
        ),
      ],
    );
  }
}
