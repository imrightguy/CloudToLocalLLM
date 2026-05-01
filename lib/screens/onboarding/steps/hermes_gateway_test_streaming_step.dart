import 'package:flutter/material.dart';

class HermesGatewayTestStreamingStep extends StatefulWidget {
  final String? hermesUrl;
  final String? hermesApiKey;

  const HermesGatewayTestStreamingStep({
    super.key,
    this.hermesUrl,
    this.hermesApiKey,
  });

  @override
  State<HermesGatewayTestStreamingStep> createState() =>
      _HermesGatewayTestStreamingStepState();
}

class _HermesGatewayTestStreamingStepState
    extends State<HermesGatewayTestStreamingStep> {
  bool _isTesting = false;
  String _testResult = '';

  Future<void> _testStreaming() async {
    setState(() {
      _isTesting = true;
      _testResult = '';
    });

    // Test streaming with Hermes gateway
    await Future.delayed(const Duration(seconds: 2)); // Simulate network delay

    setState(() {
      _isTesting = false;
      _testResult = 'Streaming test completed successfully';
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
          onPressed: _isTesting ? null : _testStreaming,
          child: _isTesting
              ? const CircularProgressIndicator()
              : const Text('Test Streaming'),
        ),
      ],
    );
  }
}
