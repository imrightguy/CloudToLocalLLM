import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/admin_center_service.dart';
import '../../services/platform_adapter.dart';
import '../../services/auth_service.dart';
import '../../di/locator.dart' as di;
import '../../models/admin_role_model.dart';
import 'dashboard_tab.dart';
import 'user_management_tab.dart';
import 'payment_management_tab.dart';
import 'subscription_management_tab.dart';
import 'financial_reports_tab.dart';
import 'audit_log_viewer_tab.dart';
import 'admin_management_tab.dart';
import 'email_provider_config_tab.dart';
import 'email_metrics_tab.dart';
import 'dns_config_tab.dart';

/// Admin Center main screen for managing users, payments, and subscriptions.
/// This is separate from the AdminPanelScreen which handles system administration
/// (Docker containers, system stats). The Admin Center focuses on user/payment management.
class AdminCenterScreen extends StatefulWidget {
  const AdminCenterScreen({super.key});

  @override
  State<AdminCenterScreen> createState() => _AdminCenterScreenState();
}

/// Navigation item for the sidebar
class _NavigationItem {
  final String id;
  final String label;
  final IconData icon;
  final Widget Function() builder;
  final List<AdminPermission> requiredPermissions;

  const _NavigationItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.requiredPermissions = const [],
  });
}

class _AdminCenterScreenState extends State<AdminCenterScreen> {
  bool _isCheckingAuth = true;
  bool _isAuthorized = false;
  String? _errorMessage;
  String _selectedTabId = 'dashboard';
  late AdminCenterService _adminService;

  late PlatformAdapter _platformAdapter;

  // Define all navigation items
  late final List<_NavigationItem> _allNavigationItems;

  @override
  void initState() {
    super.initState();
    _adminService = di.serviceLocator.get<AdminCenterService>();
    _platformAdapter = di.serviceLocator.get<PlatformAdapter>();
    _initializeNavigationItems();
    _checkAdminAuthorization();
  }

  /// Initialize navigation items with their permissions
  void _initializeNavigationItems() {
    _allNavigationItems = [
      _NavigationItem(
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard,
        builder: () => const DashboardTab(),
        requiredPermissions: [], // All admins can view dashboard
      ),
      _NavigationItem(
        id: 'users',
        label: 'User Management',
        icon: Icons.people,
        builder: () => const UserManagementTab(),
        requiredPermissions: [AdminPermission.viewUsers],
      ),
      _NavigationItem(
        id: 'payments',
        label: 'Payment Management',
        icon: Icons.payment,
        builder: () => const PaymentManagementTab(),
        requiredPermissions: [AdminPermission.viewPayments],
      ),
      _NavigationItem(
        id: 'subscriptions',
        label: 'Subscription Management',
        icon: Icons.subscriptions,
        builder: () => const SubscriptionManagementTab(),
        requiredPermissions: [AdminPermission.viewSubscriptions],
      ),
      _NavigationItem(
        id: 'reports',
        label: 'Financial Reports',
        icon: Icons.bar_chart,
        builder: () => const FinancialReportsTab(),
        requiredPermissions: [AdminPermission.viewReports],
      ),
      _NavigationItem(
        id: 'audit',
        label: 'Audit Logs',
        icon: Icons.history,
        builder: () => const AuditLogViewerTab(),
        requiredPermissions: [AdminPermission.viewAuditLogs],
      ),
      _NavigationItem(
        id: 'admins',
        label: 'Admin Management',
        icon: Icons.admin_panel_settings,
        builder: () => const AdminManagementTab(),
        requiredPermissions: [AdminPermission.viewAdmins],
      ),
      _NavigationItem(
        id: 'email',
        label: 'Email Provider',
        icon: Icons.email,
        builder: () => const EmailProviderConfigTab(),
        requiredPermissions: [AdminPermission.viewConfiguration],
      ),
      _NavigationItem(
        id: 'email-metrics',
        label: 'Email Metrics',
        icon: Icons.analytics,
        builder: () => const EmailMetricsTab(),
        requiredPermissions: [AdminPermission.viewConfiguration],
      ),
      _NavigationItem(
        id: 'dns',
        label: 'DNS Configuration',
        icon: Icons.dns,
        builder: () => const DnsConfigTab(),
        requiredPermissions: [AdminPermission.viewConfiguration],
      ),
    ];
  }

  /// Get filtered navigation items based on user permissions
  List<_NavigationItem> get _visibleNavigationItems {
    return _allNavigationItems.where((item) {
      // If no permissions required, show to all admins
      if (item.requiredPermissions.isEmpty) return true;

      // Check if user has any of the required permissions
      return item.requiredPermissions
          .any((permission) => _adminService.hasPermission(permission));
    }).toList();
  }

  /// Check if the current user has admin privileges
  Future<void> _checkAdminAuthorization() async {
    try {
      final authService = di.serviceLocator.get<AuthService>();
      final userEmail = authService.currentUser?.email;

      debugPrint(
          '[AdminCenterScreen] Checking admin authorization for: $userEmail');

      // Check if user email matches the authorized admin admin email
      // On Desktop, we allow access in Guest Mode
      final isAuthorized = userEmail == 'christopher.maltais@gmail.com' ||
          (!kIsWeb && userEmail == null);

      if (isAuthorized) {
        // Initialize admin service to load roles
        await _adminService.initialize();
      }

      setState(() {
        _isAuthorized = isAuthorized;
        _isCheckingAuth = false;
        if (!isAuthorized) {
          _errorMessage =
              'You do not have permission to access the Admin Center.';
        }
      });

      debugPrint(
          '[AdminCenterScreen] Authorization check complete: $isAuthorized');
    } catch (e) {
      debugPrint('[AdminCenterScreen] Error checking admin authorization: $e');
      setState(() {
        _isCheckingAuth = false;
        _isAuthorized = false;
        _errorMessage = 'Error checking admin permissions: $e';
      });
    }
  }

  /// Handle tab selection
  void _onTabSelected(String tabId) {
    setState(() {
      _selectedTabId = tabId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    // Show loading indicator while checking authorization
    if (_isCheckingAuth) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Admin Center',
            semanticsLabel: 'Admin Center',
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _platformAdapter.buildProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Verifying admin permissions...',
                style: theme.textTheme.bodyLarge,
                semanticsLabel: 'Verifying admin permissions',
              ),
            ],
          ),
        ),
      );
    }

    // Show error message if not authorized
    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Admin Center',
            semanticsLabel: 'Admin Center',
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: isMobile ? 48 : 64,
                    color: theme.colorScheme.error,
                    semanticLabel: 'Access denied icon',
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  Text(
                    'Access Denied',
                    style: (isMobile
                            ? theme.textTheme.titleLarge
                            : theme.textTheme.headlineSmall)
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    semanticsLabel: 'Access Denied',
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  Text(
                    _errorMessage ??
                        'You do not have permission to access this page.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isMobile ? 16 : 24),
                  _platformAdapter.buildButton(
                    onPressed: () => context.go('/'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.home, size: isMobile ? 20 : 18),
                        SizedBox(width: isMobile ? 8 : 6),
                        const Text('Return to Home'),
                      ],
                    ),
                    isPrimary: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Get visible navigation items based on permissions
    final visibleItems = _visibleNavigationItems;
    final selectedItem = visibleItems.firstWhere(
      (item) => item.id == _selectedTabId,
      orElse: () => visibleItems.first,
    );

    // Show Admin Center interface with responsive layout
    if (isMobile) {
      return _buildMobileLayout(context, visibleItems, selectedItem);
    } else if (isTablet) {
      return _buildTabletLayout(context, visibleItems, selectedItem);
    } else {
      return _buildDesktopLayout(context, visibleItems, selectedItem);
    }
  }

  /// Build mobile layout with bottom navigation
  Widget _buildMobileLayout(
    BuildContext context,
    List<_NavigationItem> visibleItems,
    _NavigationItem selectedItem,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectedItem.label,
          semanticsLabel: selectedItem.label,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
          tooltip: 'Back to Chat',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshCurrentTab(context, selectedItem),
            tooltip: 'Refresh',
            iconSize: 24,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => context.go('/'),
            tooltip: 'Exit Admin Center',
            iconSize: 24,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
      body: selectedItem.builder(),
      bottomNavigationBar: _buildBottomNavigation(context, visibleItems),
    );
  }

  /// Build tablet layout with rail navigation
  Widget _buildTabletLayout(
    BuildContext context,
    List<_NavigationItem> visibleItems,
    _NavigationItem selectedItem,
  ) {
    return Scaffold(
      body: Row(
        children: [
          _buildNavigationRail(context, visibleItems),
          Expanded(
            child: Column(
              children: [
                _buildHeader(context, selectedItem),
                Expanded(child: selectedItem.builder()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build desktop layout with full sidebar
  Widget _buildDesktopLayout(
    BuildContext context,
    List<_NavigationItem> visibleItems,
    _NavigationItem selectedItem,
  ) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(context, visibleItems),
          Expanded(
            child: Column(
              children: [
                _buildHeader(context, selectedItem),
                Expanded(child: selectedItem.builder()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build bottom navigation for mobile
  Widget _buildBottomNavigation(
    BuildContext context,
    List<_NavigationItem> visibleItems,
  ) {
    // Show only first 5 items in bottom nav, rest in overflow menu
    final bottomNavItems = visibleItems.take(5).toList();

    return NavigationBar(
      selectedIndex: bottomNavItems
          .indexWhere((item) => item.id == _selectedTabId)
          .clamp(0, bottomNavItems.length - 1),
      onDestinationSelected: (index) {
        if (index < bottomNavItems.length) {
          _onTabSelected(bottomNavItems[index].id);
        }
      },
      destinations: bottomNavItems.map((item) {
        return NavigationDestination(
          icon: Icon(item.icon, semanticLabel: item.label),
          label: item.label,
        );
      }).toList(),
      height: 64,
    );
  }

  /// Build navigation rail for tablet
  Widget _buildNavigationRail(
    BuildContext context,
    List<_NavigationItem> visibleItems,
  ) {
    final selectedIndex = visibleItems
        .indexWhere((item) => item.id == _selectedTabId)
        .clamp(0, visibleItems.length - 1);

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (index < visibleItems.length) {
          _onTabSelected(visibleItems[index].id);
        }
      },
      labelType: NavigationRailLabelType.selected,
      destinations: visibleItems.map((item) {
        return NavigationRailDestination(
          icon: Icon(item.icon, semanticLabel: item.label),
          label: Text(item.label),
        );
      }).toList(),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () => context.go('/'),
              tooltip: 'Exit Admin Center',
              iconSize: 24,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
        ),
      ),
    );
  }

  /// Refresh current tab
  void _refreshCurrentTab(BuildContext context, _NavigationItem selectedItem) {
    setState(() {
      // This will trigger a rebuild of the current tab
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Refreshing ${selectedItem.label}...'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Build the sidebar navigation
  Widget _buildSidebar(
      BuildContext context, List<_NavigationItem> visibleItems) {
    final theme = Theme.of(context);
    final authService = di.serviceLocator.get<AuthService>();
    final userEmail = authService.currentUser?.email ?? 'Admin';

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Admin Center header
          Semantics(
            label: 'Admin Center navigation header',
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: theme.colorScheme.primary,
                        size: 28,
                        semanticLabel: 'Admin panel icon',
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Admin Center',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userEmail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Navigation items
          Expanded(
            child: Semantics(
              label: 'Admin Center navigation menu',
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: visibleItems.length,
                itemBuilder: (context, index) {
                  final item = visibleItems[index];
                  final isSelected = item.id == _selectedTabId;

                  return _buildNavigationItem(
                    context,
                    item: item,
                    isSelected: isSelected,
                    onTap: () => _onTabSelected(item.id),
                  );
                },
              ),
            ),
          ),

          // Logout button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: _platformAdapter.buildButton(
                onPressed: () => context.go('/'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.exit_to_app, size: 18),
                    SizedBox(width: 6),
                    Text('Exit Admin Center'),
                  ],
                ),
                isPrimary: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a single navigation item
  Widget _buildNavigationItem(
    BuildContext context, {
    required _NavigationItem item,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Semantics(
      label: '${item.label} navigation item',
      selected: isSelected,
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 20,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    semanticLabel: '${item.label} icon',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the header with title and actions
  Widget _buildHeader(BuildContext context, _NavigationItem selectedItem) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Semantics(
      label: '${selectedItem.label} header',
      header: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: isMobile ? 12 : 16,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selectedItem.icon,
              size: isMobile ? 24 : 28,
              color: theme.colorScheme.primary,
              semanticLabel: '${selectedItem.label} icon',
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Text(
                selectedItem.label,
                style: (isMobile
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.headlineSmall)
                    ?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _refreshCurrentTab(context, selectedItem),
              tooltip: 'Refresh',
              iconSize: isMobile ? 20 : 24,
              constraints: BoxConstraints(
                minWidth: isMobile ? 44 : 36,
                minHeight: isMobile ? 44 : 36,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
