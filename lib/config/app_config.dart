import 'package:flutter/foundation.dart';

/// Application configuration constants
class AppConfig {
  // App Information
  static const String appName = 'CloudToLocalLLM';
  static const String appVersion = '10.1.187';
  static const String appDescription =
      'Manage and run powerful Large Language Models locally, orchestrated via a cloud interface.';

  // URLs
  static const String homepageUrl = 'https://zoidbot.online';
  static const String appUrl = 'https://app.zoidbot.online';
  static const String adminCenterUrl = 'https://admin.zoidbot.online';
  static const String githubUrl =
      'https://github.com/Zoidbot/Zoidbot';
  static const String githubReleasesUrl =
      'https://github.com/Zoidbot/Zoidbot/releases/latest';


  // Configured Authentication Provider
  static const AuthProviderType authProvider = AuthProviderType.auth0;


  // Sentry Configuration
  // Can be overridden at compile time using --dart-define=SENTRY_DSN=your_dsn
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue:
        'https://b2fd3263e0ad7b490b0583f7df2e165a@o4509853774315520.ingest.us.sentry.io/4509853780541440',
  );
  static const String sentryEnvironment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: kReleaseMode ? 'production' : 'development',
  );

  // Development mode settings
  static const bool enableDevMode = true; // Set to false for production
  static const String devModeUser = 'dev@zoidbot.online';

  // API Configuration
  static const String apiBaseUrl = 'http://localhost:3000';
  static const Duration apiTimeout = Duration(seconds: 30);
  // Tunnel Configuration (SSH over WebSocket)
  static const String tunnelSshUrl =
      'ws://localhost:3000/ssh';
  static const String tunnelSshUrlDev =
      'ws://localhost:3000/ssh';
  // UI Configuration
  static const double maxContentWidth = 1200.0;
  static const double mobileBreakpoint = 768.0;
  static const double tabletBreakpoint = 1024.0;

  // Feature Flags
  static const bool enableDarkMode = true;
  static const bool enableAnalytics = false; // Disabled for privacy
  static const bool enableDebugMode = true; // Enabled for v3.5.2 development

  // Enhanced debug features for v3.5.2
  static const bool showTunnelDebugInfo = true;
  static const bool enableVerboseLogging = true;

  // Tier-based feature flags
  static const bool enableTierDetection = true;
  static const bool showTierInformation = true;
  static const bool enableDirectTunnelMode = true;

  // Platform-specific admin server URLs
  static const String adminServerUrlWeb =
      'https://api.zoidbot.online:3001';
  static const String adminServerUrlDesktop = 'http://localhost:3001';

  // Get admin server URL based on platform
  static String get adminServerUrl =>
      kIsWeb ? adminServerUrlWeb : adminServerUrlDesktop;
  static String get adminApiBaseUrl => '$adminServerUrl/api/admin';

  static const Duration adminApiTimeout = Duration(seconds: 45);

  // Admin Interface Feature Flags
  static const bool enableAdminSystemMonitoring = true;
  static const bool enableAdminUserManagement = true;
  static const bool enableAdminConfigManagement = true;
  static const bool enableAdminContainerManagement = true;
  static const bool enableAdminDataFlush = true;

  // Admin Interface Security Settings
  static const bool requireAdminRole = true;
  static const bool enableAdminAuditLogging = true;
  static const bool enableAdminRateLimiting = true;
  static const int adminSessionTimeoutMinutes = 30;

  // Admin Interface UI Configuration
  static const int adminDashboardRefreshIntervalSeconds = 30;
  static const int adminRealtimeUpdateIntervalSeconds = 5;
  static const bool enableAdminDarkMode = true;
  static const bool showAdminDebugInfo = enableDebugMode;

  // Debug logging for configuration
  static void logConfiguration() {
    debugPrint('[DEBUG] AppConfig loaded:');
    debugPrint('[DEBUG] - Admin Server URL: $adminServerUrl');
    debugPrint('[DEBUG] - Admin API Base URL: $adminApiBaseUrl');
  }
}

enum AuthProviderType {
  auth0,
}
