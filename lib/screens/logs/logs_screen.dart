/// Screen for viewing and filtering system logs.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/navigation/popout_button.dart';
import '../../models/log_entry.dart';

// TODO: Uncomment when integrating with actual services
// import '../../services/logging_service.dart';
// import '../../di/locator.dart' as di;

/// Screen displaying system logs with filtering and search.
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<LogEntry> _logs = [];
  List<LogEntry> _filteredLogs = [];

  // Filter state
  LogSeverity? _selectedSeverity;
  String _searchQuery = '';
  String? _selectedSource;

  // TODO: Integrate with actual services
  // final LoggingService _loggingService = di.serviceLocator<LoggingService>();

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Simulate data loading
      await Future.delayed(const Duration(milliseconds: 300));

      // TODO: Fetch from LoggingService
      // _logs = await _loggingService.getLogs();

      // Mock data for now
      _logs = _getMockLogs();
      _applyFilters();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load logs: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  void _applyFilters() {
    _filteredLogs = _logs.where((log) {
      // Severity filter
      if (_selectedSeverity != null && log.severity != _selectedSeverity) {
        return false;
      }

      // Source filter
      if (_selectedSource != null && log.source != _selectedSource) {
        return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return log.message.toLowerCase().contains(query) ||
            log.source.toLowerCase().contains(query) ||
            (log.errorDetails?.toLowerCase().contains(query) ?? false);
      }

      return true;
    }).toList();
  }

  Future<void> _exportLogs() async {
    // TODO: Implement export via LoggingService
    final logsText = _filteredLogs.map((log) {
      final timestamp = '${log.formatDate()} ${log.formatTimestamp()}';
      final severity = log.severityLabel.padRight(8);
      return '[$timestamp] [$severity] [${log.source}] ${log.message}';
    }).join('\n');

    await Clipboard.setData(ClipboardData(text: logsText));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logs copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  List<LogEntry> _getMockLogs() {
    final now = DateTime.now();
    return [
      LogEntry(
        id: '1',
        timestamp: now.subtract(const Duration(minutes: 1)),
        severity: LogSeverity.info,
        source: 'Gateway',
        message: 'Gateway connection established',
      ),
      LogEntry(
        id: '2',
        timestamp: now.subtract(const Duration(minutes: 2)),
        severity: LogSeverity.info,
        source: 'Router',
        message: 'LLM request completed: glm-4 (2.3s)',
      ),
      LogEntry(
        id: '3',
        timestamp: now.subtract(const Duration(minutes: 5)),
        severity: LogSeverity.warning,
        source: 'ProviderDiscovery',
        message: 'OpenClaw Gateway not responding',
        errorDetails: 'Connection timeout after 5s',
      ),
      LogEntry(
        id: '4',
        timestamp: now.subtract(const Duration(minutes: 10)),
        severity: LogSeverity.error,
        source: 'Tunnel',
        message: 'SSH tunnel connection failed',
        errorDetails: 'Authentication failed for user tunnel-user',
        stackTrace:
            'at SSHConnection.connect (ssh.dart:245)\nat TunnelService.establish (tunnel_service.dart:89)',
      ),
      LogEntry(
        id: '5',
        timestamp: now.subtract(const Duration(minutes: 15)),
        severity: LogSeverity.info,
        source: 'Avatar',
        message: 'Personality traits updated: formality +0.1',
      ),
      LogEntry(
        id: '6',
        timestamp: now.subtract(const Duration(minutes: 20)),
        severity: LogSeverity.debug,
        source: 'Router',
        message: 'Rate limit check: 1/1 requests allowed for glm-4',
      ),
      LogEntry(
        id: '7',
        timestamp: now.subtract(const Duration(minutes: 25)),
        severity: LogSeverity.critical,
        source: 'Database',
        message: 'Connection pool exhausted',
        errorDetails: 'No available connections in pool (max: 10)',
        stackTrace:
            'at Pool.acquire (pool.dart:123)\nat Database.query (database.dart:456)',
      ),
      LogEntry(
        id: '8',
        timestamp: now.subtract(const Duration(minutes: 30)),
        severity: LogSeverity.info,
        source: 'Cron',
        message: 'Job "Database Backup" completed successfully',
      ),
      LogEntry(
        id: '9',
        timestamp: now.subtract(const Duration(minutes: 35)),
        severity: LogSeverity.warning,
        source: 'Memory',
        message: 'Memory usage high: 85% (1.7GB/2GB)',
      ),
      LogEntry(
        id: '10',
        timestamp: now.subtract(const Duration(minutes: 40)),
        severity: LogSeverity.info,
        source: 'Agent',
        message: 'Agent "CodeReviewer" task completed',
      ),
    ];
  }

  List<String> get _availableSources {
    return _logs.map((log) => log.source).toSet().toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshableScreen(
      onRefresh: _onRefresh,
      errorMessage: _errorMessage,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Logs'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _onRefresh,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportLogs,
              tooltip: 'Export Logs',
            ),
            const PopOutButton(sectionName: 'logs', branchIndex: 12),
          ],
        ),
        body: _isLoading
            ? const LoadingSkeleton(itemCount: 5, height: 80)
            : _errorMessage != null
                ? ErrorState(message: _errorMessage!, onRetry: _onRefresh)
                : Column(
                    children: [
                      _buildFilters(),
                      Expanded(
                        child: _filteredLogs.isEmpty
                            ? EmptyState(
                                icon: Icons.search_off,
                                title: 'No logs found',
                                message: _searchQuery.isNotEmpty ||
                                        _selectedSeverity != null ||
                                        _selectedSource != null
                                    ? 'Try adjusting your filters'
                                    : 'No logs available',
                              )
                            : _buildLogsList(),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildFilters() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search logs...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _applyFilters();
                        });
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilters();
              });
            },
          ),
          const SizedBox(height: 12),
          // Filter chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Severity filter
              FilterChip(
                label: const Text('Severity'),
                selected: _selectedSeverity != null,
                onSelected: (selected) {
                  setState(() {
                    _selectedSeverity = selected ? LogSeverity.info : null;
                    _applyFilters();
                  });
                },
                avatar: _selectedSeverity != null
                    ? Icon(
                        _getSeverityIcon(_selectedSeverity!),
                        size: 18,
                      )
                    : null,
              ),
              // Source filter
              FilterChip(
                label: const Text('Source'),
                selected: _selectedSource != null,
                onSelected: (selected) {
                  _showSourceFilter();
                },
                avatar: _selectedSource != null
                    ? const Icon(Icons.business, size: 18)
                    : null,
              ),
              // Clear all filters
              if (_selectedSeverity != null ||
                  _selectedSource != null ||
                  _searchQuery.isNotEmpty)
                ActionChip(
                  label: const Text('Clear All'),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedSeverity = null;
                      _selectedSource = null;
                      _applyFilters();
                    });
                  },
                  avatar: const Icon(Icons.clear_all, size: 18),
                ),
              // Results count
              Chip(
                label: Text('${_filteredLogs.length} / ${_logs.length}'),
                avatar: const Icon(Icons.filter_list, size: 18),
              ),
            ],
          ),
          // Severity chips
          if (_selectedSeverity != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                children: LogSeverity.values.map((severity) {
                  final isSelected = _selectedSeverity == severity;
                  return FilterChip(
                    label: Text(severity.name.toUpperCase()),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSeverity = selected ? severity : null;
                        _applyFilters();
                      });
                    },
                    selectedColor:
                        _getSeverityColor(severity).withValues(alpha: 0.3),
                    checkmarkColor: _getSeverityColor(severity),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredLogs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final log = _filteredLogs[index];
        return _buildLogCard(log);
      },
    );
  }

  Widget _buildLogCard(LogEntry log) {
    final theme = Theme.of(context);
    final severityColor = log.getSeverityColor(context);

    return Card(
      elevation: 1,
      child: InkWell(
        onTap: log.hasErrorDetails ? () => _showLogDetails(log) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Severity icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  log.severityIcon,
                  size: 20,
                  color: severityColor,
                ),
              ),
              const SizedBox(width: 12),
              // Log content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        Text(
                          log.formatTimestamp(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          status: log.severity == LogSeverity.critical
                              ? StatusType.error
                              : log.severity == LogSeverity.error
                                  ? StatusType.error
                                  : log.severity == LogSeverity.warning
                                      ? StatusType.idle
                                      : StatusType.running,
                          label: log.severityLabel,
                          showIcon: false,
                        ),
                        const Spacer(),
                        Text(
                          log.source,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Message
                    Text(
                      log.message,
                      style: theme.textTheme.bodyMedium,
                    ),
                    // Error indicator
                    if (log.hasErrorDetails) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.expand_more,
                            size: 16,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'View details',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogDetails(LogEntry log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(log.severityIcon, color: log.getSeverityColor(context)),
            const SizedBox(width: 8),
            Text('Log Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow(
                  'Timestamp', '${log.formatDate()} ${log.formatTimestamp()}'),
              _detailRow('Severity', log.severityLabel),
              _detailRow('Source', log.source),
              const Divider(),
              const Text('Message',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(log.message),
              if (log.errorDetails != null) ...[
                const Divider(),
                const Text('Error',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  log.errorDetails!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (log.stackTrace != null) ...[
                const Divider(),
                const Text('Stack Trace',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  log.stackTrace!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showSourceFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Source'),
        content: RadioGroup<String>(
          groupValue: _selectedSource,
          onChanged: (value) {
            setState(() {
              _selectedSource = value;
              _applyFilters();
            });
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _availableSources.map((source) {
              return RadioListTile<String>(
                title: Text(source),
                value: source,
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedSource = null;
                _applyFilters();
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  IconData _getSeverityIcon(LogSeverity severity) {
    switch (severity) {
      case LogSeverity.debug:
        return Icons.bug_report_outlined;
      case LogSeverity.info:
        return Icons.info_outline;
      case LogSeverity.warning:
        return Icons.warning_outlined;
      case LogSeverity.error:
        return Icons.error_outline;
      case LogSeverity.critical:
        return Icons.dangerous;
    }
  }

  Color _getSeverityColor(LogSeverity severity) {
    switch (severity) {
      case LogSeverity.debug:
        return Colors.grey;
      case LogSeverity.info:
        return Colors.blue;
      case LogSeverity.warning:
        return Colors.orange;
      case LogSeverity.error:
        return Colors.red;
      case LogSeverity.critical:
        return Colors.red.shade700;
    }
  }
}
