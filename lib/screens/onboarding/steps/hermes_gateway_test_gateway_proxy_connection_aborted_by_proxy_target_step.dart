import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionAbortedByProxyTargetStep');

class HermesGatewayTestGatewayProxyConnectionAbortedByProxyTargetStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionAbortedByProxyTargetStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionAbortedByProxyTargetStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionAbortedByProxyTargetState();
}

class _HermesGatewayTestGatewayProxyConnectionAbortedByProxyTargetState
    extends State<
        HermesGatewayTestGatewayProxyConnectionAbortedByProxyTargetStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cancel, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Target Connection Aborted',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The proxy server\'s target (Hermes gateway) aborted the connection. This may be due to a network issue or gateway termination.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target connection aborted - restarting Hermes gateway...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Hermes Gateway'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy target connection aborted - checking logs...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.archive),
          label: const Text('View Hermes Gateway Logs'),
        ),
      ],
    );
  }
}
