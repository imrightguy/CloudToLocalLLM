

import 'package:flutter/material.dart';
class HermesGatewayStatusStep extends StatefulWidget {
  final bool hermesEnabled;

  const HermesGatewayStatusStep({Key? key, this.hermesEnabled = false})
      : super(key: key);

  @override
  State<HermesGatewayStatusStep> createState() =>
      _HermesGatewayStatusStepState();
}

class _HermesGatewayStatusStepState extends State<HermesGatewayStatusStep> {
  bool _gatewayRunning = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(
              _gatewayRunning ? Icons.check_circle : Icons.warning,
              color: _gatewayRunning ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _gatewayRunning
                    ? 'Hermes gateway is running'
                    : 'Hermes gateway is not running',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: _gatewayRunning ? FontWeight.bold : FontWeight.normal,
                  color: _gatewayRunning ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!_gatewayRunning)
          Text(
            'Please start the Hermes gateway in settings or ensure it is installed.',
            style: TextStyle(color: Colors.red),
          ),
      ],
    );
  }
}