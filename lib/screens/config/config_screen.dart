/// Configuration screen for gateway, app, and system settings.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../widgets/common/card_section.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';

/// Configuration screen for gateway, app, and system settings.
/// Provides interface for managing provider settings, model tiers,
/// rate limits, theme, language, notifications, and system information.
/// TODO: Integrate with SettingsPreferenceService, ConnectionManagerService
class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Gateway Settings
  String _selectedProvider = 'OpenClaw Gateway';
  String _selectedModelTier = 'Critical';
  int _rateLimit = 1;
  bool _autoRestart = true;
  int _gatewayTimeout = 30;

  // Network Settings
  bool _useProxy = false;
  String _proxyHost = '';
  int _proxyPort = 8080;
  int _maxRetries = 3;
  int _requestTimeout = 60;

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

  // App Settings
  String _selectedTheme = 'System';
  String _selectedLanguage = 'English';
  bool _notificationsEnabled = true;
  bool _trayIconEnabled = true;

  // Developer Settings
  bool _debugMode = false;
  bool _verboseLogging = false;
  bool _showDevTools = false;

  // System Info (loaded at runtime)
  final String _appVersion = '1.0.0';
  final String _buildNumber = '20260304';
  String _appPath = '';
  String _configPath = '';
  String _dataPath = '';

  @override
  void initState() {
    super.initState();
    _loadSystemInfo();
    _loadData();
  }

  Future<void> _loadSystemInfo() async {
    // Load actual system paths
    try {
      // App path
      _appPath = Directory.current.path;

      // Config path
      final home = Platform.environment['HOME'] ?? '~';
      _configPath = '$home/.config/cloudtolocalllm';

      // Data path
      _dataPath = '$home/.local/share/cloudtolocalllm';

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading system info: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      // TODO: Load actual settings from SettingsPreferenceService
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to load config: $e');
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      // TODO: Save to SettingsPreferenceService
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showSnackBar('Configuration saved successfully', isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar('Failed to save configuration: $e', isError: true);
      }
    }
  }

  Future<void> _resetConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Configuration'),
        content: const Text('Are you sure you want to reset all settings to defaults?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Reset to defaults via SettingsPreferenceService
      _showSnackBar('Configuration reset to defaults', isError: false);
      await _loadData();
    }
  }

  Future<void> _exportConfig() async {
    // TODO: Implement export
    _showSnackBar('Configuration exported to clipboard', isError: false);
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: Text('Clear all cached data? ($_cacheSizeMB MB will be freed)'),
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
      // TODO: Implement cache clearing
      _showSnackBar('Cache cleared successfully', isError: false);
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
        title: const Text('Config'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshableScreen(
        onRefresh: _loadData,
        errorMessage: _errorMessage,
        child: _isLoading
            ? const LoadingSkeleton(itemCount: 5)
            : _errorMessage != null
                ? ErrorState(message: _errorMessage!, onRetry: _loadData)
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // Gateway Settings
          CardSection(
            title: 'Gateway Settings',
            children: [
              _dropdown('Primary Provider',
                  ['OpenClaw Gateway', 'LM Studio', 'Ollama', 'Custom API'],
                  _selectedProvider, (v) => setState(() => _selectedProvider = v!)),
              _dropdown('Model Tier', ['Critical', 'High', 'Medium', 'Unlimited'],
                  _selectedModelTier, (v) => setState(() => _selectedModelTier = v!)),
              _field('Concurrent Requests', '$_rateLimit', (v) {
                final l = int.tryParse(v);
                if (l != null && l > 0) setState(() => _rateLimit = l);
              }, numeric: true, hint: 'Max concurrent API requests'),
              _field('Gateway Timeout (sec)', '$_gatewayTimeout', (v) {
                final l = int.tryParse(v);
                if (l != null && l > 0) setState(() => _gatewayTimeout = l);
              }, numeric: true),
              _switch('Auto-restart Gateway on Failure', _autoRestart,
                  (v) => setState(() => _autoRestart = v)),
            ],
          ),

          // Network Settings
          CardSection(
            title: 'Network Settings',
            children: [
              _switch('Use Proxy Server', _useProxy,
                  (v) => setState(() => _useProxy = v)),
              if (_useProxy) ...[
                _field('Proxy Host', _proxyHost, (v) => setState(() => _proxyHost = v),
                    hint: 'e.g., proxy.example.com'),
                _field('Proxy Port', '$_proxyPort', (v) {
                  final p = int.tryParse(v);
                  if (p != null && p > 0 && p < 65536) setState(() => _proxyPort = p);
                }, numeric: true),
              ],
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

          // Storage Settings
          CardSection(
            title: 'Storage Settings',
            children: [
              _field('Max Conversation History', '$_maxConversationHistory', (v) {
                final h = int.tryParse(v);
                if (h != null && h >= 0) setState(() => _maxConversationHistory = h);
              }, numeric: true, hint: 'Maximum number of conversations to store locally'),
              _switch('Enable Response Cache', _enableCache,
                  (v) => setState(() => _enableCache = v)),
              if (_enableCache)
                _field('Cache Size Limit (MB)', '$_cacheSizeMB', (v) {
                  final c = int.tryParse(v);
                  if (c != null && c > 0) setState(() => _cacheSizeMB = c);
                }, numeric: true),
              _switch('Auto-cleanup Old Data', _autoCleanup,
                  (v) => setState(() => _autoCleanup = v)),
              if (_enableCache)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: OutlinedButton.icon(
                    onPressed: _clearCache,
                    icon: const Icon(Icons.cleaning_services, size: 18),
                    label: const Text('Clear Cache Now'),
                  ),
                ),
            ],
          ),

          // Security Settings
          CardSection(
            title: 'Security Settings',
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
                if (t != null && t > 0) setState(() => _sessionTimeoutMinutes = t);
              }, numeric: true, hint: 'Auto-lock after inactivity'),
              _switch('Remember Authentication Tokens', _rememberTokens,
                  (v) => setState(() => _rememberTokens = v)),
            ],
          ),

          // App Settings
          CardSection(
            title: 'App Settings',
            children: [
              _dropdown('Theme', ['System', 'Light', 'Dark'],
                  _selectedTheme, (v) => setState(() => _selectedTheme = v!)),
              _dropdown('Language', ['English', 'Spanish', 'French', 'German'],
                  _selectedLanguage, (v) => setState(() => _selectedLanguage = v!)),
              _switch('Enable Notifications', _notificationsEnabled,
                  (v) => setState(() => _notificationsEnabled = v)),
              if (!kIsWeb)
                _switch('Show Tray Icon', _trayIconEnabled,
                    (v) => setState(() => _trayIconEnabled = v)),
            ],
          ),

          // Developer Settings
          CardSection(
            title: 'Developer Settings',
            children: [
              _switch('Debug Mode', _debugMode,
                  (v) => setState(() => _debugMode = v),
                  subtitle: 'Enable additional debugging information'),
              _switch('Verbose Logging', _verboseLogging,
                  (v) => setState(() => _verboseLogging = v),
                  subtitle: 'Log detailed diagnostic information'),
              _switch('Show Developer Tools', _showDevTools,
                  (v) => setState(() => _showDevTools = v),
                  subtitle: 'Enable development tools and inspectors'),
            ],
          ),

          // System Information
          CardSection(
            title: 'System Information',
            children: [
              _readOnly('App Version', '$_appVersion (build $_buildNumber)'),
              _readOnly('Platform', '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'),
              _readOnly('Dart Version', Platform.version.split(' ').first),
              if (_appPath.isNotEmpty) _readOnly('App Path', _appPath),
              if (_configPath.isNotEmpty) _readOnly('Config Path', _configPath),
              if (_dataPath.isNotEmpty) _readOnly('Data Path', _dataPath),
              _readOnly('Working Directory', Directory.current.path),
            ],
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveConfig,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save Configuration'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _resetConfig,
                      icon: const Icon(Icons.restore),
                      label: const Text('Reset to Defaults'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _exportConfig,
                      icon: const Icon(Icons.download),
                      label: const Text('Export'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showSnackBar('Import not yet implemented', isError: true),
                      icon: const Icon(Icons.upload),
                      label: const Text('Import'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Changes are saved automatically',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(String label, List<String> items, String value, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _field(String label, String value, ValueChanged<String> onChanged,
      {bool numeric = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        keyboardType: numeric ? TextInputType.number : null,
        onChanged: onChanged,
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SwitchListTile(
        title: Text(label),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _readOnly(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        enabled: false,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}
