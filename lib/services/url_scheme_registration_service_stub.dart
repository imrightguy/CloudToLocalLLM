import 'package:flutter/foundation.dart';

/// Web stub for UrlSchemeRegistrationService
/// On web, URL scheme registration is not needed as OAuth uses standard redirects
class UrlSchemeRegistrationService {
  static const String _customScheme = 'online.cloudtolocalllm.app';

  /// Web stub - always returns true as no registration is needed
  static Future<bool> registerUrlScheme() async {
    debugPrint('[UrlSchemeRegistration] Web platform - no registration needed');
    return true;
  }

  /// Web stub - always returns true as no registration check is needed
  static Future<bool> isSchemeRegistered() async {
    debugPrint(
        '[UrlSchemeRegistration] Web platform - scheme always available');
    return true;
  }

  /// Gets the custom scheme used by the app
  static String get customScheme => _customScheme;
}
