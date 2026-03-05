library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/connection_manager_service.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/navigation/popout_button.dart';

/// Debug screen for troubleshooting and diagnostics
///
/// Provides tools for connection testing, API inspection, and service status.
/// TODO: Implement actual debugging functionality
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  /// Loading state indicator
  bool _isLoading = false;

  /// Error message if data loading fails
  String? _errorMessage;

  /// Set of expanded panel keys
  final Set<String> _expandedPanels = {};

  /// Connection test log
  String _connectionLog = '';

  /// API request response
  String _apiResponse = '';

  /// API request method
  String _apiMethod = 'GET';

  /// API request URL controller
  final TextEditingController _apiUrlController = TextEditingController();

  /// API request body controller
  final TextEditingController _apiBodyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiBodyController.dispose();
    super.dispose();
  }

  /// Load debug data
  ///
  /// TODO: Replace with actual diagnostic data collection
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Simulate data loading
      await Future.delayed(const Duration(milliseconds: 300));

      // TODO: Collect actual service status and diagnostics
      // await connectionManager.runDiagnostics();

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
        children: [
          // Connection Debugger Panel
          ExpansionTile(
            title: const Text('Connection Debugger'),
            subtitle: const Text('Test WebSocket and HTTP connections'),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.speed),
                          label: const Text('Test Connection'),
                          onPressed: () async {
                            final startTime = DateTime.now();
                            try {
                              // TODO: Actual connection test
                              await Future.delayed(const Duration(milliseconds: 100));
                              final latency = DateTime.now().difference(startTime).inMilliseconds;
                              if (mounted) {
                                setState(() {
                                  _connectionLog = 'Connection test completed: ${latency}ms latency';
                                });
                              }
                            } catch (e) {
                              if (mounted) {
                                setState(() {
                                  _connectionLog = 'Connection test failed: $e';
                                });
                              }
                            }
                          },
                        ),
                        const SizedBox(width: 16),
                        Text(_connectionLog.isEmpty ? 'Ready' : _connectionLog),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Connection Log:'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      height: 100,
                      child: _connectionLog.isEmpty
                          ? const Center(child: Text('No connection attempts yet'))
                          : Text(_connectionLog),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // API Inspector Panel
          ExpansionTile(
            title: const Text('API Inspector'),
            subtitle: const Text('Request builder and response viewer'),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _apiMethod,
                      decoration: const InputDecoration(
                        labelText: 'Method',
                        border: OutlineInputBorder(),
                      ),
                      items: ['GET', 'POST', 'PUT', 'DELETE']
                          .map<DropdownMenuItem<String>>((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _apiMethod = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _apiUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL',
                        border: OutlineInputBorder(),
                        hintText: 'https://api.example.com/endpoint',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _apiBodyController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Body (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text('Send Request'),
                      onPressed: () async {
                        if (_apiUrlController.text.isEmpty) {
                          if (mounted) {
                            setState(() {
                              _apiResponse = 'Error: URL is required';
                            });
                          }
                          return;
                        }
                        setState(() {
                          _apiResponse = 'Sending...';
                        });
                        try {
                          // TODO: Actual API request
                          await Future.delayed(const Duration(milliseconds: 500));
                          if (mounted) {
                            setState(() {
                              _apiResponse = 'Response: 200 OK\n${DateTime.now()}';
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              _apiResponse = 'Error: $e';
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Response:'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      height: 100,
                      child: _apiResponse.isEmpty
                          ? const Center(child: Text('No requests sent yet'))
                          : Text(_apiResponse),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Service Status Panel
          ExpansionTile(
            title: const Text('Service Status'),
            subtitle: const Text('Health checks and restart controls'),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildServiceTile(
                      'Connection Manager',
                      connService.isConnected ? 'Connected' : 'Disconnected',
                      connService.isConnected,
                    ),
                    const Divider(),
                    _buildServiceTile('Router Server', 'Active', true),
                    const Divider(),
                    _buildServiceTile('Tunnel Service', 'Not connected', false),
                    const SizedBox(height: 8),
                    const Text(
                      'TODO: Integrate with all services',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTile(String name, String status, bool isHealthy) {
    return ListTile(
      title: Text(name),
      subtitle: Text(status),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusBadge(
            status: isHealthy ? StatusType.active : StatusType.stopped,
            label: status,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: () {
              // TODO: Implement service restart
              debugPrint('Restart service: $name');
            },
            tooltip: 'Restart service',
          ),
        ],
      ),
    );
  }
}
