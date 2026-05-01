import 'package:flutter/material.dart';

class HermesGatewayLoggingStep extends StatefulWidget {
  const HermesGatewayLoggingStep({super.key});

  @override
  State<HermesGatewayLoggingStep> createState() =>
      _HermesGatewayLoggingStepState();
}

class _HermesGatewayLoggingStepState extends State<HermesGatewayLoggingStep> {
  bool _enableAccessLog = true;
  bool _enableErrorLog = true;
  bool _enableDebugLog = false;
  String _logLevel = 'info';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Hermes Gateway Logging',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SwitchListTile(
          title: const Text('Access Log'),
          value: _enableAccessLog,
          onChanged: (value) {
            setState(() => _enableAccessLog = value);
          },
          subtitle: const Text('Log all incoming requests'),
        ),
        SwitchListTile(
          title: const Text('Error Log'),
          value: _enableErrorLog,
          onChanged: (value) {
            setState(() => _enableErrorLog = value);
          },
          subtitle: const Text('Log all errors and warnings'),
        ),
        SwitchListTile(
          title: const Text('Debug Log'),
          value: _enableDebugLog,
          onChanged: (value) {
            setState(() => _enableDebugLog = value);
          },
          subtitle: const Text('Verbose logging for debugging'),
        ),
        DropdownButton<String>(
          value: _logLevel,
          items: [
            DropdownMenuItem(
              value: 'error',
              child: const Text('Error Level'),
            ),
            DropdownMenuItem(
              value: 'warn',
              child: const Text('Warning Level'),
            ),
            DropdownMenuItem(
              value: 'info',
              child: const Text('Info Level'),
            ),
            DropdownMenuItem(
              value: 'debug',
              child: const Text('Debug Level'),
            ),
          ],
          onChanged: (String? newValue) {
            setState(() => _logLevel = newValue!);
          },
          hint: const Text('Log Level'),
        ),
      ]).toList(),
    );
  }
}
