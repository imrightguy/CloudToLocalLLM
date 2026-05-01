import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger(
    'HermesGatewayTestGatewayProxyConnectionAbortedByProxyTargetProxyStep');

class HermesGatewayTestGatewayProxyConnectionAbortedByProxyTargetProxyStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionAbortedByProxyTargetProxyStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionAbortedByProxyTargetProxyStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionAbortedByProxyTargetProxyState();
}

class _HermesGatewayTestGatewayProxyConnectionAbortedByProxyTargetProxyState
    extends State<
        HermesGatewayTestGatewayProxyConnectionAbortedByProxyTargetProxyStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cancel, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Target Proxy Connection Aborted',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The proxy server\'s target proxy aborted the connection. This may be due to a network issue or proxy termination.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target proxy connection aborted - restarting target proxy server...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Target Proxy Server'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target proxy connection aborted - checking logs...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.archive),
          label: const Text('View Target Proxy Server Logs'),
        ),
      ],
    );
  }
}
