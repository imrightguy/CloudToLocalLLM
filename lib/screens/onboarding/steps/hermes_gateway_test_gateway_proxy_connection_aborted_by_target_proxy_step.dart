import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionAbortedByTargetProxyStep');

class HermesGatewayTestGatewayProxyConnectionAbortedByTargetProxyStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionAbortedByTargetProxyStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionAbortedByTargetProxyStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionAbortedByTargetProxyState();
}

class _HermesGatewayTestGatewayProxyConnectionAbortedByTargetProxyState
    extends State<
        HermesGatewayTestGatewayProxyConnectionAbortedByTargetProxyStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cancel, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Target Proxy Connection Aborted',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The target proxy server aborted the connection. This may be due to a network issue or proxy termination.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Target proxy connection aborted - restarting proxy server...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Proxy Server'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Target proxy connection aborted - checking logs...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.archive),
          label: const Text('View Proxy Server Logs'),
        ),
      ],
    );
  }
}
