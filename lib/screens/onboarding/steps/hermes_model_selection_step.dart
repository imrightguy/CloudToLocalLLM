import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesModelSelectionStep');

class HermesModelSelectionStep extends StatefulWidget {
  const HermesModelSelectionStep({super.key});

  @override
  State<HermesModelSelectionStep> createState() =>
      _HermesModelSelectionStepState();
}

class _HermesModelSelectionStepState extends State<HermesModelSelectionStep> {
  String? _selectedModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Select a model for Hermes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        DropdownButton<String>(
          value: _selectedModel,
          hint: const Text('Choose a model'),
          items: [
            DropdownMenuItem(
              value: 'hermes/model',
              child: const Text('Hermes Default'),
            ),
            DropdownMenuItem(
              value: 'meta/llama-3-70b',
              child: const Text('Llama 3 70B'),
            ),
            DropdownMenuItem(
              value: 'mistral/medium',
              child: const Text('Mistral Medium'),
            ),
            DropdownMenuItem(
              value: 'google/gemini-pro',
              child: const Text('Gemini Pro'),
            ),
          ],
          onChanged: (String? newValue) {
            setState(() => _selectedModel = newValue);
            _log.info('Hermes model selected: $newValue');
            // Save model selection
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _selectedModel != null
                    ? () {
                        // Save model selection and finish onboarding
                        _log.info('Hermes model configured: $_selectedModel');
                        // Complete onboarding
                      }
                    : null,
                child: const Text('Finish Setup'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
