/// Settings Import/Export Service
///
/// Provides functionality to export settings to JSON and import from JSON files.
library;

import 'dart:convert';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';
import 'package:cloudtolocalllm/services/settings_validator.dart';
import 'package:cloudtolocalllm/utils/settings_error_handler.dart';

/// Settings import/export service
class SettingsImportExportService {
  final SettingsPreferenceService _preferencesService;

  /// Current export version for compatibility checking
  static const String exportVersion = '1.0';

  /// Export file extension
  static const String fileExtension = '.json';

  /// Export file prefix
  static const String filePrefix = 'CloudToLocalLLM-settings';

  SettingsImportExportService({
    required SettingsPreferenceService preferencesService,
  }) : _preferencesService = preferencesService;

  /// Export all settings to a JSON string
  Future<String> exportSettingsToJson() async {
    try {
      final settings = await _collectAllSettings();
      final exportData = {
        'version': exportVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': settings,
      };

      return jsonEncode(exportData);
    } catch (e) {
      throw SettingsError.importExportFailed(
        'Failed to export settings: $e',
        originalException: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Generate a downloadable filename for export
  String generateExportFilename() {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    return '$filePrefix-$timestamp$fileExtension';
  }

  /// Import settings from a JSON string
  Future<Map<String, dynamic>> importSettingsFromJson(String jsonString) async {
    try {
      // Parse JSON
      final Map<String, dynamic> data = jsonDecode(jsonString);

      // Validate structure
      if (!data.containsKey('version') ||
          !data.containsKey('settings') ||
          data['settings'] is! Map) {
        throw SettingsError.importExportFailed(
          'Invalid settings file format. Missing required fields.',
        );
      }

      // Check version compatibility
      final version = data['version'] as String?;
      if (version != exportVersion) {
        throw SettingsError.importExportFailed(
          'Settings file version ($version) is not compatible with current version ($exportVersion).',
        );
      }

      // Validate settings data
      final settings = data['settings'] as Map<String, dynamic>;
      final validationResult = SettingsValidator.validateSettingsJson(settings);

      if (!validationResult.isValid) {
        final errors = validationResult.getAllErrors().join(', ');
        throw SettingsError.importExportFailed(
          'Invalid settings data: $errors',
        );
      }

      return settings;
    } on SettingsError {
      rethrow;
    } catch (e) {
      throw SettingsError.importExportFailed(
        'Failed to parse settings file: $e',
        originalException: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Apply imported settings to preferences
  Future<void> applyImportedSettings(Map<String, dynamic> settings) async {
    try {
      // General Settings
      if (settings.containsKey('theme')) {
        await _preferencesService.setTheme(settings['theme'] as String);
      }

      if (settings.containsKey('language')) {
        await _preferencesService.setLanguage(settings['language'] as String);
      }

      // Privacy Settings
      if (settings.containsKey('analyticsEnabled')) {
        await _preferencesService
            .setAnalyticsEnabled(settings['analyticsEnabled'] as bool);
      }

      if (settings.containsKey('crashReportingEnabled')) {
        await _preferencesService.setCrashReportingEnabled(
            settings['crashReportingEnabled'] as bool);
      }

      if (settings.containsKey('usageStatsEnabled')) {
        await _preferencesService
            .setUsageStatsEnabled(settings['usageStatsEnabled'] as bool);
      }

      // Desktop Settings
      if (settings.containsKey('launchOnStartupEnabled')) {
        await _preferencesService.setLaunchOnStartupEnabled(
            settings['launchOnStartupEnabled'] as bool);
      }

      if (settings.containsKey('minimizeToTrayEnabled')) {
        await _preferencesService.setMinimizeToTrayEnabled(
            settings['minimizeToTrayEnabled'] as bool);
      }

      if (settings.containsKey('alwaysOnTopEnabled')) {
        await _preferencesService
            .setAlwaysOnTopEnabled(settings['alwaysOnTopEnabled'] as bool);
      }

      if (settings.containsKey('rememberWindowPositionEnabled')) {
        await _preferencesService.setRememberWindowPositionEnabled(
            settings['rememberWindowPositionEnabled'] as bool);
      }

      if (settings.containsKey('rememberWindowSizeEnabled')) {
        await _preferencesService.setRememberWindowSizeEnabled(
            settings['rememberWindowSizeEnabled'] as bool);
      }

      if (settings.containsKey('windowPosition')) {
        final position = settings['windowPosition'] as Map<String, dynamic>;
        await _preferencesService.setWindowPosition(
          (position['x'] as num).toDouble(),
          (position['y'] as num).toDouble(),
        );
      }

      if (settings.containsKey('windowSize')) {
        final size = settings['windowSize'] as Map<String, dynamic>;
        await _preferencesService.setWindowSize(
          (size['width'] as num).toDouble(),
          (size['height'] as num).toDouble(),
        );
      }

      // Mobile Settings
      if (settings.containsKey('biometricAuthEnabled')) {
        await _preferencesService
            .setBiometricAuthEnabled(settings['biometricAuthEnabled'] as bool);
      }

      if (settings.containsKey('notificationsEnabled')) {
        await _preferencesService
            .setNotificationsEnabled(settings['notificationsEnabled'] as bool);
      }

      if (settings.containsKey('notificationSoundEnabled')) {
        await _preferencesService.setNotificationSoundEnabled(
            settings['notificationSoundEnabled'] as bool);
      }

      if (settings.containsKey('vibrationEnabled')) {
        await _preferencesService
            .setVibrationEnabled(settings['vibrationEnabled'] as bool);
      }
    } catch (e) {
      throw SettingsError.importExportFailed(
        'Failed to apply imported settings: $e',
        originalException: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Collect all current settings
  Future<Map<String, dynamic>> _collectAllSettings() async {
    final windowPosition = await _preferencesService.getWindowPosition();
    final windowSize = await _preferencesService.getWindowSize();

    return {
      // General Settings
      'theme': await _preferencesService.getTheme(),
      'language': await _preferencesService.getLanguage(),

      // Privacy Settings
      'analyticsEnabled': await _preferencesService.isAnalyticsEnabled(),
      'crashReportingEnabled':
          await _preferencesService.isCrashReportingEnabled(),
      'usageStatsEnabled': await _preferencesService.isUsageStatsEnabled(),

      // Desktop Settings
      'launchOnStartupEnabled':
          await _preferencesService.isLaunchOnStartupEnabled(),
      'minimizeToTrayEnabled':
          await _preferencesService.isMinimizeToTrayEnabled(),
      'alwaysOnTopEnabled': await _preferencesService.isAlwaysOnTopEnabled(),
      'rememberWindowPositionEnabled':
          await _preferencesService.isRememberWindowPositionEnabled(),
      'rememberWindowSizeEnabled':
          await _preferencesService.isRememberWindowSizeEnabled(),
      'windowPosition': windowPosition,
      'windowSize': windowSize,

      // Mobile Settings
      'biometricAuthEnabled':
          await _preferencesService.isBiometricAuthEnabled(),
      'notificationsEnabled':
          await _preferencesService.isNotificationsEnabled(),
      'notificationSoundEnabled':
          await _preferencesService.isNotificationSoundEnabled(),
      'vibrationEnabled': await _preferencesService.isVibrationEnabled(),
    };
  }

  /// Validate settings file before import
  Future<ValidationResult> validateSettingsFile(String jsonString) async {
    try {
      await importSettingsFromJson(jsonString);
      return ValidationResult.success();
    } on SettingsError catch (e) {
      return ValidationResult.error(e.message);
    } catch (e) {
      return ValidationResult.error('Failed to validate settings file: $e');
    }
  }
}
