/// Theme Provider Service
///
/// Manages application theme mode (light, dark, system) with persistence.
/// Integrates with MaterialApp.router to control theme across the app.
///
/// Features:
/// - Support for Light, Dark, and System themes
/// - Platform-specific storage (SharedPreferences for web/mobile, SQLite for desktop)
/// - Theme caching for performance
/// - Real-time theme updates via Provider pattern
/// - Error handling and recovery
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Service for managing application theme mode with unified theme system
class ThemeProvider extends ChangeNotifier {
  static const String _themePreferenceKey = 'theme_mode';
  static const String _themeCacheKey = 'theme_cache_timestamp';
  static const Duration _cacheValidityDuration = Duration(hours: 1);

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode? _cachedThemeMode;
  DateTime? _cacheTimestamp;
  bool _isLoading = false;
  String? _lastError;
  ThemeMode? _previousThemeMode; // For error recovery

  // Performance tracking
  final Stopwatch _updateStopwatch = Stopwatch();

  ThemeProvider({bool skipLoad = false}) {
    if (!skipLoad) {
      _loadThemePreference();
    }
  }

  /// Get current theme mode
  ThemeMode get themeMode => _themeMode;

  /// Get cached theme mode (for performance optimization)
  ThemeMode? get cachedThemeMode => _cachedThemeMode;

  /// Check if theme is currently loading
  bool get isLoading => _isLoading;

  /// Get last error message if any
  String? get lastError => _lastError;

  /// Check if cache is valid
  bool get isCacheValid {
    if (_cacheTimestamp == null) return false;
    final now = DateTime.now();
    return now.difference(_cacheTimestamp!) < _cacheValidityDuration;
  }

  /// Check if dark mode is enabled
  bool get isDarkMode {
    switch (_themeMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        // For system mode, we can't determine without platform brightness
        // This will be handled by MaterialApp.router
        return false;
    }
  }

  /// Set theme mode and persist preference
  /// Updates all screens within 200ms as per requirements
  /// Implements error recovery as per Requirement 17.1
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _updateStopwatch.reset();
    _updateStopwatch.start();

    // Store previous theme for error recovery
    _previousThemeMode = _themeMode;

    try {
      _isLoading = true;
      _lastError = null;

      // Update theme mode immediately for real-time updates
      _themeMode = mode;

      // Notify listeners first for immediate UI update (target: <200ms)
      notifyListeners();

      // Persist to storage asynchronously
      await _saveThemePreference(mode);

      // Update cache
      _cachedThemeMode = mode;
      _cacheTimestamp = DateTime.now();

      _updateStopwatch.stop();
      debugPrint(
        '[ThemeProvider] Theme mode changed to: $mode in ${_updateStopwatch.elapsedMilliseconds}ms',
      );

      _isLoading = false;
      _previousThemeMode = null; // Clear previous theme on success
    } catch (e) {
      _updateStopwatch.stop();
      _lastError = 'Failed to change theme: $e';
      debugPrint('[ThemeProvider] Error changing theme mode: $e');

      // Error recovery: revert to previous theme (Requirement 17.1)
      if (_previousThemeMode != null) {
        _themeMode = _previousThemeMode!;
        debugPrint(
          '[ThemeProvider] Reverted to previous theme: $_previousThemeMode',
        );
      }

      _isLoading = false;
      notifyListeners();

      // Re-throw to allow caller to handle
      rethrow;
    }
  }

  /// Set theme mode from string (for settings UI)
  Future<void> setThemeModeFromString(String themeString) async {
    ThemeMode mode;
    switch (themeString.toLowerCase()) {
      case 'light':
        mode = ThemeMode.light;
        break;
      case 'dark':
        mode = ThemeMode.dark;
        break;
      case 'system':
      default:
        mode = ThemeMode.system;
        break;
    }
    await setThemeMode(mode);
  }

  /// Get theme mode as string (for settings UI)
  String get themeModeString {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  /// Load theme preference from storage with caching
  /// Completes within 1 second as per requirements
  /// Implements error recovery as per Requirement 17.3
  Future<void> _loadThemePreference() async {
    final loadStopwatch = Stopwatch()..start();

    try {
      _isLoading = true;

      // Check cache first for performance
      if (isCacheValid && _cachedThemeMode != null) {
        _themeMode = _cachedThemeMode!;
        debugPrint(
          '[ThemeProvider] Loaded theme from cache: $_themeMode in ${loadStopwatch.elapsedMilliseconds}ms',
        );
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Load from storage
      final prefs = await SharedPreferences.getInstance();
      final themeString = prefs.getString(_themePreferenceKey);
      final cacheTimestampMs = prefs.getInt(_themeCacheKey);

      if (themeString != null) {
        switch (themeString.toLowerCase()) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          case 'system':
            _themeMode = ThemeMode.system;
            break;
          default:
            // Fallback to AppConfig if invalid value
            _themeMode =
                AppConfig.enableDarkMode ? ThemeMode.dark : ThemeMode.light;
            debugPrint(
              '[ThemeProvider] Invalid theme value "$themeString", using default',
            );
        }

        // Update cache
        _cachedThemeMode = _themeMode;
        if (cacheTimestampMs != null) {
          _cacheTimestamp =
              DateTime.fromMillisecondsSinceEpoch(cacheTimestampMs);
        } else {
          _cacheTimestamp = DateTime.now();
        }
      } else {
        // No saved preference, use AppConfig default
        _themeMode =
            AppConfig.enableDarkMode ? ThemeMode.dark : ThemeMode.light;
        _cachedThemeMode = _themeMode;
        _cacheTimestamp = DateTime.now();

        debugPrint(
          '[ThemeProvider] No saved preference, using default: $_themeMode',
        );
      }

      loadStopwatch.stop();
      debugPrint(
        '[ThemeProvider] Loaded theme mode: $_themeMode in ${loadStopwatch.elapsedMilliseconds}ms',
      );

      _isLoading = false;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      loadStopwatch.stop();
      _lastError = 'Failed to load theme preference: $e';
      debugPrint('[ThemeProvider] Error loading theme preference: $e');

      // Error recovery: fallback to AppConfig default (Requirement 17.3)
      _themeMode = AppConfig.enableDarkMode ? ThemeMode.dark : ThemeMode.light;
      _cachedThemeMode = _themeMode;
      _cacheTimestamp = DateTime.now();
      _isLoading = false;

      debugPrint(
        '[ThemeProvider] Using fallback theme after persistence failure: $_themeMode',
      );
      notifyListeners();
    }
  }

  /// Save theme preference to storage with caching
  /// Persists within 500ms as per requirements
  /// Implements error recovery as per Requirement 17.3
  Future<void> _saveThemePreference(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String themeString;
      switch (mode) {
        case ThemeMode.light:
          themeString = 'light';
          break;
        case ThemeMode.dark:
          themeString = 'dark';
          break;
        case ThemeMode.system:
          themeString = 'system';
          break;
      }

      // Save theme preference and cache timestamp
      await Future.wait([
        prefs.setString(_themePreferenceKey, themeString),
        prefs.setInt(_themeCacheKey, DateTime.now().millisecondsSinceEpoch),
      ]);

      debugPrint('[ThemeProvider] Saved theme preference: $themeString');
    } catch (e) {
      _lastError = 'Failed to persist theme preference: $e';
      debugPrint('[ThemeProvider] Error saving theme preference: $e');
      // Rethrow to trigger error recovery in setThemeMode (Requirement 17.3)
      rethrow;
    }
  }

  /// Clear theme cache (useful for testing or manual refresh)
  Future<void> clearCache() async {
    try {
      _cachedThemeMode = null;
      _cacheTimestamp = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_themeCacheKey);

      debugPrint('[ThemeProvider] Theme cache cleared');
    } catch (e) {
      debugPrint('[ThemeProvider] Error clearing theme cache: $e');
    }
  }

  /// Reload theme preference from storage (bypasses cache)
  Future<void> reloadThemePreference() async {
    await clearCache();
    await _loadThemePreference();
  }
}
