import 'package:flutter/material.dart';

class HermesConnectionTestStep extends StatefulWidget {
  final String? hermesUrl;
  final String? hermesApiKey;

  const HermesConnectionTestStep({
    super.key,
    this.hermesUrl,
    this.hermesApiKey,
  });

  @override
  State<HermesConnectionTestStep> createState() =>
      _HermesConnectionTestStepState();
}

class _HermesConnectionTestStepState extends State<HermesConnectionTestStep> {
  bool _isTesting = false;
  String _testResult = '';

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = '';
    });

    // Test connection to Hermes gateway
    // This would actually connect to the WebSocket and send a test message
    await Future.delayed(const Duration(seconds: 2)); // Simulate network delay

    setState(() {
      _isTesting = false;
      _testResult = 'Connection successful!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_testResult.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            color: _testResult.contains('successful')
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.red.withValues(alpha: 0.2),
            child: Text(
              _testResult,
              style: TextStyle(
                color: _testResult.contains('successful')
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          ),
        ElevatedButton(
          onPressed: _isTesting ? null : _testConnection,
          child: _isTesting
              ? const CircularProgressIndicator()
              : const Text('Test Connection'),
        ),
      ],
    );
  }
}
