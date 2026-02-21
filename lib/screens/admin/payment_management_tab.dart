import 'package:flutter/material.dart';
import '../../services/payment_gateway_service.dart';
import '../../services/admin_center_service.dart';
import '../../models/admin_role_model.dart';
import '../../models/payment_transaction_model.dart';
import '../../models/refund_model.dart';
import '../../di/locator.dart' as di;
import 'dart:async';

/// Payment Management Tab for the Admin Center
/// Provides transaction viewing, filtering, and refund processing
class PaymentManagementTab extends StatefulWidget {
  const PaymentManagementTab({super.key});

  @override
  State<PaymentManagementTab> createState() => _PaymentManagementTabState();
}

class _PaymentManagementTabState extends State<PaymentManagementTab> {
  // Controllers
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // State
  List<PaymentTransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalTransactions = 0;
  final int _pageSize = 100;

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedStatus;
  String? _selectedUserId;
  double? _minAmount;
  double? _maxAmount;
  String _sortBy = 'created_at';
  String _sortOrder = 'desc';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Load transactions with current filters
  Future<void> _loadTransactions() async {
    final paymentService = di.serviceLocator.get<PaymentGatewayService>();
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.viewPayments)) {
      setState(() {
        _error = 'You do not have permission to view payments';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final transactions = await paymentService.getTransactions(
        userId: _selectedUserId,
        startDate: _startDate,
        endDate: _endDate,
        status: _selectedStatus,
        page: _currentPage,
        limit: _pageSize,
        forceRefresh: true,
      );

      // Apply client-side filtering for amount range
      var filteredTransactions = transactions;
      if (_minAmount != null) {
        filteredTransactions =
            filteredTransactions.where((t) => t.amount >= _minAmount!).toList();
      }
      if (_maxAmount != null) {
        filteredTransactions =
            filteredTransactions.where((t) => t.amount <= _maxAmount!).toList();
      }

      // Apply sorting
      filteredTransactions.sort((a, b) {
        int comparison;
        switch (_sortBy) {
          case 'amount':
            comparison = a.amount.compareTo(b.amount);
            break;
          case 'status':
            comparison = a.status.value.compareTo(b.status.value);
            break;
          case 'created_at':
          default:
            comparison = a.createdAt.compareTo(b.createdAt);
        }
        return _sortOrder == 'asc' ? comparison : -comparison;
      });

      setState(() {
        _transactions = filteredTransactions;
        _totalTransactions = filteredTransactions.length;
        _totalPages = (_totalTransactions / _pageSize).ceil();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load transactions: $e';
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
      _loadTransactions();
    });
  }

  /// Handle filter change
  void _onFilterChanged() {
    _currentPage = 1;
    _loadTransactions();
  }

  /// Handle page change
  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadTransactions();
  }

  /// Show transaction detail dialog
  void _showTransactionDetail(PaymentTransactionModel transaction) {
    showDialog(
      context: context,
      builder: (context) => _TransactionDetailDialog(transaction: transaction),
    );
  }

  /// Show refund dialog
  void _showRefundDialog(PaymentTransactionModel transaction) {
    showDialog(
      context: context,
      builder: (context) => _RefundDialog(
        transaction: transaction,
        onRefunded: () {
          Navigator.of(context).pop();
          _loadTransactions(); // Refresh the list
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
                'Payment Management',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'View payment transactions, process refunds, and manage payment methods',
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

              // Filters row 1
              Row(
                children: [
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
                        ...TransactionStatus.values.map((status) {
                          return DropdownMenuItem(
                            value: status.value,
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

                  // Date range filter
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _startDate != null && _endDate != null
                            ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                            : 'Select Date Range',
                      ),
                      onPressed: _showDateRangePicker,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Sort options
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sortBy,
                      decoration: InputDecoration(
                        labelText: 'Sort By',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'created_at',
                          child: Text('Date'),
                        ),
                        DropdownMenuItem(
                          value: 'amount',
                          child: Text('Amount'),
                        ),
                        DropdownMenuItem(
                          value: 'status',
                          child: Text('Status'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _sortBy = value;
                          });
                          _onFilterChanged();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Sort order toggle
                  IconButton(
                    icon: Icon(
                      _sortOrder == 'asc'
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                    ),
                    onPressed: () {
                      setState(() {
                        _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
                      });
                      _onFilterChanged();
                    },
                    tooltip: _sortOrder == 'asc' ? 'Ascending' : 'Descending',
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Transaction table
        Expanded(child: _buildTransactionTable()),

        // Pagination
        if (_totalPages > 1) _buildPagination(),
      ],
    );
  }

  Widget _buildTransactionTable() {
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
              onPressed: _loadTransactions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_transactions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No transactions found'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Transaction ID')),
            DataColumn(label: Text('User')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Payment Method')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _transactions.map(_buildTransactionRow).toList(),
        ),
      ),
    );
  }

  DataRow _buildTransactionRow(PaymentTransactionModel transaction) {
    final canRefund = transaction.status == TransactionStatus.succeeded;

    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 120,
            child: Text(
              transaction.id.substring(0, 8),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(transaction.userId.substring(0, 8))),
        DataCell(Text('\$${transaction.amount.toStringAsFixed(2)}')),
        DataCell(_buildStatusChip(transaction.status)),
        DataCell(Text(transaction.paymentMethodType ?? 'N/A')),
        DataCell(Text(_formatDateTime(transaction.createdAt))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                onPressed: () => _showTransactionDetail(transaction),
                tooltip: 'View Details',
              ),
              if (canRefund)
                IconButton(
                  icon: const Icon(
                    Icons.money_off,
                    size: 20,
                    color: Colors.orange,
                  ),
                  onPressed: () => _showRefundDialog(transaction),
                  tooltip: 'Process Refund',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(TransactionStatus status) {
    Color color;
    switch (status) {
      case TransactionStatus.succeeded:
        color = Colors.green;
        break;
      case TransactionStatus.pending:
        color = Colors.orange;
        break;
      case TransactionStatus.failed:
        color = Colors.red;
        break;
      case TransactionStatus.refunded:
        color = Colors.purple;
        break;
      case TransactionStatus.partiallyRefunded:
        color = Colors.blue;
        break;
      case TransactionStatus.disputed:
        color = Colors.deepOrange;
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
            'Showing ${(_currentPage - 1) * _pageSize + 1}-${_currentPage * _pageSize > _totalTransactions ? _totalTransactions : _currentPage * _pageSize} of $_totalTransactions transactions',
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

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _onFilterChanged();
    }
  }
}

/// Transaction Detail Dialog - displays comprehensive transaction information
class _TransactionDetailDialog extends StatefulWidget {
  final PaymentTransactionModel transaction;

  const _TransactionDetailDialog({required this.transaction});

  @override
  State<_TransactionDetailDialog> createState() =>
      _TransactionDetailDialogState();
}

class _TransactionDetailDialogState extends State<_TransactionDetailDialog> {
  bool _isLoading = true;
  String? _error;
  List<RefundModel> _refunds = [];

  @override
  void initState() {
    super.initState();
    _loadTransactionDetails();
  }

  Future<void> _loadTransactionDetails() async {
    final paymentService = di.serviceLocator.get<PaymentGatewayService>();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get refunds for this transaction
      final refunds = await paymentService.getRefundsForTransaction(
        widget.transaction.id,
      );

      setState(() {
        _refunds = refunds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load transaction details: $e';
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
                  'Transaction Details',
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
              onPressed: _loadTransactionDetails,
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
          // Transaction Information
          _buildSection('Transaction Information', [
            _buildInfoRow('Transaction ID', widget.transaction.id),
            _buildInfoRow('User ID', widget.transaction.userId),
            _buildInfoRow(
              'Amount',
              '\$${widget.transaction.amount.toStringAsFixed(2)} ${widget.transaction.currency}',
            ),
            _buildInfoRow('Status', widget.transaction.status.displayName),
            _buildInfoRow(
              'Created',
              _formatDateTime(widget.transaction.createdAt),
            ),
            _buildInfoRow(
              'Updated',
              _formatDateTime(widget.transaction.updatedAt),
            ),
          ]),

          const SizedBox(height: 24),

          // Payment Method Information
          _buildSection('Payment Method', [
            _buildInfoRow(
              'Type',
              widget.transaction.paymentMethodType ?? 'N/A',
            ),
            _buildInfoRow(
              'Last 4 Digits',
              widget.transaction.paymentMethodLast4 ?? 'N/A',
            ),
            if (widget.transaction.receiptUrl != null)
              _buildInfoRow(
                'Receipt',
                widget.transaction.receiptUrl!,
                isLink: true,
              ),
          ]),

          const SizedBox(height: 24),

          // Stripe Information
          if (widget.transaction.stripePaymentIntentId != null)
            _buildSection('Stripe Information', [
              _buildInfoRow(
                'Payment Intent ID',
                widget.transaction.stripePaymentIntentId!,
              ),
              if (widget.transaction.stripeChargeId != null)
                _buildInfoRow('Charge ID', widget.transaction.stripeChargeId!),
            ]),

          const SizedBox(height: 24),

          // Failure Information
          if (widget.transaction.status == TransactionStatus.failed)
            _buildSection('Failure Information', [
              _buildInfoRow(
                'Failure Code',
                widget.transaction.failureCode ?? 'N/A',
                isWarning: true,
              ),
              _buildInfoRow(
                'Failure Message',
                widget.transaction.failureMessage ?? 'N/A',
                isWarning: true,
              ),
            ]),

          const SizedBox(height: 24),

          // Refund Information
          if (_refunds.isNotEmpty)
            _buildSection('Refunds', [_buildRefundsTable(_refunds)]),

          const SizedBox(height: 24),

          // Metadata
          if (widget.transaction.metadata != null &&
              widget.transaction.metadata!.isNotEmpty)
            _buildSection('Metadata', [
              _buildMetadataTable(widget.transaction.metadata!),
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

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isWarning = false,
    bool isLink = false,
  }) {
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
            child: isLink
                ? InkWell(
                    onTap: () {
                      // Open link in browser
                    },
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                : Text(
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

  Widget _buildRefundsTable(List<RefundModel> refunds) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Refund ID')),
        DataColumn(label: Text('Amount')),
        DataColumn(label: Text('Reason')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Date')),
      ],
      rows: refunds.map((refund) {
        return DataRow(
          cells: [
            DataCell(Text(refund.id.substring(0, 8))),
            DataCell(Text('\$${refund.amount.toStringAsFixed(2)}')),
            DataCell(Text(refund.reason.displayName)),
            DataCell(Text(refund.status.displayName)),
            DataCell(Text(_formatDateTime(refund.createdAt))),
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

/// Refund Dialog - allows processing refunds for transactions
class _RefundDialog extends StatefulWidget {
  final PaymentTransactionModel transaction;
  final VoidCallback onRefunded;

  const _RefundDialog({required this.transaction, required this.onRefunded});

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonDetailsController =
      TextEditingController();
  RefundReason _selectedReason = RefundReason.customerRequest;
  bool _isFullRefund = true;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.transaction.amount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonDetailsController.dispose();
    super.dispose();
  }

  Future<void> _processRefund() async {
    // Validate amount
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _error = 'Please enter a valid refund amount';
      });
      return;
    }

    if (amount > widget.transaction.amount) {
      setState(() {
        _error = 'Refund amount cannot exceed transaction amount';
      });
      return;
    }

    final paymentService = di.serviceLocator.get<PaymentGatewayService>();
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.processRefunds)) {
      setState(() {
        _error = 'You do not have permission to process refunds';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final refund = await paymentService.processRefund(
        transactionId: widget.transaction.id,
        amount: _isFullRefund ? null : amount,
        reason: _selectedReason,
        reasonDetails: _reasonDetailsController.text.trim().isNotEmpty
            ? _reasonDetailsController.text.trim()
            : null,
      );

      if (refund != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Refund processed successfully')),
        );
        widget.onRefunded();
      } else {
        setState(() {
          _error = 'Failed to process refund';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to process refund: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Process Refund'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transaction info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction: ${widget.transaction.id.substring(0, 16)}...',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Amount: \$${widget.transaction.amount.toStringAsFixed(2)}',
                    ),
                    Text('Status: ${widget.transaction.status.displayName}'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Refund type
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isFullRefund = true;
                                _amountController.text = widget
                                    .transaction.amount
                                    .toStringAsFixed(2);
                              });
                            },
                      child: RadioListTile<bool>(
                        title: const Text('Full Refund'),
                        value: true,
                        selected: _isFullRefund,
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isFullRefund = false;
                              });
                            },
                      child: RadioListTile<bool>(
                        title: const Text('Partial Refund'),
                        value: false,
                        selected: !_isFullRefund,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Refund amount
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Refund Amount *',
                  prefixText: '\$',
                  border: const OutlineInputBorder(),
                  enabled: !_isFullRefund && !_isLoading,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),

              // Refund reason
              DropdownButtonFormField<RefundReason>(
                initialValue: _selectedReason,
                decoration: const InputDecoration(
                  labelText: 'Refund Reason *',
                  border: OutlineInputBorder(),
                ),
                items: RefundReason.values.map((reason) {
                  return DropdownMenuItem(
                    value: reason,
                    child: Text(reason.displayName),
                  );
                }).toList(),
                onChanged: _isLoading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _selectedReason = value;
                          });
                        }
                      },
              ),
              const SizedBox(height: 16),

              // Reason details
              TextField(
                controller: _reasonDetailsController,
                decoration: const InputDecoration(
                  labelText: 'Additional Details (Optional)',
                  hintText: 'Provide additional context for this refund',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                enabled: !_isLoading,
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Warning message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone. The refund will be processed immediately through the payment gateway.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _processRefund,
          style: FilledButton.styleFrom(backgroundColor: Colors.orange),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Process Refund'),
        ),
      ],
    );
  }
}
