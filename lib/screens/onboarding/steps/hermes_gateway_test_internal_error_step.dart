import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestInternalErrorStep');

class HermesGatewayTestInternalErrorStep extends StatefulWidget {
  const HermesGatewayTestInternalErrorStep({super.key});

  @override
  State<HermesGatewayTestInternalErrorStep> createState() =>
      _HermesGatewayTestInternalErrorState();
}

class _HermesGatewayTestInternalErrorState
    extends State<HermesGatewayTestInternalErrorStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.bug_report, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Internal Server Error',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway encountered an internal error. Please try again later or contact support.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Internal error - restarting gateway...');
          },
          icon: const Icon(Icons.restart_alt),
          label: const Text('Restart Gateway'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Internal error - checking logs...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.archive),
          label: const Text('View Gateway Logs'),
        ),
      ],
    );
  }
}
