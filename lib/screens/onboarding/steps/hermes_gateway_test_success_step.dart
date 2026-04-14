library screens.onboarding.steps.hermes_gateway_test_success_step;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../services/hermes_manager/hermes_manager.dart';

final Logger _log = Logger('HermesGatewayTestSuccessStep');

class HermesGatewayTestSuccessStep extends StatefulWidget {
  @override
  State<HermesGatewayTestSuccessStep> createState() =>
      _HermesGatewayTestSuccessStepState();
}

class _HermesGatewayTestSuccessStepState
    extends State<HermesGatewayTestSuccessStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Tests Passed!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway is working correctly.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Tests passed - moving to home screen');
          },
          icon: const Icon(Icons.done_all),
          label: const Text('Continue to Home Screen'),
        ),
      ],
    );
  }
}