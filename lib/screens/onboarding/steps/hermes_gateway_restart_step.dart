import 'package:flutter/material.dart';

class HermesGatewayRestartStep extends StatefulWidget {
  const HermesGatewayRestartStep({super.key});

  @override
  State<HermesGatewayRestartStep> createState() =>
      _HermesGatewayRestartStepState();
}

class _HermesGatewayRestartStepState extends State<HermesGatewayRestartStep> {
  bool _restarting = false;

  Future<void> _restartGateway() async {
    setState(() => _restarting = true);

    // Restart the Hermes gateway
    // This would stop and then start the gateway
    await Future.delayed(const Duration(seconds: 3)); // Simulate restart

    setState(() => _restarting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_restarting) const CircularProgressIndicator(),
        if (!_restarting)
          ElevatedButton(
            onPressed: _restartGateway,
            child: const Text('Restart Hermes Gateway'),
          ),
      ],
    );
  }
}
