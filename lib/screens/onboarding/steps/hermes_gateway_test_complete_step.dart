library screens.onboarding.steps.hermes_gateway_test_complete_step;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../services/hermes_manager/hermes_manager.dart';

final Logger _log = Logger('HermesGatewayTestCompleteStep');

class HermesGatewayTestCompleteStep extends StatefulWidget {
  @override
  State<HermesGatewayTestCompleteStep> createState() =>
      _HermesGatewayTestCompleteStepState();
}

class _HermesGatewayTestCompleteStepState
    extends State<HermesGatewayTestCompleteStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Testing Complete!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway has been successfully tested and is ready for use.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Testing complete - moving to home screen');
          },
          icon: const Icon(Icons.done_all),
          label: const Text('Continue to Home Screen'),
        ),
      ],
    );
  }
}