/// Screen for managing scheduled cron jobs.
library;

import 'package:flutter/material.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/navigation/popout_button.dart';
import '../../models/cron_job.dart';

// TODO: Uncomment when integrating with actual services
// import '../../services/cron_service.dart';
// import '../../di/locator.dart' as di;

/// Screen displaying and managing scheduled cron jobs.
class CronJobsScreen extends StatefulWidget {
  const CronJobsScreen({super.key});

  @override
  State<CronJobsScreen> createState() => _CronJobsScreenState();
}

class _CronJobsScreenState extends State<CronJobsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<CronJob> _jobs = [];

  // TODO: Integrate with actual services
  // final CronService _cronService = di.serviceLocator<CronService>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Simulate data loading
      await Future.delayed(const Duration(milliseconds: 300));

      // TODO: Fetch from CronService
      // _jobs = await _cronService.listJobs();

      // Mock data for now
      _jobs = _getMockJobs();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load cron jobs: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  /// Toggle job active/inactive
  Future<void> _toggleJob(CronJob job) async {
    // TODO: Implement toggle via CronService
    debugPrint('Toggle job: ${job.id}');
    await _loadData();
  }

  /// Run job immediately
  Future<void> _runJob(CronJob job) async {
    // TODO: Implement run now via CronService
    debugPrint('Run job now: ${job.id}');
  }

  /// Edit job schedule
  Future<void> _editJob(CronJob job) async {
    // TODO: Implement edit dialog
    debugPrint('Edit job: ${job.id}');
  }

  List<CronJob> _getMockJobs() {
    final now = DateTime.now();
    return [
      CronJob(
        id: '1',
        name: 'Database Backup',
        schedule: '0 2 * * *',
        scheduleDescription: 'Daily at 2:00 AM',
        command: '/usr/local/bin/backup-db.sh',
        status: CronJobStatus.active,
        nextRun: DateTime(now.year, now.month, now.day + 1, 2, 0),
        lastRun: DateTime(now.year, now.month, now.day - 1, 2, 0),
        lastRunSuccess: true,
        lastRunOutput: 'Backup completed: 2.3GB in 45s',
      ),
      CronJob(
        id: '2',
        name: 'Log Cleanup',
        schedule: '0 3 * * 0',
        scheduleDescription: 'Weekly (Sundays at 3:00 AM)',
        command: '/usr/local/bin/cleanup-logs.sh',
        status: CronJobStatus.active,
        nextRun: DateTime(
            now.year, now.month, now.day + (7 - now.weekday % 7), 3, 0),
        lastRun: DateTime(now.year, now.month, now.day - 7, 3, 0),
        lastRunSuccess: true,
        lastRunOutput: 'Cleaned 1.2GB of old logs',
      ),
      CronJob(
        id: '3',
        name: 'Health Check',
        schedule: '*/30 * * * *',
        scheduleDescription: 'Every 30 minutes',
        command: '/usr/local/bin/health-check.sh',
        status: CronJobStatus.active,
        nextRun: now.add(const Duration(minutes: 30)),
        lastRun: now.subtract(const Duration(minutes: 5)),
        lastRunSuccess: true,
        lastRunOutput: 'All systems operational',
      ),
      CronJob(
        id: '4',
        name: 'Report Generation',
        schedule: '0 8 * * 1-5',
        scheduleDescription: 'Weekdays at 8:00 AM',
        command: '/usr/local/bin/generate-reports.sh',
        status: CronJobStatus.inactive,
        nextRun: null,
        lastRun: DateTime(now.year, now.month, now.day - 3, 8, 0),
        lastRunSuccess: false,
        lastRunOutput: 'Error: Database connection timeout',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return RefreshableScreen(
      onRefresh: _onRefresh,
      errorMessage: _errorMessage,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cron Jobs'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _onRefresh,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                // TODO: Implement add job dialog
                debugPrint('Add new cron job');
              },
              tooltip: 'Add Job',
            ),
            const PopOutButton(sectionName: 'cron', branchIndex: 6),
          ],
        ),
        body: _isLoading
            ? const LoadingSkeleton(itemCount: 3, height: 120)
            : _errorMessage != null
                ? ErrorState(message: _errorMessage!, onRetry: _onRefresh)
                : _jobs.isEmpty
                    ? const EmptyState(
                        icon: Icons.schedule_outlined,
                        title: 'No Cron Jobs',
                        message:
                            'Create scheduled tasks to automate maintenance',
                      )
                    : _buildJobsList(),
      ),
    );
  }

  Widget _buildJobsList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _jobs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final job = _jobs[index];
        return _buildJobCard(job);
      },
    );
  }

  Widget _buildJobCard(CronJob job) {
    final theme = Theme.of(context);
    final statusColor = job.getStatusColor(context);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and status
            Row(
              children: [
                Icon(
                  job.statusIcon,
                  size: 20,
                  color: statusColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.scheduleDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  status: job.status == CronJobStatus.active
                      ? StatusType.active
                      : job.status == CronJobStatus.inactive
                          ? StatusType.stopped
                          : job.status == CronJobStatus.failed
                              ? StatusType.error
                              : StatusType.running,
                  label: job.statusText,
                  showIcon: false,
                ),
              ],
            ),
            const Divider(height: 24),
            // Schedule and timing info
            _buildInfoRow(
              Icons.schedule_outlined,
              'Schedule',
              job.schedule,
            ),
            const SizedBox(height: 8),
            if (job.nextRun != null)
              _buildInfoRow(
                Icons.access_time,
                'Next run',
                _formatDateTime(job.nextRun!),
              ),
            if (job.lastRun != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.history,
                'Last run',
                _formatDateTime(job.lastRun!),
                status: job.lastRunStatusText,
              ),
            ],
            if (job.lastRunOutput != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      job.lastRunSuccess
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 16,
                      color: job.lastRunSuccess
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        job.lastRunOutput!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Actions
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _runJob(job),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Run Now'),
                ),
                TextButton.icon(
                  onPressed: () => _editJob(job),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () => _toggleJob(job),
                  icon: Icon(
                    job.status == CronJobStatus.active
                        ? Icons.pause
                        : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(
                    job.status == CronJobStatus.active ? 'Disable' : 'Enable',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {String? status}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
        if (status != null)
          Text(
            status,
            style: theme.textTheme.bodySmall?.copyWith(
              color: status == 'Success'
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
