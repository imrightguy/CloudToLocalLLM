library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../services/connection_manager_service.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/navigation/popout_button.dart';

/// Debug screen for troubleshooting and diagnostics.
///
/// Provides connection testing against the Hermes gateway,
/// an API request inspector, and live service status.
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  final Set<String> _expandedPanels = {};
  String _connectionLog = '';
  bool _isTestingConnection = false;

  // API Inspector state
  String _apiResponse = '';
  String _apiMethod = 'GET';
  bool _isSendingRequest = false;
  final TextEditingController _apiUrlController = TextEditingController();
  final TextEditingController _apiBodyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill API URL with Hermes gateway
    _apiUrlController.text = '${AppConfig.defaultGatewayUrl}/v1/models';
    _loadData();
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiBodyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Collect real service status
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load debug data: $e';
          _isLoading = false;
        });
      }
    }
  }

  String get _gatewayUrl {
    final connService =
        Provider.of<ConnectionManagerService>(context, listen: false);
    return connService.isConnected
        ? AppConfig.defaultGatewayUrl
        : AppConfig.defaultGatewayUrl;
  }

  /// Test connectivity to the Hermes gateway.
  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionLog = 'Testing connection...\n';
    });

    final buffer = StringBuffer();
    final url = _gatewayUrl;

    try {
      // 1. Basic HTTP reachability
      buffer.writeln('━━━ Hermes Gateway: $url ━━━');
      final startTime = DateTime.now();

      try {
        final response = await http
            .get(Uri.parse('$url/health'))
            .timeout(const Duration(seconds: 5));
        final latency = DateTime.now().difference(startTime).inMilliseconds;
        buffer.writeln(
          '✓ HTTP reachable (${response.statusCode}) — ${latency}ms',
        );
      } catch (e) {
        final latency = DateTime.now().difference(startTime).inMilliseconds;
        buffer.writeln('✗ HTTP unreachable — ${latency}ms — $e');
      }

      // 2. Check /v1/models endpoint
      try {
        final startTime2 = DateTime.now();
        final response = await http
            .get(Uri.parse('$url/v1/models'))
            .timeout(const Duration(seconds: 5));
        final latency = DateTime.now().difference(startTime2).inMilliseconds;

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final models = body['data'] as List<dynamic>?;
          buffer.writeln(
            '✓ /v1/models — ${models?.length ?? 0} models available (${latency}ms)',
          );
          if (models != null && models.isNotEmpty) {
            for (final m in models.take(5)) {
              final id = m['id'] as String? ?? 'unknown';
              buffer.writeln('    • $id');
            }
            if (models.length > 5) {
              buffer.writeln('    ... and ${models.length - 5} more');
            }
          }
        } else {
          buffer.writeln(
            '✗ /v1/models — HTTP ${response.statusCode} (${latency}ms)',
          );
        }
      } catch (e) {
        buffer.writeln('✗ /v1/models — $e');
      }

      // 3. Check /v1/runs endpoint (agent runs)
      try {
        final startTime3 = DateTime.now();
        final response = await http
            .get(Uri.parse('$url/v1/runs'))
            .timeout(const Duration(seconds: 5));
        final latency = DateTime.now().difference(startTime3).inMilliseconds;
        // 405 is expected for GET on a POST endpoint — means it exists
        if (response.statusCode == 405 || response.statusCode == 200) {
          buffer.writeln(
            '✓ /v1/runs — Agent runs endpoint available (${latency}ms)',
          );
        } else {
          buffer.writeln(
            '⚠ /v1/runs — HTTP ${response.statusCode} (${latency}ms)',
          );
        }
      } catch (e) {
        buffer.writeln('✗ /v1/runs — $e');
      }

      // 4. Connection manager status
      if (mounted) {
        final connService =
            Provider.of<ConnectionManagerService>(context, listen: false);
        buffer.writeln('');
        buffer.writeln('━━━ App Connection State ━━━');
        buffer.writeln('Connected: ${connService.isConnected}');
        buffer.writeln(
          'Health: ${connService.healthStatus}',
        );
        buffer.writeln(
            'Preferred: ${connService.preferredConnectionType ?? "auto"}');
        buffer.writeln('Model: ${connService.selectedModel ?? "none"}');
        buffer
            .writeln('Models: ${connService.availableModels.length} available');

        if (connService.lastError != null) {
          buffer.writeln('Last error: ${connService.lastError}');
        }
        if (connService.lastSuccessfulConnection != null) {
          buffer.writeln(
            'Last success: ${connService.lastSuccessfulConnection}',
          );
        }
      }

      buffer.writeln('');
      buffer.writeln('━━━ Complete ━━━');
    } catch (e) {
      buffer.writeln('\nConnection test error: $e');
    }

    if (mounted) {
      setState(() {
        _connectionLog = buffer.toString();
        _isTestingConnection = false;
      });
    }
  }

  /// Send an API request using the inspector.
  Future<void> _sendApiRequest() async {
    final url = _apiUrlController.text.trim();
    if (url.isEmpty) {
      setState(() => _apiResponse = 'Error: URL is required');
      return;
    }

    setState(() {
      _isSendingRequest = true;
      _apiResponse = 'Sending $_apiMethod request...';
    });

    try {
      final uri = Uri.parse(url);
      final startTime = DateTime.now();
      http.Response response;

      switch (_apiMethod) {
        case 'POST':
          final body = _apiBodyController.text.trim();
          response = await http
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: body.isNotEmpty ? body : null,
              )
              .timeout(const Duration(seconds: 10));
          break;
        case 'PUT':
          final body = _apiBodyController.text.trim();
          response = await http
              .put(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: body.isNotEmpty ? body : null,
              )
              .timeout(const Duration(seconds: 10));
          break;
        case 'DELETE':
          response =
              await http.delete(uri).timeout(const Duration(seconds: 10));
          break;
        default:
          response = await http.get(uri).timeout(const Duration(seconds: 10));
      }

      final latency = DateTime.now().difference(startTime).inMilliseconds;
      final bodyPreview = response.body.length > 2000
          ? '${response.body.substring(0, 2000)}\n\n... (truncated, ${response.body.length} chars total)'
          : response.body;

      // Try to pretty-print JSON
      String formattedBody;
      try {
        final decoded = jsonDecode(response.body);
        formattedBody = const JsonEncoder.withIndent('  ').convert(decoded);
        if (formattedBody.length > 3000) {
          formattedBody =
              '${formattedBody.substring(0, 3000)}\n\n... (truncated)';
        }
      } catch (_) {
        formattedBody = bodyPreview;
      }

      if (mounted) {
        setState(() {
          _apiResponse = [
            '$_apiMethod ${response.statusCode} ${response.reasonPhrase} — ${latency}ms',
            '',
            'Headers:',
            ...response.headers.entries
                .take(5)
                .map((e) => '  ${e.key}: ${e.value}'),
            if (response.headers.length > 5)
              '  ... ${response.headers.length - 5} more headers',
            '',
            'Body:',
            formattedBody,
          ].join('\n');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _apiResponse = 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingRequest = false);
      }
    }
  }

  /// Quick-fill the API URL with common endpoints.
  void _quickFillEndpoint(String path) {
    setState(() {
      _apiUrlController.text = '$_gatewayUrl$path';
      if (path.contains('runs') && _apiMethod == 'GET') {
        _apiMethod = 'POST';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final connService = context.watch<ConnectionManagerService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'Refresh',
          ),
          const PopOutButton(sectionName: 'debug', branchIndex: 11),
        ],
      ),
      body: RefreshableScreen(
        onRefresh: _loadData,
        errorMessage: _errorMessage,
        child: _isLoading
            ? const LoadingSkeleton(itemCount: 3)
            : _buildContent(connService),
      ),
    );
  }

  Widget _buildContent(ConnectionManagerService connService) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection status banner
          _buildConnectionBanner(connService),
          const SizedBox(height: 16),

          // Connection Debugger Panel
          _buildConnectionDebugger(),
          const SizedBox(height: 8),

          // API Inspector Panel
          _buildApiInspector(),
          const SizedBox(height: 8),

          // Service Status Panel
          _buildServiceStatus(connService),
        ],
      ),
    );
  }

  Widget _buildConnectionBanner(ConnectionManagerService connService) {
    final isConnected = connService.isConnected;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConnected
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.cloud_done : Icons.cloud_off,
            color: isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Connected to Gateway' : 'Disconnected',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isConnected ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppConfig.defaultGatewayUrl} • ${connService.selectedModel ?? "no model"}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                ),
              ],
            ),
          ),
          StatusBadge(
            status: isConnected ? StatusType.active : StatusType.stopped,
            label: connService.healthStatus ?? 'unknown',
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionDebugger() {
    return Card(
      child: ExpansionTile(
        title: const Text('Connection Debugger'),
        subtitle: const Text('Test Hermes gateway connectivity'),
        leading: const Icon(Icons.wifi_tethering),
        initiallyExpanded: _expandedPanels.contains('connection'),
        onExpansionChanged: (expanded) {
          setState(() {
            if (expanded) {
              _expandedPanels.add('connection');
            } else {
              _expandedPanels.remove('connection');
            }
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  icon: _isTestingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.speed),
                  label: Text(_isTestingConnection
                      ? 'Testing...'
                      : 'Run Connection Test'),
                  onPressed: _isTestingConnection ? null : _testConnection,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(minHeight: 120),
                  child: _connectionLog.isEmpty
                      ? Text(
                          'No tests run yet. Click "Run Connection Test" to check Hermes gateway health.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color),
                        )
                      : SelectableText(
                          _connectionLog,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontFamily: 'monospace', fontSize: 11),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiInspector() {
    return Card(
      child: ExpansionTile(
        title: const Text('API Inspector'),
        subtitle: const Text('Send requests to any endpoint'),
        leading: const Icon(Icons.api),
        initiallyExpanded: _expandedPanels.contains('api'),
        onExpansionChanged: (expanded) {
          setState(() {
            if (expanded) {
              _expandedPanels.add('api');
            } else {
              _expandedPanels.remove('api');
            }
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick-fill chips
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _QuickFillChip(
                      label: '/v1/models',
                      onTap: () => _quickFillEndpoint('/v1/models'),
                    ),
                    _QuickFillChip(
                      label: '/v1/runs',
                      onTap: () => _quickFillEndpoint('/v1/runs'),
                    ),
                    _QuickFillChip(
                      label: '/health',
                      onTap: () => _quickFillEndpoint('/health'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Method + URL row
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: DropdownButtonFormField<String>(
                        initialValue: _apiMethod,
                        decoration: const InputDecoration(
                          labelText: 'Method',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: ['GET', 'POST', 'PUT', 'DELETE']
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _apiMethod = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _apiUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL',
                          border: OutlineInputBorder(),
                          isDense: true,
                          hintText: 'http://localhost:8642/v1/models',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Body (only for POST/PUT)
                if (_apiMethod == 'POST' || _apiMethod == 'PUT') ...[
                  TextField(
                    controller: _apiBodyController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Body (JSON)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: '{"input": "hello", "model": "default"}',
                    ),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                ],

                // Send button
                ElevatedButton.icon(
                  icon: _isSendingRequest
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label:
                      Text(_isSendingRequest ? 'Sending...' : 'Send Request'),
                  onPressed: _isSendingRequest ? null : _sendApiRequest,
                ),
                const SizedBox(height: 12),

                // Response area
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(minHeight: 120),
                  child: _apiResponse.isEmpty
                      ? Text(
                          'No requests sent yet.',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : SelectableText(
                          _apiResponse,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontFamily: 'monospace', fontSize: 11),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceStatus(ConnectionManagerService connService) {
    return Card(
      child: ExpansionTile(
        title: const Text('Service Status'),
        subtitle: const Text('Health checks and diagnostics'),
        leading: const Icon(Icons.health_and_safety),
        initiallyExpanded: _expandedPanels.contains('services'),
        onExpansionChanged: (expanded) {
          setState(() {
            if (expanded) {
              _expandedPanels.add('services');
            } else {
              _expandedPanels.remove('services');
            }
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildServiceTile(
                  name: 'Connection Manager',
                  status:
                      connService.isConnected ? 'Connected' : 'Disconnected',
                  isHealthy: connService.isConnected,
                  details: connService.preferredConnectionType ?? 'auto',
                ),
                const Divider(),
                _buildServiceTile(
                  name: 'Hermes Gateway',
                  status: connService.isConnected ? 'Active' : 'Unreachable',
                  isHealthy: connService.isConnected,
                  details: AppConfig.defaultGatewayUrl,
                ),
                const Divider(),
                _buildServiceTile(
                  name: 'Active Model',
                  status: connService.selectedModel ?? 'None selected',
                  isHealthy: connService.selectedModel != null,
                  details:
                      '${connService.availableModels.length} models available',
                ),
                if (connService.lastError != null) ...[
                  const Divider(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Last error: ${connService.lastError}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.red),
                          ),
                        ),
                      ],
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

  Widget _buildServiceTile({
    required String name,
    required String status,
    required bool isHealthy,
    String? details,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(name),
      subtitle: details != null ? Text(details) : null,
      trailing: StatusBadge(
        status: isHealthy ? StatusType.active : StatusType.stopped,
        label: status,
      ),
    );
  }
}

/// Quick-fill chip for common API endpoints.
class _QuickFillChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickFillChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}
