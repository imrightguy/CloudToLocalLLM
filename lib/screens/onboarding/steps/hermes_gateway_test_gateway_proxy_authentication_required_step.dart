import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log =
    Logger('HermesGatewayTestGatewayProxyAuthenticationRequiredStep');

class HermesGatewayTestGatewayProxyAuthenticationRequiredStep
    extends StatefulWidget {
  const HermesGatewayTestGatewayProxyAuthenticationRequiredStep({super.key});

  @override
  State<HermesGatewayTestGatewayProxyAuthenticationRequiredStep>
      createState() =>
          _HermesGatewayTestGatewayProxyAuthenticationRequiredState();
}

class _HermesGatewayTestGatewayProxyAuthenticationRequiredState
    extends State<HermesGatewayTestGatewayProxyAuthenticationRequiredStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.lock, color: Colors.orange, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Authentication Required',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The proxy server requires authentication to connect to Hermes gateway. Please check your proxy credentials.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy auth required - checking credentials...');
          },
          icon: const Icon(Icons.key),
          label: const Text('Check Proxy Credentials'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy auth required - editing proxy settings...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.settings),
          label: const Text('Edit Proxy Settings'),
        ),
      ],
    );
  }
}
