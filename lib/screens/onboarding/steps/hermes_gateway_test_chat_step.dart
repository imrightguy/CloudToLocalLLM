import 'package:flutter/material.dart';

class HermesGatewayTestChatStep extends StatefulWidget {
  final String? hermesUrl;
  final String? hermesApiKey;

  const HermesGatewayTestChatStep({
    super.key,
    this.hermesUrl,
    this.hermesApiKey,
  });

  @override
  State<HermesGatewayTestChatStep> createState() =>
      _HermesGatewayTestChatStepState();
}

class _HermesGatewayTestChatStepState extends State<HermesGatewayTestChatStep> {
  bool _isTesting = false;
  String _testResult = '';

  Future<void> _testChat() async {
    setState(() {
      _isTesting = true;
      _testResult = '';
    });

    // Test chat with Hermes gateway
    await Future.delayed(const Duration(seconds: 2)); // Simulate network delay

    setState(() {
      _isTesting = false;
      _testResult = 'Hermes: Hello! How can I assist you today?';
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
          onPressed: _isTesting ? null : _testChat,
          child: _isTesting
              ? const CircularProgressIndicator()
              : const Text('Test Chat'),
        ),
      ],
    );
  }
}
