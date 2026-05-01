import 'package:flutter/material.dart';

class HermesGatewayUpdateStep extends StatefulWidget {
  const HermesGatewayUpdateStep({super.key});

  @override
  State<HermesGatewayUpdateStep> createState() =>
      _HermesGatewayUpdateStepState();
}

class _HermesGatewayUpdateStepState extends State<HermesGatewayUpdateStep> {
  bool _autoUpdate = true;
  bool _notifyUpdates = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Hermes Gateway Updates',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SwitchListTile(
          title: const Text('Enable Automatic Updates'),
          value: _autoUpdate,
          onChanged: (value) {
            setState(() => _autoUpdate = value);
          },
          subtitle: const Text('Automatically update to latest version'),
        ),
        SwitchListTile(
          title: const Text('Notify About Updates'),
          value: _notifyUpdates,
          onChanged: (value) {
            setState(() => _notifyUpdates = value);
          },
          subtitle: const Text('Receive notifications for new versions'),
        ),
      ]).toList(),
    );
  }
}
