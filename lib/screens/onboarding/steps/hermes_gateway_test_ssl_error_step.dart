library screens.onboarding.steps.hermes_gateway_test_ssl_error_step;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../services/hermes_manager/hermes_manager.dart';

final Logger _log = Logger('HermesGatewayTestSSLErrorStep');

class HermesGatewayTestSSLErrorStep extends StatefulWidget {
  @override
  State<HermesGatewayTestSSLErrorStep> createState() =>
      _HermesGatewayTestSSLErrorState();
}

class _HermesGatewayTestSSLErrorState
    extends State<HermesGatewayTestSSLErrorStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.security, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'SSL/TLS Error',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'There is an SSL/TLS error connecting to Hermes gateway. This may be due to a self-signed certificate or mismatched hostname.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('SSL error - continuing anyway...');
          },
          icon: const Icon(Icons.warning),
          label: const Text('Continue Anyway (insecure)'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('SSL error - checking certificate...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.certified),
          label: const Text('Check Certificate'),
        ),
      ],
    );
  }
}