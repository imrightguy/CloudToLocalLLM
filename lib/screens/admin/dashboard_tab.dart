import 'dart:async';
import 'package:flutter/material.dart';
import '../../di/locator.dart' as di;
import '../../services/admin_center_service.dart';
import '../../widgets/admin_stat_card.dart';
import '../../widgets/admin_error_message.dart';
import '../../config/theme.dart';

/// Dashboard tab for Admin Center
/// Displays key metrics, charts, and recent transactions
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  Timer? _refreshTimer;
  DateTime? _lastUpdated;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _metrics;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    if (!const bool.fromEnvironment('FLUTTER_TEST')) {
      _startAutoRefresh();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Load dashboard metrics
  Future<void> _loadMetrics() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final adminService = di.serviceLocator.get<AdminCenterService>();
      final metrics = await adminService.getDashboardMetrics();

      if (mounted) {
        setState(() {
          _metrics = metrics['data'];
          _lastUpdated = DateTime.now();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Start auto-refresh timer (every 60 seconds)
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _loadMetrics();
    });
  }

  /// Manual refresh
  Future<void> _handleRefresh() async {
    await _loadMetrics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          // Last updated timestamp
          if (_lastUpdated != null)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                child: Text(
                  'Last updated: ${_formatTime(_lastUpdated!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textColorLight,
                      ),
                ),
              ),
            ),

          // Manual refresh button
          IconButton(
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _handleRefresh,
            tooltip: 'Refresh metrics',
          ),
          SizedBox(width: AppTheme.spacingS),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AdminErrorMessage(errorMessage: _error!),
            SizedBox(height: AppTheme.spacingM),
            ElevatedButton.icon(
              onPressed: _loadMetrics,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_metrics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Key metrics cards
            _buildMetricsGrid(),

            SizedBox(height: AppTheme.spacingXL),

            // Subscription distribution chart
            _buildSubscriptionDistribution(),

            SizedBox(height: AppTheme.spacingXL),

            // Recent transactions
            _buildRecentTransactions(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final users = _metrics!['users'] as Map<String, dynamic>;
    final subscriptions = _metrics!['subscriptions'] as Map<String, dynamic>;
    final revenue = _metrics!['revenue'] as Map<String, dynamic>;

    return AdminStatCardGrid(
      cards: [
        // Total Users
        AdminStatCard(
          title: 'Total Users',
          value: _formatNumber(users['total']),
          icon: Icons.people,
          iconColor: AppTheme.primaryColor,
          subtitle: '${users['newThisMonth']} new this month',
        ),

        // Active Users
        AdminStatCard(
          title: 'Active Users',
          value: _formatNumber(users['active']),
          icon: Icons.person_outline,
          iconColor: AppTheme.successColor,
          subtitle: '${users['activePercentage']}% of total',
        ),

        // Monthly Recurring Revenue
        AdminStatCard(
          title: 'Monthly Recurring Revenue',
          value: '\$${_formatCurrency(revenue['mrr'])}',
          icon: Icons.attach_money,
          iconColor: AppTheme.warningColor,
          subtitle: 'From ${subscriptions['totalSubscribed']} subscribers',
        ),

        // Current Month Revenue
        AdminStatCard(
          title: 'Current Month Revenue',
          value: '\$${_formatCurrency(revenue['currentMonth'])}',
          icon: Icons.trending_up,
          iconColor: AppTheme.infoColor,
          subtitle: '${revenue['transactionCount']} transactions',
        ),
      ],
    );
  }

  Widget _buildSubscriptionDistribution() {
    final subscriptions = _metrics!['subscriptions'] as Map<String, dynamic>;
    final distribution = subscriptions['distribution'] as Map<String, dynamic>;

    final total = (distribution['free'] as int) +
        (distribution['premium'] as int) +
        (distribution['enterprise'] as int);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subscription Distribution',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),

            SizedBox(height: AppTheme.spacingM),

            Text(
              'Conversion Rate: ${subscriptions['conversionRate']}%',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColorLight),
            ),

            SizedBox(height: AppTheme.spacingL),

            // Subscription tier bars
            _buildSubscriptionBar(
              'Free',
              distribution['free'] as int,
              total,
              AppTheme.textColorLight,
            ),

            SizedBox(height: AppTheme.spacingM),

            _buildSubscriptionBar(
              'Premium',
              distribution['premium'] as int,
              total,
              AppTheme.primaryColor,
            ),

            SizedBox(height: AppTheme.spacingM),

            _buildSubscriptionBar(
              'Enterprise',
              distribution['enterprise'] as int,
              total,
              AppTheme.warningColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionBar(String tier, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tier,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '$count (${percentage.toStringAsFixed(1)}%)',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColorLight),
            ),
          ],
        ),
        SizedBox(height: AppTheme.spacingS),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
    final transactions = _metrics!['recentTransactions'] as List<dynamic>;

    if (transactions.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingL),
          child: Center(
            child: Text(
              'No recent transactions',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColorLight),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Transactions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppTheme.spacingM),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              separatorBuilder: (context, index) =>
                  Divider(height: AppTheme.spacingM * 2),
              itemBuilder: (context, index) {
                final transaction = transactions[index] as Map<String, dynamic>;
                return _buildTransactionItem(transaction);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final status = transaction['status'] as String;
    final isSuccess = status == 'succeeded';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: (isSuccess ? AppTheme.successColor : AppTheme.dangerColor)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
        ),
        child: Icon(
          isSuccess ? Icons.check_circle : Icons.error,
          color: isSuccess ? AppTheme.successColor : AppTheme.dangerColor,
        ),
      ),
      title: Text(
        transaction['userEmail'] as String,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${transaction['paymentMethod']} •••• ${transaction['last4']} • ${_formatDateTime(transaction['createdAt'])}',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '\$${_formatCurrency(transaction['amount'])}',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            transaction['subscriptionTier'] as String,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _formatNumber(dynamic value) {
    if (value is int) return value.toString();
    if (value is String) return value;
    return '0';
  }

  String _formatCurrency(dynamic value) {
    if (value is String) {
      final amount = double.tryParse(value) ?? 0.0;
      return amount.toStringAsFixed(2);
    }
    if (value is num) {
      return value.toStringAsFixed(2);
    }
    return '0.00';
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatDateTime(dynamic value) {
    if (value is! String) return '';

    try {
      final dateTime = DateTime.parse(value);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return value;
    }
  }
}
