import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger(
    'HermesGatewayTestGatewayProxyConnectionResetByProxyTargetProxyProxyStep');

class HermesGatewayTestGatewayProxyConnectionResetByProxyTargetProxyProxyStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionResetByProxyTargetProxyProxyStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionResetByProxyTargetProxyProxyStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionResetByProxyTargetProxyProxyState();
}

class _HermesGatewayTestGatewayProxyConnectionResetByProxyTargetProxyProxyState
    extends State<
        HermesGatewayTestGatewayProxyConnectionResetByProxyTargetProxyProxyStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.refresh, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Target Proxy Connection Reset',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The proxy server\'s target proxy reset the connection. This may be due to a network issue or proxy crash.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Proxy target proxy connection reset - restarting target proxy server...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Target Proxy Server'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy target proxy connection reset - checking logs...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.archive),
          label: const Text('View Target Proxy Server Logs'),
        ),
      ],
    );
  }
}
