library screens.onboarding.steps.hermes_gateway_logs_step;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../services/hermes_manager/hermes_manager.dart';

final Logger _log = Logger('HermesGatewayLogsStep');

class HermesGatewayLogsStep extends StatefulWidget {
  @override
  State<HermesGatewayLogsStep> createState() => _HermesGatewayLogsStepState();
}

class _HermesGatewayLogsStepState extends State<HermesGatewayLogsStep> {
  String _logs = 'Hermes gateway logs will appear here...';

  @override
  Widget build(BuildContext context) {
    return Column(
      children:
          ListTile.divideTiles(context: context, tiles: [
        Text(
          'Gateway Logs',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Text(_logs),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            // Refresh logs
            setState(() => _logs = 'Refreshing logs...');
          },
          child: const Text('Refresh Logs'),
        ),
      ]).toList(),
    );
  }
}