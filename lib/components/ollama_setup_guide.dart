import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/ollama_connection_error.dart';

/// Setup guide dialog for Ollama installation and configuration
class OllamaSetupGuide extends StatelessWidget {
  final OllamaConnectionError? connectionError;

  const OllamaSetupGuide({super.key, this.connectionError});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 500,
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  size: 32,
                  color: AppTheme.primaryColor,
                ),
                SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ollama Setup Guide',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (connectionError != null)
                        Text(
                          '${connectionError!.getErrorIcon()} ${connectionError!.userFriendlyMessage}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.orange),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            SizedBox(height: AppTheme.spacingL),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (connectionError != null) ...[
                      _buildErrorSpecificGuidance(context),
                      SizedBox(height: AppTheme.spacingL),
                      const Divider(),
                      SizedBox(height: AppTheme.spacingL),
                    ],
                    _buildGeneralSetupInstructions(context),
                  ],
                ),
              ),
            ),

            // Action buttons
            SizedBox(height: AppTheme.spacingL),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _launchOllamaWebsite,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Visit Ollama.ai'),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    SizedBox(width: AppTheme.spacingM),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Trigger connection test
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Test Connection'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSpecificGuidance(BuildContext context) {
    if (connectionError == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                connectionError!.getErrorIcon(),
                style: const TextStyle(fontSize: 20),
              ),
              SizedBox(width: AppTheme.spacingS),
              Text(
                'Specific Issue: ${connectionError!.userFriendlyMessage}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),
          Text(
            connectionError!.actionableGuidance,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SizedBox(height: AppTheme.spacingM),
          Text(
            connectionError!.getSetupInstructions(),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSetupInstructions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'General Setup Instructions',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: AppTheme.spacingM),
        _buildSetupStep(
          context,
          '1',
          'Install Ollama',
          'Download and install Ollama from the official website',
          'Visit https://ollama.ai and download the installer for your operating system.',
          Icons.download,
        ),
        _buildSetupStep(
          context,
          '2',
          'Start Ollama Service',
          'Ensure Ollama is running on your system',
          'Linux/macOS: Run "ollama serve" in terminal\nWindows: Ollama should start automatically after installation',
          Icons.play_arrow,
        ),
        _buildSetupStep(
          context,
          '3',
          'Download a Model',
          'Download at least one language model',
          'Run "ollama pull llama2" or "ollama pull mistral" to download a model',
          Icons.cloud_download,
        ),
        _buildSetupStep(
          context,
          '4',
          'Test Installation',
          'Verify Ollama is working correctly',
          'Run "ollama list" to see installed models\nTry "ollama run llama2" to test a model',
          Icons.check_circle,
        ),
        _buildSetupStep(
          context,
          '5',
          'Connect CloudToLocalLLM',
          'Return to CloudToLocalLLM and test the connection',
          'Use the "Test Connection" button in the settings to verify connectivity',
          Icons.link,
        ),
      ],
    );
  }

  Widget _buildSetupStep(
    BuildContext context,
    String stepNumber,
    String title,
    String subtitle,
    String description,
    IconData icon,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacingM),
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: AppTheme.primaryColor),
                    SizedBox(width: AppTheme.spacingS),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacingS),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textColorLight,
                      ),
                ),
                SizedBox(height: AppTheme.spacingS),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchOllamaWebsite() async {
    final uri = Uri.parse('https://ollama.ai');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

/// Quick setup tips widget for inline display
class OllamaQuickTips extends StatelessWidget {
  final OllamaConnectionError? connectionError;

  const OllamaQuickTips({super.key, this.connectionError});

  @override
  Widget build(BuildContext context) {
    if (connectionError == null) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: AppTheme.spacingM),
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
              SizedBox(width: AppTheme.spacingS),
              Text(
                'Quick Fix',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingS),
          Text(
            connectionError!.actionableGuidance,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
