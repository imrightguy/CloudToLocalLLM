import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionAbortedByTargetStep');

class HermesGatewayTestGatewayProxyConnectionAbortedByTargetStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionAbortedByTargetStep({super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionAbortedByTargetStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionAbortedByTargetState();
}

class _HermesGatewayTestGatewayProxyConnectionAbortedByTargetState
    extends State<HermesGatewayTestGatewayProxyConnectionAbortedByTargetStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cancel, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Target Connection Aborted',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The target server (Hermes gateway) aborted the connection through the proxy. This may be due to a network issue or gateway termination.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Target connection aborted - restarting Hermes gateway...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Hermes Gateway'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Target connection aborted - checking logs...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.archive),
          label: const Text('View Hermes Gateway Logs'),
        ),
      ],
    );
  }
}
