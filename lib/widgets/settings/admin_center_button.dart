/// Admin Center Button Widget
///
/// Provides access to the Admin Center for authenticated admin users.
/// Implements keyboard accessibility, ARIA labels, and error handling.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../di/locator.dart' as di;
import '../../services/auth_service.dart';
import '../../services/admin_center_service.dart';
import '../../services/navigation_service.dart';

import '../../models/user_model.dart';

/// Admin Center Button - Navigation to Admin Center for Admin Users
class AdminCenterButton extends StatefulWidget {
  /// Callback when navigation is attempted
  final VoidCallback? onNavigate;

  /// Callback when error occurs
  final Function(String error)? onError;

  /// Custom button label
  final String label;

  /// Custom button icon
  final IconData icon;

  /// Whether to show loading state
  final bool isLoading;

  const AdminCenterButton({
    super.key,
    this.onNavigate,
    this.onError,
    this.label = 'Open Admin Center',
    this.icon = Icons.admin_panel_settings,
    this.isLoading = false,
  });

  @override
  State<AdminCenterButton> createState() => _AdminCenterButtonState();
}

class _AdminCenterButtonState extends State<AdminCenterButton> {
  late AuthService _authService;
  AdminCenterService? _adminCenterService;
  NavigationService? _navigationService;

  bool _isAdmin = false;
  bool _isNavigating = false;
  String? _errorMessage;
  FocusNode? _focusNode;

  @override
  void initState() {
    super.initState();

    // Get AuthService - try to get from DI, but handle gracefully if not available
    try {
      _authService = di.serviceLocator.get<AuthService>();
    } catch (e) {
      debugPrint('[AdminCenterButton] AuthService not available: $e');
      // Create a minimal auth service for testing
      _authService = _MinimalAuthService();
    }

    // Get optional services
    try {
      _adminCenterService = di.serviceLocator.get<AdminCenterService>();
    } catch (e) {
      debugPrint('[AdminCenterButton] AdminCenterService not available: $e');
    }

    try {
      _navigationService = di.serviceLocator.get<NavigationService>();
    } catch (e) {
      debugPrint('[AdminCenterButton] NavigationService not available: $e');
    }

    _focusNode = FocusNode();
    _checkAdminStatus();
  }

  /// Check if current user is admin
  void _checkAdminStatus() {
    final stopwatch = Stopwatch()..start();

    try {
      if (_adminCenterService != null) {
        setState(() {
          _isAdmin = _adminCenterService!.isAdmin;
        });
      }

      stopwatch.stop();
      debugPrint(
          '[AdminCenterButton] Admin status check completed in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      debugPrint('[AdminCenterButton] Error checking admin status: $e');
      setState(() {
        _isAdmin = false;
      });
    }
  }

  /// Navigate to Admin Center
  Future<void> _navigateToAdminCenter() async {
    if (_isNavigating) return;

    setState(() {
      _isNavigating = true;
      _errorMessage = null;
    });

    final stopwatch = Stopwatch()..start();

    try {
      // Get session token
      final token = await _authService.getAccessToken();

      if (token == null) {
        throw Exception('No session token available');
      }

      stopwatch.stop();
      debugPrint(
          '[AdminCenterButton] Navigation initiated in ${stopwatch.elapsedMilliseconds}ms');

      // Navigate to Admin Center
      if (_navigationService != null) {
        await _navigationService!.navigateToAdminCenter(token: token);
      } else {
        // Fallback: use direct navigation
        // This would be handled by the app's routing logic
        debugPrint('[AdminCenterButton] NavigationService not available');
      }

      widget.onNavigate?.call();

      setState(() {
        _isNavigating = false;
      });
    } catch (e) {
      stopwatch.stop();
      debugPrint(
          '[AdminCenterButton] Error navigating to Admin Center: $e (${stopwatch.elapsedMilliseconds}ms)');

      setState(() {
        _isNavigating = false;
        _errorMessage = 'Failed to navigate to Admin Center: ${e.toString()}';
      });

      widget.onError?.call(_errorMessage!);

      // Show error dialog
      if (mounted) {
        _showErrorDialog(_errorMessage!);
      }
    }
  }

  /// Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Navigation Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToAdminCenter();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _focusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hide button if user is not admin
    if (!_isAdmin) {
      return const SizedBox.shrink();
    }

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          _navigateToAdminCenter();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red.shade600),
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Admin Center Button
          FilledButton.icon(
            onPressed: _isNavigating ? null : _navigateToAdminCenter,
            icon: _isNavigating
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
                : Icon(widget.icon),
            label: Text(
              _isNavigating ? 'Navigating...' : widget.label,
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              minimumSize: const Size(44, 44), // Minimum touch target size
            ),
          ),
        ],
      ),
    );
  }
}

/// Semantic wrapper for Admin Center Button with accessibility support
class AdminCenterButtonAccessible extends StatelessWidget {
  final VoidCallback? onNavigate;
  final Function(String error)? onError;
  final String label;
  final IconData icon;
  final bool isLoading;

  const AdminCenterButtonAccessible({
    super.key,
    this.onNavigate,
    this.onError,
    this.label = 'Open Admin Center',
    this.icon = Icons.admin_panel_settings,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !isLoading,
      label: 'Open Admin Center - Navigate to the admin dashboard',
      onTap: onNavigate,
      child: AdminCenterButton(
        onNavigate: onNavigate,
        onError: onError,
        label: label,
        icon: icon,
        isLoading: isLoading,
      ),
    );
  }
}

/// Minimal Auth Service for testing
class _MinimalAuthService extends ChangeNotifier implements AuthService {
  @override
  ValueNotifier<bool> get areAuthenticatedServicesLoaded =>
      ValueNotifier(false);

  @override
  UserModel? get currentUser => null;

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getValidatedAccessToken() async => null;

  @override
  Future<bool> handleCallback({String? callbackUrl, String? code}) async =>
      true;

  @override
  Future<void> init() async {}

  @override
  ValueNotifier<bool> get isAuthenticated => ValueNotifier(false);

  @override
  ValueNotifier<bool> get isLoading => ValueNotifier(false);

  @override
  bool get isSessionBootstrapComplete => false;

  @override
  bool get isRestoringSession => false;

  @override
  Future<void> updateDisplayName(String name) async {}

  @override
  String get assistantName => 'CloudToLocalLLM';

  @override
  bool get isWeb => kIsWeb;

  @override
  Future<void> login({String? tenantId}) async {}

  @override
  Future<void> loginMockDeveloper() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> get sessionBootstrapFuture async {}
}
