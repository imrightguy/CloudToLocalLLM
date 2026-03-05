library;

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
  String? _errorMessage;
  String _selectedProvider = 'OpenClaw Gateway';
  String _selectedModelTier = 'Critical';
  int _rateLimit = 1;
  bool _autoRestart = true;
  String _selectedTheme = 'System';
  String _selectedLanguage = 'English';
  bool _notificationsEnabled = true;
  bool _trayIconEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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
            ? const LoadingSkeleton(itemCount: 3)
            : _errorMessage != null
                ? ErrorState(message: _errorMessage!, onRetry: _loadData)
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          CardSection(
            title: 'Gateway Config',
            children: [
              _dropdown('Provider', ['OpenClaw Gateway', 'LM Studio', 'Ollama'],
                  _selectedProvider, (v) => setState(() => _selectedProvider = v!)),
              _dropdown('Model Tier', ['Critical', 'High', 'Medium', 'Unlimited'],
                  _selectedModelTier, (v) => setState(() => _selectedModelTier = v!)),
              _field('Rate Limit', '$_rateLimit', (v) {
                final l = int.tryParse(v);
                if (l != null) setState(() => _rateLimit = l);
              }, numeric: true),
              _switch('Auto-restart Gateway', _autoRestart,
                  (v) => setState(() => _autoRestart = v)),
            ],
          ),
          CardSection(
            title: 'App Config',
            children: [
              _dropdown('Theme', ['System', 'Light', 'Dark'],
                  _selectedTheme, (v) => setState(() => _selectedTheme = v!)),
              _dropdown('Language', ['English', 'Spanish', 'French', 'German'],
                  _selectedLanguage, (v) => setState(() => _selectedLanguage = v!)),
              _switch('Notifications', _notificationsEnabled,
                  (v) => setState(() => _notificationsEnabled = v)),
              _switch('Tray Icon', _trayIconEnabled,
                  (v) => setState(() => _trayIconEnabled = v)),
            ],
          ),
          CardSection(
            title: 'System Information',
            children: [
              _readOnly('Version', '1.0.0'),
              _readOnly('App Path', '/opt/cloudtolocalllm'),
              _readOnly('Config Path', '~/.config/cloudtolocalllm'),
              _readOnly('Data Path', '~/.local/share/cloudtolocalllm'),
              _readOnly('Platform', 'Linux'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => debugPrint('Save config'),
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
                OutlinedButton.icon(
                  onPressed: () => debugPrint('Reset config'),
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset'),
                ),
                OutlinedButton.icon(
                  onPressed: () => debugPrint('Export config'),
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
                ),
                OutlinedButton.icon(
                  onPressed: () => debugPrint('Import config'),
                  icon: const Icon(Icons.upload),
                  label: const Text('Import'),
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
        value: value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _field(String label, String value, ValueChanged<String> onChanged, {bool numeric = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        keyboardType: numeric ? TextInputType.number : null,
        onChanged: onChanged,
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SwitchListTile(title: Text(label), value: value, onChanged: onChanged),
    );
  }

  Widget _readOnly(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), filled: true),
        enabled: false,
      ),
    );
  }
}
