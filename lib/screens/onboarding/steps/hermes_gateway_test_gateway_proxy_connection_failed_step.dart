library screens.onboarding.steps.hermes_gateway_test_gateway_proxy_connection_failed_step;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../services/hermes_manager/hermes_manager.dart';

final Logger _log = Logger('HermesGatewayTestGatewayProxyConnectionFailedStep');

class HermesGatewayTestGatewayProxyConnectionFailedStep extends StatefulWidget {
  @override
  State<HermesGatewayTestGatewayProxyConnectionFailedStep> createState() =>
      _HermesGatewayTestGatewayProxyConnectionFailedState();
}

class _HermesGatewayTestGatewayProxyConnectionFailedState
    extends State<HermesGatewayTestGatewayProxyConnectionFailedStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Connection Failed',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Failed to establish a connection to Hermes gateway through the proxy server. Please check your proxy settings.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy connection failed - checking proxy settings...');
          },
          icon: const Icon(Icons.settings),
          label: const Text('Check Proxy Settings'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy connection failed - checking network...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.network_check),
          label: const Text('Check Network Connection'),
        ),
      ],
    );
  }
}