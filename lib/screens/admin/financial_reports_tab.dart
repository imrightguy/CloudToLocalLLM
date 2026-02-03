import 'package:flutter/material.dart';
import '../../di/locator.dart' as di;
import '../../services/admin_center_service.dart';
import '../../models/admin_role_model.dart';
import 'package:intl/intl.dart';
import 'dart:async';

/// Financial Reports Tab for the Admin Center
/// Provides revenue reports, subscription metrics, and export functionality
class FinancialReportsTab extends StatefulWidget {
  const FinancialReportsTab({super.key});

  @override
  State<FinancialReportsTab> createState() => _FinancialReportsTabState();
}

class _FinancialReportsTabState extends State<FinancialReportsTab> {
  // State
  String _selectedReportType = 'revenue';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  /// Load report based on selected type and date range
  Future<void> _loadReport() async {
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.viewReports)) {
      setState(() {
        _error = 'You do not have permission to view reports';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Map<String, dynamic> data;
      if (_selectedReportType == 'revenue') {
        data = await adminService.getRevenueReport(
          startDate: _startDate,
          endDate: _endDate,
        );
      } else {
        data = await adminService.getSubscriptionMetrics(
          startDate: _startDate,
          endDate: _endDate,
        );
      }

      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load report: $e';
        _isLoading = false;
      });
    }
  }

  /// Handle report type change
  void _onReportTypeChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedReportType = value;
        _reportData = null;
      });
      _loadReport();
    }
  }

  /// Show date range picker
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _reportData = null;
      });
      await _loadReport();
    }
  }

  /// Export report
  Future<void> _exportReport(String format) async {
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.exportReports)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to export reports'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await adminService.exportReport(
        type: _selectedReportType,
        format: format,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report exported successfully as $format'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Financial Reports',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'View revenue reports, subscription metrics, and export data',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),

        // Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Report Type Selector
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report Type',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedReportType,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'revenue',
                                  child: Text('Revenue Report'),
                                ),
                                DropdownMenuItem(
                                  value: 'subscriptions',
                                  child: Text('Subscription Metrics'),
                                ),
                              ],
                              onChanged: _onReportTypeChanged,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Date Range Picker
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date Range',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _selectDateRange,
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                '${DateFormat('MMM d, y').format(_startDate)} - ${DateFormat('MMM d, y').format(_endDate)}',
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Export Buttons
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _exportReport('csv'),
                                icon: const Icon(Icons.file_download),
                                label: const Text('CSV'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _exportReport('pdf'),
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('PDF'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Report Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _buildReportContent(),
          ),
        ),
      ],
    );
  }

  /// Build report content based on type
  Widget _buildReportContent() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadReport, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reportData == null) {
      return const Center(child: Text('No data available'));
    }

    if (_selectedReportType == 'revenue') {
      return _buildRevenueReport();
    } else {
      return _buildSubscriptionMetrics();
    }
  }

  /// Build revenue report view
  Widget _buildRevenueReport() {
    final data = _reportData!;
    final totalRevenue = data['totalRevenue'] ?? 0.0;
    final transactionCount = data['transactionCount'] ?? 0;
    final avgTransactionValue = data['averageTransactionValue'] ?? 0.0;
    final revenueByTier = List<Map<String, dynamic>>.from(
      data['revenueByTier'] ?? [],
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Revenue',
                  '\$${totalRevenue.toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Transactions',
                  transactionCount.toString(),
                  Icons.receipt_long,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Avg Transaction',
                  '\$${avgTransactionValue.toStringAsFixed(2)}',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Revenue by Tier
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenue by Subscription Tier',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildRevenueByTierTable(revenueByTier),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build subscription metrics view
  Widget _buildSubscriptionMetrics() {
    final data = _reportData!;
    final mrr = data['monthlyRecurringRevenue'] ?? 0.0;
    final churnRate = data['churnRate'] ?? 0.0;
    final retentionRate = data['retentionRate'] ?? 0.0;
    final activeSubscriptions = data['activeSubscriptions'] ?? 0;
    final newSubscriptions = data['newSubscriptions'] ?? 0;
    final canceledSubscriptions = data['canceledSubscriptions'] ?? 0;
    final subscriptionsByTier = List<Map<String, dynamic>>.from(
      data['subscriptionsByTier'] ?? [],
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Monthly Recurring Revenue',
                  '\$${mrr.toStringAsFixed(2)}',
                  Icons.autorenew,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Active Subscriptions',
                  activeSubscriptions.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Churn Rate',
                  '${churnRate.toStringAsFixed(1)}%',
                  Icons.trending_down,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Retention Rate',
                  '${retentionRate.toStringAsFixed(1)}%',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'New Subscriptions',
                  newSubscriptions.toString(),
                  Icons.add_circle,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Canceled Subscriptions',
                  canceledSubscriptions.toString(),
                  Icons.cancel,
                  Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Subscriptions by Tier
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscriptions by Tier',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildSubscriptionsByTierTable(subscriptionsByTier),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build metric card
  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build revenue by tier table
  Widget _buildRevenueByTierTable(List<Map<String, dynamic>> data) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
      },
      children: [
        // Header
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            _buildTableCell('Tier', isHeader: true),
            _buildTableCell('Transactions', isHeader: true),
            _buildTableCell('Total Revenue', isHeader: true),
            _buildTableCell('Avg Value', isHeader: true),
          ],
        ),
        // Data rows
        ...data.map((row) {
          final tier = row['tier'] ?? '';
          final count = row['transactionCount'] ?? 0;
          final revenue = row['totalRevenue'] ?? 0.0;
          final avg = row['averageTransactionValue'] ?? 0.0;

          return TableRow(
            children: [
              _buildTableCell(_formatTier(tier)),
              _buildTableCell(count.toString()),
              _buildTableCell('\$${revenue.toStringAsFixed(2)}'),
              _buildTableCell('\$${avg.toStringAsFixed(2)}'),
            ],
          );
        }),
      ],
    );
  }

  /// Build subscriptions by tier table
  Widget _buildSubscriptionsByTierTable(List<Map<String, dynamic>> data) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1),
      },
      children: [
        // Header
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            _buildTableCell('Tier', isHeader: true),
            _buildTableCell('Total', isHeader: true),
            _buildTableCell('Active', isHeader: true),
            _buildTableCell('New', isHeader: true),
            _buildTableCell('Canceled', isHeader: true),
          ],
        ),
        // Data rows
        ...data.map((row) {
          final tier = row['tier'] ?? '';
          final total = row['totalCount'] ?? 0;
          final active = row['activeCount'] ?? 0;
          final newCount = row['newCount'] ?? 0;
          final canceled = row['canceledCount'] ?? 0;

          return TableRow(
            children: [
              _buildTableCell(_formatTier(tier)),
              _buildTableCell(total.toString()),
              _buildTableCell(active.toString()),
              _buildTableCell(newCount.toString()),
              _buildTableCell(canceled.toString()),
            ],
          );
        }),
      ],
    );
  }

  /// Build table cell
  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  /// Format tier name
  String _formatTier(String tier) {
    switch (tier.toLowerCase()) {
      case 'free':
        return 'Free';
      case 'premium':
        return 'Premium';
      case 'enterprise':
        return 'Enterprise';
      default:
        return tier;
    }
  }
}
