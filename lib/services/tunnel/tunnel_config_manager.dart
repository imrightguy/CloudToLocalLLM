/// Tunnel Configuration Manager
/// Manages loading, saving, and validating tunnel configurations
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'interfaces/tunnel_config.dart';

/// Profile type enum
enum ProfileType {
  stable,
  unstable,
  lowBandwidth,
  custom,
}

/// Validation result
class ValidationResult {
  final bool isValid;
  final List<String> errors;

  ValidationResult({
    required this.isValid,
    required this.errors,
  });

  /// Create a valid result
  factory ValidationResult.valid() {
    return ValidationResult(isValid: true, errors: []);
  }

  /// Create an invalid result
  factory ValidationResult.invalid(List<String> errors) {
    return ValidationResult(isValid: false, errors: errors);
  }
}

/// Tunnel Configuration Manager
/// Handles loading, saving, and validating tunnel configurations
class TunnelConfigManager {
  static const String _configKey = 'tunnel_config';
  static const String _profileKey = 'tunnel_profile';

  late SharedPreferences _prefs;
  TunnelConfig _currentConfig = const TunnelConfig();
  ProfileType _currentProfile = ProfileType.custom;

  /// Initialize the configuration manager
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadConfig();
  }

  /// Load configuration from SharedPreferences
  Future<void> _loadConfig() async {
    try {
      final configJson = _prefs.getString(_configKey);
      final profileStr = _prefs.getString(_profileKey);

      if (configJson != null) {
        final decoded = _parseJson(configJson);
        _currentConfig = TunnelConfig.fromJson(decoded);
      } else {
        _currentConfig = const TunnelConfig();
      }

      if (profileStr != null) {
        _currentProfile = ProfileType.values.firstWhere(
          (e) => e.name == profileStr,
          orElse: () => ProfileType.custom,
        );
      } else {
        _currentProfile = ProfileType.custom;
      }
    } catch (e) {
      // If loading fails, use defaults and clear corrupted data
      _currentConfig = const TunnelConfig();
      _currentProfile = ProfileType.custom;
      await _prefs.remove(_configKey);
      await _prefs.remove(_profileKey);
    }
  }

  /// Get current configuration
  TunnelConfig getCurrentConfig() {
    return _currentConfig;
  }

  /// Get current profile
  ProfileType getCurrentProfile() {
    return _currentProfile;
  }

  /// Update configuration
  Future<void> updateConfig(TunnelConfig config) async {
    final validation = validateConfig(config);
    if (!validation.isValid) {
      throw Exception('Invalid configuration: ${validation.errors.join(', ')}');
    }

    _currentConfig = config;
    _currentProfile = ProfileType.custom;

    // Save to SharedPreferences
    final configJson = config.toJson();
    await _prefs.setString(_configKey, _encodeJson(configJson));
    await _prefs.setString(_profileKey, _currentProfile.name);
  }

  /// Load a predefined profile
  Future<void> loadProfile(ProfileType profile) async {
    late TunnelConfig config;

    switch (profile) {
      case ProfileType.stable:
        config = TunnelConfig.stableNetwork();
        break;
      case ProfileType.unstable:
        config = TunnelConfig.unstableNetwork();
        break;
      case ProfileType.lowBandwidth:
        config = TunnelConfig.lowBandwidth();
        break;
      case ProfileType.custom:
        // Keep current config
        return;
    }

    _currentConfig = config;
    _currentProfile = profile;

    // Save to SharedPreferences
    final configJson = config.toJson();
    await _prefs.setString(_configKey, _encodeJson(configJson));
    await _prefs.setString(_profileKey, profile.name);
  }

  /// Validate configuration
  ValidationResult validateConfig(TunnelConfig config) {
    final errors = <String>[];

    // Validate maxReconnectAttempts (1-20)
    if (config.maxReconnectAttempts < 1 || config.maxReconnectAttempts > 20) {
      errors.add(
        'Max reconnect attempts must be between 1 and 20, got ${config.maxReconnectAttempts}',
      );
    }

    // Validate maxQueueSize (10-1000)
    if (config.maxQueueSize < 10 || config.maxQueueSize > 1000) {
      errors.add(
        'Max queue size must be between 10 and 1000, got ${config.maxQueueSize}',
      );
    }

    // Validate requestTimeout (5s-120s)
    if (config.requestTimeout.inSeconds < 5 ||
        config.requestTimeout.inSeconds > 120) {
      errors.add(
        'Request timeout must be between 5 and 120 seconds, got ${config.requestTimeout.inSeconds}s',
      );
    }

    // Validate reconnectBaseDelay (1s-60s)
    if (config.reconnectBaseDelay.inSeconds < 1 ||
        config.reconnectBaseDelay.inSeconds > 60) {
      errors.add(
        'Reconnect base delay must be between 1 and 60 seconds, got ${config.reconnectBaseDelay.inSeconds}s',
      );
    }

    if (errors.isEmpty) {
      return ValidationResult.valid();
    } else {
      return ValidationResult.invalid(errors);
    }
  }

  /// Reset to default configuration
  Future<void> resetToDefaults() async {
    _currentConfig = const TunnelConfig();
    _currentProfile = ProfileType.custom;

    final configJson = _currentConfig.toJson();
    await _prefs.setString(_configKey, _encodeJson(configJson));
    await _prefs.setString(_profileKey, _currentProfile.name);
  }

  /// Helper to parse JSON string
  Map<String, dynamic> _parseJson(String jsonStr) {
    // Simple JSON parsing - in production, use json package
    // For now, we'll use a basic implementation
    try {
      // This is a simplified version - in production use:
      // import 'dart:convert';
      // return jsonDecode(jsonStr);
      return _simpleJsonParse(jsonStr);
    } catch (e) {
      throw Exception('Failed to parse configuration JSON: $e');
    }
  }

  /// Helper to encode JSON
  String _encodeJson(Map<String, dynamic> json) {
    // Simple JSON encoding - in production, use json package
    try {
      // This is a simplified version - in production use:
      // import 'dart:convert';
      // return jsonEncode(json);
      return _simpleJsonEncode(json);
    } catch (e) {
      throw Exception('Failed to encode configuration JSON: $e');
    }
  }

  /// Simple JSON parser (fallback)
  Map<String, dynamic> _simpleJsonParse(String jsonStr) {
    // This is a very basic implementation
    // In production, use the json package
    final result = <String, dynamic>{};

    // Remove outer braces
    var content = jsonStr.trim();
    if (content.startsWith('{')) content = content.substring(1);
    if (content.endsWith('}')) {
      content = content.substring(0, content.length - 1);
    }

    // Split by comma (simplified - doesn't handle nested objects)
    final pairs = content.split(',');
    for (final pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        final key = parts[0].trim().replaceAll('"', '');
        var value = parts[1].trim();

        // Parse value based on type
        if (value == 'true') {
          result[key] = true;
        } else if (value == 'false') {
          result[key] = false;
        } else if (value.startsWith('"')) {
          result[key] = value.replaceAll('"', '');
        } else {
          try {
            result[key] = int.parse(value);
          } catch (e) {
            try {
              result[key] = double.parse(value);
            } catch (e) {
              result[key] = value;
            }
          }
        }
      }
    }

    return result;
  }

  /// Simple JSON encoder (fallback)
  String _simpleJsonEncode(Map<String, dynamic> json) {
    // This is a very basic implementation
    // In production, use the json package
    final pairs = <String>[];

    json.forEach((key, value) {
      String encodedValue;
      if (value is String) {
        encodedValue = '"$value"';
      } else if (value is bool) {
        encodedValue = value.toString();
      } else if (value is num) {
        encodedValue = value.toString();
      } else {
        encodedValue = '"$value"';
      }
      pairs.add('"$key":$encodedValue');
    });

    return '{${pairs.join(',')}}';
  }
}
