import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../di/locator.dart' as di;

import '../../config/theme_config.dart';
import '../../services/admin_data_flush_service.dart';
import '../../services/platform_adapter.dart';
import '../../services/platform_detection_service.dart';

/// Administrative Data Flush Screen
///
/// Provides secure administrative interface for data flush operations
/// with multi-step confirmation and comprehensive audit trail.
class AdminDataFlushScreen extends StatefulWidget {
  const AdminDataFlushScreen({super.key});

  @override
  State<AdminDataFlushScreen> createState() => _AdminDataFlushScreenState();
}

class _AdminDataFlushScreenState extends State<AdminDataFlushScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _targetUserController = TextEditingController();
  String _selectedScope = 'FULL_FLUSH';
  final Map<String, bool> _flushOptions = {
    'skipAuth': false,
    'skipConversations': false,
    'skipPreferences': false,
    'skipCache': false,
    'skipContainers': false,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _targetUserController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final adminService = di.serviceLocator.get<AdminDataFlushService>();
    await adminService.getSystemStatistics();
    await adminService.loadFlushHistory();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platformService = di.serviceLocator.get<PlatformDetectionService>();
    final platformAdapter = PlatformAdapter(platformService);

    // Responsive layout breakpoints
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin-center'),
          tooltip: 'Back to Admin Center',
        ),
        title: Text(
          '🔒 Administrative Data Flush',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation ?? 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodySmall?.color,
          indicatorColor: theme.colorScheme.primary,
          tabs: [
            Tab(
              text: isMobile ? null : 'Dashboard',
              icon: const Icon(Icons.dashboard),
            ),
            Tab(
              text: isMobile ? null : 'Data Flush',
              icon: const Icon(Icons.delete_forever),
            ),
            Tab(
              text: isMobile ? null : 'Audit Trail',
              icon: const Icon(Icons.history),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(context, theme, platformAdapter, isMobile),
          _buildDataFlushTab(context, theme, platformAdapter, isMobile),
          _buildAuditTrailTab(context, theme, platformAdapter, isMobile),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(
    BuildContext context,
    ThemeData theme,
    PlatformAdapter platformAdapter,
    bool isMobile,
  ) {
    return Consumer<AdminDataFlushService>(
      builder: (context, adminService, child) {
        if (adminService.isLoading) {
          return Center(
            child: platformAdapter.buildProgressIndicator(
              color: theme.colorScheme.primary,
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSystemStatsCard(context, theme, platformAdapter, isMobile),
              SizedBox(height: isMobile ? 12 : 16),
              _buildQuickActionsCard(context, theme, platformAdapter, isMobile),
              SizedBox(height: isMobile ? 12 : 16),
              _buildRecentOperationsCard(
                  context, theme, platformAdapter, isMobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSystemStatsCard(
    BuildContext context,
    ThemeData theme,
    PlatformAdapter platformAdapter,
    bool isMobile,
  ) {
    return Consumer<AdminDataFlushService>(
      builder: (context, adminService, child) {
        return platformAdapter.buildCard(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'System Statistics',
                style: theme.textTheme.headlineSmall,
              ),
              SizedBox(height: isMobile ? 12 : 16),
              // System stats would be displayed here
              // This is a placeholder for the actual implementation
              Text(
                'Loading system statistics...',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsCard(
    BuildContext context,
    ThemeData theme,
    PlatformAdapter platformAdapter,
    bool isMobile,
  ) {
    return platformAdapter.buildCard(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: theme.textTheme.headlineSmall,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          isMobile
              ? Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _performEmergencyCleanup,
                        icon: const Icon(Icons.cleaning_services),
                        label: const Text('Emergency Cleanup'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeConfig.warningColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _refreshData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Data'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _performEmergencyCleanup,
                        icon: const Icon(Icons.cleaning_services),
                        label: const Text('Emergency Cleanup'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeConfig.warningColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _refreshData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Data'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildRecentOperationsCard(
    BuildContext context,
    ThemeData theme,
    PlatformAdapter platformAdapter,
    bool isMobile,
  ) {
    return Consumer<AdminDataFlushService>(
      builder: (context, adminService, child) {
        final recentOps = adminService.operationHistory.take(5).toList();

        return platformAdapter.buildCard(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Operations',
                style: theme.textTheme.headlineSmall,
              ),
              SizedBox(height: isMobile ? 12 : 16),
              if (recentOps.isEmpty)
                Text(
                  'No recent operations',
                  style: theme.textTheme.bodyMedium,
                )
              else
                ...recentOps.map((op) => _buildOperationTile(op, theme)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataFlushTab(
    BuildContext context,
    ThemeData theme,
    PlatformAdapter platformAdapter,
    bool isMobile,
  ) {
    return Consumer<AdminDataFlushService>(
      builder: (context, adminService, child) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWarningCard(context, theme, platformAdapter, isMobile),
              SizedBox(height: isMobile ? 12 : 16),
              _buildFlushConfigurationCard(
                  context, theme, platformAdapter, isMobile),
              SizedBox(height: isMobile ? 12 : 16),
              _buildFlushExecutionCard(
                  context, theme, platformAdapter, isMobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWarningCard(
    BuildContext context,
    ThemeData theme,
    PlatformAdapter platformAdapter,
    bool isMobile,
  ) {
    return Card(
      color: ThemeConfig.dangerColor,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          children: [
            Icon(Icons.warning, color: Colors.white, size: isMobile ? 40 : 48),
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              'CRITICAL WARNING',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              'Data flush operations permanently delete user data and cannot be undone. '
              'Ensure you have proper authorization and have backed up any necessary data.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlushConfigurationCard(
    BuildContext context,
    ThemeData theme,
    PlatformAdapter platformAdapter,
    bool isMobile,
  ) {
    return platformAdapter.buildCard(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Flush Configuration',
            style: theme.textTheme.headlineSmall,
          ),
          SizedBox(height: isMobile ? 12 : 16),

          // Scope selection
          DropdownButtonFormField<String>(
            initialValue: _selectedScope,
            decoration: const InputDecoration(
              labelText: 'Flush Scope',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'FULL_FLUSH',
                child: Text('Full System Flush'),
              ),
              DropdownMenuItem(
                value: 'USER_SPECIFIC',
                child: Text('Specific User'),
              ),
              DropdownMenuItem(
                value: 'CONTAINERS_ONLY',
                child: Text('Containers Only'),
              ),
              DropdownMenuItem(
                value: 'AUTH_ONLY',
                child: Text('Authentication Only'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedScope = value!;
              });
            },
          ),

          SizedBox(height: isMobile ? 12 : 16),

          // Target user (if user-specific)
          if (_selectedScope == 'USER_SPECIFIC')
            TextField(
              controller: _targetUserController,
              decoration: const InputDecoration(
                labelText: 'Target User ID',
                border: OutlineInputBorder(),
                hintText: 'Enter specific user ID to target',
              ),
            ),

          SizedBox(height: isMobile ? 12 : 16),

          // Flush options
          Text(
            'Flush Options',
            style: theme.textTheme.titleMedium,
          ),
          SizedBox(height: isMobile ? 6 : 8),

          ..._flushOptions.entries.map(
            (entry) => CheckboxListTile(
              title: Text(_getOptionLabel(entry.key)),
              subtitle: Text(_getOptionDescription(entry.key)),
              value: entry.value,
              onChanged: (value) {
                setState(() {
                  _flushOptions[entry.key] = value ?? false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlushExecutionCard(
    BuildContext context,
    ThemeData theme,
    PlatformAdapter platformAdapter,
    bool isMobile,
  ) {
    return Consumer<AdminDataFlushService>(
      builder: (context, adminService, child) {
        return platformAdapter.buildCard(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Flush Execution',
                style: theme.textTheme.headlineSmall,
              ),
              SizedBox(height: isMobile ? 12 : 16),
              if (adminService.error != null)
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 12),
                  decoration: BoxDecoration(
                    color: ThemeConfig.dangerColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    adminService.error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              SizedBox(height: isMobile ? 12 : 16),
              isMobile
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                adminService.isLoading ? null : _prepareFlush,
                            icon: const Icon(Icons.security),
                            label: Text(
                              adminService.hasValidConfirmationToken
                                  ? 'Token Ready'
                                  : 'Prepare Flush',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  adminService.hasValidConfirmationToken
                                      ? ThemeConfig.successColor
                                      : theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 44),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: adminService.hasValidConfirmationToken &&
                                    !adminService.isLoading
                                ? _executeFlush
                                : null,
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('EXECUTE FLUSH'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ThemeConfig.dangerColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 44),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                adminService.isLoading ? null : _prepareFlush,
                            icon: const Icon(Icons.security),
                            label: Text(
                              adminService.hasValidConfirmationToken
                                  ? 'Token Ready'
                                  : 'Prepare Flush',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  adminService.hasValidConfirmationToken
                                      ? ThemeConfig.successColor
                                      : theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: adminService.hasValidConfirmationToken &&
                                    !adminService.isLoading
                                ? _executeFlush
                                : null,
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('EXECUTE FLUSH'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ThemeConfig.dangerColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
              if (adminService.isLoading)
                Padding(
                  padding: EdgeInsets.only(top: isMobile ? 12 : 16),
                  child: const LinearProgressIndicator(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuditTrailTab(
    BuildContext context,
    ThemeData theme,
    PlatformAdapter platformAdapter,
    bool isMobile,
  ) {
    return Consumer<AdminDataFlushService>(
      builder: (context, adminService, child) {
        return ListView.builder(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          itemCount: adminService.operationHistory.length,
          itemBuilder: (context, index) {
            final operation = adminService.operationHistory[index];
            return _buildOperationCard(operation, theme, platformAdapter);
          },
        );
      },
    );
  }

  Widget _buildOperationTile(Map<String, dynamic> operation, ThemeData theme) {
    return ListTile(
      leading: Icon(Icons.delete_forever, color: ThemeConfig.dangerColor),
      title: Text(
        'Operation ${operation['operationId']?.substring(0, 8) ?? 'Unknown'}',
        style: theme.textTheme.bodyLarge,
      ),
      subtitle: Text(
        'Target: ${operation['targetUserId'] ?? 'Unknown'}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Text(
        _formatTimestamp(operation['timestamp']),
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  Widget _buildOperationCard(
    Map<String, dynamic> operation,
    ThemeData theme,
    PlatformAdapter platformAdapter,
  ) {
    return platformAdapter.buildCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.delete_forever, color: ThemeConfig.dangerColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Operation ${operation['operationId']?.substring(0, 8) ?? 'Unknown'}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _formatTimestamp(operation['timestamp']),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Target: ${operation['targetUserId'] ?? 'Unknown'}',
            style: theme.textTheme.bodyMedium,
          ),
          if (operation['duration'] != null)
            Text(
              'Duration: ${operation['duration']}ms',
              style: theme.textTheme.bodyMedium,
            ),
          if (operation['results'] != null)
            Text(
              'Results: ${operation['results'].toString()}',
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }

  String _getOptionLabel(String key) {
    switch (key) {
      case 'skipAuth':
        return 'Skip Authentication Data';
      case 'skipConversations':
        return 'Skip Conversation Data';
      case 'skipPreferences':
        return 'Skip Preferences Data';
      case 'skipCache':
        return 'Skip Cache Data';
      case 'skipContainers':
        return 'Skip Container Cleanup';
      default:
        return key;
    }
  }

  String _getOptionDescription(String key) {
    switch (key) {
      case 'skipAuth':
        return 'Preserve user authentication tokens and sessions';
      case 'skipConversations':
        return 'Preserve conversation history and chat data';
      case 'skipPreferences':
        return 'Preserve user settings and preferences';
      case 'skipCache':
        return 'Preserve cached data and temporary files';
      case 'skipContainers':
        return 'Preserve Docker containers and networks';
      default:
        return '';
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = DateTime.parse(timestamp);
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid';
    }
  }

  Future<void> _prepareFlush() async {
    final adminService = di.serviceLocator.get<AdminDataFlushService>();

    final confirmed = await _showConfirmationDialog(
      'Prepare Data Flush',
      'This will prepare a data flush operation. Are you sure you want to continue?',
    );

    if (confirmed) {
      final targetUserId = _selectedScope == 'USER_SPECIFIC'
          ? _targetUserController.text.trim()
          : null;

      await adminService.prepareDataFlush(
        targetUserId: targetUserId,
        scope: _selectedScope,
      );
    }
  }

  Future<void> _executeFlush() async {
    final adminService = di.serviceLocator.get<AdminDataFlushService>();

    final confirmed = await _showConfirmationDialog(
      'EXECUTE DATA FLUSH',
      'This will PERMANENTLY DELETE user data. This action CANNOT be undone. Are you absolutely sure?',
      isDestructive: true,
    );

    if (confirmed) {
      final targetUserId = _selectedScope == 'USER_SPECIFIC'
          ? _targetUserController.text.trim()
          : null;

      final success = await adminService.executeDataFlush(
        targetUserId: targetUserId,
        options: _flushOptions,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data flush executed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _performEmergencyCleanup() async {
    final adminService = di.serviceLocator.get<AdminDataFlushService>();

    final confirmed = await _showConfirmationDialog(
      'Emergency Container Cleanup',
      'This will remove all orphaned containers and networks. Continue?',
    );

    if (confirmed) {
      await adminService.emergencyContainerCleanup();
    }
  }

  Future<void> _refreshData() async {
    await _loadInitialData();
  }

  Future<bool> _showConfirmationDialog(
    String title,
    String message, {
    bool isDestructive = false,
  }) async {
    final theme = Theme.of(context);

    if (isDestructive) {
      return await _showDestructiveConfirmationDialog(title, message);
    }

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isDestructive ? Icons.warning : Icons.info,
                  color: isDestructive
                      ? ThemeConfig.warningColor
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(title)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: theme.textTheme.bodyMedium),
                if (isDestructive) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThemeConfig.dangerColor.withValues(alpha: 0.1),
                      border: Border.all(
                        color: ThemeConfig.dangerColor.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning,
                            color: ThemeConfig.dangerColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This action cannot be undone!',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: ThemeConfig.dangerColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDestructive
                      ? ThemeConfig.dangerColor
                      : theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(isDestructive ? 'I Understand' : 'Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Enhanced destructive confirmation dialog with multi-step verification
  Future<bool> _showDestructiveConfirmationDialog(
    String title,
    String message,
  ) async {
    final theme = Theme.of(context);
    final TextEditingController confirmationController =
        TextEditingController();
    bool canConfirm = false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.dangerous, color: ThemeConfig.dangerColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: ThemeConfig.dangerColor,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ThemeConfig.dangerColor.withValues(alpha: 0.1),
                      border: Border.all(
                        color: ThemeConfig.dangerColor.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning,
                                color: ThemeConfig.dangerColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'CRITICAL WARNING',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: ThemeConfig.dangerColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• This will PERMANENTLY delete user data\n'
                          '• This action CANNOT be undone\n'
                          '• All conversations will be lost\n'
                          '• All authentication tokens will be cleared\n'
                          '• Docker containers will be removed',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: ThemeConfig.dangerColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Type "DELETE" to confirm this destructive action:',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmationController,
                    decoration: const InputDecoration(
                      hintText: 'Type DELETE here',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        canConfirm = value.trim().toUpperCase() == 'DELETE';
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      canConfirm ? () => Navigator.of(context).pop(true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.dangerColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('EXECUTE DELETION'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }
}
