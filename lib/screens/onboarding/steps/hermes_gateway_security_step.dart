import 'package:flutter/material.dart';

class HermesGatewaySecurityStep extends StatefulWidget {
  const HermesGatewaySecurityStep({super.key});

  @override
  State<HermesGatewaySecurityStep> createState() =>
      _HermesGatewaySecurityStepState();
}

class _HermesGatewaySecurityStepState extends State<HermesGatewaySecurityStep> {
  bool _requireAuth = false;
  bool _encryptTraffic = true;
  bool _validateTokens = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Hermes Gateway Security',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SwitchListTile(
          title: const Text('Require API Key Authentication'),
          value: _requireAuth,
          onChanged: (value) {
            setState(() => _requireAuth = value);
          },
        ),
        if (_requireAuth)
          TextField(
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'Enter or generate API key',
            ),
            obscureText: true,
          ),
        SwitchListTile(
          title: const Text('Encrypt Traffic (TLS)'),
          value: _encryptTraffic,
          onChanged: (value) {
            setState(() => _encryptTraffic = value);
          },
        ),
        SwitchListTile(
          title: const Text('Validate JWT Tokens'),
          value: _validateTokens,
          onChanged: (value) {
            setState(() => _validateTokens = value);
          },
        ),
      ]).toList(),
    );
  }
}
