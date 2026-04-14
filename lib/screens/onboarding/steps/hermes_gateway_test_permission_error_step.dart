library screens/onboarding.steps.hermes_gateway_test_permission_error_step;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../services/hermes_manager/hermes_manager.dart';

final Logger _log = Logger('HermesGatewayTestPermissionErrorStep');

class HermesGatewayTestPermissionErrorStep extends StatefulWidget {
  @override
  State<HermesGatewayTestPermissionErrorStep> createState() =>
      _HermesGatewayTestPermissionErrorState();
}

class _HermesGatewayTestPermissionErrorState
    extends State<HermesGatewayTestPermissionErrorStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.block, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Permission Denied',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway denied access. Please check your permissions and API key.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Permission error - checking permissions...');
          },
          icon: const Icon(Icons.permissions),
          label: const Text('Check Permissions'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Permission error - editing API key...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.edit),
          label: const Text('Edit API Key'),
        ),
      ],
    );
  }
}