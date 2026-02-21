import 'package:flutter/material.dart';
import '../../services/payment_gateway_service.dart';
import '../../services/admin_center_service.dart';
import '../../models/admin_role_model.dart';
import '../../models/subscription_model.dart';
import '../../di/locator.dart' as di;
import 'dart:async';

/// Subscription Management Tab for the Admin Center
/// Provides subscription viewing, filtering, and management (upgrade, downgrade, cancel)
class SubscriptionManagementTab extends StatefulWidget {
  const SubscriptionManagementTab({super.key});

  @override
  State<SubscriptionManagementTab> createState() =>
      _SubscriptionManagementTabState();
}

class _SubscriptionManagementTabState extends State<SubscriptionManagementTab> {
  // Controllers
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // State
  List<SubscriptionModel> _subscriptions = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalSubscriptions = 0;
  final int _pageSize = 50;

  // Filters
  String? _selectedTier;
  String? _selectedStatus;
  String? _selectedUserId;
  bool _showUpcomingRenewals = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Load subscriptions with current filters
  Future<void> _loadSubscriptions() async {
    final paymentService = di.serviceLocator.get<PaymentGatewayService>();
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.viewSubscriptions)) {
      setState(() {
        _error = 'You do not have permission to view subscriptions';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final subscriptions = await paymentService.getSubscriptions(
        userId: _selectedUserId,
        tier: _selectedTier,
        status: _selectedStatus,
        page: _currentPage,
        limit: _pageSize,
        forceRefresh: true,
      );

      // Filter for upcoming renewals if enabled
      var filteredSubscriptions = subscriptions;
      if (_showUpcomingRenewals) {
        final now = DateTime.now();
        final thirtyDaysFromNow = now.add(const Duration(days: 30));
        filteredSubscriptions = subscriptions.where((sub) {
          if (sub.currentPeriodEnd == null) return false;
          return sub.currentPeriodEnd!.isAfter(now) &&
              sub.currentPeriodEnd!.isBefore(thirtyDaysFromNow) &&
              sub.isActive;
        }).toList();
      }

      setState(() {
        _subscriptions = filteredSubscriptions;
        _totalSubscriptions = filteredSubscriptions.length;
        _totalPages = (_totalSubscriptions / _pageSize).ceil();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load subscriptions: $e';
        _isLoading = false;
      });
    }
  }

  /// Handle search with debouncing
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _selectedUserId = value.isNotEmpty ? value : null;
      });
      _currentPage = 1;
      _loadSubscriptions();
    });
  }

  /// Handle filter change
  void _onFilterChanged() {
    _currentPage = 1;
    _loadSubscriptions();
  }

  /// Handle page change
  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadSubscriptions();
  }

  /// Show subscription detail dialog
  void _showSubscriptionDetail(SubscriptionModel subscription) {
    showDialog(
      context: context,
      builder: (context) =>
          _SubscriptionDetailDialog(subscription: subscription),
    );
  }

  /// Show upgrade/downgrade dialog
  void _showUpgradeDowngradeDialog(SubscriptionModel subscription) {
    showDialog(
      context: context,
      builder: (context) => _UpgradeDowngradeDialog(
        subscription: subscription,
        onUpdated: () {
          Navigator.of(context).pop();
          _loadSubscriptions(); // Refresh the list
        },
      ),
    );
  }

  /// Show cancel subscription dialog
  void _showCancelDialog(SubscriptionModel subscription) {
    showDialog(
      context: context,
      builder: (context) => _CancelSubscriptionDialog(
        subscription: subscription,
        onCanceled: () {
          Navigator.of(context).pop();
          _loadSubscriptions(); // Refresh the list
        },
      ),
    );
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
                'Subscription Management',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'View and manage user subscriptions, upgrades, downgrades, and cancellations',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),

        // Search and filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Search bar
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search by user ID or email...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Filters row
              Row(
                children: [
                  // Tier filter
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedTier,
                      decoration: InputDecoration(
                        labelText: 'Subscription Tier',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Tiers'),
                        ),
                        ...SubscriptionTier.values.map((tier) {
                          return DropdownMenuItem(
                            value: tier.name,
                            child: Text(tier.displayName),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedTier = value;
                        });
                        _onFilterChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Status filter
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Statuses'),
                        ),
                        ...SubscriptionStatus.values.map((status) {
                          return DropdownMenuItem(
                            value: status.name,
                            child: Text(status.displayName),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value;
                        });
                        _onFilterChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Upcoming renewals toggle
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Upcoming Renewals (30 days)'),
                      value: _showUpcomingRenewals,
                      onChanged: (value) {
                        setState(() {
                          _showUpcomingRenewals = value ?? false;
                        });
                        _onFilterChanged();
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Subscription table
        Expanded(child: _buildSubscriptionTable()),

        // Pagination
        if (_totalPages > 1) _buildPagination(),
      ],
    );
  }

  Widget _buildSubscriptionTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSubscriptions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_subscriptions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.subscriptions_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No subscriptions found'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Subscription ID')),
            DataColumn(label: Text('User')),
            DataColumn(label: Text('Tier')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Current Period')),
            DataColumn(label: Text('Renewal Date')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _subscriptions.map(_buildSubscriptionRow).toList(),
        ),
      ),
    );
  }

  DataRow _buildSubscriptionRow(SubscriptionModel subscription) {
    final canModify = subscription.isActive;

    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 120,
            child: Text(
              subscription.id.substring(0, 8),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(subscription.userId.substring(0, 8))),
        DataCell(_buildTierChip(subscription.tier)),
        DataCell(_buildStatusChip(subscription.status)),
        DataCell(
          Text(
            subscription.currentPeriodStart != null &&
                    subscription.currentPeriodEnd != null
                ? '${_formatDate(subscription.currentPeriodStart!)} - ${_formatDate(subscription.currentPeriodEnd!)}'
                : 'N/A',
          ),
        ),
        DataCell(
          Text(
            subscription.currentPeriodEnd != null
                ? _formatDate(subscription.currentPeriodEnd!)
                : 'N/A',
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                onPressed: () => _showSubscriptionDetail(subscription),
                tooltip: 'View Details',
              ),
              if (canModify)
                IconButton(
                  icon: const Icon(Icons.upgrade, size: 20, color: Colors.blue),
                  onPressed: () => _showUpgradeDowngradeDialog(subscription),
                  tooltip: 'Upgrade/Downgrade',
                ),
              if (canModify && !subscription.cancelAtPeriodEnd)
                IconButton(
                  icon: const Icon(Icons.cancel, size: 20, color: Colors.red),
                  onPressed: () => _showCancelDialog(subscription),
                  tooltip: 'Cancel Subscription',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTierChip(SubscriptionTier tier) {
    Color color;
    switch (tier) {
      case SubscriptionTier.enterprise:
        color = Colors.purple;
        break;
      case SubscriptionTier.premium:
        color = Colors.blue;
        break;
      case SubscriptionTier.free:
        color = Colors.grey;
        break;
    }

    return Chip(
      label: Text(
        tier.displayName.toUpperCase(),
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildStatusChip(SubscriptionStatus status) {
    Color color;
    switch (status) {
      case SubscriptionStatus.active:
        color = Colors.green;
        break;
      case SubscriptionStatus.canceled:
        color = Colors.red;
        break;
      case SubscriptionStatus.pastDue:
        color = Colors.orange;
        break;
      case SubscriptionStatus.trialing:
        color = Colors.blue;
        break;
      case SubscriptionStatus.incomplete:
        color = Colors.grey;
        break;
    }

    return Chip(
      label: Text(
        status.displayName.toUpperCase(),
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${(_currentPage - 1) * _pageSize + 1}-${_currentPage * _pageSize > _totalSubscriptions ? _totalSubscriptions : _currentPage * _pageSize} of $_totalSubscriptions subscriptions',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () => _onPageChanged(_currentPage - 1)
                    : null,
              ),
              Text('Page $_currentPage of $_totalPages'),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages
                    ? () => _onPageChanged(_currentPage + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Subscription Detail Dialog - displays comprehensive subscription information
class _SubscriptionDetailDialog extends StatefulWidget {
  final SubscriptionModel subscription;

  const _SubscriptionDetailDialog({required this.subscription});

  @override
  State<_SubscriptionDetailDialog> createState() =>
      _SubscriptionDetailDialogState();
}

class _SubscriptionDetailDialogState extends State<_SubscriptionDetailDialog> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _userDetails;
  List<Map<String, dynamic>> _paymentHistory = [];

  @override
  void initState() {
    super.initState();
    _loadSubscriptionDetails();
  }

  Future<void> _loadSubscriptionDetails() async {
    final adminService = di.serviceLocator.get<AdminCenterService>();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get user details
      final userDetails = await adminService.getUserDetails(
        widget.subscription.userId,
      );

      setState(() {
        _userDetails = userDetails;
        _paymentHistory = List<Map<String, dynamic>>.from(
          userDetails['payment_history'] ?? [],
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load subscription details: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subscription Details',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Content
            Expanded(child: _buildContent()),

            // Actions
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSubscriptionDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subscription Information
          _buildSection('Subscription Information', [
            _buildInfoRow('Subscription ID', widget.subscription.id),
            _buildInfoRow('User ID', widget.subscription.userId),
            _buildInfoRow('Tier', widget.subscription.tier.displayName),
            _buildInfoRow('Status', widget.subscription.status.displayName),
            _buildInfoRow(
              'Created',
              _formatDateTime(widget.subscription.createdAt),
            ),
            _buildInfoRow(
              'Updated',
              _formatDateTime(widget.subscription.updatedAt),
            ),
          ]),

          const SizedBox(height: 24),

          // Billing Information
          _buildSection('Billing Information', [
            _buildInfoRow(
              'Current Period Start',
              widget.subscription.currentPeriodStart != null
                  ? _formatDateTime(widget.subscription.currentPeriodStart!)
                  : 'N/A',
            ),
            _buildInfoRow(
              'Current Period End',
              widget.subscription.currentPeriodEnd != null
                  ? _formatDateTime(widget.subscription.currentPeriodEnd!)
                  : 'N/A',
            ),
            if (widget.subscription.currentPeriodEnd != null)
              _buildInfoRow(
                'Days Remaining',
                '${widget.subscription.daysRemaining} days',
              ),
            if (widget.subscription.cancelAtPeriodEnd)
              _buildInfoRow(
                'Cancellation',
                'Scheduled at period end',
                isWarning: true,
              ),
            if (widget.subscription.canceledAt != null)
              _buildInfoRow(
                'Canceled At',
                _formatDateTime(widget.subscription.canceledAt!),
                isWarning: true,
              ),
          ]),

          const SizedBox(height: 24),

          // Trial Information
          if (widget.subscription.trialStart != null ||
              widget.subscription.trialEnd != null)
            _buildSection('Trial Information', [
              if (widget.subscription.trialStart != null)
                _buildInfoRow(
                  'Trial Start',
                  _formatDateTime(widget.subscription.trialStart!),
                ),
              if (widget.subscription.trialEnd != null)
                _buildInfoRow(
                  'Trial End',
                  _formatDateTime(widget.subscription.trialEnd!),
                ),
              _buildInfoRow(
                'Trial Status',
                widget.subscription.isTrialing ? 'Active' : 'Ended',
              ),
            ]),

          const SizedBox(height: 24),

          // Stripe Information
          if (widget.subscription.stripeSubscriptionId != null)
            _buildSection('Stripe Information', [
              _buildInfoRow(
                'Subscription ID',
                widget.subscription.stripeSubscriptionId!,
              ),
              if (widget.subscription.stripeCustomerId != null)
                _buildInfoRow(
                  'Customer ID',
                  widget.subscription.stripeCustomerId!,
                ),
            ]),

          const SizedBox(height: 24),

          // User Information
          if (_userDetails != null)
            _buildSection('User Information', [
              _buildInfoRow('Email', _userDetails!['email'] ?? 'N/A'),
              _buildInfoRow(
                'Username',
                _userDetails!['username'] ?? _userDetails!['name'] ?? 'N/A',
              ),
              _buildInfoRow('Status', _userDetails!['status'] ?? 'N/A'),
            ]),

          const SizedBox(height: 24),

          // Payment History
          if (_paymentHistory.isNotEmpty)
            _buildSection('Recent Payment History', [
              _buildPaymentHistoryTable(_paymentHistory),
            ]),

          const SizedBox(height: 24),

          // Metadata
          if (widget.subscription.metadata != null &&
              widget.subscription.metadata!.isNotEmpty)
            _buildSection('Metadata', [
              _buildMetadataTable(widget.subscription.metadata!),
            ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isWarning ? Colors.orange : null,
                fontWeight: isWarning ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryTable(List<Map<String, dynamic>> payments) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Amount')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Method')),
      ],
      rows: payments.take(5).map((payment) {
        return DataRow(
          cells: [
            DataCell(
              Text(
                _formatDateTime(
                  DateTime.tryParse(payment['created_at'] ?? '') ??
                      DateTime.now(),
                ),
              ),
            ),
            DataCell(
              Text('\$${payment['amount']?.toStringAsFixed(2) ?? '0.00'}'),
            ),
            DataCell(Text(payment['status'] ?? 'N/A')),
            DataCell(Text(payment['payment_method_type'] ?? 'N/A')),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMetadataTable(Map<String, dynamic> metadata) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Key')),
        DataColumn(label: Text('Value')),
      ],
      rows: metadata.entries.map((entry) {
        return DataRow(
          cells: [
            DataCell(Text(entry.key)),
            DataCell(Text(entry.value.toString())),
          ],
        );
      }).toList(),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Upgrade/Downgrade Dialog - allows changing subscription tier
class _UpgradeDowngradeDialog extends StatefulWidget {
  final SubscriptionModel subscription;
  final VoidCallback onUpdated;

  const _UpgradeDowngradeDialog({
    required this.subscription,
    required this.onUpdated,
  });

  @override
  State<_UpgradeDowngradeDialog> createState() =>
      _UpgradeDowngradeDialogState();
}

class _UpgradeDowngradeDialogState extends State<_UpgradeDowngradeDialog> {
  late SubscriptionTier _selectedTier;
  bool _isLoading = false;
  String? _error;
  double? _proratedCharge;

  @override
  void initState() {
    super.initState();
    _selectedTier = widget.subscription.tier;
  }

  /// Calculate prorated charges for tier change
  void _calculateProratedCharge() {
    if (_selectedTier == widget.subscription.tier) {
      setState(() {
        _proratedCharge = null;
      });
      return;
    }

    // Simple proration calculation (this would be more complex in production)
    final tierPrices = {
      SubscriptionTier.free: 0.0,
      SubscriptionTier.premium: 9.99,
      SubscriptionTier.enterprise: 29.99,
    };

    final currentPrice = tierPrices[widget.subscription.tier] ?? 0.0;
    final newPrice = tierPrices[_selectedTier] ?? 0.0;
    final priceDiff = newPrice - currentPrice;

    // Calculate days remaining in current period
    final daysRemaining = widget.subscription.daysRemaining;
    final daysInPeriod = 30; // Assuming monthly billing

    // Prorated charge = (price difference) * (days remaining / days in period)
    final prorated =
        priceDiff * ((daysRemaining ?? 30) / daysInPeriod.toDouble());

    setState(() {
      _proratedCharge = prorated;
    });
  }

  Future<void> _updateSubscription() async {
    if (_selectedTier == widget.subscription.tier) {
      setState(() {
        _error = 'Please select a different tier';
      });
      return;
    }

    final paymentService = di.serviceLocator.get<PaymentGatewayService>();
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.editSubscriptions)) {
      setState(() {
        _error = 'You do not have permission to edit subscriptions';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // In a real implementation, we would need to get the price ID for the new tier
      // For now, we'll use a placeholder
      final newPriceId = 'price_${_selectedTier.name}';

      final updatedSubscription = await paymentService.updateSubscription(
        subscriptionId: widget.subscription.id,
        newPriceId: newPriceId,
      );

      if (updatedSubscription != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription updated successfully')),
        );
        widget.onUpdated();
      } else {
        setState(() {
          _error = 'Failed to update subscription';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to update subscription: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upgrade/Downgrade Subscription'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Tier: ${widget.subscription.tier.displayName}'),
            const SizedBox(height: 24),
            DropdownButtonFormField<SubscriptionTier>(
              initialValue: _selectedTier,
              decoration: const InputDecoration(
                labelText: 'New Subscription Tier',
                border: OutlineInputBorder(),
              ),
              items: SubscriptionTier.values.map((tier) {
                return DropdownMenuItem(
                  value: tier,
                  child: Text(tier.displayName),
                );
              }).toList(),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _selectedTier = value;
                        });
                        _calculateProratedCharge();
                      }
                    },
            ),
            const SizedBox(height: 16),
            if (_proratedCharge != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _proratedCharge! >= 0
                      ? Colors.blue.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _proratedCharge! >= 0
                        ? Colors.blue.shade200
                        : Colors.green.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prorated Charge',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _proratedCharge! >= 0
                            ? Colors.blue.shade900
                            : Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _proratedCharge! >= 0
                          ? 'User will be charged \$${_proratedCharge!.abs().toStringAsFixed(2)} for the upgrade'
                          : 'User will receive a credit of \$${_proratedCharge!.abs().toStringAsFixed(2)} for the downgrade',
                      style: TextStyle(
                        fontSize: 12,
                        color: _proratedCharge! >= 0
                            ? Colors.blue.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on ${widget.subscription.daysRemaining} days remaining in current period',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _updateSubscription,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}

/// Cancel Subscription Dialog - allows canceling a subscription
class _CancelSubscriptionDialog extends StatefulWidget {
  final SubscriptionModel subscription;
  final VoidCallback onCanceled;

  const _CancelSubscriptionDialog({
    required this.subscription,
    required this.onCanceled,
  });

  @override
  State<_CancelSubscriptionDialog> createState() =>
      _CancelSubscriptionDialogState();
}

class _CancelSubscriptionDialogState extends State<_CancelSubscriptionDialog> {
  bool _immediate = false;
  bool _isLoading = false;
  String? _error;

  Future<void> _cancelSubscription() async {
    final paymentService = di.serviceLocator.get<PaymentGatewayService>();
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.editSubscriptions)) {
      setState(() {
        _error = 'You do not have permission to cancel subscriptions';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final canceledSubscription = await paymentService.cancelSubscription(
        subscriptionId: widget.subscription.id,
        immediate: _immediate,
      );

      if (canceledSubscription != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _immediate
                  ? 'Subscription canceled immediately'
                  : 'Subscription will be canceled at period end',
            ),
          ),
        );
        widget.onCanceled();
      } else {
        setState(() {
          _error = 'Failed to cancel subscription';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to cancel subscription: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel Subscription'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subscription: ${widget.subscription.tier.displayName}'),
            const SizedBox(height: 8),
            Text('User ID: ${widget.subscription.userId.substring(0, 8)}'),
            const SizedBox(height: 24),
            const Text(
              'Choose cancellation type:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _immediate = false;
                      });
                    },
              child: RadioListTile<bool>(
                title: const Text('Cancel at period end'),
                subtitle: Text(
                  widget.subscription.currentPeriodEnd != null
                      ? 'User will retain access until ${_formatDate(widget.subscription.currentPeriodEnd!)}'
                      : 'User will retain access until the end of the current billing period',
                ),
                value: false,
                selected: !_immediate,
              ),
            ),
            GestureDetector(
              onTap: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _immediate = true;
                      });
                    },
              child: RadioListTile<bool>(
                title: const Text('Cancel immediately'),
                subtitle: const Text(
                  'User will lose access immediately. No refund will be issued.',
                  style: TextStyle(color: Colors.red),
                ),
                value: true,
                selected: _immediate,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _cancelSubscription,
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Cancel Subscription'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
