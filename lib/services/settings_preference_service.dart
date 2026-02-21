import 'package:shared_preferences/shared_preferences.dart';

class SettingsPreferenceService {
  static const String _proModeKey = 'settings_pro_mode';
  static const String _themeKey = 'settings_theme';
  static const String _languageKey = 'settings_language';

  // Privacy Settings
  static const String _analyticsKey = 'settings_analytics_enabled';
  static const String _crashReportingKey = 'settings_crash_reporting_enabled';
  static const String _usageStatsKey = 'settings_usage_stats_enabled';

  // Desktop Settings
  static const String _launchOnStartupKey = 'settings_launch_on_startup';
  static const String _minimizeToTrayKey = 'settings_minimize_to_tray';
  static const String _alwaysOnTopKey = 'settings_always_on_top';
  static const String _rememberWindowPositionKey =
      'settings_remember_window_position';
  static const String _rememberWindowSizeKey = 'settings_remember_window_size';
  static const String _windowPositionXKey = 'settings_window_position_x';
  static const String _windowPositionYKey = 'settings_window_position_y';
  static const String _windowWidthKey = 'settings_window_width';
  static const String _windowHeightKey = 'settings_window_height';
  static const String _gatewayAutoRestartKey = 'settings_gateway_auto_restart';
  static const String _gatewayUrlKey = 'settings_gateway_url';

  // Mobile Settings
  static const String _biometricAuthKey = 'settings_biometric_auth_enabled';
  static const String _notificationsKey = 'settings_notifications_enabled';
  static const String _notificationSoundKey =
      'settings_notification_sound_enabled';
  static const String _vibrationKey = 'settings_vibration_enabled';

  // Pro Mode
  Future<bool> isProMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_proModeKey) ?? false;
  }

  Future<void> setProMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proModeKey, value);
  }

  // Theme Preference
  /// Get the saved theme preference ('light', 'dark', or 'system')
  Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }

  /// Save the theme preference
  Future<void> setTheme(String theme) async {
    if (!['light', 'dark', 'system'].contains(theme)) {
      throw ArgumentError('Invalid theme: $theme');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme);
  }

  // Language Preference
  /// Get the saved language preference (language code like 'en', 'es', etc.)
  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'en';
  }

  /// Save the language preference
  Future<void> setLanguage(String language) async {
    if (!['en', 'es', 'fr', 'de', 'ja', 'zh'].contains(language)) {
      throw ArgumentError('Invalid language: $language');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
  }

  // Privacy Settings
  /// Get analytics enabled preference
  Future<bool> isAnalyticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_analyticsKey) ?? true;
  }

  /// Set analytics enabled preference
  Future<void> setAnalyticsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_analyticsKey, value);
  }

  /// Get crash reporting enabled preference
  Future<bool> isCrashReportingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_crashReportingKey) ?? true;
  }

  /// Set crash reporting enabled preference
  Future<void> setCrashReportingEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_crashReportingKey, value);
  }

  /// Get usage statistics enabled preference
  Future<bool> isUsageStatsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_usageStatsKey) ?? true;
  }

  /// Set usage statistics enabled preference
  Future<void> setUsageStatsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_usageStatsKey, value);
  }

  /// Clear all stored preferences
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Desktop Settings

  /// Get launch on startup preference
  Future<bool> isLaunchOnStartupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_launchOnStartupKey) ?? false;
  }

  /// Set launch on startup preference
  Future<void> setLaunchOnStartupEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_launchOnStartupKey, value);
  }

  /// Get minimize to tray preference
  Future<bool> isMinimizeToTrayEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_minimizeToTrayKey) ?? false;
  }

  /// Set minimize to tray preference
  Future<void> setMinimizeToTrayEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_minimizeToTrayKey, value);
  }

  /// Get always on top preference
  Future<bool> isAlwaysOnTopEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_alwaysOnTopKey) ?? false;
  }

  /// Set always on top preference
  Future<void> setAlwaysOnTopEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alwaysOnTopKey, value);
  }

  /// Get remember window position preference
  Future<bool> isRememberWindowPositionEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberWindowPositionKey) ?? true;
  }

  /// Set remember window position preference
  Future<void> setRememberWindowPositionEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberWindowPositionKey, value);
  }

  /// Get remember window size preference
  Future<bool> isRememberWindowSizeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberWindowSizeKey) ?? true;
  }

  /// Set remember window size preference
  Future<void> setRememberWindowSizeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberWindowSizeKey, value);
  }

  /// Get saved window position
  Future<Map<String, double>> getWindowPosition() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'x': prefs.getDouble(_windowPositionXKey) ?? 0.0,
      'y': prefs.getDouble(_windowPositionYKey) ?? 0.0,
    };
  }

  /// Save window position
  Future<void> setWindowPosition(double x, double y) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_windowPositionXKey, x);
    await prefs.setDouble(_windowPositionYKey, y);
  }

  /// Get saved window size
  Future<Map<String, double>> getWindowSize() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'width': prefs.getDouble(_windowWidthKey) ?? 1280.0,
      'height': prefs.getDouble(_windowHeightKey) ?? 720.0,
    };
  }

  /// Save window size
  Future<void> setWindowSize(double width, double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_windowWidthKey, width);
    await prefs.setDouble(_windowHeightKey, height);
  }

  // Mobile Settings

  /// Get biometric authentication enabled preference
  Future<bool> isBiometricAuthEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricAuthKey) ?? false;
  }

  /// Set biometric authentication enabled preference
  Future<void> setBiometricAuthEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricAuthKey, value);
  }

  /// Get notifications enabled preference
  Future<bool> isNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsKey) ?? true;
  }

  /// Set notifications enabled preference
  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
  }

  /// Get notification sound enabled preference
  Future<bool> isNotificationSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationSoundKey) ?? true;
  }

  /// Set notification sound enabled preference
  Future<void> setNotificationSoundEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationSoundKey, value);
  }

  /// Get vibration enabled preference
  Future<bool> isVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vibrationKey) ?? true;
  }

  /// Set vibration enabled preference
  Future<void> setVibrationEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationKey, value);
  }

  // Gateway Settings

  /// Get gateway auto-restart enabled preference
  Future<bool?> getGatewayAutoRestart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_gatewayAutoRestartKey);
  }

  /// Set gateway auto-restart enabled preference
  Future<void> setGatewayAutoRestart(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gatewayAutoRestartKey, value);
  }

  /// Get configured gateway URL (returns null if using default)
  Future<String?> getGatewayUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_gatewayUrlKey);
  }

  /// Set gateway URL (set to empty string to use default)
  Future<void> setGatewayUrl(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await prefs.remove(_gatewayUrlKey);
    } else {
      await prefs.setString(_gatewayUrlKey, value);
    }
  }
}
