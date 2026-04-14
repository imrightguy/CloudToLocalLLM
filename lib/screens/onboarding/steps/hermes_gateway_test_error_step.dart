library screens.onboarding.steps.hermes_gateway_test_error_step;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../services/hermes_manager/hermes_manager.dart';

final Logger _log = Logger('HermesGatewayTestErrorStep');

class HermesGatewayTestErrorStep extends StatefulWidget {
  final String? errorMessage;

  const HermesGatewayTestErrorStep({Key? key, this.errorMessage})
      : super(key: key);

  @override
  State<HermesGatewayTestErrorStep> createState() =>
      _HermesGatewayTestErrorStepState();
}

class _HermesGatewayTestErrorStepState
    extends State<HermesGatewayTestErrorStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Test Error',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (widget.errorMessage != null)
          Text(
            widget.errorMessage!,
            style: const TextStyle(color: Colors.red),
          ),
        const SizedBox(height: 16),
        const Text(
          'Please check your configuration and try again.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Retrying Hermes gateway test');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry Test'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Test error - skipping...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.skip_next),
          label: const Text('Skip Test'),
        ),
      ],
    );
  }
}