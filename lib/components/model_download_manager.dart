import 'package:flutter/material.dart';
import 'modern_card.dart';

/// Model download progress state
class ModelDownloadProgress {
  final String modelName;
  final double progress; // 0.0 to 1.0
  final String status;
  final bool isCompleted;
  final String? error;

  const ModelDownloadProgress({
    required this.modelName,
    required this.progress,
    required this.status,
    this.isCompleted = false,
    this.error,
  });

  ModelDownloadProgress copyWith({
    String? modelName,
    double? progress,
    String? status,
    bool? isCompleted,
    String? error,
  }) {
    return ModelDownloadProgress(
      modelName: modelName ?? this.modelName,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error ?? this.error,
    );
  }
}

/// Model download manager widget - stub version
///
/// Note: Ollama integration removed. Model downloads disabled.
/// To enable, integrate with vLLM or another model server.
class ModelDownloadManager extends StatelessWidget {
  const ModelDownloadManager({super.key});

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Model Downloads',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Model download functionality is currently disabled. '
              'Use GUI Automation for local model control.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: null, // Disabled
              icon: const Icon(Icons.download),
              label: const Text('Download Models (Disabled)'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Model list widget - stub version
class ModelList extends StatelessWidget {
  const ModelList({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No models available. Ollama integration removed.'),
    );
  }
}
