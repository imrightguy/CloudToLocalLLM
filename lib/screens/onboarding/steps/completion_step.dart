import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/onboarding/setup_wizard_service.dart';
import 'package:cloudtolocalllm/models/provider_configuration.dart';

/// Completion Step
/// Shows success message after setup is complete
class CompletionStep extends StatefulWidget {
  const CompletionStep({super.key});

  @override
  State<CompletionStep> createState() => _CompletionStepState();
}

class _CompletionStepState extends State<CompletionStep> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SetupWizardService>(
      builder: (context, wizard, child) {
        final provider = wizard.state.selectedProvider;

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success animation
              if (!wizard.state.isLoading) ...[
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 60,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'You\'re All Set!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your agent runtime is configured and ready to use.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(height: 24),
                Text(
                  'Saving configuration...',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
              const SizedBox(height: 32),

              // Config summary
              if (!wizard.state.isLoading && provider != null)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configuration:',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 12),
                      _buildConfigRow('Runtime', provider.name),
                      _buildConfigRow(
                          'Type', _getProviderTypeLabel(provider.type)),
                      _buildConfigRow('URL', provider.url),
                      _buildConfigRow(
                        'Location',
                        provider.isLocal ? 'Local' : 'Remote',
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              // Next steps info
              if (!wizard.state.isLoading)
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
                          Icon(Icons.rocket_launch,
                              color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Ready to start chatting!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your setup is complete. You can start chatting now!',
                        style: TextStyle(color: Colors.blue.shade900),
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

  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String _getProviderTypeLabel(ProviderType type) {
    switch (type) {
      case ProviderType.openclaw:
        return 'OpenClaw Gateway';
      case ProviderType.hermes:
        return 'Hermes Agent';
      case ProviderType.lmStudio:
        return 'LM Studio';
      case ProviderType.ollama:
        return 'Ollama';
      case ProviderType.openAICompatible:
        return 'OpenAI Compatible';
      case ProviderType.custom:
        return 'Custom';
    }
  }
}
