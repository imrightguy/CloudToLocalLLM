import 'package:cloudtolocalllm/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/onboarding/setup_wizard_service.dart';

/// Connection Test Step
/// Tests connectivity to the selected provider
class ConnectionTestStep extends StatefulWidget {
  const ConnectionTestStep({super.key});

  @override
  State<ConnectionTestStep> createState() => _ConnectionTestStepState();
}

class _ConnectionTestStepState extends State<ConnectionTestStep> {
  @override
  void initState() {
    super.initState();
    // Auto-start test when step is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wizard = context.read<SetupWizardService>();
      if (wizard.state.selectedProvider?.url != null) {
        _runTest(wizard);
      }
    });
  }

  Future<void> _runTest(SetupWizardService wizard) async {
    final url = wizard.state.hermesUrl ??
        wizard.state.customUrl ??
        wizard.state.selectedProvider?.url ??
        AppConfig.gatewayUrl;
    await wizard.testConnection(url);
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
              ] else if (wizard.state.errorMessage != null) ...[
                _buildError(context, wizard),
              ] else ...[
                _buildSuccess(context, wizard),
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
          'Testing connection...',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        _buildTestItem('DNS resolution', true),
        _buildTestItem('TCP connection', null),
        _buildTestItem('Runtime API', null),
      ],
    );
  }

  Widget _buildError(BuildContext context, SetupWizardService wizard) {
    final provider = wizard.state.selectedProvider;
    final url = provider?.url ?? wizard.state.customUrl ?? 'Unknown';

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.error_outline,
            size: 40,
            color: Colors.red.shade700,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Connection Failed',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.red.shade700,
              ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      wizard.state.errorMessage ?? 'Unknown error',
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Retry button
        FilledButton.icon(
          onPressed: () => _runTest(wizard),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry Test'),
        ),
        const SizedBox(height: 16),

        // Go back option
        TextButton.icon(
          onPressed: () => wizard.previousStep(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Check connection settings'),
        ),

        const SizedBox(height: 24),
        Text(
          'Connecting to: $url',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: Colors.grey.shade600,
              ),
        ),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context, SetupWizardService wizard) {
    final provider = wizard.state.selectedProvider;

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
          'Connection Successful!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.green.shade700,
              ),
        ),
        const SizedBox(height: 16),

        // Provider info card
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
            children: [
              _buildTestItem('DNS resolution', true),
              _buildTestItem('TCP connection', true),
              _buildTestItem('Runtime API', true),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (provider != null) ...[
          Text(
            'Connected to:',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Text(
            provider.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            provider.url,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: Colors.grey.shade600,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildTestItem(String label, bool? success) {
    final color = success == null
        ? Colors.grey
        : success == true
            ? Colors.green
            : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            success == null
                ? Icons.radio_button_unchecked
                : success == true
                    ? Icons.check_circle
                    : Icons.cancel,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}
