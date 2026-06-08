library;

import 'package:flutter/widgets.dart';

import 'popout_window.dart';

/// Service for managing pop-out window state
class PopOutManager extends ChangeNotifier {
  /// Map of currently open windows (key: sectionName)
  final Map<String, PopOutWindow> _openWindows = {};

  /// Map of section pop-out enabled states (key: sectionName, value: enabled)
  final Map<String, bool> _sectionPopOutEnabled = {};

  PopOutManager() {
    _initializeDefaultStates();
  }

  /// Initialize default pop-out enabled states for all sections
  void _initializeDefaultStates() {
    // Enable all sections except those in default disabled list
    _sectionPopOutEnabled['channels'] = true;
    _sectionPopOutEnabled['instances'] = true;
    _sectionPopOutEnabled['sessions'] = true;
    _sectionPopOutEnabled['usage'] = true;
    _sectionPopOutEnabled['agents'] = true;
    _sectionPopOutEnabled['skills'] = true;
    _sectionPopOutEnabled['nodes'] = true;
    _sectionPopOutEnabled['debug'] = true;
    _sectionPopOutEnabled['config'] = false;
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
    final key = '$sectionName:$branchIndex';
    final existingWindow = _openWindows[key];

    if (existingWindow != null) {
      // Window is open, close it
      _openWindows.remove(key);
      debugPrint('[PopOutManager] Closed window for section: $sectionName branch: $branchIndex');
    } else {
      // Window is closed, check if enabled
      if (!isSectionPopOutEnabled(sectionName)) {
        debugPrint(
            '[PopOutManager] Pop-out disabled for section: $sectionName');
        return;
      }

      // Open new window
      final newWindow = PopOutWindow(
        id: key,
        sectionName: sectionName,
        branchIndex: branchIndex,
        isVisible: true,
      );
      _openWindows[key] = newWindow;
      debugPrint('[PopOutManager] Opened window for section: $sectionName branch: $branchIndex');
    }

    notifyListeners();
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
      final sectionEnabledJson =
          json['sectionPopOutEnabled'] as Map<String, dynamic>?;
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
}
