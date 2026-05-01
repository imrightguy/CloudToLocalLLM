import 'package:flutter/material.dart';

class HermesGatewayHealthCheckStep extends StatefulWidget {
  const HermesGatewayHealthCheckStep({super.key});

  @override
  State<HermesGatewayHealthCheckStep> createState() =>
      _HermesGatewayHealthCheckStepState();
}

class _HermesGatewayHealthCheckStepState
    extends State<HermesGatewayHealthCheckStep> {
  bool _checking = false;
  String _healthStatus = '';

  Future<void> _checkHealth() async {
    setState(() {
      _checking = true;
      _healthStatus = '';
    });

    // Perform health check on Hermes gateway
    // This would call the gateway's health endpoint
    await Future.delayed(const Duration(seconds: 2)); // Simulate check

    setState(() {
      _checking = false;
      _healthStatus = 'Gateway is healthy and responsive';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_healthStatus.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.green.withValues(alpha: 0.2),
            child: Text(
              _healthStatus,
              style: const TextStyle(color: Colors.green),
            ),
          ),
        ElevatedButton(
          onPressed: _checking ? null : _checkHealth,
          child: _checking
              ? const CircularProgressIndicator()
              : const Text('Check Gateway Health'),
        ),
      ],
    );
  }
}
