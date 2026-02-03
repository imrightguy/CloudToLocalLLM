import 'package:flutter/material.dart';
import '../../di/locator.dart' as di;
import 'dart:async';
import 'dart:convert';
import '../../services/admin_center_service.dart';
import '../../models/admin_audit_log_model.dart';

/// Audit Log Viewer Tab for Admin Center
///
/// Displays paginated audit log table with comprehensive filtering:
/// - Date range filtering
/// - Admin user filtering
/// - Action type filtering
/// - Affected user filtering
/// - Severity filtering
///
/// Features:
/// - Paginated audit log table
/// - Advanced filtering capabilities
/// - Log detail modal with JSON formatting
/// - CSV export functionality
/// - Real-time log updates
class AuditLogViewerTab extends StatefulWidget {
  const AuditLogViewerTab({super.key});

  @override
  State<AuditLogViewerTab> createState() => _AuditLogViewerTabState();
}

class _AuditLogViewerTabState extends State<AuditLogViewerTab> {
  // Pagination
  int _currentPage = 1;
  final int _itemsPerPage = 100;
  int _totalLogs = 0;
  int _totalPages = 0;

  // Data
  List<AdminAuditLogModel> _logs = [];
  bool _isLoading = false;
  String? _error;

  // Filters
  String? _selectedAdminUserId;
  String? _selectedAction;
  String? _selectedResourceType;
  String? _selectedAffectedUserId;
  DateTime? _startDate;
  DateTime? _endDate;
  AuditLogSeverity? _selectedSeverity;
  final String _sortBy = 'created_at';
  final String _sortOrder = 'desc';

  // Controllers
  final TextEditingController _adminUserIdController = TextEditingController();
  final TextEditingController _affectedUserIdController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  @override
  void dispose() {
    _adminUserIdController.dispose();
    _affectedUserIdController.dispose();
    super.dispose();
  }

  /// Load audit logs with current filters
  Future<void> _loadAuditLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final adminService = di.serviceLocator.get<AdminCenterService>();
      final response = await adminService.getAuditLogs(
        page: _currentPage,
        limit: _itemsPerPage,
        adminUserId: _selectedAdminUserId,
        action: _selectedAction,
        resourceType: _selectedResourceType,
        affectedUserId: _selectedAffectedUserId,
        startDate: _startDate,
        endDate: _endDate,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      );

      final data = response['data'] as Map<String, dynamic>;
      final logsData = data['logs'] as List;
      final pagination = data['pagination'] as Map<String, dynamic>;

      final logs =
          logsData.map((json) => AdminAuditLogModel.fromJson(json)).toList();

      // Filter by severity if selected (client-side filtering)
      final filteredLogs = _selectedSeverity != null
          ? logs.where((log) => log.severity == _selectedSeverity).toList()
          : logs;

      setState(() {
        _logs = filteredLogs;
        _totalLogs = pagination['totalLogs'] as int;
        _totalPages = pagination['totalPages'] as int;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Show log detail modal
  void _showLogDetail(AdminAuditLogModel log) async {
    try {
      final adminService = di.serviceLocator.get<AdminCenterService>();
      final response = await adminService.getAuditLogDetails(log.id);
      final logData = response['data']['log'] as Map<String, dynamic>;

      if (!mounted) return;

      unawaited(showDialog(
        context: context,
        builder: (context) => _LogDetailDialog(logData: logData),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load log details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Export audit logs to CSV
  Future<void> _exportLogs() async {
    try {
      final adminService = di.serviceLocator.get<AdminCenterService>();
      await adminService.exportAuditLogs(
        adminUserId: _selectedAdminUserId,
        action: _selectedAction,
        resourceType: _selectedResourceType,
        affectedUserId: _selectedAffectedUserId,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audit logs exported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export logs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Show filter dialog
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        adminUserId: _selectedAdminUserId,
        action: _selectedAction,
        resourceType: _selectedResourceType,
        affectedUserId: _selectedAffectedUserId,
        startDate: _startDate,
        endDate: _endDate,
        severity: _selectedSeverity,
        onApply: (filters) {
          setState(() {
            _selectedAdminUserId = filters['adminUserId'];
            _selectedAction = filters['action'];
            _selectedResourceType = filters['resourceType'];
            _selectedAffectedUserId = filters['affectedUserId'];
            _startDate = filters['startDate'];
            _endDate = filters['endDate'];
            _selectedSeverity = filters['severity'];
            _currentPage = 1;
          });
          _loadAuditLogs();
        },
      ),
    );
  }

  /// Clear all filters
  void _clearFilters() {
    setState(() {
      _selectedAdminUserId = null;
      _selectedAction = null;
      _selectedResourceType = null;
      _selectedAffectedUserId = null;
      _startDate = null;
      _endDate = null;
      _selectedSeverity = null;
      _currentPage = 1;
    });
    _loadAuditLogs();
  }

  /// Get active filter count
  int get _activeFilterCount {
    int count = 0;
    if (_selectedAdminUserId != null) count++;
    if (_selectedAction != null) count++;
    if (_selectedResourceType != null) count++;
    if (_selectedAffectedUserId != null) count++;
    if (_startDate != null) count++;
    if (_endDate != null) count++;
    if (_selectedSeverity != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with filters and export
        _buildHeader(),
        const SizedBox(height: 16),

        // Active filters chips
        if (_activeFilterCount > 0) ...[
          _buildActiveFilters(),
          const SizedBox(height: 16),
        ],

        // Audit log table
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : _logs.isEmpty
                      ? _buildEmptyState()
                      : _buildLogsTable(),
        ),

        // Pagination
        if (_totalPages > 1) ...[const Divider(), _buildPagination()],
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Title
        const Text(
          'Audit Logs',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const Spacer(),

        // Filter button
        Badge(
          label: Text('$_activeFilterCount'),
          isLabelVisible: _activeFilterCount > 0,
          child: OutlinedButton.icon(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
            label: const Text('Filters'),
          ),
        ),
        const SizedBox(width: 8),

        // Clear filters button
        if (_activeFilterCount > 0)
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
          ),
        const SizedBox(width: 8),

        // Export button
        ElevatedButton.icon(
          onPressed: _exportLogs,
          icon: const Icon(Icons.download),
          label: const Text('Export CSV'),
        ),
        const SizedBox(width: 8),

        // Refresh button
        IconButton(
          onPressed: _loadAuditLogs,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildActiveFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_selectedAdminUserId != null)
          Chip(
            label: Text('Admin: $_selectedAdminUserId'),
            onDeleted: () {
              setState(() => _selectedAdminUserId = null);
              _loadAuditLogs();
            },
          ),
        if (_selectedAction != null)
          Chip(
            label: Text('Action: $_selectedAction'),
            onDeleted: () {
              setState(() => _selectedAction = null);
              _loadAuditLogs();
            },
          ),
        if (_selectedResourceType != null)
          Chip(
            label: Text('Resource: $_selectedResourceType'),
            onDeleted: () {
              setState(() => _selectedResourceType = null);
              _loadAuditLogs();
            },
          ),
        if (_selectedAffectedUserId != null)
          Chip(
            label: Text('Affected User: $_selectedAffectedUserId'),
            onDeleted: () {
              setState(() => _selectedAffectedUserId = null);
              _loadAuditLogs();
            },
          ),
        if (_startDate != null)
          Chip(
            label: Text(
              'From: ${_startDate!.toLocal().toString().split(' ')[0]}',
            ),
            onDeleted: () {
              setState(() => _startDate = null);
              _loadAuditLogs();
            },
          ),
        if (_endDate != null)
          Chip(
            label: Text('To: ${_endDate!.toLocal().toString().split(' ')[0]}'),
            onDeleted: () {
              setState(() => _endDate = null);
              _loadAuditLogs();
            },
          ),
        if (_selectedSeverity != null)
          Chip(
            label: Text('Severity: ${_selectedSeverity!.displayName}'),
            onDeleted: () {
              setState(() => _selectedSeverity = null);
              _loadAuditLogs();
            },
          ),
      ],
    );
  }

  Widget _buildLogsTable() {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Timestamp')),
              DataColumn(label: Text('Action')),
              DataColumn(label: Text('Resource')),
              DataColumn(label: Text('Admin')),
              DataColumn(label: Text('Affected User')),
              DataColumn(label: Text('Severity')),
              DataColumn(label: Text('IP Address')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _logs.map((log) {
              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          log.createdAt.toLocal().toString().split('.')[0],
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          log.timeAgo,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(log.actionDisplayName),
                        Text(
                          log.actionCategory,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(log.resourceTypeDisplayName),
                        Text(
                          log.resourceId,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(log.adminUserId)),
                  DataCell(Text(log.affectedUserId ?? '-')),
                  DataCell(
                    Chip(
                      label: Text(
                        log.severity.displayName,
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: _getSeverityColor(log.severity),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  DataCell(Text(log.ipAddress ?? '-')),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 20),
                      onPressed: () => _showLogDetail(log),
                      tooltip: 'View Details',
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor(AuditLogSeverity severity) {
    switch (severity) {
      case AuditLogSeverity.low:
        return Colors.green.withValues(alpha: 0.2);
      case AuditLogSeverity.medium:
        return Colors.orange.withValues(alpha: 0.2);
      case AuditLogSeverity.high:
        return Colors.red.withValues(alpha: 0.2);
    }
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${(_currentPage - 1) * _itemsPerPage + 1}-${(_currentPage * _itemsPerPage).clamp(0, _totalLogs)} of $_totalLogs logs',
            style: TextStyle(color: Colors.grey[600]),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 1
                    ? () {
                        setState(() => _currentPage--);
                        _loadAuditLogs();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Page $_currentPage of $_totalPages'),
              IconButton(
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() => _currentPage++);
                        _loadAuditLogs();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $_error'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadAuditLogs, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No audit logs found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          if (_activeFilterCount > 0) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Filter Dialog for Audit Logs
class _FilterDialog extends StatefulWidget {
  final String? adminUserId;
  final String? action;
  final String? resourceType;
  final String? affectedUserId;
  final DateTime? startDate;
  final DateTime? endDate;
  final AuditLogSeverity? severity;
  final Function(Map<String, dynamic>) onApply;

  const _FilterDialog({
    this.adminUserId,
    this.action,
    this.resourceType,
    this.affectedUserId,
    this.startDate,
    this.endDate,
    this.severity,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late TextEditingController _adminUserIdController;
  late TextEditingController _actionController;
  late TextEditingController _resourceTypeController;
  late TextEditingController _affectedUserIdController;
  DateTime? _startDate;
  DateTime? _endDate;
  AuditLogSeverity? _severity;

  @override
  void initState() {
    super.initState();
    _adminUserIdController = TextEditingController(text: widget.adminUserId);
    _actionController = TextEditingController(text: widget.action);
    _resourceTypeController = TextEditingController(text: widget.resourceType);
    _affectedUserIdController = TextEditingController(
      text: widget.affectedUserId,
    );
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _severity = widget.severity;
  }

  @override
  void dispose() {
    _adminUserIdController.dispose();
    _actionController.dispose();
    _resourceTypeController.dispose();
    _affectedUserIdController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Audit Logs'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Admin User ID
              TextField(
                controller: _adminUserIdController,
                decoration: const InputDecoration(
                  labelText: 'Admin User ID',
                  hintText: 'Filter by admin user ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Action
              TextField(
                controller: _actionController,
                decoration: const InputDecoration(
                  labelText: 'Action',
                  hintText: 'e.g., user_suspended, refund_processed',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Resource Type
              TextField(
                controller: _resourceTypeController,
                decoration: const InputDecoration(
                  labelText: 'Resource Type',
                  hintText: 'e.g., user, subscription, transaction',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Affected User ID
              TextField(
                controller: _affectedUserIdController,
                decoration: const InputDecoration(
                  labelText: 'Affected User ID',
                  hintText: 'Filter by affected user ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Date Range
              const Text(
                'Date Range',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context, true),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _startDate != null
                            ? _startDate!.toLocal().toString().split(' ')[0]
                            : 'Start Date',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context, false),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _endDate != null
                            ? _endDate!.toLocal().toString().split(' ')[0]
                            : 'End Date',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Severity
              const Text(
                'Severity',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<AuditLogSeverity>(
                initialValue: _severity,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'All severities',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All severities'),
                  ),
                  ...AuditLogSeverity.values.map((severity) {
                    return DropdownMenuItem(
                      value: severity,
                      child: Text(severity.displayName),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => _severity = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            // Clear all filters
            _adminUserIdController.clear();
            _actionController.clear();
            _resourceTypeController.clear();
            _affectedUserIdController.clear();
            setState(() {
              _startDate = null;
              _endDate = null;
              _severity = null;
            });
          },
          child: const Text('Clear All'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply({
              'adminUserId': _adminUserIdController.text.trim().isEmpty
                  ? null
                  : _adminUserIdController.text.trim(),
              'action': _actionController.text.trim().isEmpty
                  ? null
                  : _actionController.text.trim(),
              'resourceType': _resourceTypeController.text.trim().isEmpty
                  ? null
                  : _resourceTypeController.text.trim(),
              'affectedUserId': _affectedUserIdController.text.trim().isEmpty
                  ? null
                  : _affectedUserIdController.text.trim(),
              'startDate': _startDate,
              'endDate': _endDate,
              'severity': _severity,
            });
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

/// Log Detail Dialog
class _LogDetailDialog extends StatelessWidget {
  final Map<String, dynamic> logData;

  const _LogDetailDialog({required this.logData});

  @override
  Widget build(BuildContext context) {
    final log = logData;
    final adminUser = log['adminUser'] as Map<String, dynamic>?;
    final affectedUser = log['affectedUser'] as Map<String, dynamic>?;
    final details = log['details'];

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 8),
          const Text('Audit Log Details'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Log ID
              _buildDetailRow('Log ID', log['id']),
              const Divider(),

              // Timestamp
              _buildDetailRow(
                'Timestamp',
                DateTime.parse(
                  log['createdAt'],
                ).toLocal().toString().split('.')[0],
              ),
              const Divider(),

              // Action
              _buildDetailRow('Action', log['action']),
              const Divider(),

              // Resource
              _buildDetailRow('Resource Type', log['resourceType']),
              _buildDetailRow('Resource ID', log['resourceId']),
              const Divider(),

              // Admin User
              const Text(
                'Admin User',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (adminUser != null) ...[
                _buildDetailRow('Email', adminUser['email']),
                _buildDetailRow('Username', adminUser['username']),
                _buildDetailRow('Role', adminUser['role']),
                _buildDetailRow('User ID', adminUser['id']),
              ],
              const Divider(),

              // Affected User
              if (affectedUser != null) ...[
                const Text(
                  'Affected User',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildDetailRow('Email', affectedUser['email']),
                _buildDetailRow('Username', affectedUser['username']),
                _buildDetailRow('User ID', affectedUser['id']),
                const Divider(),
              ],

              // IP Address and User Agent
              _buildDetailRow('IP Address', log['ipAddress'] ?? 'N/A'),
              _buildDetailRow('User Agent', log['userAgent'] ?? 'N/A'),
              const Divider(),

              // Action Details (JSON)
              const Text(
                'Action Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SelectableText(
                  _formatJson(details),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  String _formatJson(dynamic json) {
    if (json == null) return 'null';
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    } catch (e) {
      return json.toString();
    }
  }
}
