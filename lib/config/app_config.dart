import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';

/// Application configuration constants
class AppConfig {
  // App Information
  static const String appName = 'Aiman';
  static const String appVersion = '10.1.205';
  static const String appDescription =
      'Privacy-first local AI workspace with support for multiple AI backends. Login is optional and used only to enable Cloud Relay and secure tunnels.';

  // URLs
  static const String homepageUrl = 'https://cloudtolocalllm.online';
  static const String appUrl = 'https://app.cloudtolocalllm.online';
  static const String adminCenterUrl = 'https://admin.cloudtolocalllm.online';
  static const String githubUrl =
      'https://github.com/CloudToLocalLLM-online/CloudToLocalLLM';
  static const String githubReleasesUrl =
      'https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest';

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
  static const bool enableDevMode = false; // Set to false for production
  static const String devModeUser = 'dev@cloudtolocalllm.online';

  // Testing mode settings
  static const bool forceSetupWizard =
      false; // Set to true only for testing new setup flow
  // Gateway Connection Options
  static const bool skipDeviceIdentity =
      false; // Use paired-device auth, reject token-only
  // API Configuration
  static const String apiBaseUrl = 'https://api.cloudtolocalllm.online';
  static const Duration apiTimeout = Duration(seconds: 30);
  // Tunnel Configuration (SSH over WebSocket)
  static const String tunnelSshUrl =
      'wss://api.cloudtolocalllm.online/ssh';
  static const String tunnelSshUrlDev =
      'wss://api.cloudtolocalllm.online/ssh';
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
  static const bool enableDirectTunnelMode = false;
  static const bool enableLegacyTunnelServices = false;
  static const bool enableLegacyStreamingProxyServices = false;

  // ==========================================================================
  // Gateway Configuration (Runtime Configurable)
  // ==========================================================================
  //
  // Architecture:
  // 1. Defaults defined here (compile-time)
  // 2. Environment variables override at startup (container/deployment)
  // 3. SharedPreferences override at runtime (user config)
  // 4. All code reads from getters, never from constants directly
  //
  // Environment Variables:
  // - OPENCLAW_GATEWAY_HOST (e.g., "127.0.0.1", "100.78.133.50")
  // - OPENCLAW_GATEWAY_PORT (e.g., "18789")
  // - OPENCLAW_GATEWAY_URL (full URL, overrides host/port if set)

  // Default values (compile-time fallbacks)
  static const String _defaultGatewayHost = '127.0.0.1';
  static const int _defaultGatewayPort = 18789;

  // Hermes Agent API server defaults
  static const String defaultHermesHost = '127.0.0.1';
  static const int defaultHermesPort = 8642;
  static String get defaultHermesUrl =>
      'http://$defaultHermesHost:$defaultHermesPort';
  static const Duration gatewayTimeout = Duration(seconds: 60);

  // Runtime values (initialized from env vars or defaults)
  static String _runtimeGatewayHost = String.fromEnvironment(
    'OPENCLAW_GATEWAY_HOST',
    defaultValue: _defaultGatewayHost,
  );
  static int _runtimeGatewayPort = int.tryParse(
        const String.fromEnvironment('OPENCLAW_GATEWAY_PORT',
            defaultValue: '18789'),
      ) ??
      _defaultGatewayPort;
  static String? _runtimeGatewayUrl = String.fromEnvironment(
    'OPENCLAW_GATEWAY_URL',
    defaultValue: '',
  ).isNotEmpty
      ? const String.fromEnvironment('OPENCLAW_GATEWAY_URL')
      : null;

  // Getters for gateway configuration
  /// Default gateway host (compile-time constant)
  static String get defaultGatewayHost => _defaultGatewayHost;

  /// Default gateway port (compile-time constant)
  static int get defaultGatewayPort => _defaultGatewayPort;

  /// Default gateway URL (compile-time constant)
  static String get defaultGatewayUrl =>
      'http://$_defaultGatewayHost:$_defaultGatewayPort';

  /// Runtime gateway host (from env var or default)
  static String get gatewayHost => _runtimeGatewayHost;

  /// Runtime gateway port (from env var or default)
  static int get gatewayPort => _runtimeGatewayPort;

  /// Runtime gateway URL (from env var, SharedPreferences, or default)
  /// Note: For sync contexts, this returns the env/default URL.
  /// For async contexts with SharedPreferences, use getGatewayUrl() instead.
  static String get gatewayUrl =>
      _runtimeGatewayUrl ?? 'http://$_runtimeGatewayHost:$_runtimeGatewayPort';

  /// Update runtime gateway configuration (call at startup or from settings)
  static void setGatewayConfig({String? host, int? port, String? url}) {
    if (host != null) _runtimeGatewayHost = host;
    if (port != null) _runtimeGatewayPort = port;
    if (url != null) _runtimeGatewayUrl = url;
    debugPrint(
        '[AppConfig] Gateway config updated: host=\$host, port=\$port, url=\$url');
  }

  /// Reset gateway config to defaults
  static void resetGatewayConfig() {
    _runtimeGatewayHost = _defaultGatewayHost;
    _runtimeGatewayPort = _defaultGatewayPort;
    _runtimeGatewayUrl = null;
  }

  /// Get the actual gateway URL to use
  /// This reads from settings preference if configured, otherwise returns runtime URL
  /// Note: This is async and requires SettingsPreferenceService
  /// For sync contexts, use gatewayUrl getter instead
  static Future<String> getGatewayUrl() async {
    final settingsService = SettingsPreferenceService();
    final configuredUrl = await settingsService.getGatewayUrl();
    return (configuredUrl?.isNotEmpty ?? false)
        ? configuredUrl!
        : gatewayUrl; // Use runtime URL, not hardcoded default
  }

  /// Get gateway URL synchronously (for use during initialization)
  /// Returns runtime URL (env var or default)
  static String getGatewayUrlSync() => gatewayUrl;

  // Cloud Relay Configuration (via OpenClaw)
  static const String cloudGatewayUrl = '$apiBaseUrl/v1';

  // Admin Interface Configuration
  static const bool enableAdminInterface = true;
  static const int adminServerPort = 8080;

  // Platform-specific admin server URLs
  static const String adminServerUrlWeb = 'https://api.cloudtolocalllm.online';
  static const String adminServerUrlDesktop = 'http://127.0.0.1:8080';

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
    debugPrint('[DEBUG] - OpenClaw Gateway: $defaultGatewayUrl');
    debugPrint('[DEBUG] - Bridge Status URL: $bridgeStatusUrl');
    debugPrint('[DEBUG] - Bridge Register URL: $bridgeRegisterUrl');
    debugPrint('[DEBUG] - Admin Server URL: $adminServerUrl');
    debugPrint('[DEBUG] - Admin API Base URL: $adminApiBaseUrl');
  }

  // Bridge Configuration
  static const String bridgePollingUrl = '$apiBaseUrl/v1/bridge-polling';
  static const String bridgeStatusUrl = '$bridgePollingUrl/:bridgeId/status';
  static const String bridgeRegisterUrl = '$bridgePollingUrl/register';
}

enum AuthProviderType {
  auth0,
}
