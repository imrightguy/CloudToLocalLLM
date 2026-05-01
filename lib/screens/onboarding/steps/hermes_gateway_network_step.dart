import 'package:flutter/material.dart';

class HermesGatewayNetworkStep extends StatefulWidget {
  const HermesGatewayNetworkStep({super.key});

  @override
  State<HermesGatewayNetworkStep> createState() =>
      _HermesGatewayNetworkStepState();
}

class _HermesGatewayNetworkStepState extends State<HermesGatewayNetworkStep> {
  int _port = 1337;
  String _host = '0.0.0.0';
  bool _allowRemote = false;
  late TextEditingController _hostController;
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: _host);
    _portController = TextEditingController(text: _port.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Hermes Gateway Network Settings',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        TextField(
          controller: _hostController,
          decoration: const InputDecoration(
            labelText: 'Host Interface',
            hintText: '0.0.0.0 (all interfaces) or 127.0.0.1 (localhost only)',
          ),
          onChanged: (value) {
            setState(() => _host = value);
          },
        ),
        TextField(
          controller: _portController,
          decoration: const InputDecoration(
            labelText: 'Port',
            hintText: '1337 (default)',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(() => _port = int.tryParse(value) ?? 1337);
          },
        ),
        SwitchListTile(
          title: const Text('Allow Remote Connections'),
          value: _allowRemote,
          onChanged: (value) {
            setState(() => _allowRemote = value);
          },
          subtitle: const Text(
              'Enable if you need to access Hermes from other devices on your network'),
        ),
      ]).toList(),
    );
  }
}
