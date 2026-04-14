library screens.onboarding.steps.hermes_gateway_test_gateway_proxy_connection_lost_step;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../services/hermes_manager/hermes_manager.dart';

final Logger _log = Logger('HermesGatewayTestGatewayProxyConnectionLostStep');

class HermesGatewayTestGatewayProxyConnectionLostStep extends StatefulWidget {
  @override
  State<HermesGatewayTestGatewayProxyConnectionLostStep> createState() =>
      _HermesGatewayTestGatewayProxyConnectionLostState();
}

class _HermesGatewayTestGatewayProxyConnectionLostState
    extends State<HermesGatewayTestGatewayProxyConnectionLostStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cloud_off, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Proxy Connection Lost',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The connection through the proxy server to Hermes gateway was lost. Please check your network connection and proxy server.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy connection lost - checking network...');
          },
          icon: const Icon(Icons.wifi),
          label: const Text('Check Network Connection'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Proxy connection lost - restarting proxy...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Proxy Server'),
        ),
      ],
    );
  }
}