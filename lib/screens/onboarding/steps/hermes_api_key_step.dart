import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesApiKeyStep');

class HermesApiKeyStep extends StatefulWidget {
  final String? hermesApiKey;

  const HermesApiKeyStep({super.key, this.hermesApiKey});

  @override
  State<HermesApiKeyStep> createState() => _HermesApiKeyStepState();
}

class _HermesApiKeyStepState extends State<HermesApiKeyStep> {
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = widget.hermesApiKey ?? '';
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _apiKeyController,
          decoration: const InputDecoration(
            labelText: 'Hermes API Key',
            hintText: 'Enter your Hermes API key',
          ),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _apiKeyController.text.isNotEmpty
                    ? () {
                        // Save API key
                        final apiKey = _apiKeyController.text;
                        _log.info(
                            'Hermes API key saved: ${apiKey.length} chars');
                        // Store in preferences
                        // Move to next step
                      }
                    : null,
                child: const Text('Save API Key'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
