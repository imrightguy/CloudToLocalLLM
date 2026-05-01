import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesUrlStep');

class HermesUrlStep extends StatefulWidget {
  final String? hermesUrl;
  final String? hermesApiKey;

  const HermesUrlStep({
    super.key,
    this.hermesUrl,
    this.hermesApiKey,
  });

  @override
  State<HermesUrlStep> createState() => _HermesUrlStepState();
}

class _HermesUrlStepState extends State<HermesUrlStep> {
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
      children: [
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'Hermes Gateway URL',
            hintText: 'ws://localhost:1337',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _apiKeyController,
          decoration: const InputDecoration(
            labelText: 'Hermes API Key (optional)',
            hintText: 'Enter API key if required',
          ),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _urlController.text.isNotEmpty
                    ? () {
                        // Save Hermes configuration
                        final hermesConfig = {
                          'hermesUrl': _urlController.text,
                          'hermesApiKey': _apiKeyController.text,
                        };
                        _log.info('Hermes config: $hermesConfig');
                        // Store in preferences
                        // Move to next step
                      }
                    : null,
                child: const Text('Save and Continue'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
