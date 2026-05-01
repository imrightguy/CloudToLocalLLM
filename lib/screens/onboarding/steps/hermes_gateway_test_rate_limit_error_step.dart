import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestRateLimitErrorStep');

class HermesGatewayTestRateLimitErrorStep extends StatefulWidget {
  const HermesGatewayTestRateLimitErrorStep({super.key});

  @override
  State<HermesGatewayTestRateLimitErrorStep> createState() =>
      _HermesGatewayTestRateLimitErrorState();
}

class _HermesGatewayTestRateLimitErrorState
    extends State<HermesGatewayTestRateLimitErrorStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.thumb_down, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Rate Limit Exceeded',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway has exceeded its rate limit. Please wait before trying again or increase your rate limit.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Rate limit - waiting and retrying...');
          },
          icon: const Icon(Icons.timer),
          label: const Text('Wait and Retry'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Rate limit - checking limits...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.tune),
          label: const Text('Check Rate Limits'),
        ),
      ],
    );
  }
}
