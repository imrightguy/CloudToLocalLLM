import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'package:cloudtolocalllm/config/app_config.dart';
import 'package:cloudtolocalllm/services/onboarding/setup_wizard_service.dart';

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
    _urlController.text = widget.hermesUrl ?? AppConfig.defaultHermesUrl;
    _apiKeyController.text = widget.hermesApiKey ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SetupWizardService>().setHermesUrl(_urlController.text);
      }
    });
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
          decoration: InputDecoration(
            labelText: 'Hermes Agent URL',
            hintText: AppConfig.defaultHermesUrl,
          ),
          onChanged: (value) {
            context.read<SetupWizardService>().setHermesUrl(value);
          },
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
                        context
                            .read<SetupWizardService>()
                            .setHermesUrl(_urlController.text);
                        final hermesConfig = {
                          'hermesUrl': _urlController.text,
                          'hermesApiKey': _apiKeyController.text,
                        };
                        _log.info('Hermes config: $hermesConfig');
                        context.read<SetupWizardService>().nextStep();
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
