import 'package:cloudtolocalllm/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/onboarding/setup_wizard_service.dart';

/// Hermes URL Step
/// User enters the URL for their Hermes Agent
class HermesUrlStep extends StatefulWidget {
  const HermesUrlStep({super.key});

  @override
  State<HermesUrlStep> createState() => _HermesUrlStepState();
}

class _HermesUrlStepState extends State<HermesUrlStep> {
  final TextEditingController _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wizard = context.read<SetupWizardService>();
      final currentUrl = wizard.state.hermesUrl;
      if (currentUrl != null && currentUrl.isNotEmpty) {
        _urlController.text = currentUrl;
      } else {
        _urlController.text = AppConfig.defaultHermesUrl;
        wizard.setHermesUrl(AppConfig.defaultHermesUrl);
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SetupWizardService>(
      builder: (context, wizard, child) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              Icon(
                Icons.smart_toy,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Enter Hermes Agent URL',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                'Enter the URL where your Hermes Agent is running',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // URL input form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'Hermes Agent URL',
                        hintText: 'http://127.0.0.1:8642',
                        prefixIcon: Icon(Icons.http),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a URL';
                        }
                        final url = Uri.tryParse(value);
                        if (url == null || !url.hasScheme) {
                          return 'Please enter a valid URL (e.g., http://127.0.0.1:8642)';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        wizard.setHermesUrl(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Default endpoint:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppConfig.defaultHermesUrl,
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
