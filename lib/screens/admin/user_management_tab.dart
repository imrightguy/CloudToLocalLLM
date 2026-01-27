import 'package:flutter/material.dart';
import '../../services/admin_center_service.dart';
import '../../models/admin_role_model.dart';
import '../../models/subscription_model.dart';
import '../../di/locator.dart' as di;
import 'dart:async';

/// User Management Tab for the Admin Center
/// Provides search, filtering, and management of user accounts
class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  // Controllers
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // State
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalUsers = 0;
  final int _pageSize = 50;

  // Filters
  String? _selectedTier;
  String? _selectedStatus;
  String _sortBy = 'created_at';
  String _sortOrder = 'desc';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Load users with current filters
  Future<void> _loadUsers() async {
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.viewUsers)) {
      setState(() {
        _error = 'You do not have permission to view users';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await adminService.getUsers(
        page: _currentPage,
        limit: _pageSize,
        search:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        tier: _selectedTier,
        status: _selectedStatus,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      );

      setState(() {
        _users = List<Map<String, dynamic>>.from(result['users'] ?? []);
        _totalUsers = result['total'] ?? 0;
        _totalPages = result['totalPages'] ?? 1;
        _currentPage = result['page'] ?? 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load users: $e';
        _isLoading = false;
      });
    }
  }

  /// Handle search with debouncing
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _currentPage = 1;
      _loadUsers();
    });
  }

  /// Handle filter change
  void _onFilterChanged() {
    _currentPage = 1;
    _loadUsers();
  }

  /// Handle page change
  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadUsers();
  }

  /// Show user detail dialog
  void _showUserDetail(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => _UserDetailDialog(userId: user['id']),
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
                'User Management',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'View and manage user accounts, subscriptions, and permissions',
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
                  hintText: 'Search by email, username, or user ID...',
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
                        labelText: 'Account Status',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('All Statuses'),
                        ),
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'suspended',
                          child: Text('Suspended'),
                        ),
                        DropdownMenuItem(
                          value: 'deleted',
                          child: Text('Deleted'),
                        ),
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
                          child: Text('Registration Date'),
                        ),
                        DropdownMenuItem(
                          value: 'last_login',
                          child: Text('Last Login'),
                        ),
                        DropdownMenuItem(value: 'email', child: Text('Email')),
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

        // User table
        Expanded(child: _buildUserTable()),

        // Pagination
        if (_totalPages > 1) _buildPagination(),
      ],
    );
  }

  Widget _buildUserTable() {
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
            ElevatedButton(onPressed: _loadUsers, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No users found'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Username')),
            DataColumn(label: Text('Subscription')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Registered')),
            DataColumn(label: Text('Last Login')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _users.map(_buildUserRow).toList(),
        ),
      ),
    );
  }

  DataRow _buildUserRow(Map<String, dynamic> user) {
    final tier = user['subscription_tier'] ?? 'free';
    final status = user['status'] ?? 'active';
    final createdAt = DateTime.tryParse(user['created_at'] ?? '');
    final lastLogin = DateTime.tryParse(user['last_login'] ?? '');

    return DataRow(
      cells: [
        DataCell(Text(user['email'] ?? '')),
        DataCell(Text(user['username'] ?? user['name'] ?? '')),
        DataCell(_buildTierChip(tier)),
        DataCell(_buildStatusChip(status)),
        DataCell(Text(createdAt != null ? _formatDate(createdAt) : 'N/A')),
        DataCell(Text(lastLogin != null ? _formatDate(lastLogin) : 'Never')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                onPressed: () => _showUserDetail(user),
                tooltip: 'View Details',
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _showEditDialog(user),
                tooltip: 'Edit',
              ),
              if (status == 'active')
                IconButton(
                  icon: const Icon(Icons.block, size: 20, color: Colors.red),
                  onPressed: () => _showSuspendDialog(user),
                  tooltip: 'Suspend',
                )
              else if (status == 'suspended')
                IconButton(
                  icon: const Icon(
                    Icons.check_circle,
                    size: 20,
                    color: Colors.green,
                  ),
                  onPressed: () => _showReactivateDialog(user),
                  tooltip: 'Reactivate',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTierChip(String tier) {
    Color color;
    switch (tier.toLowerCase()) {
      case 'enterprise':
        color = Colors.purple;
        break;
      case 'premium':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        tier.toUpperCase(),
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
        color = Colors.green;
        break;
      case 'suspended':
        color = Colors.red;
        break;
      case 'deleted':
        color = Colors.grey;
        break;
      default:
        color = Colors.orange;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
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
            'Showing ${(_currentPage - 1) * _pageSize + 1}-${_currentPage * _pageSize > _totalUsers ? _totalUsers : _currentPage * _pageSize} of $_totalUsers users',
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

  void _showEditDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => _EditUserDialog(
        user: user,
        onSaved: () {
          Navigator.of(context).pop();
          _loadUsers(); // Refresh the list
        },
      ),
    );
  }

  void _showSuspendDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => _SuspendUserDialog(
        user: user,
        onSuspended: () {
          Navigator.of(context).pop();
          _loadUsers(); // Refresh the list
        },
      ),
    );
  }

  void _showReactivateDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => _ReactivateUserDialog(
        user: user,
        onReactivated: () {
          Navigator.of(context).pop();
          _loadUsers(); // Refresh the list
        },
      ),
    );
  }
}

/// User Detail Dialog - displays comprehensive user information
class _UserDetailDialog extends StatefulWidget {
  final String userId;

  const _UserDetailDialog({required this.userId});

  @override
  State<_UserDetailDialog> createState() => _UserDetailDialogState();
}

class _UserDetailDialogState extends State<_UserDetailDialog> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _userDetails;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    final adminService = di.serviceLocator.get<AdminCenterService>();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final details = await adminService.getUserDetails(widget.userId);
      setState(() {
        _userDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load user details: $e';
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
                  'User Details',
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
              onPressed: _loadUserDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_userDetails == null) {
      return const Center(child: Text('No user details available'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Information
          _buildSection('Profile Information', [
            _buildInfoRow('User ID', _userDetails!['id'] ?? 'N/A'),
            _buildInfoRow('Email', _userDetails!['email'] ?? 'N/A'),
            _buildInfoRow(
              'Username',
              _userDetails!['username'] ?? _userDetails!['name'] ?? 'N/A',
            ),
            _buildInfoRow('Status', _userDetails!['status'] ?? 'N/A'),
            _buildInfoRow(
              'Registered',
              _formatDateTime(_userDetails!['created_at']),
            ),
            _buildInfoRow(
              'Last Login',
              _formatDateTime(_userDetails!['last_login']),
            ),
          ]),

          const SizedBox(height: 24),

          // Subscription Information
          if (_userDetails!['subscription'] != null)
            _buildSection('Subscription Information', [
              _buildInfoRow(
                'Tier',
                _userDetails!['subscription']['tier'] ?? 'N/A',
              ),
              _buildInfoRow(
                'Status',
                _userDetails!['subscription']['status'] ?? 'N/A',
              ),
              _buildInfoRow(
                'Current Period Start',
                _formatDateTime(
                  _userDetails!['subscription']['current_period_start'],
                ),
              ),
              _buildInfoRow(
                'Current Period End',
                _formatDateTime(
                  _userDetails!['subscription']['current_period_end'],
                ),
              ),
              if (_userDetails!['subscription']['cancel_at_period_end'] == true)
                _buildInfoRow(
                  'Cancellation',
                  'Scheduled at period end',
                  isWarning: true,
                ),
            ]),

          const SizedBox(height: 24),

          // Payment History
          if (_userDetails!['payment_history'] != null &&
              (_userDetails!['payment_history'] as List).isNotEmpty)
            _buildSection('Recent Payment History', [
              _buildPaymentHistoryTable(_userDetails!['payment_history']),
            ]),

          const SizedBox(height: 24),

          // Session Information
          if (_userDetails!['sessions'] != null &&
              (_userDetails!['sessions'] as List).isNotEmpty)
            _buildSection('Active Sessions', [
              _buildSessionsTable(_userDetails!['sessions']),
            ]),

          const SizedBox(height: 24),

          // Activity Timeline
          if (_userDetails!['activity'] != null &&
              (_userDetails!['activity'] as List).isNotEmpty)
            _buildSection('Recent Activity', [
              _buildActivityTimeline(_userDetails!['activity']),
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

  Widget _buildPaymentHistoryTable(List<dynamic> payments) {
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
            DataCell(Text(_formatDateTime(payment['created_at']))),
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

  Widget _buildSessionsTable(List<dynamic> sessions) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('IP Address')),
        DataColumn(label: Text('User Agent')),
        DataColumn(label: Text('Last Active')),
      ],
      rows: sessions.take(5).map((session) {
        return DataRow(
          cells: [
            DataCell(Text(session['ip_address'] ?? 'N/A')),
            DataCell(
              SizedBox(
                width: 200,
                child: Text(
                  session['user_agent'] ?? 'N/A',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(Text(_formatDateTime(session['last_active']))),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildActivityTimeline(List<dynamic> activities) {
    return Column(
      children: activities.take(10).map((activity) {
        return ListTile(
          leading: const Icon(Icons.circle, size: 12),
          title: Text(activity['action'] ?? 'Unknown action'),
          subtitle: Text(_formatDateTime(activity['created_at'])),
          dense: true,
        );
      }).toList(),
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}

/// Edit User Dialog - allows changing subscription tier
class _EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSaved;

  const _EditUserDialog({required this.user, required this.onSaved});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late String _selectedTier;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedTier = widget.user['subscription_tier'] ?? 'free';
  }

  Future<void> _saveChanges() async {
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.editUsers)) {
      setState(() {
        _error = 'You do not have permission to edit users';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await adminService.updateUserSubscription(
        widget.user['id'],
        _selectedTier,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User subscription updated successfully'),
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to update user: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit User Subscription'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${widget.user['email']}'),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _selectedTier,
              decoration: const InputDecoration(
                labelText: 'Subscription Tier',
                border: OutlineInputBorder(),
              ),
              items: SubscriptionTier.values.map((tier) {
                return DropdownMenuItem(
                  value: tier.name,
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
                      }
                    },
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
          onPressed: _isLoading ? null : _saveChanges,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// Suspend User Dialog - allows suspending a user account with reason
class _SuspendUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSuspended;

  const _SuspendUserDialog({required this.user, required this.onSuspended});

  @override
  State<_SuspendUserDialog> createState() => _SuspendUserDialogState();
}

class _SuspendUserDialogState extends State<_SuspendUserDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _suspendUser() async {
    if (_reasonController.text.trim().isEmpty) {
      setState(() {
        _error = 'Please provide a reason for suspension';
      });
      return;
    }

    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.suspendUsers)) {
      setState(() {
        _error = 'You do not have permission to suspend users';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await adminService.suspendUser(
        widget.user['id'],
        _reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User suspended successfully')),
        );
        widget.onSuspended();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to suspend user: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Suspend User Account'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${widget.user['email']}'),
            const SizedBox(height: 16),
            const Text(
              'This will suspend the user account and prevent them from accessing the application.',
              style: TextStyle(color: Colors.orange),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for suspension *',
                hintText: 'Enter the reason for suspending this account',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              enabled: !_isLoading,
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
          onPressed: _isLoading ? null : _suspendUser,
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Suspend'),
        ),
      ],
    );
  }
}

/// Reactivate User Dialog - allows reactivating a suspended user account
class _ReactivateUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onReactivated;

  const _ReactivateUserDialog({
    required this.user,
    required this.onReactivated,
  });

  @override
  State<_ReactivateUserDialog> createState() => _ReactivateUserDialogState();
}

class _ReactivateUserDialogState extends State<_ReactivateUserDialog> {
  bool _isLoading = false;
  String? _error;

  Future<void> _reactivateUser() async {
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.suspendUsers)) {
      setState(() {
        _error = 'You do not have permission to reactivate users';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await adminService.reactivateUser(widget.user['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User reactivated successfully')),
        );
        widget.onReactivated();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to reactivate user: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reactivate User Account'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${widget.user['email']}'),
            const SizedBox(height: 16),
            const Text(
              'This will reactivate the user account and restore their access to the application.',
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
          onPressed: _isLoading ? null : _reactivateUser,
          style: FilledButton.styleFrom(backgroundColor: Colors.green),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Reactivate'),
        ),
      ],
    );
  }
}
