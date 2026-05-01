import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyConnectionResetByTargetProxyStep');

class HermesGatewayTestGatewayProxyConnectionResetByTargetProxyStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyConnectionResetByTargetProxyStep(
      {super.key});

  @override
  State<HermesGatewayTestGatewayProxyConnectionResetByTargetProxyStep>
      createState() =>
          _HermesGatewayTestGatewayProxyConnectionResetByTargetProxyState();
}

class _HermesGatewayTestGatewayProxyConnectionResetByTargetProxyState
    extends State<
        HermesGatewayTestGatewayProxyConnectionResetByTargetProxyStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.refresh, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Target Proxy Connection Reset',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The target proxy server reset the connection. This may be due to a network issue or proxy crash.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info(
                'Target proxy connection reset - restarting proxy server...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Proxy Server'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Target proxy connection reset - checking logs...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.archive),
          label: const Text('View Proxy Server Logs'),
        ),
      ],
    );
  }
}
