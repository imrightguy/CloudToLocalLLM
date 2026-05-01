import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionAbortedStep');

class HermesGatewayTestGatewayProxyConnectionAbortedStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionAbortedStep({super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionAbortedStep> createState() =>
      _HermesGatewayTestGatewayProxyConnectionAbortedState();
}

class _HermesGatewayTestGatewayProxyConnectionAbortedState
    extends State<HermesGatewayTestGatewayProxyConnectionAbortedStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cancel, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Connection Aborted',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The proxy server aborted the connection to Hermes gateway. This may be due to a network issue or proxy termination.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy connection aborted - restarting proxy...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Proxy'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy connection aborted - checking logs...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.archive),
          label: const Text('View Proxy Logs'),
        ),
      ],
    );
  }
}
