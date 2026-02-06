import 'package:flutter/material.dart';
import '../services/agent_status_service.dart' show AgentState, AgentStatus, AgentStatusService;

/// Widget state for loading/error scenarios
enum WidgetState {
  loading,  // Initial connection
  success,  // Successfully showing data
  error,    // Connection problem
  empty,    // No agents available (distinct from error)
}

/// Agent Status Widget with improved error handling and loading states
class AgentStatusWidget extends StatefulWidget {
  const AgentStatusWidget({super.key});

  @override
  State<AgentStatusWidget> createState() => _AgentStatusWidgetState();
}

class _AgentStatusWidgetState extends State<AgentStatusWidget> {
  final AgentStatusService _service = AgentStatusService();

  AgentStatus? _currentStatus;
  WidgetState _widgetState = WidgetState.loading;
  String? _errorMessage;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _loadInitialStatus();

    // Listen to status updates
    _service.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
          _widgetState = WidgetState.success;
          _errorMessage = null;
        });
      }
    });

    // Listen to errors
    _service.errorStream.listen((error) {
      if (mounted) {
        setState(() {
          if (_widgetState == WidgetState.loading) {
            _widgetState = WidgetState.error;
          }
          _errorMessage = error;
          _isRetrying = false;
        });
      }
    });
  }

  /// Load initial status
  Future<void> _loadInitialStatus() async {
    setState(() {
      _widgetState = WidgetState.loading;
      _errorMessage = null;
    });

    final status = await _service.fetchStatus();

    if (mounted) {
      setState(() {
        if (status != null) {
          _currentStatus = status;
          _widgetState = WidgetState.success;
        } else {
          // Determine if it's "no agents" or "connection problem"
          if (_service.consecutiveErrors > 0) {
            _widgetState = WidgetState.error;
            _errorMessage = 'Connection failed. Tap Retry to reconnect.';
          } else {
            _widgetState = WidgetState.empty;
          }
        }
      });
    }
  }

  /// User-triggered retry
  Future<void> _retryConnection() async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
      _widgetState = WidgetState.loading;
      _errorMessage = null;
    });

    // Reset error count to allow immediate retry
    _service.resetErrorCount();

    final status = await _service.fetchStatus();

    if (mounted) {
      setState(() {
        if (status != null) {
          _currentStatus = status;
          _widgetState = WidgetState.success;
        } else {
          _widgetState = WidgetState.error;
          _errorMessage = 'Connection failed. Tap Retry to reconnect.';
        }
        _isRetrying = false;
      });
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.psychology, size: 24),
        const SizedBox(width: 8),
        const Text(
          'Agent Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (_service.isBackedOff)
          _buildBackoffBadge(),
      ],
    );
  }

  Widget _buildBackoffBadge() {
    final remainingMs = _service.backoffUntil
        ?.difference(DateTime.now())
        .inMilliseconds
        .clamp(0, 60000);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 14, color: Colors.orange),
          const SizedBox(width: 4),
          Text(
            'Retry in ${remainingMs ?? 0 ~/ 1000}s',
            style: const TextStyle(fontSize: 12, color: Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_widgetState) {
      case WidgetState.loading:
        return _buildLoadingState();
      case WidgetState.success:
        return _buildSuccessState();
      case WidgetState.error:
        return _buildErrorState();
      case WidgetState.empty:
        return _buildEmptyState();
    }
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          _isRetrying ? 'Reconnecting...' : 'Loading agent status...',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    if (_currentStatus == null) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildStatusIcon(_currentStatus!.state),
        const SizedBox(height: 8),
        Text(
          _currentStatus!.message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Updated: ${_formatTimestamp(_currentStatus!.timestamp)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        Icon(
          Icons.error_outline,
          size: 48,
          color: Colors.red[400],
        ),
        const SizedBox(height: 12),
        Text(
          'Connection Problem',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (_errorMessage != null)
          Text(
            _errorMessage!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _isRetrying ? null : _retryConnection,
          icon: _isRetrying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: Text(_isRetrying ? 'Connecting...' : 'Retry'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 48,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 12),
        Text(
          'No Agents Available',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'No agent status data received',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(AgentState state) {
    IconData icon;
    Color color;

    switch (state) {
      case AgentState.idle:
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case AgentState.thinking:
        icon = Icons.psychology;
        color = Colors.blue;
        break;
      case AgentState.busy:
        icon = Icons.build;
        color = Colors.orange;
        break;
      case AgentState.error:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 32,
        color: color,
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }
}
