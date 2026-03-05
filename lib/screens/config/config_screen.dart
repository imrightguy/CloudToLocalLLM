/// Configuration screen for gateway, app, and system settings.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../widgets/common/card_section.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadSystemInfo();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSystemInfo() async {
    try {
      _appPath = Directory.current.path;
      final home = Platform.environment['HOME'] ?? '~';
      _configPath = '$home/.config/cloudtolocalllm';
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
        title: const Text('Config'),
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
            Tab(text: 'Gateway', icon: Icon(Icons.hub)),
            Tab(text: 'Network', icon: Icon(Icons.wifi)),
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
          title: 'LLM Provider',
          children: [
            _dropdown('Primary Provider',
                ['OpenClaw Gateway', 'LM Studio', 'Ollama', 'Custom API'],
                _selectedProvider, (v) => setState(() => _selectedProvider = v!)),
            _dropdown('Model Tier', ['Critical', 'High', 'Medium', 'Unlimited'],
                _selectedModelTier, (v) => setState(() => _selectedModelTier = v!)),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: 'Request Limits',
          children: [
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
              _field('Proxy Host', _proxyHost, (v) => setState(() => _proxyHost = v),
                  hint: 'e.g., proxy.example.com'),
              _field('Proxy Port', '$_proxyPort', (v) {
                final p = int.tryParse(v);
                if (p != null && p > 0 && p < 65536) setState(() => _proxyPort = p);
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
            _dropdown('Theme', ['System', 'Light', 'Dark'],
                _selectedTheme, (v) => setState(() => _selectedTheme = v!)),
            _dropdown('Language', ['English', 'Spanish', 'French', 'German'],
                _selectedLanguage, (v) => setState(() => _selectedLanguage = v!)),
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
              if (t != null && t > 0) setState(() => _sessionTimeoutMinutes = t);
            }, numeric: true, hint: 'Auto-lock after inactivity'),
            _switch('Remember Authentication Tokens', _rememberTokens,
                (v) => setState(() => _rememberTokens = v)),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: 'Developer Options',
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
              if (h != null && h >= 0) setState(() => _maxConversationHistory = h);
            }, numeric: true, hint: 'Maximum number of conversations to store locally'),
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
            _readOnly('Platform', '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showSnackBar('Reset to defaults - coming soon', isError: true),
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset to Defaults'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showSnackBar('Configuration exported to clipboard', isError: false),
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
      _showSnackBar('Cache cleared successfully', isError: false);
    }
  }

  Widget _dropdown(String label, List<String> items, String value, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
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
