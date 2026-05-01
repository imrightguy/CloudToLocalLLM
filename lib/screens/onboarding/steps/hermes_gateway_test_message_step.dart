import 'package:flutter/material.dart';

class HermesGatewayTestMessageStep extends StatefulWidget {
  final String? hermesUrl;
  final String? hermesApiKey;

  const HermesGatewayTestMessageStep({
    super.key,
    this.hermesUrl,
    this.hermesApiKey,
  });

  @override
  State<HermesGatewayTestMessageStep> createState() =>
      _HermesGatewayTestMessageStepState();
}

class _HermesGatewayTestMessageStepState
    extends State<HermesGatewayTestMessageStep> {
  bool _isTesting = false;
  String _testResult = '';

  Future<void> _sendMessage() async {
    setState(() {
      _isTesting = true;
      _testResult = '';
    });

    // Send a test message to Hermes gateway
    // This would actually send a WebSocket message and get a response
    await Future.delayed(const Duration(seconds: 2)); // Simulate network delay

    setState(() {
      _isTesting = false;
      _testResult = 'Hello from Hermes!';
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
          onPressed: _isTesting ? null : _sendMessage,
          child: _isTesting
              ? const CircularProgressIndicator()
              : const Text('Send Test Message'),
        ),
      ],
    );
  }
}
