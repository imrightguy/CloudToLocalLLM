/// Settings Import/Export Widget
///
/// Provides UI components for importing and exporting settings.
library;

import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/services/settings_import_export_service.dart';
import 'package:cloudtolocalllm/utils/settings_error_handler.dart';

/// Settings import/export widget
class SettingsImportExportWidget extends StatefulWidget {
  /// Import/export service
  final SettingsImportExportService importExportService;

  /// Callback when settings are successfully imported
  final Future<void> Function(Map<String, dynamic>) onSettingsImported;

  /// Callback when settings are successfully exported
  final Future<void> Function(String) onSettingsExported;

  const SettingsImportExportWidget({
    required this.importExportService,
    required this.onSettingsImported,
    required this.onSettingsExported,
    super.key,
  });

  @override
  State<SettingsImportExportWidget> createState() =>
      _SettingsImportExportWidgetState();
}

class _SettingsImportExportWidgetState
    extends State<SettingsImportExportWidget> {
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Export Button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isExporting ? null : _handleExport,
            icon: _isExporting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(_isExporting ? 'Exporting...' : 'Export Settings'),
          ),
        ),
        const SizedBox(height: 12),

        // Import Button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isImporting ? null : _handleImport,
            icon: _isImporting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.upload),
            label: Text(_isImporting ? 'Importing...' : 'Import Settings'),
          ),
        ),
      ],
    );
  }

  /// Handle export button press
  Future<void> _handleExport() async {
    setState(() => _isExporting = true);

    try {
      final jsonString =
          await widget.importExportService.exportSettingsToJson();
      final filename = widget.importExportService.generateExportFilename();

      // Call the export callback
      await widget.onSettingsExported(jsonString);

      if (mounted) {
        SettingsErrorHandler.showSuccessMessage(
          context,
          'Settings exported successfully as $filename',
        );
      }
    } on SettingsError catch (e) {
      if (mounted) {
        SettingsErrorHandler.showErrorSnackbar(context, e);
      }
    } catch (e) {
      if (mounted) {
        final error = SettingsError.importExportFailed(
          'Failed to export settings: $e',
          originalException: e is Exception ? e : Exception(e.toString()),
        );
        SettingsErrorHandler.showErrorSnackbar(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  /// Handle import button press
  Future<void> _handleImport() async {
    // Show import dialog
    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _ImportSettingsDialog(
        importExportService: widget.importExportService,
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _isImporting = true);

    try {
      // Parse and validate imported settings
      final settings =
          await widget.importExportService.importSettingsFromJson(result);

      // Show confirmation dialog
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _ImportConfirmationDialog(
          settingsCount: settings.length,
        ),
      );

      if (confirmed != true || !mounted) return;

      // Apply imported settings
      await widget.importExportService.applyImportedSettings(settings);

      // Call the import callback
      await widget.onSettingsImported(settings);

      if (mounted) {
        SettingsErrorHandler.showSuccessMessage(
          context,
          'Settings imported successfully',
        );
      }
    } on SettingsError catch (e) {
      if (mounted) {
        SettingsErrorHandler.showErrorSnackbar(context, e);
      }
    } catch (e) {
      if (mounted) {
        final error = SettingsError.importExportFailed(
          'Failed to import settings: $e',
          originalException: e is Exception ? e : Exception(e.toString()),
        );
        SettingsErrorHandler.showErrorSnackbar(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }
}

/// Import settings dialog
class _ImportSettingsDialog extends StatefulWidget {
  final SettingsImportExportService importExportService;

  const _ImportSettingsDialog({
    required this.importExportService,
  });

  @override
  State<_ImportSettingsDialog> createState() => _ImportSettingsDialogState();
}

class _ImportSettingsDialogState extends State<_ImportSettingsDialog> {
  final _textController = TextEditingController();
  String? _validationError;
  bool _isValidating = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste your settings JSON here:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 10,
              minLines: 5,
              decoration: InputDecoration(
                hintText: 'Paste settings JSON...',
                border: const OutlineInputBorder(),
                errorText: _validationError,
                errorMaxLines: 3,
              ),
              onChanged: (_) {
                if (_validationError != null) {
                  setState(() => _validationError = null);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isValidating ? null : _handleImport,
          child: _isValidating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Import'),
        ),
      ],
    );
  }

  Future<void> _handleImport() async {
    final jsonString = _textController.text.trim();

    if (jsonString.isEmpty) {
      setState(() => _validationError = 'Please paste settings JSON');
      return;
    }

    setState(() => _isValidating = true);

    try {
      final validationResult =
          await widget.importExportService.validateSettingsFile(jsonString);

      if (!validationResult.isValid) {
        setState(() => _validationError = validationResult.overallError);
        return;
      }

      if (mounted) {
        Navigator.pop(context, jsonString);
      }
    } catch (e) {
      setState(() => _validationError = 'Invalid JSON format: $e');
    } finally {
      if (mounted) {
        setState(() => _isValidating = false);
      }
    }
  }
}

/// Import confirmation dialog
class _ImportConfirmationDialog extends StatelessWidget {
  final int settingsCount;

  const _ImportConfirmationDialog({
    required this.settingsCount,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Import'),
      content: Text(
        'This will import $settingsCount settings and overwrite your current preferences. Continue?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Import'),
        ),
      ],
    );
  }
}
