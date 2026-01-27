import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../di/locator.dart' as di;
import '../../services/admin_center_service.dart';
import '../../models/admin_role_model.dart';

/// Admin Management Tab for managing administrator accounts and roles.
/// Only accessible to Super Admin users.
///
/// Features:
/// - List all administrators with their roles
/// - Add new administrators by searching for users
/// - Assign roles (Support Admin or Finance Admin)
/// - Revoke admin roles
/// - View admin activity history
class AdminManagementTab extends StatefulWidget {
  const AdminManagementTab({super.key});

  @override
  State<AdminManagementTab> createState() => _AdminManagementTabState();
}

class _AdminManagementTabState extends State<AdminManagementTab> {
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  /// Load all administrators
  Future<void> _loadAdmins() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final adminService = di.serviceLocator.get<AdminCenterService>();
      final response = await adminService.getAdmins();

      setState(() {
        _admins = List<Map<String, dynamic>>.from(response['admins'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load administrators: $e';
        _isLoading = false;
      });
    }
  }

  /// Show add admin dialog
  Future<void> _showAddAdminDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _AddAdminDialog(onAdminAdded: _loadAdmins),
    );
  }

  /// Show revoke role confirmation dialog
  Future<void> _showRevokeRoleDialog(
    Map<String, dynamic> admin,
    Map<String, dynamic> role,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Admin Role'),
        content: Text(
          'Are you sure you want to revoke the ${_formatRole(role['role'])} role from ${admin['email']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _revokeRole(admin['userId'], role['role']);
    }
  }

  /// Revoke admin role
  Future<void> _revokeRole(String userId, String role) async {
    try {
      final adminService = di.serviceLocator.get<AdminCenterService>();
      await adminService.revokeAdminRole(userId, role);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin role revoked successfully')),
        );
        await _loadAdmins();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to revoke role: $e')));
      }
    }
  }

  /// Format role name for display
  String _formatRole(String role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'support_admin':
        return 'Support Admin';
      case 'finance_admin':
        return 'Finance Admin';
      default:
        return role;
    }
  }

  /// Get role badge color
  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin':
        return Colors.purple;
      case 'support_admin':
        return Colors.blue;
      case 'finance_admin':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminService = context.watch<AdminCenterService>();

    // Check if user is Super Admin
    if (!adminService.isSuperAdmin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Super Admin Access Required',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('Only Super Admins can manage administrator accounts.'),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Management',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage administrator accounts and roles',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _showAddAdminDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Add Admin'),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Error message
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.red.shade50,
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => setState(() => _errorMessage = null),
                ),
              ],
            ),
          ),

        // Loading indicator
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_admins.isEmpty)
          const Expanded(child: Center(child: Text('No administrators found')))
        else
          // Admin list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _admins.length,
              itemBuilder: (context, index) {
                final admin = _admins[index];
                return _buildAdminCard(admin);
              },
            ),
          ),
      ],
    );
  }

  /// Build admin card
  Widget _buildAdminCard(Map<String, dynamic> admin) {
    final roles = List<Map<String, dynamic>>.from(admin['roles'] ?? []);
    final activeRoles = roles.where((r) => r['isActive'] == true).toList();
    final activitySummary = admin['activitySummary'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    admin['email']?.substring(0, 1).toUpperCase() ?? '?',
                    style: TextStyle(
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        admin['email'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (admin['username'] != null)
                        Text(
                          admin['username'],
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Active roles
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activeRoles.map((role) {
                return Chip(
                  label: Text(_formatRole(role['role'])),
                  backgroundColor: _getRoleColor(
                    role['role'],
                  ).withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: _getRoleColor(role['role']),
                    fontWeight: FontWeight.bold,
                  ),
                  deleteIcon: role['role'] != 'super_admin'
                      ? const Icon(Icons.close, size: 18)
                      : null,
                  onDeleted: role['role'] != 'super_admin'
                      ? () => _showRevokeRoleDialog(admin, role)
                      : null,
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Activity summary
            if (activitySummary != null)
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActivityStat(
                        'Total Actions',
                        activitySummary['totalActions']?.toString() ?? '0',
                      ),
                    ),
                    Expanded(
                      child: _buildActivityStat(
                        'Recent (30d)',
                        activitySummary['recentActions']?.toString() ?? '0',
                      ),
                    ),
                    Expanded(
                      child: _buildActivityStat(
                        'Last Action',
                        activitySummary['lastActionAt'] != null
                            ? _formatDate(activitySummary['lastActionAt'])
                            : 'Never',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build activity stat
  Widget _buildActivityStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// Format date for display
  String _formatDate(dynamic date) {
    if (date == null) return 'Never';
    try {
      final dateTime =
          date is DateTime ? date : DateTime.parse(date.toString());
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()}w ago';
      } else {
        return '${(difference.inDays / 30).floor()}mo ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}

/// Dialog for adding a new admin
class _AddAdminDialog extends StatefulWidget {
  final VoidCallback onAdminAdded;

  const _AddAdminDialog({required this.onAdminAdded});

  @override
  State<_AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<_AddAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  AdminRole _selectedRole = AdminRole.supportAdmin;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Add admin
  Future<void> _addAdmin() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final adminService = di.serviceLocator.get<AdminCenterService>();
      await adminService.assignAdminRole(
        _emailController.text.trim(),
        _selectedRole,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin role assigned successfully')),
        );
        widget.onAdminAdded();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Administrator'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email field
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'user@example.com',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email is required';
                }
                if (!value.contains('@')) {
                  return 'Invalid email address';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Role selection
            Text('Select Role', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<AdminRole>(
              initialValue: _selectedRole,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.admin_panel_settings),
              ),
              items: [
                DropdownMenuItem(
                  value: AdminRole.supportAdmin,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Support Admin'),
                      Text(
                        'User management and support',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: AdminRole.financeAdmin,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Finance Admin'),
                      Text(
                        'Payments, refunds, and reports',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedRole = value);
                }
              },
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
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
          onPressed: _isLoading ? null : _addAdmin,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Admin'),
        ),
      ],
    );
  }
}
