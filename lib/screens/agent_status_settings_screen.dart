import 'package:flutter/material.dart';
import '../config/app_config.dart';

/// Settings screen for configuring the Agent Status Dashboard
class AgentStatusSettingsScreen extends StatefulWidget {
  const AgentStatusSettingsScreen({super.key});

  @override
  State<AgentStatusSettingsScreen> createState() => _AgentStatusSettingsScreenState();
}

class _AgentStatusSettingsScreenState extends State<AgentStatusSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _config = AppConfig();

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _pollIntervalController = TextEditingController();
  final TextEditingController _timeoutController = TextEditingController();

  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    await _config.initialize();

    setState(() {
      _urlController.text = _config.getAgentStatusUrl();
      _pollIntervalController.text = _config.getAgentStatusPollIntervalMs().toString();
      _timeoutController.text = _config.getAgentStatusTimeoutMs().toString();
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save each setting
      await _config.setAgentStatusUrl(_urlController.text.trim());
      await _config.setAgentStatusPollIntervalMs(
        int.parse(_pollIntervalController.text),
      );
      await _config.setAgentStatusTimeoutMs(
        int.parse(_timeoutController.text),
      );

      setState(() {
        _hasChanges = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text('Are you sure you want to reset all settings to default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      await _config.resetAgentStatusSettings();
      await _loadSettings();

      setState(() {
        _hasChanges = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings reset to defaults'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _pollIntervalController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Status Settings'),
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveSettings,
              tooltip: 'Save',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSection('Connection Settings'),
                  _buildUrlField(),
                  const SizedBox(height: 16),
                  _buildPollIntervalField(),
                  const SizedBox(height: 16),
                  _buildTimeoutField(),
                  const SizedBox(height: 32),
                  _buildSection('Danger Zone'),
                  _buildResetButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildUrlField() {
    return TextFormField(
      controller: _urlController,
      decoration: const InputDecoration(
        labelText: 'Status URL',
        hintText: 'http://localhost:8080/status',
        prefixIcon: Icon(Icons.link),
        border: OutlineInputBorder(),
        helperText: 'The URL to fetch agent status from',
      ),
      keyboardType: TextInputType.url,
      onChanged: (_) => setState(() => _hasChanges = true),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a URL';
        }
        final uri = Uri.tryParse(value.trim());
        if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
          return 'Please enter a valid URL (e.g., http://localhost:8080/status)';
        }
        return null;
      },
    );
  }

  Widget _buildPollIntervalField() {
    return TextFormField(
      controller: _pollIntervalController,
      decoration: const InputDecoration(
        labelText: 'Poll Interval (ms)',
        hintText: '2000',
        prefixIcon: Icon(Icons.timer),
        border: OutlineInputBorder(),
        helperText: 'How often to check for status updates',
        suffixText: 'ms',
      ),
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() => _hasChanges = true),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a poll interval';
        }
        final interval = int.tryParse(value);
        if (interval == null || interval < 100) {
          return 'Please enter a valid interval (min 100ms)';
        }
        return null;
      },
    );
  }

  Widget _buildTimeoutField() {
    return TextFormField(
      controller: _timeoutController,
      decoration: const InputDecoration(
        labelText: 'Connection Timeout (ms)',
        hintText: '5000',
        prefixIcon: Icon(Icons.access_time),
        border: OutlineInputBorder(),
        helperText: 'Maximum time to wait for a response',
        suffixText: 'ms',
      ),
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() => _hasChanges = true),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a timeout value';
        }
        final timeout = int.tryParse(value);
        if (timeout == null || timeout < 100) {
          return 'Please enter a valid timeout (min 100ms)';
        }
        return null;
      },
    );
  }

  Widget _buildResetButton() {
    return ElevatedButton.icon(
      onPressed: _resetToDefaults,
      icon: const Icon(Icons.restore),
      label: const Text('Reset to Defaults'),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.red,
        backgroundColor: Colors.red.withValues(alpha: 0.1),
      ),
    );
  }
}
