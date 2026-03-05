/// Pop-Out Window Manager Service
///
/// Manages pop-out window state for OpenClaw Gateway sections.
/// Allows users to open any section in a separate window with synchronized state.
///
/// Features:
/// - Track open windows by section name
/// - Enable/disable pop-out for specific sections
/// - Window visibility management
/// - Position and size persistence
/// - State synchronization between main and pop-out windows
library;

import 'package:flutter/widgets.dart';

import 'popout_window.dart';

/// Service for managing pop-out window state
class PopOutManager extends ChangeNotifier {
  /// Map of currently open windows (key: sectionName)
  final Map<String, PopOutWindow> _openWindows = {};

  /// Map of section pop-out enabled states (key: sectionName, value: enabled)
  final Map<String, bool> _sectionPopOutEnabled = {};

  /// List of all Gateway section names
  static const List<String> _allSections = [
    'channels',
    'instances',
    'sessions',
    'usage',
    'agents',
    'skills',
    'nodes',
    'debug',
    'config',
  ];

  /// Sections that should NOT have pop-out enabled by default
  static const Set<String> _defaultDisabledSections = {
    'config',
  };

  PopOutManager() {
    _initializeDefaultStates();
  }

  /// Initialize default pop-out enabled states for all sections
  void _initializeDefaultStates() {
    for (final section in _allSections) {
      // Enable all sections except those in default disabled list
      _sectionPopOutEnabled[section] = !_defaultDisabledSections.contains(section);
    }
  }

  /// Get all open windows
  Map<String, PopOutWindow> get openWindows => Map.unmodifiable(_openWindows);

  /// Get window for a specific section
  PopOutWindow? getWindow(String sectionName) {
    return _openWindows[sectionName];
  }

  /// Check if a section has an open window
  bool isWindowOpen(String sectionName) {
    return _openWindows.containsKey(sectionName);
  }

  /// Check if pop-out is enabled for a section
  bool isSectionPopOutEnabled(String sectionName) {
    return _sectionPopOutEnabled[sectionName] ?? true;
  }

  /// Enable or disable pop-out for a section
  void setSectionPopOutEnabled(String sectionName, bool enabled) {
    if (_sectionPopOutEnabled[sectionName] != enabled) {
      _sectionPopOutEnabled[sectionName] = enabled;
      notifyListeners();
    }
  }

  /// Toggle pop-out window for a section
  ///
  /// If window is open, closes it. If closed and enabled, opens it.
  void togglePopOut(String sectionName, int branchIndex) {
    final existingWindow = _openWindows[sectionName];

    if (existingWindow != null) {
      // Window is open, close it
      _openWindows.remove(sectionName);
      debugPrint('[PopOutManager] Closed window for section: $sectionName');
    } else {
      // Window is closed, check if enabled
      if (!isSectionPopOutEnabled(sectionName)) {
        debugPrint('[PopOutManager] Pop-out disabled for section: $sectionName');
        return;
      }

      // Open new window
      final newWindow = PopOutWindow(
        id: sectionName,
        sectionName: sectionName,
        branchIndex: branchIndex,
        isVisible: true,
      );
      _openWindows[sectionName] = newWindow;
      debugPrint('[PopOutManager] Opened window for section: $sectionName');
    }

    notifyListeners();
  }

  /// Update window visibility
  void setWindowVisible(String sectionName, bool visible) {
    final window = _openWindows[sectionName];
    if (window != null && window.isVisible != visible) {
      _openWindows[sectionName] = window.copyWith(isVisible: visible);
      notifyListeners();
    }
  }

  /// Update window position
  void setWindowPosition(String sectionName, Offset position) {
    final window = _openWindows[sectionName];
    if (window != null) {
      _openWindows[sectionName] = window.copyWith(position: position);
      notifyListeners();
    }
  }

  /// Update window size
  void setWindowSize(String sectionName, Size size) {
    final window = _openWindows[sectionName];
    if (window != null) {
      _openWindows[sectionName] = window.copyWith(size: size);
      notifyListeners();
    }
  }

  /// Close a specific window
  void closeWindow(String sectionName) {
    if (_openWindows.remove(sectionName) != null) {
      debugPrint('[PopOutManager] Closed window for section: $sectionName');
      notifyListeners();
    }
  }

  /// Close all open windows
  void closeAllWindows() {
    if (_openWindows.isNotEmpty) {
      final count = _openWindows.length;
      _openWindows.clear();
      debugPrint('[PopOutManager] Closed $count windows');
      notifyListeners();
    }
  }

  /// Get list of sections with pop-out enabled
  List<String> getEnabledSections() {
    return _sectionPopOutEnabled.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get list of sections with pop-out disabled
  List<String> getDisabledSections() {
    return _sectionPopOutEnabled.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// Convert state to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'openWindows': _openWindows.map(
        (key, window) => MapEntry(key, window.toJson()),
      ),
      'sectionPopOutEnabled': Map<String, dynamic>.from(_sectionPopOutEnabled),
    };
  }

  /// Restore state from JSON
  void fromJson(Map<String, dynamic> json) {
    try {
      // Restore open windows
      final openWindowsJson = json['openWindows'] as Map<String, dynamic>?;
      if (openWindowsJson != null) {
        _openWindows.clear();
        openWindowsJson.forEach((key, windowJson) {
          _openWindows[key] = PopOutWindow.fromJson(
            windowJson as Map<String, dynamic>,
          );
        });
      }

      // Restore section enabled states
      final sectionEnabledJson = json['sectionPopOutEnabled'] as Map<String, dynamic>?;
      if (sectionEnabledJson != null) {
        sectionEnabledJson.forEach((key, value) {
          _sectionPopOutEnabled[key] = value as bool;
        });
      }

      debugPrint('[PopOutManager] State restored from JSON');
      notifyListeners();
    } catch (e) {
      debugPrint('[PopOutManager] Error restoring state from JSON: $e');
    }
  }

  /// Reset to default state
  void resetToDefaults() {
    _openWindows.clear();
    _sectionPopOutEnabled.clear();
    _initializeDefaultStates();
    debugPrint('[PopOutManager] Reset to default state');
    notifyListeners();
  }

  @override
  String toString() {
    return 'PopOutManager(openWindows: ${_openWindows.length}, '
        'enabledSections: ${getEnabledSections().length})';
  }
}
