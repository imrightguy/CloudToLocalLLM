import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../services/theme_provider.dart';
import '../services/platform_adapter.dart';
import '../services/platform_detection_service.dart';

// Conditional import for debug panel - only import on web platform
import '../widgets/auth_debug_panel.dart'
    if (dart.library.io) '../widgets/auth_debug_panel_stub.dart';

/// Modern login screen with Supabase integration and unified theming
///
/// Requirements:
/// - 7.1: Apply unified theme system to all UI elements
/// - 7.2: Use platform-appropriate components and layouts
/// - 7.3: Display Authentication interface consistently
/// - 7.4: Adapt layout for different screen sizes
/// - 7.5: Maintain proper spacing and typography
/// - 7.6: Update when system theme settings change
/// - 13.1-13.3: Responsive design for mobile, tablet, desktop
/// - 14.1-14.6: Accessibility features
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  DateTime? _lastLoginAttempt;

  @override
  void initState() {
    super.initState();
    // Listen for authentication state changes to handle desktop auth completion
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      authService.isAuthenticated.addListener(_onAuthStateChanged);
    });
  }

  @override
  void dispose() {
    // Remove the listener to prevent memory leaks
    try {
      final authService = context.read<AuthService>();
      authService.isAuthenticated.removeListener(_onAuthStateChanged);
    } catch (e) {
      // Ignore errors during disposal
    }
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (mounted) {
      final authService = context.read<AuthService>();
      final isAuthenticated = authService.isAuthenticated.value;
      debugPrint(
          ' [LoginScreen] _onAuthStateChanged: isAuthenticated=$isAuthenticated');

      if (isAuthenticated) {
        debugPrint(' [LoginScreen] User authenticated, redirecting to home');
        // Use go('/') instead of pushing to avoid stacking screens
        context.go('/');
      }
    }
  }

  Future<void> _handleLogin() async {
    debugPrint(' [Login] Login button clicked!');

    // Prevent multiple rapid login attempts
    if (_isLoading) {
      debugPrint(' [Login] Login already in progress, ignoring button click');
      return;
    }

    // Prevent rapid successive clicks (within 2 seconds)
    if (_lastLoginAttempt != null &&
        DateTime.now().difference(_lastLoginAttempt!).inSeconds < 2) {
      debugPrint(
        ' [Login] Login button clicked too soon after previous attempt, ignoring',
      );
      return;
    }

    setState(() => _isLoading = true);
    _lastLoginAttempt = DateTime.now();
    debugPrint(' [Login] Starting login process');

    try {
      final authService = context.read<AuthService>();
      debugPrint(
        ' [Login] Platform info: ${authService.isWeb ? "Web" : "Native"}',
      );
      debugPrint(' [Login] Calling authService.login()');
      await authService.login();

      debugPrint(
        ' [Login] Login call completed',
      );

      // On Web with redirect, the code execution stops as the page reloads
      // For Native or Popup, we check the state
      if (mounted && authService.isAuthenticated.value) {
        debugPrint(' [Login] User authenticated, redirecting to home');
        context.go('/');
      }
    } catch (e, s) {
      debugPrint(' [Login] Login failed with error: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'An unexpected error occurred during login. Please try again.'),
            backgroundColor: AppTheme.dangerColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        debugPrint(' [Login] Setting loading state to false');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get unified theme and platform services (Requirements 7.1, 7.2, 7.6)
    // ThemeProvider is watched to ensure updates when system theme changes
    context.watch<ThemeProvider>();
    final platformService = context.watch<PlatformDetectionService>();
    final platformAdapter = PlatformAdapter(platformService);

    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    // Responsive layout breakpoints (Requirements 13.1, 13.2, 13.3, 7.4)
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1024;

    // Platform-appropriate spacing (Requirement 7.5)
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 32.0 : 48.0);
    final verticalPadding = isMobile ? 16.0 : 24.0;
    final cardMaxWidth =
        isMobile ? double.infinity : (isTablet ? 500.0 : 450.0);

    // Platform-appropriate typography (Requirement 7.5)
    final titleFontSize = isMobile ? 24.0 : 28.0;
    final descriptionFontSize = isMobile ? 14.0 : 16.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Background with theme-aware gradient (Requirement 7.1)
          Container(
            decoration: BoxDecoration(
              gradient: isDarkMode
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.2),
                        colorScheme.surface,
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.1),
                        colorScheme.surface,
                      ],
                    ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: cardMaxWidth,
                    ),
                    // Platform-appropriate card (Requirement 7.2)
                    child: platformAdapter.buildCard(
                      padding: EdgeInsets.all(isMobile ? 24.0 : 32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo/Icon with theme-aware colors (Requirement 7.1)
                          Container(
                            width: isMobile ? 80.0 : 100.0,
                            height: isMobile ? 80.0 : 100.0,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.3),
                                width: 3,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                '🦞',
                                style: TextStyle(fontSize: 48),
                              ),
                            ),
                          ),

                          SizedBox(height: isMobile ? 24.0 : 32.0),

                          // Welcome text with theme-aware colors (Requirement 7.1, 7.5)
                          Text(
                            'Hey Christopher!',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: 8.0),

                          // App name with theme-aware colors (Requirement 7.1, 7.5)
                          Text(
                            'I\'m CloudToLocalLLM, your AI assistant.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.8),
                              fontSize: descriptionFontSize,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: isMobile ? 32.0 : 40.0),

                          // Platform-appropriate login button (Requirements 7.2, 13.6)
                          SizedBox(
                            width: double.infinity,
                            height: isMobile
                                ? 48.0
                                : 52.0, // Touch target size (Requirement 13.6)
                            child: platformAdapter.buildButton(
                              onPressed:
                                  context.watch<AuthService>().isLoading.value
                                      ? null
                                      : _handleLogin,
                              isPrimary: true,
                              child: context
                                      .watch<AuthService>()
                                      .isLoading
                                      .value
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.cloud_queue, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Connect to Cloud Relay',
                                          style: TextStyle(
                                            fontSize: isMobile ? 16.0 : 18.0,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          SizedBox(height: 16.0),

                          TextButton(
                            onPressed: () => context.go('/'),
                            child: const Text('Continue in Local Mode'),
                          ),

                          const SizedBox(height: 8.0),

                           TextButton(
                             onPressed: _isLoading
                                 ? null
                                 : () async {
                                     final authService = context.read<AuthService>();
                                     setState(() => _isLoading = true);
                                     try {
                                       await authService.loginMockDeveloper();
                                       if (!context.mounted) return;
                                       context.go('/');
                                     } catch (e) {
                                       debugPrint('Bypass failed: $e');
                                     } finally {
                                       if (mounted) {
                                         setState(() => _isLoading = false);
                                       }
                                     }
                                   },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.orange,
                            ),
                            child: const Text('Bypass to Test User (Debug)'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Debug panel (only visible in debug mode and on web)
          const AuthDebugPanel(),
        ],
      ),
    );
  }
}
