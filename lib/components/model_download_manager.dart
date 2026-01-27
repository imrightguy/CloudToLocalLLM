import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../services/ollama_service.dart';
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

/// Popular Ollama models catalog
class PopularModel {
  final String name;
  final String displayName;
  final String description;
  final String size;
  final List<String> tags;

  const PopularModel({
    required this.name,
    required this.displayName,
    required this.description,
    required this.size,
    required this.tags,
  });

  static const List<PopularModel> catalog = [
    PopularModel(
      name: 'llama2',
      displayName: 'Llama 2',
      description: 'Meta\'s Llama 2 model, great for general conversation',
      size: '3.8GB',
      tags: ['general', 'conversation', 'popular'],
    ),
    PopularModel(
      name: 'mistral',
      displayName: 'Mistral',
      description: 'High-performance model with excellent reasoning',
      size: '4.1GB',
      tags: ['general', 'reasoning', 'fast'],
    ),
    PopularModel(
      name: 'codellama',
      displayName: 'Code Llama',
      description: 'Specialized for code generation and programming',
      size: '3.8GB',
      tags: ['coding', 'programming', 'development'],
    ),
    PopularModel(
      name: 'neural-chat',
      displayName: 'Neural Chat',
      description: 'Optimized for conversational AI applications',
      size: '4.1GB',
      tags: ['conversation', 'chat', 'assistant'],
    ),
    PopularModel(
      name: 'orca-mini',
      displayName: 'Orca Mini',
      description: 'Compact model with good performance',
      size: '1.9GB',
      tags: ['compact', 'fast', 'efficient'],
    ),
    PopularModel(
      name: 'vicuna',
      displayName: 'Vicuna',
      description: 'Fine-tuned for instruction following',
      size: '3.8GB',
      tags: ['instruction', 'helpful', 'assistant'],
    ),
  ];
}

/// Comprehensive model download and management widget
class ModelDownloadManager extends StatefulWidget {
  final bool isProMode;
  const ModelDownloadManager({super.key, this.isProMode = false});

  @override
  State<ModelDownloadManager> createState() => _ModelDownloadManagerState();
}

class _ModelDownloadManagerState extends State<ModelDownloadManager> {
  final Map<String, ModelDownloadProgress> _downloadProgress = {};
  String _searchQuery = '';
  String _selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    return Consumer<OllamaService>(
      builder: (context, ollamaService, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 16),

            // Search and filter
            if (widget.isProMode) ...[
              _buildSearchAndFilter(),
              const SizedBox(height: 16),
            ],

            // Connection configuration and status
            if (widget.isProMode) ...[
              _buildConnectionConfiguration(ollamaService),
              const SizedBox(height: 16),
            ],

            // Installed models section
            _buildInstalledModelsSection(ollamaService),
            const SizedBox(height: 16),

            // Popular models catalog
            _buildPopularModelsSection(ollamaService),

            // Active downloads
            if (_downloadProgress.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildActiveDownloadsSection(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.download_for_offline,
            color: AppTheme.primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Model Manager',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                'Download and manage Ollama models',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textColorLight,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search models...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        const SizedBox(width: 16),
        DropdownButton<String>(
          value: _selectedCategory,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Categories')),
            DropdownMenuItem(value: 'general', child: Text('General')),
            DropdownMenuItem(value: 'coding', child: Text('Coding')),
            DropdownMenuItem(
              value: 'conversation',
              child: Text('Conversation'),
            ),
            DropdownMenuItem(value: 'compact', child: Text('Compact')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedCategory = value ?? 'all';
            });
          },
        ),
      ],
    );
  }

  Widget _buildConnectionConfiguration(OllamaService ollamaService) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.settings_ethernet, color: AppTheme.accentColor),
              const SizedBox(width: 8),
              Text(
                'Ollama Connection',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Connection status
          _buildConnectionStatusRow(ollamaService),
          const SizedBox(height: 16),

          // Connection settings (desktop only)
          if (!kIsWeb) ...[
            _buildConnectionSettings(),
            const SizedBox(height: 16),
          ],

          // Connection test button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: ollamaService.isLoading
                  ? null
                  : () => ollamaService.testConnection(),
              icon: ollamaService.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(
                ollamaService.isLoading ? 'Testing...' : 'Test Connection',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusRow(OllamaService ollamaService) {
    return Row(
      children: [
        Icon(
          ollamaService.isConnected ? Icons.check_circle : Icons.error,
          color: ollamaService.isConnected ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ollamaService.isConnected
                    ? 'Connected to Ollama'
                    : 'Not connected to Ollama',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (ollamaService.error != null)
                Text(
                  ollamaService.error!,
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
            ],
          ),
        ),
        if (ollamaService.isConnected) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Ready',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConnectionSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connection Settings',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Host address field
        TextFormField(
          initialValue: 'localhost',
          decoration: const InputDecoration(
            labelText: 'Host Address',
            hintText: 'localhost',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: _saveOllamaHostAddress,
        ),
        const SizedBox(height: 12),

        // Port field
        TextFormField(
          initialValue: '11434',
          decoration: const InputDecoration(
            labelText: 'Port',
            hintText: '11434',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          keyboardType: TextInputType.number,
          onChanged: _saveOllamaPort,
        ),
        const SizedBox(height: 12),

        // Info text
        Text(
          'Configure the connection to your local Ollama instance. Default settings work for most installations.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
        ),
      ],
    );
  }

  Widget _buildInstalledModelsSection(OllamaService ollamaService) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Installed Models',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: ollamaService.isLoading
                    ? null
                    : () => ollamaService.getModels(),
                icon: ollamaService.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(ollamaService.isLoading ? 'Loading...' : 'Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ollamaService.models.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 48, color: AppTheme.textColorLight),
                  const SizedBox(height: 8),
                  Text(
                    'No models installed',
                    style: TextStyle(
                      color: AppTheme.textColorLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Download models from the catalog below',
                    style: TextStyle(
                      color: AppTheme.textColorLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ...ollamaService.models.map(
              _buildInstalledModelTile,
            ),
        ],
      ),
    );
  }

  Widget _buildInstalledModelTile(OllamaModel model) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.smart_toy, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (model.size != null)
                  Text(
                    'Size: ${model.size}',
                    style: TextStyle(
                      color: AppTheme.textColorLight,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'delete') {
                _showDeleteModelDialog(model.name);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
            child: const Icon(Icons.more_vert),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularModelsSection(OllamaService ollamaService) {
    final filteredModels = PopularModel.catalog.where((model) {
      final matchesSearch = _searchQuery.isEmpty ||
          model.displayName.toLowerCase().contains(_searchQuery) ||
          model.description.toLowerCase().contains(_searchQuery);

      final matchesCategory =
          _selectedCategory == 'all' || model.tags.contains(_selectedCategory);

      return matchesSearch && matchesCategory;
    }).toList();

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Popular Models',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (filteredModels.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No models match your search criteria',
                style: TextStyle(color: AppTheme.textColorLight),
              ),
            )
          else
            ...filteredModels.map(
              (model) => _buildPopularModelTile(model, ollamaService),
            ),
        ],
      ),
    );
  }

  Widget _buildPopularModelTile(
    PopularModel model,
    OllamaService ollamaService,
  ) {
    final isInstalled = ollamaService.models.any(
      (installed) => installed.name == model.name,
    );
    final isDownloading = _downloadProgress.containsKey(model.name);
    final downloadProgress = _downloadProgress[model.name];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          model.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            model.size,
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.description,
                      style: TextStyle(
                        color: AppTheme.textColorLight,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: model.tags
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  color: AppTheme.textColorLight,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (isInstalled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Installed',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else if (isDownloading)
                SizedBox(
                  width: 100,
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: downloadProgress?.progress,
                        backgroundColor: AppTheme.secondaryColor.withValues(
                          alpha: 0.3,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        downloadProgress?.status ?? 'Downloading...',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textColorLight,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: ollamaService.isConnected
                      ? () => _downloadModel(model.name, ollamaService)
                      : null,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                ),
            ],
          ),
          if (downloadProgress?.error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      downloadProgress!.error!,
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _downloadModel(model.name, ollamaService),
                    child: Text('Retry', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveDownloadsSection() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Downloads',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._downloadProgress.entries.map((entry) {
            final modelName = entry.key;
            final progress = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        modelName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${(progress.progress * 100).toInt()}%',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress.progress,
                    backgroundColor: AppTheme.secondaryColor.withValues(
                      alpha: 0.3,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progress.status,
                    style: TextStyle(
                      color: AppTheme.textColorLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _downloadModel(
    String modelName,
    OllamaService ollamaService,
  ) async {
    setState(() {
      _downloadProgress[modelName] = ModelDownloadProgress(
        modelName: modelName,
        progress: 0.0,
        status: 'Starting download...',
      );
    });

    try {
      // Simulate download progress updates
      // In a real implementation, this would be integrated with Ollama's streaming API
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() {
            _downloadProgress[modelName] = ModelDownloadProgress(
              modelName: modelName,
              progress: i / 100.0,
              status: i < 100 ? 'Downloading... $i%' : 'Finalizing...',
            );
          });
        }
      }

      // Call the actual Ollama service to download the model
      final success = await ollamaService.pullModel(modelName);

      if (success) {
        setState(() {
          _downloadProgress[modelName] = ModelDownloadProgress(
            modelName: modelName,
            progress: 1.0,
            status: 'Download completed',
            isCompleted: true,
          );
        });

        // Remove from progress after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _downloadProgress.remove(modelName);
            });
            // Refresh the models list
            ollamaService.getModels();
          }
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$modelName downloaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Download failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadProgress[modelName] = ModelDownloadProgress(
            modelName: modelName,
            progress: 0.0,
            status: 'Download failed',
            error: e.toString(),
          );
        });
      }
    }
  }

  void _showDeleteModelDialog(String modelName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete $modelName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteModel(modelName);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteModel(String modelName) async {
    try {
      final ollamaService = Provider.of<OllamaService>(context, listen: false);

      debugPrint(' [ModelManager] Attempting to delete model: $modelName');

      // Show loading state
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Deleting model $modelName...'),
            ],
          ),
          backgroundColor: AppTheme.primaryColor,
          duration: Duration(seconds: 30), // Longer duration for deletion
        ),
      );

      final success = await ollamaService.deleteModel(modelName);

      // Check if widget is still mounted before using context
      if (!mounted) return;

      // Clear any existing snackbars
      ScaffoldMessenger.of(context).clearSnackBars();

      if (success) {
        debugPrint(' [ModelManager] Successfully deleted model: $modelName');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Successfully deleted $modelName'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        debugPrint(' [ModelManager] Failed to delete model: $modelName');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to delete $modelName: ${ollamaService.error ?? "Unknown error"}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint(' [ModelManager] Error during model deletion: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Failed to delete model: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  /// Save Ollama host address to shared preferences
  Future<void> _saveOllamaHostAddress(String hostAddress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ollama_host_address', hostAddress);
      debugPrint(
        '� [ModelDownloadManager] Saved Ollama host address: $hostAddress',
      );
    } catch (e) {
      debugPrint(' [ModelDownloadManager] Failed to save host address: $e');
    }
  }

  /// Save Ollama port to shared preferences
  Future<void> _saveOllamaPort(String port) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Validate port number
      final portNumber = int.tryParse(port);
      if (portNumber != null && portNumber > 0 && portNumber <= 65535) {
        await prefs.setInt('ollama_port', portNumber);
        debugPrint('� [ModelDownloadManager] Saved Ollama port: $portNumber');
      } else {
        debugPrint(' [ModelDownloadManager] Invalid port number: $port');
      }
    } catch (e) {
      debugPrint(' [ModelDownloadManager] Failed to save port: $e');
    }
  }
}
