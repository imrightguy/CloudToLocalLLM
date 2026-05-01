import 'package:flutter/material.dart';

class HermesGatewayStartStep extends StatefulWidget {
  const HermesGatewayStartStep({super.key});

  @override
  State<HermesGatewayStartStep> createState() => _HermesGatewayStartStepState();
}

class _HermesGatewayStartStepState extends State<HermesGatewayStartStep> {
  bool _starting = false;

  Future<void> _startGateway() async {
    setState(() => _starting = true);

    // Start the Hermes gateway
    // This would run the hermes-agent gateway start command
    await Future.delayed(const Duration(seconds: 2)); // Simulate startup

    setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_starting) const CircularProgressIndicator(),
        if (!_starting)
          ElevatedButton(
            onPressed: _startGateway,
            child: const Text('Start Hermes Gateway'),
          ),
      ],
    );
  }
}
