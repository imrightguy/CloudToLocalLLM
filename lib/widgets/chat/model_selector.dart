import 'package:flutter/material.dart';

/// Reusable widget for selecting LLM models from a dropdown.
class ModelSelector extends StatelessWidget {
  /// Currently selected model (format: provider-name/model-id)
  final String? selectedModel;

  /// List of available models to select from
  /// Format: "provider-name/model-id" (e.g., "zhipu/glm-4-plus")
  final List<String> availableModels;

  /// Callback when model selection changes
  final Function(String?) onModelChanged;

  const ModelSelector({
    super.key,
    required this.selectedModel,
    required this.availableModels,
    required this.onModelChanged,
  });

  /// Get display name for a model
  String _getModelDisplayName(String modelId) {
    final parts = modelId.split('/');
    if (parts.length != 2) return modelId;

    final provider = parts[0];
    final model = parts[1];

    final providerName = _getProviderDisplayName(provider);
    final modelName = _getModelShortName(model);

    return '$providerName ($modelName)';
  }

  String _getProviderDisplayName(String providerId) {
    switch (providerId.toLowerCase()) {
      case 'zhipu':
        return 'GLM';
      case 'google':
        return 'Gemini';
      case 'moonshot':
        return 'Kimi';
      case 'openai':
        return 'GPT';
      case 'anthropic':
        return 'Claude';
      default:
        return providerId[0].toUpperCase() + providerId.substring(1);
    }
  }

  String _getModelShortName(String modelId) {
    // Extract the short model name
    final short = modelId
        .replaceAll(RegExp(r'^.*?[-/]'), '') // Remove everything before - or /
        .replaceAll(RegExp(r'-preview$'), '')
        .replaceAll(RegExp(r'-turbo$'), '')
        .replaceAll(RegExp(r'-\d{8}$'), '') // Remove date suffix
        .replaceAll(RegExp(r'^glm-'), '')
        .replaceAll(RegExp(r'^gemini-'), '')
        .replaceAll(RegExp(r'^gpt-'), '')
        .replaceAll(RegExp(r'^claude-'), '');

    // Convert to title case
    if (short.isEmpty) return modelId;

    // Special cases
    switch (short.toLowerCase()) {
      case '4plus':
      case '4-plus':
        return '4 Plus';
      case '4flash':
      case '4-flash':
        return '4 Flash';
      case 'pro':
        return 'Pro';
      case 'ultra':
        return 'Ultra';
      default:
        return short[0].toUpperCase() + short.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(Icons.smart_toy, color: theme.primaryColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: availableModels.isEmpty
              ? Text(
                  'No providers available',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedModel,
                    hint: const Text('Select provider'),
                    isExpanded: true,
                    items: availableModels.map((model) {
                      return DropdownMenuItem(
                        value: model,
                        child: Row(
                          children: [
                            Icon(_getProviderIcon(model), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getModelDisplayName(model),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: onModelChanged,
                  ),
                ),
        ),
        if (availableModels.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Refresh providers',
            onPressed: () {
              // Trigger model refresh via connection manager
              // This will be handled by the parent component
            },
          ),
      ],
    );
  }

  IconData _getProviderIcon(String modelId) {
    final parts = modelId.split('/');
    if (parts.isEmpty) return Icons.smart_toy;

    final provider = parts[0].toLowerCase();
    switch (provider) {
      case 'zhipu':
        return Icons.psychology; // GLM
      case 'google':
        return Icons.search; // Gemini
      case 'moonshot':
        return Icons.nights_stay; // Kimi (moon)
      case 'openai':
        return Icons.auto_awesome; // GPT
      case 'anthropic':
        return Icons.chat_bubble_outline; // Claude
      default:
        return Icons.smart_toy;
    }
  }
}
