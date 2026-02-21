/// OpenClaw Gateway Settings Category Widget
///
/// Provides configuration for the OpenClaw Gateway connection and displays model capacity.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../capacity_gauge.dart';
import '../../services/connection_manager_service.dart';
import 'settings_category_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OpenClaw Gateway settings category
class OpenClawGatewayCategory extends SettingsCategoryContentWidget {
  const OpenClawGatewayCategory({
    super.key,
    required super.categoryId,
    super.isActive = true,
    super.onSettingsChanged,
  });

  @override
  Widget buildCategoryContent(BuildContext context) {
    return const _OpenClawGatewayCategoryContent();
  }
}

class _OpenClawGatewayCategoryContent extends StatefulWidget {
  const _OpenClawGatewayCategoryContent();

  @override
  State<_OpenClawGatewayCategoryContent> createState() =>
      _OpenClawGatewayCategoryContentState();
}

class _OpenClawGatewayCategoryContentState
    extends State<_OpenClawGatewayCategoryContent> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isTestingConnection = false;
  String? _connectionStatus;
  bool? _connectionSuccess;
  bool _isLoadingConfig = false;

  @override
  void initState() {
    super.initState();
    _loadGatewayConfig();
  }

  Future<void> _loadGatewayConfig() async {
    setState(() => _isLoadingConfig = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final insecureAuth = prefs.getBool('openclaw_insecure_auth') ?? false;
      // Note: This setting would require gateway restart to take effect
    } finally {
      setState(() => _isLoadingConfig = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
      _connectionSuccess = null;
    });

    try {
      final connectionManager = context.read<ConnectionManagerService>();
      await connectionManager
          .setGatewayPassword(_passwordController.text.trim());

      // Test the connection
      await connectionManager.testConnection();

      if (mounted) {
        setState(() {
          _connectionStatus =
              'Connection successful! You can now chat with your local LLM.';
          _connectionSuccess = true;
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

  Future<void> _clearPassword() async {
    final connectionManager = context.read<ConnectionManagerService>();
    await connectionManager.setGatewayPassword(null);
    _passwordController.clear();
    if (mounted) {
      setState(() {
        _connectionStatus = null;
        _connectionSuccess = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionManagerService>(
      builder: (context, connectionManager, child) {
        final currentPassword = connectionManager.gatewayPassword;
        final hasPassword =
            currentPassword != null && currentPassword.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OpenClaw Gateway Connection',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure your local OpenClaw Gateway connection',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),

            // Password Configuration Section
            Text(
              'Gateway Password',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Enter your OpenClaw Gateway password',
                hintText: 'Set in ~/.openclaw/openclaw.json',
                border: OutlineInputBorder(),
                helperText: 'Required for chat functionality',
              ),
              obscureText: true,
              maxLines: 1,
            ),
            const SizedBox(height: 16),

            // Connection Status and Test Button
            if (_connectionStatus != null) ...[
              Row(
                children: [
                  Icon(
                    _connectionSuccess! ? Icons.check_circle : Icons.error,
                    color: _connectionSuccess! ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connectionStatus!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                _connectionSuccess! ? Colors.green : Colors.red,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isTestingConnection
                      ? null
                      : () {
                          if (_passwordController.text.trim().isEmpty) {
                            setState(() {
                              _connectionStatus =
                                  'Please enter a password first';
                              _connectionSuccess = false;
                            });
                            return;
                          }
                          _testConnection();
                        },
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
                const SizedBox(width: 16),
                if (hasPassword)
                  TextButton.icon(
                    onPressed: _clearPassword,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear Password'),
                  ),
              ],
            ),
            const SizedBox(height: 32),

            // Model Capacity Section
            Text(
              'Model Capacity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Current LLM model usage and rate limits',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 16),
            const CapacityGaugeWidget(),

            const SizedBox(height: 32),

            // Important Note
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
                          'About Password Authentication',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The password is set in your OpenClaw Gateway configuration file.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To set or change the password, run:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'openclaw config gateway.auth.mode=password\n'
                      'openclaw config gateway.auth.password=YOUR_PASSWORD',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Then restart the gateway for changes to take effect.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
}
