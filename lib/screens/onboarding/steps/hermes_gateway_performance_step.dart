library screens.onboarding.steps.hermes_gateway_performance_step;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../services/hermes_manager/hermes_manager.dart';

final Logger _log = Logger('HermesGatewayPerformanceStep');

class HermesGatewayPerformanceStep extends StatefulWidget {
  @override
  State<HermesGatewayPerformanceStep> createState() =>
      _HermesGatewayPerformanceStepState();
}

class _HermesGatewayPerformanceStepState extends State<HermesGatewayPerformanceStep> {
  int _maxConcurrentRequests = 10;
  int _requestTimeout = 30;
  int _maxTokens = 4096;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Hermes Gateway Performance',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        TextField(
          initialValue: _maxConcurrentRequests.toString(),
          decoration: const InputDecoration(
            labelText: 'Max Concurrent Requests',
            hintText: '10 (default)',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(() =>
                _maxConcurrentRequests = int.tryParse(value) ?? _maxConcurrentRequests);
          },
        ),
        TextField(
          initialValue: _requestTimeout.toString(),
          decoration: const InputDecoration(
            labelText: 'Request Timeout (seconds)',
            hintText: '30 (default)',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(() =>
                _requestTimeout = int.tryParse(value) ?? _requestTimeout);
          },
        ),
        TextField(
          initialValue: _maxTokens.toString(),
          decoration: const InputDecoration(
            labelText: 'Max Tokens per Request',
            hintText: '4096 (default)',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(() =>
                _maxTokens = int.tryParse(value) ?? _maxTokens);
          },
        ),
      ]).toList(),
    );
  }
}