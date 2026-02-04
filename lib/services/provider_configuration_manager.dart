/// Provider Configuration Manager for Zoidbot
///
/// This service manages provider configurations including:
/// - Configuration persistence and loading
/// - Validation and error handling
/// - Provider preference management
/// - Configuration migration and versioning
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/provider_configuration.dart';

/// Provider configuration manager service
class ProviderConfigurationManager extends ChangeNotifier {
  static const String _configKey = 'provider_configurations';
  static const String _preferencesKey = 'provider_preferences';
  static const String _versionKey = 'config_version';
  static const int _currentConfigVersion = 1;

  final Map<String, ProviderConfiguration> _configurations = {};
  final Map<String, dynamic> _preferences = {};

  bool _isInitialized = false;
  String? _preferredProviderId;
  String? _error;

  /// Whether the manager is initialized
  bool get isInitialized => _isInitialized;

  /// Current error message, if any
  String? get error => _error;

  /// All configured providers
  List<ProviderConfiguration> get configurations =>
      _configurations.values.toList();

  /// Preferred provider ID
  String? get preferredProviderId => _preferredProviderId;

  /// Get configuration for a specific provider
  ProviderConfiguration? getConfiguration(String providerId) {
    return _configurations[providerId];
  }

  /// Initialize the configuration manager
  Future<void> initialize() async {
    try {
      _error = null;
      await _loadConfigurations();
      await _loadPreferences();
      await _migrateConfigurationsIfNeeded();
      _isInitialized = true;
      notifyListeners();
      debugPrint(
          ' [ConfigManager] Initialized with ${_configurations.length} configurations');
    } catch (e) {
      _error = 'Failed to initialize configuration manager: $e';
      debugPrint(' [ConfigManager] Initialization failed: $e');
      notifyListeners();
    }
  }

  /// Add or update a provider configuration
  Future<void> setConfiguration(ProviderConfiguration config) async {
    try {
      // Validate configuration
      final validationResult =
          ProviderConfigurationFactory.validateConfiguration(config);
      if (!validationResult.isValid) {
        throw Exception(
            'Invalid configuration: ${validationResult.errors.join(', ')}');
      }

      // Log warnings if any
      for (final warning in validationResult.warnings) {
        debugPrint(' [ConfigManager] Warning: $warning');
      }

      _configurations[config.providerId] = config;
      await _saveConfigurations();

      debugPrint(
          ' [ConfigManager] Configuration saved for provider: ${config.providerId}');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to save configuration: $e';
      debugPrint(' [ConfigManager] Failed to save configuration: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Remove a provider configuration
  Future<void> removeConfiguration(String providerId) async {
    try {
      _configurations.remove(providerId);

      // Clear preferred provider if it was removed
      if (_preferredProviderId == providerId) {
        _preferredProviderId = null;
        await _savePreferences();
      }

      await _saveConfigurations();

      debugPrint(
          ' [ConfigManager] Configuration removed for provider: $providerId');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove configuration: $e';
      debugPrint(' [ConfigManager] Failed to remove configuration: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Set preferred provider
  Future<void> setPreferredProvider(String? providerId) async {
    try {
      if (providerId != null && !_configurations.containsKey(providerId)) {
        throw Exception('Provider not configured: $providerId');
      }

      _preferredProviderId = providerId;
      await _savePreferences();

      debugPrint(' [ConfigManager] Preferred provider set to: $providerId');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to set preferred provider: $e';
      debugPrint(' [ConfigManager] Failed to set preferred provider: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Get provider configurations by type
  List<ProviderConfiguration> getConfigurationsByType(String providerType) {
    return _configurations.values
        .where((config) => config.providerType == providerType)
        .toList();
  }

  /// Check if a provider is configured
  bool isProviderConfigured(String providerId) {
    return _configurations.containsKey(providerId);
  }

  /// Get configuration validation result
  ConfigurationValidationResult validateConfiguration(String providerId) {
    final config = _configurations[providerId];
    if (config == null) {
      return ConfigurationValidationResult.invalid(['Provider not found']);
    }

    return ProviderConfigurationFactory.validateConfiguration(config);
  }

  /// Update configuration preferences
  Future<void> updatePreference(String key, dynamic value) async {
    try {
      _preferences[key] = value;
      await _savePreferences();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update preference: $e';
      debugPrint(' [ConfigManager] Failed to update preference: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Get configuration preference
  T? getPreference<T>(String key, [T? defaultValue]) {
    return _preferences[key] as T? ?? defaultValue;
  }

  /// Export configurations to JSON
  Map<String, dynamic> exportConfigurations() {
    return {
      'version': _currentConfigVersion,
      'configurations':
          _configurations.map((key, config) => MapEntry(key, config.toJson())),
      'preferences': _preferences,
      'preferredProviderId': _preferredProviderId,
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Import configurations from JSON
  Future<void> importConfigurations(Map<String, dynamic> data) async {
    try {
      final version = data['version'] as int? ?? 1;
      if (version > _currentConfigVersion) {
        throw Exception('Configuration version $version is not supported');
      }

      // Clear existing configurations
      _configurations.clear();

      // Import configurations
      final configurationsData =
          data['configurations'] as Map<String, dynamic>? ?? {};
      for (final entry in configurationsData.entries) {
        final config = ProviderConfigurationFactory.fromJson(
            entry.value as Map<String, dynamic>);
        if (config != null) {
          _configurations[entry.key] = config;
        }
      }

      // Import preferences
      _preferences.clear();
      final preferencesData =
          data['preferences'] as Map<String, dynamic>? ?? {};
      _preferences.addAll(preferencesData);

      // Import preferred provider
      _preferredProviderId = data['preferredProviderId'] as String?;

      // Save imported data
      await _saveConfigurations();
      await _savePreferences();

      debugPrint(
          ' [ConfigManager] Imported ${_configurations.length} configurations');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to import configurations: $e';
      debugPrint(' [ConfigManager] Failed to import configurations: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Clear all configurations
  Future<void> clearAllConfigurations() async {
    try {
      _configurations.clear();
      _preferences.clear();
      _preferredProviderId = null;

      await _saveConfigurations();
      await _savePreferences();

      debugPrint(' [ConfigManager] All configurations cleared');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear configurations: $e';
      debugPrint(' [ConfigManager] Failed to clear configurations: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Load configurations from storage
  Future<void> _loadConfigurations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(_configKey);

      if (configJson != null) {
        final configData = jsonDecode(configJson) as Map<String, dynamic>;

        for (final entry in configData.entries) {
          final config = ProviderConfigurationFactory.fromJson(
              entry.value as Map<String, dynamic>);
          if (config != null) {
            _configurations[entry.key] = config;
          }
        }
      }

      debugPrint(
          ' [ConfigManager] Loaded ${_configurations.length} configurations');
    } catch (e) {
      debugPrint(' [ConfigManager] Error loading configurations: $e');
    }
  }

  /// Save configurations to storage
  Future<void> _saveConfigurations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configData =
          _configurations.map((key, config) => MapEntry(key, config.toJson()));
      final configJson = jsonEncode(configData);

      await prefs.setString(_configKey, configJson);
      await prefs.setInt(_versionKey, _currentConfigVersion);
    } catch (e) {
      debugPrint(' [ConfigManager] Error saving configurations: $e');
      rethrow;
    }
  }

  /// Load preferences from storage
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final preferencesJson = prefs.getString(_preferencesKey);

      if (preferencesJson != null) {
        final preferencesData =
            jsonDecode(preferencesJson) as Map<String, dynamic>;
        _preferences.addAll(preferencesData);
      }

      _preferredProviderId = prefs.getString('preferred_provider_id');

      debugPrint(' [ConfigManager] Loaded preferences');
    } catch (e) {
      debugPrint(' [ConfigManager] Error loading preferences: $e');
    }
  }

  /// Save preferences to storage
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final preferencesJson = jsonEncode(_preferences);

      await prefs.setString(_preferencesKey, preferencesJson);

      if (_preferredProviderId != null) {
        await prefs.setString('preferred_provider_id', _preferredProviderId!);
      } else {
        await prefs.remove('preferred_provider_id');
      }
    } catch (e) {
      debugPrint(' [ConfigManager] Error saving preferences: $e');
      rethrow;
    }
  }

  /// Migrate configurations if needed
  Future<void> _migrateConfigurationsIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentVersion = prefs.getInt(_versionKey) ?? 0;

      if (currentVersion < _currentConfigVersion) {
        debugPrint(
            ' [ConfigManager] Migrating configurations from version $currentVersion to $_currentConfigVersion');

        // Perform migration logic here if needed
        // For now, just update the version

        await prefs.setInt(_versionKey, _currentConfigVersion);
        debugPrint(' [ConfigManager] Configuration migration completed');
      }
    } catch (e) {
      debugPrint(' [ConfigManager] Error during configuration migration: $e');
    }
  }

  @override
  void dispose() {
    _configurations.clear();
    _preferences.clear();
    super.dispose();
  }
}
