library screens.onboarding.steps.hermes_gateway_test_gateway_not_found_step;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../services/hermes_manager/hermes_manager.dart';

final Logger _log = Logger('HermesGatewayTestGatewayNotFoundStep');

class HermesGatewayTestGatewayNotFoundStep extends StatefulWidget {
  @override
  State<HermesGatewayTestGatewayNotFoundStep> createState() =>
      _HermesGatewayTestGatewayNotFoundState();
}

class _HermesGatewayTestGatewayNotFoundState
    extends State<HermesGatewayTestGatewayNotFoundStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.router, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Not Found',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway is not installed or not running on the specified address.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway not found - checking installation...');
          },
          icon: const Icon(Icons.package),
          label: const Text('Check Installation'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway not found - installing...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.download),
          label: const Text('Install Hermes Gateway'),
        ),
      ],
    );
  }
}