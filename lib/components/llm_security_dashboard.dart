import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../services/llm_audit_service.dart';
import '../components/modern_card.dart';

/// LLM Security and Monitoring Dashboard
///
/// Displays audit logs, usage statistics, security events,
/// and performance metrics for LLM interactions.
class LLMSecurityDashboard extends StatefulWidget {
  const LLMSecurityDashboard({super.key});

  @override
  State<LLMSecurityDashboard> createState() => _LLMSecurityDashboardState();
}

class _LLMSecurityDashboardState extends State<LLMSecurityDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LLMAuditService>(
      builder: (context, auditService, child) {
        if (!auditService.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'LLM Security & Monitoring',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppTheme.spacingS),
            Text(
              'Monitor LLM interactions, security events, and usage patterns',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColorLight),
            ),
            SizedBox(height: AppTheme.spacingM),

            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textColorLight,
              indicatorColor: AppTheme.primaryColor,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Audit Log'),
                Tab(text: 'Usage Stats'),
                Tab(text: 'Security'),
              ],
            ),

            SizedBox(height: AppTheme.spacingM),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(auditService),
                  _buildAuditLogTab(auditService),
                  _buildUsageStatsTab(auditService),
                  _buildSecurityTab(auditService),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOverviewTab(LLMAuditService auditService) {
    final recentEvents = auditService.getRecentEvents(limit: 10);
    final totalStats = auditService.getUsageStats();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Requests',
                  totalStats.totalRequests.toString(),
                  Icons.send,
                  Colors.blue,
                ),
              ),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: _buildStatCard(
                  'Success Rate',
                  totalStats.totalRequests > 0
                      ? '${((totalStats.successfulRequests / totalStats.totalRequests) * 100).toStringAsFixed(1)}%'
                      : '0%',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: _buildStatCard(
                  'Avg Response',
                  '${totalStats.averageResponseTime.toStringAsFixed(0)}ms',
                  Icons.speed,
                  Colors.orange,
                ),
              ),
            ],
          ),

          SizedBox(height: AppTheme.spacingL),

          // Recent activity
          ModernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                SizedBox(height: AppTheme.spacingM),
                if (recentEvents.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppTheme.spacingL),
                      child: Text(
                        'No recent activity',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textColorLight,
                            ),
                      ),
                    ),
                  )
                else
                  ...recentEvents
                      .take(5)
                      .map(_buildEventTile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogTab(LLMAuditService auditService) {
    final events = auditService.getRecentEvents(limit: 100);

    return Column(
      children: [
        // Controls
        Row(
          children: [
            Expanded(
              child: Text(
                '${events.length} events',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textColorLight,
                    ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _exportAuditLog(auditService),
              icon: const Icon(Icons.download),
              label: const Text('Export'),
            ),
            SizedBox(width: AppTheme.spacingS),
            TextButton.icon(
              onPressed: () => _clearAuditLog(auditService),
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),

        SizedBox(height: AppTheme.spacingM),

        // Event list
        Expanded(
          child: ModernCard(
            child: events.isEmpty
                ? Center(
                    child: Text(
                      'No audit events',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textColorLight,
                          ),
                    ),
                  )
                : ListView.separated(
                    itemCount: events.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: AppTheme.borderColor, height: 1),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return _buildEventTile(event, showDetails: true);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsageStatsTab(LLMAuditService auditService) {
    final stats = auditService.usageStats;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stats.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingL),
                child: Text(
                  'No usage statistics available',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textColorLight,
                      ),
                ),
              ),
            )
          else
            ...stats.entries.map((entry) {
              final providerStats = entry.value;
              return ModernCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${providerStats.providerId} - ${providerStats.modelId}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    SizedBox(height: AppTheme.spacingM),
                    _buildUsageStatsGrid(providerStats),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSecurityTab(LLMAuditService auditService) {
    final securityEvents = auditService.getRecentEvents(
      eventType: LLMAuditEventType.security,
      limit: 50,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Security status
        ModernCard(
          child: Row(
            children: [
              Icon(
                securityEvents.isEmpty ? Icons.security : Icons.warning,
                color: securityEvents.isEmpty ? Colors.green : Colors.orange,
                size: 32,
              ),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      securityEvents.isEmpty
                          ? 'No Security Issues'
                          : 'Security Events Detected',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: securityEvents.isEmpty
                                ? Colors.green
                                : Colors.orange,
                          ),
                    ),
                    Text(
                      securityEvents.isEmpty
                          ? 'All LLM interactions are secure'
                          : '${securityEvents.length} security events require attention',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textColorLight,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: AppTheme.spacingM),

        // Security events
        if (securityEvents.isNotEmpty) ...[
          Text(
            'Security Events',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: AppTheme.spacingS),
          Expanded(
            child: ModernCard(
              child: ListView.separated(
                itemCount: securityEvents.length,
                separatorBuilder: (context, index) =>
                    Divider(color: AppTheme.borderColor, height: 1),
                itemBuilder: (context, index) {
                  final event = securityEvents[index];
                  return _buildEventTile(event, showDetails: true);
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: AppTheme.spacingXS),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingXS),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(LLMAuditEvent event, {bool showDetails = false}) {
    final isError =
        !event.success || event.eventType == LLMAuditEventType.security;

    return ListTile(
      leading: Icon(
        _getEventIcon(event),
        color: isError ? Colors.red : Colors.green,
        size: 20,
      ),
      title: Text(
        '${event.providerId ?? 'Unknown'} - ${event.requestType}',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${event.timestamp.month}/${event.timestamp.day} ${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
          ),
          if (showDetails && event.errorMessage != null)
            Text(
              event.errorMessage!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.red),
            ),
        ],
      ),
      trailing: event.responseTime != null
          ? Text(
              '${event.responseTime}ms',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
            )
          : null,
    );
  }

  Widget _buildUsageStatsGrid(LLMUsageStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3,
      crossAxisSpacing: AppTheme.spacingS,
      mainAxisSpacing: AppTheme.spacingS,
      children: [
        _buildStatItem('Total Requests', stats.totalRequests.toString()),
        _buildStatItem(
          'Success Rate',
          '${stats.totalRequests > 0 ? ((stats.successfulRequests / stats.totalRequests) * 100).toStringAsFixed(1) : 0}%',
        ),
        _buildStatItem('Input Tokens', stats.totalInputTokens.toString()),
        _buildStatItem('Output Tokens', stats.totalOutputTokens.toString()),
        _buildStatItem(
          'Avg Response',
          '${stats.averageResponseTime.toStringAsFixed(0)}ms',
        ),
        _buildStatItem(
          'Last Used',
          stats.lastUsed != null
              ? '${stats.lastUsed!.month}/${stats.lastUsed!.day} ${stats.lastUsed!.hour}:${stats.lastUsed!.minute.toString().padLeft(2, '0')}'
              : 'Never',
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  IconData _getEventIcon(LLMAuditEvent event) {
    switch (event.eventType) {
      case LLMAuditEventType.interaction:
        return event.success ? Icons.chat : Icons.error;
      case LLMAuditEventType.security:
        return Icons.security;
      case LLMAuditEventType.provider:
        return Icons.settings;
      case LLMAuditEventType.system:
        return Icons.computer;
    }
  }

  void _exportAuditLog(LLMAuditService auditService) {
    try {
      // Generate the audit log export data
      final exportData = auditService.exportAuditLog();

      // Create filename with timestamp
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'zoidbot_audit_log_$timestamp.json';

      if (kIsWeb) {
        // For web platform, show the data in a dialog for manual copy
        _showExportDataDialog(exportData, fileName);
      } else {
        // For desktop platforms, we would use file_picker or similar
        // For now, show the export data in a dialog for desktop
        _showExportDataDialog(exportData, fileName);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export audit log: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showExportDataDialog(String exportData, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File: $fileName',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Copy the data below and save it to a file:',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      exportData,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _clearAuditLog(LLMAuditService auditService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Audit Log'),
        content: const Text(
          'Are you sure you want to clear all audit events? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              auditService.clearAuditLog();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Audit log cleared'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
