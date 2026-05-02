library;

import 'package:flutter/material.dart';

import '../../di/locator.dart' as di;
import '../../models/instance.dart';
import '../../services/openclaw_manager/gateway_control_service.dart';
import '../../widgets/common/card_section.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/navigation/popout_button.dart';
import '../../services/connection_manager_service.dart';
import '../../services/hermes/hermes_streaming_service.dart';
import '../../services/settings_preference_service.dart' hide BackendType;
import '../../config/app_config.dart';

/// Screen displaying gateway process state and model instances
///
/// Shows the current status of the OpenClaw Gateway process
/// and all active model instances with their utilization.
class InstancesScreen extends StatefulWidget {
  const InstancesScreen({super.key});

  @override
  State<InstancesScreen> createState() => _InstancesScreenState();
}

class _InstancesScreenState extends State<InstancesScreen> {
  /// Loading state indicator
  bool _isLoading = true;

  /// Error message if data loading fails
  String? _errorMessage;

  /// Gateway process state
  GatewayInstanceState? _gatewayState;

  /// List of model instances
  List<ModelInstanceState> _modelInstances = [];

  late GatewayControlService _gatewayService;

  @override
  void initState() {
    super.initState();
    _gatewayService = di.serviceLocator<GatewayControlService>();
    _gatewayService.addListener(_onGatewayStateChanged);
    _loadData();
  }

  @override
  void dispose() {
    _gatewayService.removeListener(_onGatewayStateChanged);
    super.dispose();
  }

  void _onGatewayStateChanged() {
    if (mounted) {
      _updateGatewayState();
    }
  }

  /// Load all instance data
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Update gateway state from service
      await _updateGatewayState();

      // Load model instances
      await _loadModelInstances();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load instances: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Update gateway state from GatewayControlService
  Future<void> _updateGatewayState() async {
    final serviceState = await _gatewayService.getStatus();

    // Safely parse startedAt - handle both String and DateTime types
    DateTime? parseStartedAt(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    // Safely parse port - handle both int and String types
    int? parsePort(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    _gatewayState = GatewayInstanceState(
      status: serviceState['state']?.toString() ?? 'unknown',
      startedAt: parseStartedAt(serviceState['startedAt']),
      errorMessage: serviceState['errorMessage']?.toString(),
      port: parsePort(serviceState['port']),
    );

    if (mounted) {
      setState(() {});
    }
  }

  /// Load model instances data
  ///
  /// TODO: Replace with actual API integration
  Future<void> _loadModelInstances() async {
    // TODO: Replace with actual API call
    // final instances = await apiService.getModelInstances();

    // Mock data for now
    final instances = _getMockModelInstances();

    if (mounted) {
      setState(() {
        _modelInstances = instances;
      });
    }
  }

  /// Get mock model instances data for testing
  ///
  /// TODO: Remove this method when API integration is complete
  List<ModelInstanceState> _getMockModelInstances() {
    return [
      ModelInstanceState(
        provider: 'zhipu',
        model: 'glm-4',
        status: 'running',
        activeRequests: 1,
        maxConcurrent: 3,
        tier: 'high',
        rateLimited: false,
      ),
      ModelInstanceState(
        provider: 'zhipu',
        model: 'glm-4-flash',
        status: 'running',
        activeRequests: 2,
        maxConcurrent: 10,
        tier: 'medium',
        rateLimited: false,
      ),
      ModelInstanceState(
        provider: 'google',
        model: 'gemini-pro',
        status: 'running',
        activeRequests: 0,
        maxConcurrent: 3,
        tier: 'high',
        rateLimited: false,
      ),
      ModelInstanceState(
        provider: 'google',
        model: 'gemini-flash',
        status: 'idle',
        activeRequests: 0,
        maxConcurrent: 10,
        tier: 'medium',
        rateLimited: false,
      ),
      ModelInstanceState(
        provider: 'moonshot',
        model: 'moonshot-v1-8k',
        status: 'running',
        activeRequests: 1,
        maxConcurrent: 10,
        tier: 'medium',
        rateLimited: false,
      ),
      ModelInstanceState(
        provider: 'openclaw',
        model: 'llava-v1.5-7b',
        status: 'running',
        activeRequests: 0,
        maxConcurrent: 1,
        tier: 'critical',
        rateLimited: false,
      ),
    ];
  }

  /// Format duration for display
  String _formatUptime(Duration? duration) {
    if (duration == null) return 'Not started';

    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Get status badge type from gateway state string
  StatusType _getGatewayStatusType(String status) {
    switch (status.toLowerCase()) {
      case 'running':
        return StatusType.running;
      case 'stopped':
        return StatusType.stopped;
      case 'starting':
        return StatusType.active;
      case 'stopping':
        return StatusType.idle;
      case 'error':
        return StatusType.error;
      default:
        return StatusType.unknown;
    }
  }

  /// Get status badge type from model status string
  StatusType _getModelStatusType(String status) {
    switch (status.toLowerCase()) {
      case 'running':
      case 'active':
        return StatusType.running;
      case 'idle':
        return StatusType.idle;
      case 'error':
        return StatusType.error;
      case 'stopped':
        return StatusType.stopped;
      default:
        return StatusType.unknown;
    }
  }

  /// Handle gateway start action
  Future<void> _handleStartGateway() async {
    final success = await _gatewayService.start();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start gateway')),
      );
    }
  }

  /// Handle gateway stop action
  Future<void> _handleStopGateway() async {
    final success = await _gatewayService.stop();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to stop gateway')),
      );
    }
  }

  /// Handle gateway restart action
  Future<void> _handleRestartGateway() async {
    final success = await _gatewayService.restart();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to restart gateway')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instances'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh instances',
            onPressed: _isLoading ? null : _loadData,
          ),
          const PopOutButton(
            sectionName: 'instances',
            branchIndex: 3,
          ),
        ],
      ),
      body: RefreshableScreen(
        onRefresh: _loadData,
        errorMessage: _errorMessage,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingSkeleton(
        itemCount: 5,
        height: 120,
      );
    }

    if (_errorMessage != null) {
      return ErrorState(
        message: _errorMessage!,
        onRetry: _loadData,
      );
    }

    if (_gatewayState == null) {
      return const Center(
        child: Text('No gateway state available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Gateway Process Section
          CardSection(
            title: 'Gateway Process',
            children: [
              _GatewayStateCard(
                gatewayState: _gatewayState!,
                formatUptime: _formatUptime,
                getStatusType: _getGatewayStatusType,
                onStart: _handleStartGateway,
                onStop: _handleStopGateway,
                onRestart: _handleRestartGateway,
              ),
            ],
          ),

          // Hermes Agent Section
          const _HermesSettingsCard(),

          // Model Instances Section
          CardSection(
            title: 'Model Instances',
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _modelInstances.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final instance = _modelInstances[index];
                  return _ModelInstanceCard(
                    instance: instance,
                    getStatusType: _getModelStatusType,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card widget for displaying gateway process state
class _GatewayStateCard extends StatelessWidget {
  final GatewayInstanceState gatewayState;
  final String Function(Duration?) formatUptime;
  final StatusType Function(String) getStatusType;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRestart;

  const _GatewayStateCard({
    required this.gatewayState,
    required this.formatUptime,
    required this.getStatusType,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusType = getStatusType(gatewayState.status);
    final isRunning = gatewayState.status.toLowerCase() == 'running';
    final isStarting = gatewayState.status.toLowerCase() == 'starting';
    final isStopping = gatewayState.status.toLowerCase() == 'stopping';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              StatusBadge(
                status: statusType,
                label: gatewayState.status.toUpperCase(),
              ),
              const SizedBox(width: 16),
              if (gatewayState.port != null) ...[
                Icon(
                  Icons.cable,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  'Port ${gatewayState.port}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Uptime display
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                'Uptime: ${formatUptime(gatewayState.uptime)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),

          // Error message if any
          if (gatewayState.errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      gatewayState.errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Control buttons
          const SizedBox(height: 16),
          Row(
            children: [
              if (!isRunning && !isStarting) ...[
                ElevatedButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
                const SizedBox(width: 8),
              ],
              if (isRunning) ...[
                ElevatedButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer,
                    foregroundColor: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Restart'),
                ),
              ],
              if (isStarting || isStopping) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  isStarting ? 'Starting...' : 'Stopping...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Card widget for displaying a single model instance
class _ModelInstanceCard extends StatelessWidget {
  final ModelInstanceState instance;
  final StatusType Function(String) getStatusType;

  const _ModelInstanceCard({
    required this.instance,
    required this.getStatusType,
  });

  /// Get tier badge color
  Color _getTierColor(String tier, ThemeData theme) {
    switch (tier.toLowerCase()) {
      case 'critical':
        return theme.colorScheme.error;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'unlimited':
        return Colors.green;
      default:
        return theme.colorScheme.onSurface.withValues(alpha: 0.4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusType = getStatusType(instance.status);
    final utilization = instance.maxConcurrent > 0
        ? instance.activeRequests / instance.maxConcurrent
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with model name and status
            Row(
              children: [
                // Provider icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      instance.provider.isNotEmpty
                          ? instance.provider.substring(0, 1).toUpperCase()
                          : '?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Model name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        instance.model,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        instance.provider,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Status badge
                StatusBadge(
                  status: statusType,
                  label: instance.status.toUpperCase(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats row
            Row(
              children: [
                // Requests counter
                Expanded(
                  child: _StatItem(
                    icon: Icons.sync,
                    label: 'Requests',
                    value:
                        '${instance.activeRequests}/${instance.maxConcurrent}',
                  ),
                ),

                // Tier badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTierColor(instance.tier, theme)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getTierColor(instance.tier, theme),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    instance.tier.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _getTierColor(instance.tier, theme),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Rate limited indicator
                if (instance.rateLimited) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.block,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                ],
              ],
            ),

            // Progress bar
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: utilization,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                utilization > 0.9
                    ? theme.colorScheme.error
                    : utilization > 0.7
                        ? Colors.orange
                        : theme.colorScheme.primary,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 4),
            Text(
              '${(utilization * 100).toInt()}% utilized',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stat item widget for displaying key-value pairs
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Hermes Agent Settings Card
// =============================================================================

class _HermesSettingsCard extends StatefulWidget {
  const _HermesSettingsCard();

  @override
  State<_HermesSettingsCard> createState() => _HermesSettingsCardState();
}

class _HermesSettingsCardState extends State<_HermesSettingsCard> {
  final SettingsPreferenceService _settings = SettingsPreferenceService();

  bool _hermesEnabled = false;
  bool _isLoading = true;
  bool _isTesting = false;
  bool? _connectionStatus;
  String _url = AppConfig.defaultHermesUrl;
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _settings.isHermesEnabled();
    final url = await _settings.getHermesUrl();
    final apiKey = await _settings.getHermesApiKey();
    if (mounted) {
      setState(() {
        _hermesEnabled = enabled;
        _url = url ?? AppConfig.defaultHermesUrl;
        _apiKey = apiKey ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    try {
      final service = HermesStreamingService(
        baseUrl: _url,
        apiKey: _apiKey.isNotEmpty ? _apiKey : null,
      );
      final ok = await service.testConnection();
      service.dispose();
      if (mounted) {
        setState(() {
          _connectionStatus = ok;
          _isTesting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _connectionStatus = false;
          _isTesting = false;
        });
      }
    }
  }

  Future<void> _saveAndApply() async {
    await _settings.setHermesEnabled(_hermesEnabled);
    await _settings.setHermesUrl(_url);
    await _settings.setHermesApiKey(_apiKey);

    // Update connection manager
    try {
      final connectionManager = di.serviceLocator<ConnectionManagerService>();
      if (_hermesEnabled) {
        connectionManager.configureHermesRuntime(
          url: _url,
          apiKey: _apiKey,
        );
        connectionManager.setPreferredConnectionType(ConnectionType.hermes);
      } else {
        connectionManager.setPreferredConnectionType(ConnectionType.local);
      }
    } catch (_) {
      // Connection manager may not be available in all contexts
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_hermesEnabled
              ? 'Hermes Agent enabled — chat will use Hermes'
              : 'Switched back to default gateway'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CardSection(
        title: '🦞 Hermes Agent',
        children: [
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    return CardSection(
      title: '🦞 Hermes Agent',
      subtitle: _hermesEnabled
          ? 'Active — routing chat through Hermes API server'
          : 'Disabled — using default OpenClaw gateway',
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enable toggle
              SwitchListTile(
                title: const Text('Enable Hermes Agent'),
                subtitle: const Text(
                  'Route chat through Hermes for tool use, file ops, web search, and code execution',
                ),
                value: _hermesEnabled,
                onChanged: (v) => setState(() => _hermesEnabled = v),
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 16),

              // URL field
              TextField(
                decoration: InputDecoration(
                  labelText: 'Hermes API URL',
                  hintText: AppConfig.defaultHermesUrl,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: _connectionStatus == true
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : _connectionStatus == false
                          ? const Icon(Icons.error, color: Colors.red)
                          : null,
                ),
                controller: TextEditingController(text: _url),
                onChanged: (v) => _url = v,
                enabled: _hermesEnabled,
              ),

              const SizedBox(height: 12),

              // API key field
              TextField(
                decoration: const InputDecoration(
                  labelText: 'API Key (optional)',
                  hintText: 'Leave empty for local-only use',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
                controller: TextEditingController(text: _apiKey),
                onChanged: (v) => _apiKey = v,
                obscureText: true,
                enabled: _hermesEnabled,
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _hermesEnabled && !_isTesting ? _testConnection : null,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find),
                    label: const Text('Test Connection'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _saveAndApply,
                    icon: const Icon(Icons.save),
                    label: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
