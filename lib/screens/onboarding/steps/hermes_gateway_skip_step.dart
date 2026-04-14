library screens.onboarding.steps.hermes_gateway_skip_step;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../services/hermes_manager/hermes_manager.dart';

final Logger _log = Logger('HermesGatewaySkipStep');

class HermesGatewaySkipStep extends StatefulWidget {
  @override
  State<HermesGatewaySkipStep> createState() => _HermesGatewaySkipStepState();
}

class _HermesGatewaySkipStepState extends State<HermesGatewaySkipStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Skip Hermes Gateway Setup',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        const Text(
          'You can skip setting up Hermes for now and configure it later in settings.',
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            _log.info('Skipped Hermes gateway setup');
            // Skip to next step
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          child: const Text('Skip This Step'),
        ),
      ],
    );
  }
}