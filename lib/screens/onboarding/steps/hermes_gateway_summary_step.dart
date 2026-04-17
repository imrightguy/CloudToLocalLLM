library screens.onboarding.steps.hermes_gateway_summary_step;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../services/hermes_manager/hermes_manager.dart';

final Logger _log = Logger('HermesGatewaySummaryStep');

class HermesGatewaySummaryStep extends StatefulWidget {
  final String? hermesUrl;
  final String? hermesApiKey;
  final bool hermesEnabled;

  const HermesGatewaySummaryStep({
    Key? key,
    this.hermesUrl,
    this.hermesApiKey,
    this.hermesEnabled = false,
  }) : super(key: key);

  @override
  State<HermesGatewaySummaryStep> createState() =>
      _HermesGatewaySummaryStepState();
}

class _HermesGatewaySummaryStepState extends State<HermesGatewaySummaryStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Hermes Gateway Configuration Summary',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (widget.hermesEnabled)
          Column(
            children: [
              Text('Gateway URL: ${widget.hermesUrl}'),
              Text('API Key: ${widget.hermesApiKey != null ? 'Set' : 'Not set'}'),
              const SizedBox(height: 16),
              const Text(
                'Hermes gateway is enabled and ready to use!',
                style: TextStyle(color: Colors.green),
              ),
            ],
          ),
        if (!widget.hermesEnabled)
          const Text(
            'Hermes gateway is disabled. Enable it in settings to use Hermes as a backend.',
            style: TextStyle(color: Colors.red),
          ),
      ]).toList(),
    );
  }
}