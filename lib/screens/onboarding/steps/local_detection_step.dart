import 'package:cloudtolocalllm/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/onboarding/setup_wizard_service.dart';
import 'package:cloudtolocalllm/models/provider_configuration.dart';

/// Local runtime detection step.
/// Scans for compatible agent runtimes, not raw local model providers.
class LocalDetectionStep extends StatefulWidget {
  const LocalDetectionStep({super.key});

  @override
  State<LocalDetectionStep> createState() => _LocalDetectionStepState();
}

class _LocalDetectionStepState extends State<LocalDetectionStep> {
  @override
  void initState() {
    super.initState();
    // Auto-start scanning when this step is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SetupWizardService>().scanForProviders();
    });
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
              if (wizard.state.isLoading) ...[
                _buildLoading(context),
              ] else if (wizard.state.discoveredProviders.isEmpty) ...[
                _buildNotFound(context, wizard),
              ] else ...[
                _buildFound(context, wizard),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(),
        ),
        const SizedBox(height: 24),
        Text(
          'Looking for agent runtimes...',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Scanning ${AppConfig.defaultHermesUrl} and ${AppConfig.gatewayUrl}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      ],
    );
  }

  Widget _buildNotFound(BuildContext context, SetupWizardService wizard) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.search_off,
            size: 40,
            color: Colors.orange.shade700,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Agent Runtime Not Found',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          'We couldn\'t find Hermes or OpenClaw running on this computer.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Download guidance
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
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'To get started:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStep('1. Start Hermes Agent or OpenClaw Gateway'),
              _buildStep('2. Verify the runtime is reachable'),
              _buildStep('3. Click "Retry" below'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => wizard.scanForProviders(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Scan'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Alternative: Go back
        TextButton.icon(
          onPressed: () => wizard.previousStep(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Choose a different connection method'),
        ),
      ],
    );
  }

  Widget _buildFound(BuildContext context, SetupWizardService wizard) {
    final provider = wizard.state.selectedProvider!;

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle,
            size: 40,
            color: Colors.green.shade700,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Agent Runtime Found!',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        _buildProviderCard(context, provider),
        const SizedBox(height: 24),

        // Success message
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.check, color: Colors.green.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ready to proceed to connection test',
                  style: TextStyle(color: Colors.green.shade900),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProviderCard(BuildContext context, ProviderInfo provider) {
    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Icon(
                _getProviderIcon(provider.type),
                size: 28,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.url,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace',
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: provider.isAvailable
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            provider.isAvailable
                                ? 'Available'
                                : 'Check Connection',
                            style: TextStyle(
                              color: provider.isAvailable
                                  ? Colors.green.shade900
                                  : Colors.orange.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (provider.version != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            'v${provider.version}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.blue.shade900)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getProviderIcon(ProviderType type) {
    switch (type) {
      case ProviderType.openclaw:
        return Icons.hub;
      case ProviderType.hermes:
        return Icons.smart_toy;
      case ProviderType.lmStudio:
        return Icons.science;
      case ProviderType.ollama:
        return Icons.terminal;
      case ProviderType.openAICompatible:
        return Icons.smart_toy;
      case ProviderType.custom:
        return Icons.extension;
    }
  }
}
