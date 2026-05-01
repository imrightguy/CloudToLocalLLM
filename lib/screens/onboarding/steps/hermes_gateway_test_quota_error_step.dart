import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestQuotaErrorStep');

class HermesGatewayTestQuotaErrorStep extends StatefulWidget {
  const HermesGatewayTestQuotaErrorStep({super.key});

  @override
  State<HermesGatewayTestQuotaErrorStep> createState() =>
      _HermesGatewayTestQuotaErrorState();
}

class _HermesGatewayTestQuotaErrorState
    extends State<HermesGatewayTestQuotaErrorStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.storage, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Quota Exceeded',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway has exceeded its usage quota. Please upgrade your plan or wait for the next billing cycle.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Quota error - contacting support...');
          },
          icon: const Icon(Icons.support),
          label: const Text('Contact Support'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Quota error - checking usage...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.bar_chart),
          label: const Text('View Usage Statistics'),
        ),
      ],
    );
  }
}
