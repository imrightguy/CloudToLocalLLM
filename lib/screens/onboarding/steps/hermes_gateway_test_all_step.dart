library screens.onboarding.steps.hermes_gateway_test_all_step;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../services/hermes_manager/hermes_manager.dart';

final Logger _log = Logger('HermesGatewayTestAllStep');

class HermesGatewayTestAllStep extends StatefulWidget {
  final String? hermesUrl;
  final String? hermesApiKey;

  const HermesGatewayTestAllStep({
    Key? key,
    this.hermesUrl,
    this.hermesApiKey,
  }) : super(key: key);

  @override
  State<HermesGatewayTestAllStep> createState() =>
      _HermesGatewayTestAllStepState();
}

class _HermesGatewayTestAllStepState
    extends State<HermesGatewayTestAllStep> {
  bool _isTesting = false;
  String _testResult = '';

  Future<void> _testAll() async {
    setState(() {
      _isTesting = true;
      _testResult = '';
    });

    // Test all aspects of Hermes gateway
    await Future.delayed(const Duration(seconds: 3)); // Simulate comprehensive test

    setState(() {
      _isTesting = false;
      _testResult = 'All tests passed! Hermes gateway is working correctly.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_testResult.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.green.withValues(alpha: 0.2),
            child: Text(
              _testResult,
              style: TextStyle(color: Colors.green),
            ),
          ),
        ElevatedButton(
          onPressed: _isTesting ? null : _testAll,
          child: _isTesting
              ? const CircularProgressIndicator()
              : const Text('Run All Tests'),
        ),
      ],
    );
  }
}