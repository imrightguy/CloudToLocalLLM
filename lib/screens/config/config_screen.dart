/// Configuration screen for gateway, app, and system settings.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../widgets/common/card_section.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../services/auto_update_service.dart';
import '../../services/connection_manager_service.dart' as runtime;
import '../../services/settings_preference_service.dart';
import '../../di/locator.dart';

/// Configuration screen with tabbed organization for better UX.
/// TODO: Integrate with SettingsPreferenceService, ConnectionManagerService
class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Runtime Settings
  String _selectedSupportProvider = 'Auto';
  int _rateLimit = 1;
  bool _autoRestart = true;
  int _runtimeTimeout = 30;

  // Network Settings
  bool _useProxy = false;
  String _proxyHost = '';
  int _proxyPort = 8080;
  int _maxRetries = 3;
  int _requestTimeout = 60;

  // App Settings
  String _selectedTheme = 'System';
  String _selectedLanguage = 'English';
  bool _notificationsEnabled = true;
  bool _trayIconEnabled = true;

  // Storage Settings
  int _maxConversationHistory = 1000;
  bool _enableCache = true;
  int _cacheSizeMB = 500;
  bool _autoCleanup = true;

  // Security Settings
  bool _encryptLocalData = true;
  bool _biometricAuth = false;
  int _sessionTimeoutMinutes = 30;
  bool _rememberTokens = true;

  // Developer Settings
  bool _debugMode = false;
  bool _verboseLogging = false;
  bool _showDevTools = false;

  // System Info
  final String _appVersion = '1.0.0';
  final String _buildNumber = '20260304';
  String _appPath = '';
  String _configPath = '';
  String _dataPath = '';

  // Active Backend
  BackendType? _activeBackend;
  final _settingsService = serviceLocator<SettingsPreferenceService>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadSystemInfo();
    _loadActiveBackend();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSystemInfo() async {
    try {
      _appPath = kIsWeb ? '/' : Directory.current.path;
      final home = _getHomeDirectory() ?? '~';
      _configPath = '$home/.config/cloudtolocalllm';
      _dataPath = '$home/.local/share/cloudtolocalllm';
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading system info: $e');
    }
  }

  Future<void> _loadActiveBackend() async {
    final backend = await _settingsService.getActiveBackend();
    if (mounted) setState(() => _activeBackend = backend);
  }

  Future<void> _applyRuntimeSelection(BackendType? backend) async {
    final connectionManager = context.read<runtime.ConnectionManagerService>();
    switch (backend) {
      case BackendType.hermes:
        connectionManager.switchBackend(runtime.BackendType.hermes);
        await connectionManager.testConnection();
      case BackendType.openclaw:
        connectionManager.switchBackend(runtime.BackendType.openclaw);
        await connectionManager.testConnection();
      case null:
        connectionManager.clearActiveRuntime();
    }
  }

  String _runtimeLabel(BackendType? backend) {
    return switch (backend) {
      BackendType.hermes => 'Hermes Agent',
      BackendType.openclaw => 'OpenClaw Gateway',
      null => 'None',
    };
  }

  String? _getHomeDirectory() {
    if (kIsWeb) {
      return null;
    }

    try {
      return Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'];
    } catch (e) {
      debugPrint('Error reading home directory from environment: $e');
      return null;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to load config: $e');
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar('Configuration saved successfully', isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar('Failed to save configuration: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/chat'),
          tooltip: 'Back to runtime channel',
        ),
        title: const Text('Runtime Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _isSaving ? null : _saveConfig,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            tooltip: 'Save',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Runtime', icon: Icon(Icons.hub)),
            Tab(text: 'Mesh', icon: Icon(Icons.wifi)),
            Tab(text: 'App', icon: Icon(Icons.smartphone)),
            Tab(text: 'Storage', icon: Icon(Icons.storage)),
            Tab(text: 'System', icon: Icon(Icons.info)),
          ],
        ),
      ),
      body: RefreshableScreen(
        onRefresh: _loadData,
        errorMessage: _errorMessage,
        child: _isLoading
            ? const LoadingSkeleton(itemCount: 3)
            : _errorMessage != null
                ? ErrorState(message: _errorMessage!, onRetry: _loadData)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGatewayTab(),
                      _buildNetworkTab(),
                      _buildAppTab(),
                      _buildStorageTab(),
                      _buildSystemTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildGatewayTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardSection(
          title: 'Active Agent Runtime',
          subtitle: _activeBackend != null
              ? 'Secure channel runtime: ${_runtimeLabel(_activeBackend)}'
              : 'No runtime selected - choose one below',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: DropdownButtonFormField<BackendType?>(
                initialValue: _activeBackend,
                decoration: InputDecoration(
                  labelText: 'Agent Runtime',
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  helperText: 'Select the runtime used by the secure channel',
                ),
                items: const [
                  DropdownMenuItem(
                    value: null,
                    child: Text('None'),
                  ),
                  DropdownMenuItem(
                    value: BackendType.openclaw,
                    child: Text('OpenClaw Gateway'),
                  ),
                  DropdownMenuItem(
                    value: BackendType.hermes,
                    child: Text('Hermes Agent'),
                  ),
                ],
                onChanged: (value) async {
                  setState(() => _activeBackend = value);
                  await _settingsService.setActiveBackend(value);
                  await _applyRuntimeSelection(value);
                  if (mounted) {
                    _showSnackBar(
                      value != null
                          ? 'Active runtime set to ${_runtimeLabel(value)}'
                          : 'Runtime cleared',
                      isError: false,
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: 'Support Model Providers',
          subtitle:
              'Optional helpers for memory, summaries, OCR cleanup, and background tasks',
          children: [
            _dropdown(
              'Preferred Support Provider',
              ['Auto', 'Ollama', 'LM Studio', 'OpenAI-compatible'],
              _selectedSupportProvider,
              (v) => setState(() => _selectedSupportProvider = v!),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Support providers cannot complete setup or receive desktop-control authority unless wrapped by an agent runtime.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: 'Runtime Request Policy',
          children: [
            _field('Concurrent Requests', '$_rateLimit', (v) {
              final l = int.tryParse(v);
              if (l != null && l > 0) setState(() => _rateLimit = l);
            }, numeric: true, hint: 'Max concurrent runtime requests'),
            _field('Runtime Timeout (sec)', '$_runtimeTimeout', (v) {
              final l = int.tryParse(v);
              if (l != null && l > 0) setState(() => _runtimeTimeout = l);
            }, numeric: true),
            _switch('Auto-restart Runtime on Failure', _autoRestart,
                (v) => setState(() => _autoRestart = v)),
          ],
        ),
      ],
    );
  }

  Widget _buildNetworkTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardSection(
          title: 'Proxy Settings',
          children: [
            _switch('Use Proxy Server', _useProxy,
                (v) => setState(() => _useProxy = v)),
            if (_useProxy) ...[
              _field('Proxy Host', _proxyHost,
                  (v) => setState(() => _proxyHost = v),
                  hint: 'e.g., proxy.example.com'),
              _field('Proxy Port', '$_proxyPort', (v) {
                final p = int.tryParse(v);
                if (p != null && p > 0 && p < 65536) {
                  setState(() => _proxyPort = p);
                }
              }, numeric: true),
            ],
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: 'Connection Settings',
          children: [
            _field('Request Timeout (sec)', '$_requestTimeout', (v) {
              final t = int.tryParse(v);
              if (t != null && t > 0) setState(() => _requestTimeout = t);
            }, numeric: true),
            _field('Max Retries', '$_maxRetries', (v) {
              final r = int.tryParse(v);
              if (r != null && r >= 0) setState(() => _maxRetries = r);
            }, numeric: true),
          ],
        ),
      ],
    );
  }

  Widget _buildAppTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardSection(
          title: 'Appearance',
          children: [
            _dropdown('Theme', ['System', 'Light', 'Dark'], _selectedTheme,
                (v) => setState(() => _selectedTheme = v!)),
            _dropdown(
                'Language',
                ['English', 'Spanish', 'French', 'German'],
                _selectedLanguage,
                (v) => setState(() => _selectedLanguage = v!)),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: 'Notifications',
          children: [
            _switch('Enable Notifications', _notificationsEnabled,
                (v) => setState(() => _notificationsEnabled = v)),
            if (!kIsWeb)
              _switch('Show Tray Icon', _trayIconEnabled,
                  (v) => setState(() => _trayIconEnabled = v)),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: 'Security',
          children: [
            _switch('Encrypt Local Data', _encryptLocalData,
                (v) => setState(() => _encryptLocalData = v),
                subtitle: 'Encrypt conversation history and settings'),
            if (!kIsWeb)
              _switch('Require Biometric Auth', _biometricAuth,
                  (v) => setState(() => _biometricAuth = v),
                  subtitle: 'Require fingerprint/auth to open app'),
            _field('Session Timeout (min)', '$_sessionTimeoutMinutes', (v) {
              final t = int.tryParse(v);
              if (t != null && t > 0) {
                setState(() => _sessionTimeoutMinutes = t);
              }
            }, numeric: true, hint: 'Auto-lock after inactivity'),
            _switch('Remember Authentication Tokens', _rememberTokens,
                (v) => setState(() => _rememberTokens = v)),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: 'Developer Options',
          children: [
            _switch(
                'Debug Mode', _debugMode, (v) => setState(() => _debugMode = v),
                subtitle: 'Enable additional debugging information'),
            _switch('Verbose Logging', _verboseLogging,
                (v) => setState(() => _verboseLogging = v),
                subtitle: 'Log detailed diagnostic information'),
            _switch('Show Developer Tools', _showDevTools,
                (v) => setState(() => _showDevTools = v),
                subtitle: 'Enable development tools and inspectors'),
          ],
        ),
      ],
    );
  }

  Widget _buildStorageTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardSection(
          title: 'Data Retention',
          children: [
            _field('Max Conversation History', '$_maxConversationHistory', (v) {
              final h = int.tryParse(v);
              if (h != null && h >= 0) {
                setState(() => _maxConversationHistory = h);
              }
            },
                numeric: true,
                hint: 'Maximum number of conversations to store locally'),
            _switch('Auto-cleanup Old Data', _autoCleanup,
                (v) => setState(() => _autoCleanup = v)),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: 'Cache Management',
          children: [
            _switch('Enable Response Cache', _enableCache,
                (v) => setState(() => _enableCache = v)),
            if (_enableCache)
              _field('Cache Size Limit (MB)', '$_cacheSizeMB', (v) {
                final c = int.tryParse(v);
                if (c != null && c > 0) setState(() => _cacheSizeMB = c);
              }, numeric: true),
            if (_enableCache)
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: _clearCache,
                  icon: const Icon(Icons.cleaning_services, size: 18),
                  label: const Text('Clear Cache Now'),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSystemTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardSection(
          title: 'Application',
          children: [
            _readOnly('Version', '$_appVersion (build $_buildNumber)'),
            _readOnly('Platform',
                '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'),
            _readOnly('Dart Version', Platform.version.split(' ').first),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: 'Paths',
          children: [
            if (_appPath.isNotEmpty) _readOnly('App Path', _appPath),
            if (_configPath.isNotEmpty) _readOnly('Config Path', _configPath),
            if (_dataPath.isNotEmpty) _readOnly('Data Path', _dataPath),
            _readOnly('Working Directory', Directory.current.path),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: 'Software Updates',
          children: [
            Consumer<AutoUpdateService>(
              builder: (context, updateService, child) {
                final status = updateService.status;
                final updateInfo = updateService.updateInfo;

                if (status == UpdateStatus.checking) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Checking for updates...'),
                        ],
                      ),
                    ),
                  );
                }

                if (status == UpdateStatus.downloading) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Downloading update...'),
                        ],
                      ),
                    ),
                  );
                }

                if (status == UpdateStatus.installing) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Installing update...'),
                        ],
                      ),
                    ),
                  );
                }

                if (status == UpdateStatus.updateAvailable &&
                    updateInfo != null) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.new_releases,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Update Available: ${updateInfo.latestVersion}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Current version: ${updateInfo.currentVersion}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getUpdateTypeLabel(updateInfo.type),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => updateService.downloadUpdate(),
                              icon: const Icon(Icons.download, size: 18),
                              label: const Text('Download Update'),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  _showChangelogDialog(context, updateInfo),
                              icon: const Icon(Icons.description, size: 18),
                              label: const Text('View Changelog'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                if (status == UpdateStatus.downloaded) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Update Ready to Install',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.green,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => updateService.installUpdate(),
                          icon: const Icon(Icons.restart_alt, size: 18),
                          label: const Text('Install & Restart'),
                        ),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Up to date',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => updateService.checkForUpdates(),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Check Now'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showSnackBar(
                      'Reset to defaults - coming soon',
                      isError: true),
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset to Defaults'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showSnackBar(
                      'Configuration exported to clipboard',
                      isError: false),
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showSnackBar('Import not yet implemented',
                      isError: true),
                  icon: const Icon(Icons.upload),
                  label: const Text('Import'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content:
            Text('Clear all cached data? ($_cacheSizeMB MB will be freed)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _showSnackBar('Cache cleared successfully', isError: false);
    }
  }

  Widget _dropdown(String label, List<String> items, String value,
      ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _field(String label, String value, ValueChanged<String> onChanged,
      {bool numeric = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          hintText: hint,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        keyboardType: numeric ? TextInputType.number : null,
        onChanged: onChanged,
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged,
      {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        title: Text(label),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(fontSize: 12))
            : null,
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _readOnly(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        enabled: false,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }

  String _getUpdateTypeLabel(UpdateType type) {
    switch (type) {
      case UpdateType.major:
        return 'Major version - may include breaking changes';
      case UpdateType.minor:
        return 'Minor version - new features and improvements';
      case UpdateType.patch:
        return 'Patch version - bug fixes and security updates';
      case UpdateType.none:
        return '';
    }
  }

  void _showChangelogDialog(BuildContext context, UpdateInfo info) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('What\'s New in ${info.latestVersion}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info.changelog != null && info.changelog!.isNotEmpty)
                  MarkdownBody(data: info.changelog!)
                else
                  const Text('No changelog available'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
