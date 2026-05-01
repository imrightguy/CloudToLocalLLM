import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayConfigStep');

class HermesGatewayConfigStep extends StatefulWidget {
  final String? hermesUrl;
  final String? hermesApiKey;

  const HermesGatewayConfigStep({
    super.key,
    this.hermesUrl,
    this.hermesApiKey,
  });

  @override
  State<HermesGatewayConfigStep> createState() =>
      _HermesGatewayConfigStepState();
}

class _HermesGatewayConfigStepState extends State<HermesGatewayConfigStep> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.hermesUrl ?? '';
    _apiKeyController.text = widget.hermesApiKey ?? '';
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Hermes Gateway Configuration',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'Gateway URL',
            hintText: 'ws://localhost:1337',
          ),
        ),
        TextField(
          controller: _apiKeyController,
          decoration: const InputDecoration(
            labelText: 'API Key (optional)',
            hintText: 'Enter API key if required',
          ),
          obscureText: true,
        ),
        ElevatedButton(
          onPressed: () {
            final config = {
              'hermesUrl': _urlController.text,
              'hermesApiKey': _apiKeyController.text,
            };
            _log.info('Hermes gateway config saved: $config');
            // Save configuration
          },
          child: const Text('Save Configuration'),
        ),
      ]).toList(),
    );
  }
}
