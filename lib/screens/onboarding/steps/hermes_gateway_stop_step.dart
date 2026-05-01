import 'package:flutter/material.dart';

class HermesGatewayStopStep extends StatefulWidget {
  const HermesGatewayStopStep({super.key});

  @override
  State<HermesGatewayStopStep> createState() => _HermesGatewayStopStepState();
}

class _HermesGatewayStopStepState extends State<HermesGatewayStopStep> {
  bool _stopping = false;

  Future<void> _stopGateway() async {
    setState(() => _stopping = true);

    // Stop the Hermes gateway
    // This would run the hermes-agent gateway stop command
    await Future.delayed(const Duration(seconds: 2)); // Simulate shutdown

    setState(() => _stopping = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_stopping) const CircularProgressIndicator(),
        if (!_stopping)
          ElevatedButton(
            onPressed: _stopGateway,
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Stop Hermes Gateway'),
          ),
      ],
    );
  }
}
