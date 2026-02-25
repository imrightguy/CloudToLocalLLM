/// OpenClaw Gateway Settings Category Widget
///
/// Provides configuration for the OpenClaw Gateway connection and displays model capacity.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../capacity_gauge.dart';
import '../../services/connection_manager_service.dart';
import 'settings_category_widgets.dart';

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
  bool _isTestingConnection = false;
  String? _connectionStatus;
  bool? _connectionSuccess;

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
      _connectionSuccess = null;
    });

    try {
      final connectionManager = context.read<ConnectionManagerService>();

      // Load gateway token if not already loaded
      await connectionManager.loadGatewayToken();

      // Test connection
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

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionManagerService>(
      builder: (context, connectionManager, child) {
        final currentToken = connectionManager.gatewayToken;
        final hasToken = currentToken != null && currentToken.isNotEmpty;

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

            // Token Status Section
            Text(
              'Gateway Token',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hasToken ? Colors.green.shade50 : Colors.orange.shade50,
                border: Border.all(
                  color:
                      hasToken ? Colors.green.shade200 : Colors.orange.shade200,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    hasToken ? Icons.check_circle : Icons.info_outline,
                    color: hasToken ? Colors.green : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasToken ? 'Token Detected' : 'Token Not Found',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasToken
                              ? 'OpenClaw Gateway token was auto-detected from your config files'
                              : 'Run: openclaw gateway token to generate and save the token',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                  onPressed: _isTestingConnection ? null : _testConnection,
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
                          'About Token Authentication',
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
                    'The OpenClaw Gateway uses token-based authentication for local connections.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To generate a new token, run:',
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
                      'openclaw gateway token',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The token is automatically detected from:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade900,
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
                      '~/.config/openclaw/config.yaml\n'
                      '~/.openclaw/config.yaml\n'
                      '~/.config/openclaw-gateway/config.yaml',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No manual configuration needed - the app will auto-detect your token.',
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
