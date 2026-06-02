/// Account Settings Category Widget
///
/// Provides user account information, subscription tier, session details,
/// logout functionality, and admin center access for admin users.
library;

import 'package:flutter/material.dart';
import '../../di/locator.dart' as di;
import '../../services/auth_service.dart';
import '../../services/session_storage_service.dart';
import '../../services/enhanced_user_tier_service.dart';
import '../../services/admin_center_service.dart';
import '../../models/user_model.dart';
import '../../models/session_model.dart';
import 'settings_category_widgets.dart';
import 'settings_base.dart';

/// Account Settings Category - User Account and Session Information
class AccountSettingsCategory extends SettingsCategoryContentWidget {
  final SessionStorageService? sessionStorageService;

  const AccountSettingsCategory({
    super.key,
    required super.categoryId,
    super.isActive = true,
    super.onSettingsChanged,
    this.sessionStorageService,
  });

  @override
  Widget buildCategoryContent(BuildContext context) {
    return _AccountSettingsCategoryContent(
      sessionStorageService: sessionStorageService,
    );
  }
}

class _AccountSettingsCategoryContent extends StatefulWidget {
  final SessionStorageService? sessionStorageService;

  const _AccountSettingsCategoryContent({this.sessionStorageService});

  @override
  State<_AccountSettingsCategoryContent> createState() =>
      _AccountSettingsCategoryContentState();
}

class _AccountSettingsCategoryContentState
    extends State<_AccountSettingsCategoryContent> {
  late AuthService _authService;
  late SessionStorageService _sessionStorage;
  EnhancedUserTierService? _tierService;
  AdminCenterService? _adminCenterService;

  // State variables
  UserModel? _currentUser;
  SessionModel? _currentSession;
  bool _isLoading = true;
  bool _isLoggingOut = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _authService = di.serviceLocator.get<AuthService>();
    _sessionStorage = widget.sessionStorageService ?? SessionStorageService();

    // Get tier service if available
    try {
      _tierService = di.serviceLocator.get<EnhancedUserTierService>();
    } catch (e) {
      debugPrint('[AccountSettings] EnhancedUserTierService not available: $e');
    }

    // Get admin center service if available
    try {
      _adminCenterService = di.serviceLocator.get<AdminCenterService>();
    } catch (e) {
      debugPrint('[AccountSettings] AdminCenterService not available: $e');
    }

    _loadAccountInfo();
  }

  /// Load current user and session information
  Future<void> _loadAccountInfo() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get current user from AuthService
      _currentUser = _authService.currentUser;

      // Get current session from SessionStorageService
      _currentSession = await _sessionStorage.getCurrentSession();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[AccountSettings] Error loading account info: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load account information';
      });
    }
  }

  /// Handle logout
  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoggingOut = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Perform logout
      await _authService.logout();

      setState(() {
        _isLoggingOut = false;
        _successMessage = 'Logged out successfully';
      });

      // Navigate to login screen after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          // The router should handle navigation based on auth state
          // This will be handled by the app's routing logic
        }
      });
    } catch (e) {
      debugPrint('[AccountSettings] Error during logout: $e');
      setState(() {
        _isLoggingOut = false;
        _errorMessage = 'Failed to logout: ${e.toString()}';
      });
    }
  }

  /// Navigate to Admin Center
  void _navigateToAdminCenter() {
    // Navigate to admin center screen
    // This will be handled by the router
    Navigator.of(context).pushNamed('/admin');
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Get subscription tier display text
  String _getSubscriptionTier() {
    if (_tierService != null) {
      final tier = _tierService!.currentTier;
      // Convert enum to string and capitalize
      final tierStr = tier.name;
      return tierStr.isEmpty
          ? 'Free'
          : tierStr[0].toUpperCase() + tierStr.substring(1);
    }
    // Fallback to default
    return 'Free';
  }

  /// Get subscription tier color
  Color _getTierColor() {
    final tier = _tierService?.currentTier ?? 'free';
    switch (tier) {
      case 'enterprise':
        return Colors.purple;
      case 'premium':
        return Colors.blue;
      case 'free':
      default:
        return Colors.grey;
    }
  }

  /// Get subscription tier icon
  IconData _getTierIcon() {
    final tier = _tierService?.currentTier ?? 'free';
    switch (tier) {
      case 'enterprise':
        return Icons.diamond;
      case 'premium':
        return Icons.star;
      case 'free':
      default:
        return Icons.info;
    }
  }

  /// Get tier description/benefits
  List<String> _getTierBenefits() {
    if (_tierService != null) {
      return _tierService!.tierBenefits;
    }
    return ['Basic features', 'Local storage only'];
  }

  /// Check if user is on free tier
  bool _isFreeTier() {
    return (_tierService?.currentTier ?? 'free') == 'free';
  }

  /// Handle upgrade button press
  void _handleUpgrade() {
    // Navigate to upgrade/pricing page
    // This will be handled by the router
    Navigator.of(context).pushNamed('/upgrade');
  }

  /// Check if user is admin
  bool _isAdminUser() {
    // First try AdminCenterService
    if (_adminCenterService != null) {
      return _adminCenterService!.isAdmin;
    }
    // Fallback: cannot determine admin status without service
    return false;
  }

  Widget _buildBenefitRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentUser == null) {
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SettingsGroup(
              title: 'Sync to All Devices',
              description: 'Connect to Cloud Relay for multi-device sync',
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.3),
                              width: 3,
                            ),
                          ),
                          child: const Text(
                            '🦞',
                            style: TextStyle(fontSize: 48),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'Sync to All Devices',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Connect your local companion app to Cloud Relay to securely sync your chats, custom agent personalities, and model configurations across all your devices using our Tailscale-first secure mesh.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Benefits of Cloud Sync',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildBenefitRow(
                        context,
                        icon: Icons.vpn_lock,
                        title: 'Tailscale-First Secure Mesh',
                        description:
                            'Secure peer-to-peer transport that keeps your local keys on your device.',
                      ),
                      const SizedBox(height: 12),
                      _buildBenefitRow(
                        context,
                        icon: Icons.sync,
                        title: 'Seamless Synchronization',
                        description:
                            'Access your conversation history and preferences from web, mobile, or other PCs.',
                      ),
                      const SizedBox(height: 12),
                      _buildBenefitRow(
                        context,
                        icon: Icons.memory,
                        title: 'Avatar Memory Backup',
                        description:
                            'Preserve your companion\'s memory, custom skills, and evolutionary history safely.',
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () async {
                            setState(() {
                              _isLoading = true;
                            });
                            try {
                              await _authService.login();
                              if (mounted) {
                                await _loadAccountInfo();
                              }
                            } catch (e) {
                              debugPrint('[AccountSettings] Login failed: $e');
                              if (mounted) {
                                setState(() {
                                  _errorMessage = 'Failed to connect to Cloud Relay: $e';
                                });
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          },
                          icon: const Icon(Icons.cloud_queue, size: 20),
                          label: const Text(
                            'Connect to Cloud Relay',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Success message
          if (_successMessage != null)
            SettingsSuccessMessage(
              message: _successMessage!,
              onDismiss: () {
                setState(() {
                  _successMessage = null;
                });
              },
            ),

          // Error message
          if (_errorMessage != null)
            SettingsValidationError(
              message: _errorMessage!,
              onDismiss: () {
                setState(() {
                  _errorMessage = null;
                });
              },
            ),

          // User Profile Section
          SettingsGroup(
            title: 'User Profile',
            description: 'Your account information',
            children: [
              // User Email
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your email address',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.email, color: Colors.grey.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _currentUser!.email,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1,
                color: Colors.grey.shade300,
                indent: 16,
                endIndent: 16,
              ),

              // Display Name
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Display Name',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your profile name',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person, color: Colors.grey.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _currentUser!.displayName,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Subscription Section
          SettingsGroup(
            title: 'Subscription',
            description: 'Your subscription tier and benefits',
            children: [
              // Subscription Tier
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscription Tier',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your current subscription level',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getTierColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getTierColor().withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getTierIcon(),
                                color: _getTierColor(),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _getSubscriptionTier(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: _getTierColor(),
                                      ),
                                ),
                              ),
                              // Upgrade button for free tier
                              if (_isFreeTier())
                                FilledButton.icon(
                                  onPressed: _handleUpgrade,
                                  icon: const Icon(Icons.upgrade, size: 18),
                                  label: const Text('Upgrade'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _getTierColor(),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Tier benefits
                          ..._getTierBenefits().take(3).map((benefit) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                    color:
                                        _getTierColor().withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    benefit,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.grey.shade700,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Session Section
          SettingsGroup(
            title: 'Session',
            description: 'Your current session information',
            children: [
              // Login Time
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login Time',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'When you logged in',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.grey.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _currentSession != null
                                  ? _formatDate(_currentSession!.createdAt)
                                  : 'Not available',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1,
                color: Colors.grey.shade300,
                indent: 16,
                endIndent: 16,
              ),

              // Token Expiration
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Token Expiration',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'When your session expires',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.grey.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _currentSession != null
                                  ? _formatDate(_currentSession!.expiresAt)
                                  : 'Not available',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Admin Section (only for admin users)
          if (_isAdminUser())
            SettingsGroup(
              title: 'Administration',
              description: 'Admin tools and management',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _navigateToAdminCenter,
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Open Admin Center'),
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // Logout Section
          SettingsGroup(
            title: 'Session Management',
            description: 'Manage your session',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLoggingOut ? null : _handleLogout,
                    icon: _isLoggingOut
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.logout),
                    label: Text(_isLoggingOut ? 'Logging out...' : 'Logout'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Settings success message widget
class SettingsSuccessMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const SettingsSuccessMessage({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.green.shade600),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: Icon(Icons.close, color: Colors.green.shade600),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}

/// Settings validation error widget
class SettingsValidationError extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const SettingsValidationError({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.red.shade600),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: Icon(Icons.close, color: Colors.red.shade600),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}
