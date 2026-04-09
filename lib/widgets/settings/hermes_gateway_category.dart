/// Hermes Gateway Settings Category Widget
///
/// Provides configuration for the Hermes Agent gateway connection including
/// URL, connection status, and model selection.
library;

import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../di/locator.dart';
import '../../services/hermes/hermes_streaming_service.dart';
import '../../services/hermes_manager/hermes_gateway_control_service.dart';
import '../../services/openclaw_manager/gateway_control_service.dart';
import '../../services/settings_preference_service.dart';
import 'settings_category_widgets.dart';

/// Hermes Gateway settings category
class HermesGatewayCategory extends SettingsCategoryContentWidget {
  const HermesGatewayCategory({
    super.key,
    required super.categoryId,
    super.isActive = true,
    super.onSettingsChanged,
  });

  @override
  Widget buildCategoryContent(BuildContext context) {
    return const _HermesGatewayCategoryContent();
  }
}

class _HermesGatewayCategoryContent extends StatefulWidget {
  const _HermesGatewayCategoryContent();

  @override
  State<_HermesGatewayCategoryContent> createState() =>
      _HermesGatewayCategoryContentState();
}

class _HermesGatewayCategoryContentState
    extends State<_HermesGatewayCategoryContent> {
  bool _isTestingConnection = false;
  bool _isFetchingModels = false;
  String? _connectionStatus;
  bool? _connectionSuccess;
  String _hermesUrl = AppConfig.defaultHermesUrl;
  String? _selectedModel;
  List<String> _availableModels = [];

  final _settings = serviceLocator<SettingsPreferenceService>();
  final _hermesControl = serviceLocator<HermesGatewayControlService>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final savedUrl = await _settings.getHermesUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      setState(() {
        _hermesUrl = savedUrl;
      });
    }
  }

  Future<void> _saveUrl(String url) async {
    setState(() => _hermesUrl = url);
    await _settings.setHermesUrl(url);
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
      _connectionSuccess = null;
    });

    try {
      final success = await _hermesControl.testConnection();

      if (mounted) {
        setState(() {
          _connectionSuccess = success;
          if (success) {
            _connectionStatus =
                'Connection successful! Hermes Agent is running at $_hermesUrl.';
          } else {
            _connectionStatus =
                'Connection failed: ${_hermesControl.errorMessage ?? 'Unknown error'}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionStatus = 'Connection failed: $e';
          _connectionSuccess = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  Future<void> _fetchModels() async {
    setState(() {
      _isFetchingModels = true;
    });

    try {
      final streamingService = HermesStreamingService(
        baseUrl: _hermesUrl,
      );
      final models = await streamingService.getAvailableModels();
      streamingService.dispose();

      if (mounted) {
        setState(() {
          _availableModels = models;
          if (_selectedModel == null && models.isNotEmpty) {
            _selectedModel = models.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _availableModels = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingModels = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _hermesControl,
      builder: (context, _) {
        final gatewayState = _hermesControl.state;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hermes Agent Gateway',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure your local Hermes Agent gateway connection',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),

            // Connection Status Section
            Text(
              'Connection Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _buildStatusIndicator(context, gatewayState),
            const SizedBox(height: 16),

            // Hermes URL Configuration
            Text(
              'Gateway URL',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: TextFormField(
                initialValue: _hermesUrl,
                decoration: InputDecoration(
                  labelText: 'Hermes Agent URL',
                  hintText: AppConfig.defaultHermesUrl,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.restore),
                    tooltip: 'Reset to default',
                    onPressed: () => _saveUrl(AppConfig.defaultHermesUrl),
                  ),
                ),
                onChanged: _saveUrl,
              ),
            ),
            const SizedBox(height: 16),

            // Connection Test Button
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed:
                      _isTestingConnection ? null : _testConnection,
                  icon: _isTestingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: Text(
                      _isTestingConnection ? 'Testing...' : 'Test Connection'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed:
                      _isFetchingModels ? null : _fetchModels,
                  icon: _isFetchingModels
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.list),
                  label: Text(
                      _isFetchingModels ? 'Loading...' : 'Fetch Models'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Connection Result
            if (_connectionStatus != null) ...[
              Row(
                children: [
                  Icon(
                    _connectionSuccess!
                        ? Icons.check_circle
                        : Icons.error,
                    color: _connectionSuccess! ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connectionStatus!,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: _connectionSuccess!
                                    ? Colors.green
                                    : Colors.red,
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Model Selection
            if (_availableModels.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Available Models',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedModel,
                decoration: const InputDecoration(
                  labelText: 'Select Model',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 16),
                ),
                items: _availableModels
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _selectedModel = v);
                },
              ),
            ],

            const SizedBox(height: 32),

            // Info Note
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
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'About Hermes Agent',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hermes Agent is an HTTP-based AI gateway that provides '
                    'local model serving, tool-use, and agent orchestration. '
                    'No CLI or shell commands are used — all communication is '
                    'over HTTP.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Default endpoint: ${AppConfig.defaultHermesUrl}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusIndicator(BuildContext context, GatewayState state) {
    IconData icon;
    Color color;
    String label;
    String? detail;

    switch (state) {
      case GatewayState.running:
        icon = Icons.check_circle;
        color = Colors.green;
        label = 'Connected';
        detail = _hermesControl.connectedAt != null
            ? 'Since ${_hermesControl.connectedAt!.toLocal()}'
            : null;
        break;
      case GatewayState.stopped:
        icon = Icons.cancel;
        color = Colors.red;
        label = 'Disconnected';
        detail = _hermesControl.errorMessage;
        break;
      case GatewayState.error:
        icon = Icons.error;
        color = Colors.orange;
        label = 'Error';
        detail = _hermesControl.errorMessage;
        break;
      case GatewayState.unknown:
      case GatewayState.starting:
      case GatewayState.stopping:
        icon = Icons.help_outline;
        color = Colors.grey;
        label = 'Unknown';
        detail = 'Run a connection test to check status';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
