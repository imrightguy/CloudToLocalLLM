import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestAuthErrorStep');

class HermesGatewayTestAuthErrorStep extends StatefulWidget {
  const HermesGatewayTestAuthErrorStep({super.key});

  @override
  State<HermesGatewayTestAuthErrorStep> createState() =>
      _HermesGatewayTestAuthErrorState();
}

class _HermesGatewayTestAuthErrorState
    extends State<HermesGatewayTestAuthErrorStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.lock, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Authentication Error',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Invalid API key or authentication failed. Please check your API key and try again.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Auth error - retrying with new key...');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry with New Key'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Auth error - going to settings...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.settings),
          label: const Text('Edit API Key'),
        ),
      ],
    );
  }
}
