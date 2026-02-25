/// Tunnel Settings Screen
/// Configuration UI for tunnel service
library;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../services/tunnel/tunnel_config_manager.dart';
import '../services/tunnel/interfaces/tunnel_config.dart';
import '../services/tunnel/interfaces/tunnel_service.dart';
import '../services/tunnel/interfaces/diagnostic_report.dart';
import '../services/tunnel/diagnostics/diagnostic_test_suite.dart';

/// Tunnel Settings Screen
class TunnelSettingsScreen extends StatefulWidget {
  const TunnelSettingsScreen({super.key});

  @override
  State<TunnelSettingsScreen> createState() => _TunnelSettingsScreenState();
}

class _TunnelSettingsScreenState extends State<TunnelSettingsScreen> {
  late TunnelConfigManager _configManager;
  late TunnelService _tunnelService;
  late TunnelConfig _currentConfig;
  late ProfileType _selectedProfile;
  bool _showAdvancedSettings = false;
  List<String> _validationErrors = [];

  // Controllers for advanced settings
  late TextEditingController _maxReconnectController;
  late TextEditingController _reconnectDelayController;
  late TextEditingController _requestTimeoutController;
  late TextEditingController _maxQueueSizeController;

  bool _runningDiagnostics = false;
  List<String> _diagnosticResults = [];

  @override
  void initState() {
    super.initState();
    _configManager = GetIt.instance<TunnelConfigManager>();
    _tunnelService = GetIt.instance<TunnelService>();

    _currentConfig = _configManager.getCurrentConfig();
    _selectedProfile = _configManager.getCurrentProfile();

    _initializeControllers();
  }

  void _initializeControllers() {
    _maxReconnectController = TextEditingController(
        text: _currentConfig.maxReconnectAttempts.toString());
    _reconnectDelayController = TextEditingController(
        text: _currentConfig.reconnectBaseDelay.inSeconds.toString());
    _requestTimeoutController = TextEditingController(
        text: _currentConfig.requestTimeout.inSeconds.toString());
    _maxQueueSizeController =
        TextEditingController(text: _currentConfig.maxQueueSize.toString());
  }

  @override
  void dispose() {
    _maxReconnectController.dispose();
    _reconnectDelayController.dispose();
    _requestTimeoutController.dispose();
    _maxQueueSizeController.dispose();
    super.dispose();
  }

  void _updateConfigFromControllers() {
    try {
      _validationErrors.clear();

      final maxReconnect = int.tryParse(_maxReconnectController.text) ?? 10;
      final reconnectDelay = int.tryParse(_reconnectDelayController.text) ?? 2;
      final requestTimeout = int.tryParse(_requestTimeoutController.text) ?? 30;
      final maxQueueSize = int.tryParse(_maxQueueSizeController.text) ?? 100;

      _currentConfig = _currentConfig.copyWith(
        maxReconnectAttempts: maxReconnect,
        reconnectBaseDelay: Duration(seconds: reconnectDelay),
        requestTimeout: Duration(seconds: requestTimeout),
        maxQueueSize: maxQueueSize,
      );
    } catch (e) {
      _validationErrors.add('Failed to parse configuration values');
    }
  }

  Future<void> _saveConfiguration() async {
    _updateConfigFromControllers();

    final validation = _configManager.validateConfig(_currentConfig);
    if (!validation.isValid) {
      setState(() {
        _validationErrors = validation.errors;
      });
      _showErrorDialog('Configuration Validation Failed', validation.errors);
      return;
    }

    try {
      await _configManager.updateConfig(_currentConfig);
      _tunnelService.updateConfig(_currentConfig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Save Failed', ['Failed to save configuration: $e']);
      }
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults?'),
        content: const Text(
          'This will reset all tunnel settings to their default values. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _configManager.resetToDefaults();
        _currentConfig = _configManager.getCurrentConfig();
        _selectedProfile = ProfileType.custom;
        _tunnelService.updateConfig(_currentConfig);
        _initializeControllers();

        setState(() {
          _validationErrors.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configuration reset to defaults'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          _showErrorDialog(
              'Reset Failed', ['Failed to reset configuration: $e']);
        }
      }
    }
  }

  Future<void> _loadProfile(ProfileType profile) async {
    try {
      await _configManager.loadProfile(profile);
      _currentConfig = _configManager.getCurrentConfig();
      _selectedProfile = profile;
      _tunnelService.updateConfig(_currentConfig);
      _initializeControllers();

      setState(() {
        _validationErrors.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${profile.name} profile'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Profile Load Failed', ['Failed to load profile: $e']);
      }
    }
  }

  void _showErrorDialog(String title, List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: errors
                .map((error) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '• $error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _runningDiagnostics = true;
      _diagnosticResults.clear();
    });

    try {
      // Create diagnostic test suite
      final diagnosticSuite = DiagnosticTestSuite(
        serverHost: 'api.cloudtolocalllm.online',
        serverPort: 443,
        authToken: null, // Will be set from auth service if needed
        testTimeout: const Duration(seconds: 30),
      );

      // Run all tests
      final tests = await diagnosticSuite.runAllTests();

      // Build results
      final results = <String>[];
      for (final test in tests) {
        results.add('${test.name}: ${test.passed ? 'PASSED' : 'FAILED'}');
        if (!test.passed && test.errorMessage != null) {
          results.add('  Error: ${test.errorMessage}');
        }
        results.add('  Duration: ${test.duration.inMilliseconds}ms');
      }

      setState(() {
        _diagnosticResults = results;
        _runningDiagnostics = false;
      });

      // Show results dialog
      if (mounted) {
        _showDiagnosticsDialog(tests);
      }
    } catch (e) {
      setState(() {
        _diagnosticResults = ['Error running diagnostics: $e'];
        _runningDiagnostics = false;
      });

      if (mounted) {
        _showErrorDialog('Diagnostics Failed', ['Error: $e']);
      }
    }
  }

  void _showDiagnosticsDialog(List<DiagnosticTest> tests) {
    final passedCount = tests.where((t) => t.passed).length;
    final totalCount = tests.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diagnostics Results'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Passed: $passedCount/$totalCount',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      passedCount == totalCount ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(height: 12),
              ...tests.map((test) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              test.passed ? Icons.check_circle : Icons.error,
                              color: test.passed ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                test.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        if (test.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 28, top: 4),
                            child: Text(
                              test.errorMessage!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(left: 28, top: 4),
                          child: Text(
                            'Duration: ${test.duration.inMilliseconds}ms',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tunnel Configuration'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Selection
            _buildProfileSection(),
            const SizedBox(height: 24),

            // Advanced Settings
            _buildAdvancedSettingsSection(),
            const SizedBox(height: 24),

            // Validation Errors
            if (_validationErrors.isNotEmpty) _buildErrorsSection(),
            const SizedBox(height: 24),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Network Profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButton<ProfileType>(
              value: _selectedProfile,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: ProfileType.stable,
                  child: const Text('Stable Network'),
                ),
                DropdownMenuItem(
                  value: ProfileType.unstable,
                  child: const Text('Unstable Network'),
                ),
                DropdownMenuItem(
                  value: ProfileType.lowBandwidth,
                  child: const Text('Low Bandwidth'),
                ),
                DropdownMenuItem(
                  value: ProfileType.custom,
                  child: const Text('Custom'),
                ),
              ],
              onChanged: (profile) {
                if (profile != null && profile != ProfileType.custom) {
                  _loadProfile(profile);
                }
              },
            ),
            const SizedBox(height: 12),
            _buildProfileDescription(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDescription() {
    switch (_selectedProfile) {
      case ProfileType.stable:
        return const Text(
          'Optimized for reliable, low-latency networks. Fewer reconnection attempts and shorter delays.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        );
      case ProfileType.unstable:
        return const Text(
          'Optimized for unreliable, high-latency networks. More reconnection attempts and longer timeouts.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        );
      case ProfileType.lowBandwidth:
        return const Text(
          'Optimized for bandwidth-constrained networks. Compression enabled and smaller queue size.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        );
      case ProfileType.custom:
        return const Text(
          'Custom configuration. Modify settings below.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        );
    }
  }

  Widget _buildAdvancedSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _showAdvancedSettings = !_showAdvancedSettings;
                });
              },
              child: Row(
                children: [
                  Icon(
                    _showAdvancedSettings
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Advanced Settings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (_showAdvancedSettings) ...[
              const SizedBox(height: 16),
              _buildSliderSetting(
                label: 'Max Reconnect Attempts',
                controller: _maxReconnectController,
                min: 1,
                max: 20,
                divisions: 19,
              ),
              const SizedBox(height: 16),
              _buildSliderSetting(
                label: 'Reconnect Base Delay (seconds)',
                controller: _reconnectDelayController,
                min: 1,
                max: 60,
                divisions: 59,
              ),
              const SizedBox(height: 16),
              _buildSliderSetting(
                label: 'Request Timeout (seconds)',
                controller: _requestTimeoutController,
                min: 5,
                max: 120,
                divisions: 115,
              ),
              const SizedBox(height: 16),
              _buildSliderSetting(
                label: 'Max Queue Size',
                controller: _maxQueueSizeController,
                min: 10,
                max: 1000,
                divisions: 99,
              ),
              const SizedBox(height: 16),
              _buildToggleSetting(
                label: 'Enable Compression',
                value: _currentConfig.enableCompression,
                onChanged: (value) {
                  setState(() {
                    _currentConfig = _currentConfig.copyWith(
                      enableCompression: value,
                    );
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildToggleSetting(
                label: 'Enable Auto-Reconnect',
                value: _currentConfig.enableAutoReconnect,
                onChanged: (value) {
                  setState(() {
                    _currentConfig = _currentConfig.copyWith(
                      enableAutoReconnect: value,
                    );
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSetting({
    required String label,
    required TextEditingController controller,
    required double min,
    required double max,
    required int divisions,
  }) {
    final value = double.tryParse(controller.text) ?? min;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              value.toStringAsFixed(0),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: (newValue) {
            setState(() {
              controller.text = newValue.toStringAsFixed(0);
            });
          },
        ),
      ],
    );
  }

  Widget _buildToggleSetting({
    required String label,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildErrorsSection() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Validation Errors',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._validationErrors.map((error) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '• $error',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _saveConfiguration,
                child: const Text('Save Configuration'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _resetToDefaults,
                child: const Text('Reset to Defaults'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _runningDiagnostics ? null : _runDiagnostics,
            icon: _runningDiagnostics
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bug_report),
            label: Text(_runningDiagnostics
                ? 'Running Diagnostics...'
                : 'Run Diagnostics'),
          ),
        ),
      ],
    );
  }
}
