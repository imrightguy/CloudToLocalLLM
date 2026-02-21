/// Import/Export Settings Category
///
/// Provides UI for importing and exporting settings.
library;

import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/services/settings_import_export_service.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';
import 'package:cloudtolocalllm/widgets/settings/settings_import_export_widget.dart';
import 'package:cloudtolocalllm/di/locator.dart' as di;

/// Import/Export settings category widget
class ImportExportSettingsCategory extends StatefulWidget {
  /// Category ID
  final String categoryId;

  /// Whether this category is currently active
  final bool isActive;

  const ImportExportSettingsCategory({
    required this.categoryId,
    required this.isActive,
    super.key,
  });

  @override
  State<ImportExportSettingsCategory> createState() =>
      _ImportExportSettingsCategoryState();
}

class _ImportExportSettingsCategoryState
    extends State<ImportExportSettingsCategory> {
  late SettingsImportExportService _importExportService;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  void _initializeService() {
    try {
      final preferencesService =
          di.serviceLocator.get<SettingsPreferenceService>();
      _importExportService = SettingsImportExportService(
        preferencesService: preferencesService,
      );
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint(
        '[ImportExportSettingsCategory] Error initializing service: $e',
      );
      setState(() {
        _errorMessage = 'Failed to initialize import/export service: $e';
        _isInitialized = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade600),
            const SizedBox(height: 16),
            Text(
              'Error Loading Import/Export',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unexpected error occurred',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                setState(() => _isInitialized = false);
                _initializeService();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Import/Export Settings',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Backup your settings or restore them on another device',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
        const SizedBox(height: 24),

        // Info box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border.all(color: Colors.blue.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'About Import/Export',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Export your settings to a JSON file for backup or to transfer to another device. '
                'Import settings from a previously exported file to restore your configuration.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue.shade700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Note: Sensitive information like API keys is not included in exports for security reasons.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue.shade600,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Import/Export Widget
        SettingsImportExportWidget(
          importExportService: _importExportService,
          onSettingsExported: _handleSettingsExported,
          onSettingsImported: _handleSettingsImported,
        ),
      ],
    );
  }

  /// Handle successful export
  Future<void> _handleSettingsExported(String jsonString) async {
    // In a real app, this would trigger a file download
    // For now, we just copy to clipboard or show a dialog
    debugPrint('[ImportExportSettingsCategory] Settings exported');
  }

  /// Handle successful import
  Future<void> _handleSettingsImported(Map<String, dynamic> settings) async {
    debugPrint(
      '[ImportExportSettingsCategory] Settings imported: ${settings.length} settings',
    );
  }
}
