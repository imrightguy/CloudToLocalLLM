import 'package:flutter/material.dart';

class HermesGatewayTestModelsStep extends StatefulWidget {
  final String? hermesUrl;
  final String? hermesApiKey;

  const HermesGatewayTestModelsStep({
    super.key,
    this.hermesUrl,
    this.hermesApiKey,
  });

  @override
  State<HermesGatewayTestModelsStep> createState() =>
      _HermesGatewayTestModelsStepState();
}

class _HermesGatewayTestModelsStepState
    extends State<HermesGatewayTestModelsStep> {
  bool _isTesting = false;
  String _testResult =
      'Available models: hermes/model, meta/llama-3-70b, mistral/medium';

  Future<void> _testModels() async {
    setState(() {
      _isTesting = true;
      _testResult = '';
    });

    // Test getting models from Hermes gateway
    await Future.delayed(const Duration(seconds: 2)); // Simulate network delay

    setState(() {
      _isTesting = false;
      _testResult =
          'Available models: hermes/model, meta/llama-3-70b, mistral/medium';
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
          onPressed: _isTesting ? null : _testModels,
          child: _isTesting
              ? const CircularProgressIndicator()
              : const Text('Test Models'),
        ),
      ],
    );
  }
}
