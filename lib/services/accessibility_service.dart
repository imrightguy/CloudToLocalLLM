/// Accessibility Service
///
/// Manages accessibility features across all screens including:
/// - ARIA labels and semantic HTML for web
/// - Keyboard navigation with visible focus indicators
/// - Screen reader support (VoiceOver, TalkBack, Narrator)
/// - Contrast ratio validation
/// - Touch target size validation
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:cloudtolocalllm/utils/accessibility_helpers.dart';

/// Service for managing accessibility features
class AccessibilityService extends ChangeNotifier {
  /// Whether high contrast mode is enabled
  bool _highContrastMode = false;

  /// Whether screen reader is enabled
  bool _screenReaderEnabled = false;

  /// Whether keyboard navigation is enabled
  bool _keyboardNavigationEnabled = true;

  /// Current focus node for keyboard navigation
  FocusNode? _currentFocus;

  /// Get high contrast mode status
  bool get highContrastMode => _highContrastMode;

  /// Get screen reader status
  bool get screenReaderEnabled => _screenReaderEnabled;

  /// Get keyboard navigation status
  bool get keyboardNavigationEnabled => _keyboardNavigationEnabled;

  /// Get current focus node
  FocusNode? get currentFocus => _currentFocus;

  /// Enable high contrast mode
  void enableHighContrastMode() {
    _highContrastMode = true;
    notifyListeners();
  }

  /// Disable high contrast mode
  void disableHighContrastMode() {
    _highContrastMode = false;
    notifyListeners();
  }

  /// Toggle high contrast mode
  void toggleHighContrastMode() {
    _highContrastMode = !_highContrastMode;
    notifyListeners();
  }

  /// Enable screen reader
  void enableScreenReader() {
    _screenReaderEnabled = true;
    notifyListeners();
  }

  /// Disable screen reader
  void disableScreenReader() {
    _screenReaderEnabled = false;
    notifyListeners();
  }

  /// Toggle screen reader
  void toggleScreenReader() {
    _screenReaderEnabled = !_screenReaderEnabled;
    notifyListeners();
  }

  /// Enable keyboard navigation
  void enableKeyboardNavigation() {
    _keyboardNavigationEnabled = true;
    notifyListeners();
  }

  /// Disable keyboard navigation
  void disableKeyboardNavigation() {
    _keyboardNavigationEnabled = false;
    notifyListeners();
  }

  /// Toggle keyboard navigation
  void toggleKeyboardNavigation() {
    _keyboardNavigationEnabled = !_keyboardNavigationEnabled;
    notifyListeners();
  }

  /// Set current focus node
  void setCurrentFocus(FocusNode? node) {
    _currentFocus = node;
    notifyListeners();
  }

  /// Validate contrast ratio for text
  bool validateContrastRatio(Color foreground, Color background) {
    return AccessibilityHelpers.meetsContrastRequirement(
      foreground,
      background,
    );
  }

  /// Get semantic label for widget
  String getSemanticLabel(String label, {String? description}) {
    return AccessibilityHelpers.getSemanticLabel(
      label,
      description: description,
    );
  }

  /// Validate touch target size (minimum 44x44 pixels for mobile)
  bool validateTouchTargetSize(Size size, {bool isMobile = false}) {
    final minSize = isMobile ? 44.0 : 32.0;
    return size.width >= minSize && size.height >= minSize;
  }

  /// Get recommended touch target size
  Size getRecommendedTouchTargetSize({bool isMobile = false}) {
    final minSize = isMobile ? 44.0 : 32.0;
    return Size(minSize, minSize);
  }

  /// Announce message to screen reader
  void announceToScreenReader(BuildContext context, String message) {
    if (_screenReaderEnabled) {
      // Use SemanticsService to announce to screen reader
      // ignore: deprecated_member_use
      SemanticsService.announce(message, TextDirection.ltr);
    }
  }

  /// Check if platform supports screen reader
  bool get platformSupportsScreenReader {
    // Web, iOS, Android, Windows, Linux all support screen readers
    return true;
  }

  /// Get platform-specific screen reader name
  String get screenReaderName {
    if (kIsWeb) {
      return 'Screen Reader';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'VoiceOver';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'TalkBack';
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      return 'Narrator';
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      return 'Orca';
    }
    return 'Screen Reader';
  }

  /// Dispose resources
  @override
  void dispose() {
    _currentFocus?.dispose();
    super.dispose();
  }
}
