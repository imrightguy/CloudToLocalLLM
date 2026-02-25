import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service for registering custom URL schemes on Windows desktop
/// This is required for Auth0 OAuth callbacks to work properly
class UrlSchemeRegistrationService {
  static const String _customScheme = 'online.cloudtolocalllm.app';

  /// Registers the custom URL scheme in Windows Registry
  /// This allows the OS to launch our app when Auth0 redirects to our custom scheme
  static Future<bool> registerUrlScheme() async {
    if (kIsWeb) return false;
    if (!Platform.isWindows) {
      debugPrint(
          '[UrlSchemeRegistration] Not on Windows, skipping registration');
      return true;
    }

    try {
      final String appPath = Platform.resolvedExecutable;
      debugPrint(
          '[UrlSchemeRegistration] Registering scheme $_customScheme for app: $appPath');

      // Create registry entries for the custom scheme
      final result = await Process.run('reg', [
        'add',
        'HKEY_CURRENT_USER\\Software\\Classes\\$_customScheme',
        '/ve',
        '/d',
        'URL:CloudToLocalLLM Protocol',
        '/f'
      ]);

      if (result.exitCode != 0) {
        debugPrint(
            '[UrlSchemeRegistration] Failed to create main registry key: ${result.stderr}');
        return false;
      }

      // Add URL Protocol value
      final protocolResult = await Process.run('reg', [
        'add',
        'HKEY_CURRENT_USER\\Software\\Classes\\$_customScheme',
        '/v',
        'URL Protocol',
        '/d',
        '',
        '/f'
      ]);

      if (protocolResult.exitCode != 0) {
        debugPrint(
            '[UrlSchemeRegistration] Failed to add URL Protocol: ${protocolResult.stderr}');
        return false;
      }

      // Add command to launch the app
      final commandResult = await Process.run('reg', [
        'add',
        'HKEY_CURRENT_USER\\Software\\Classes\\$_customScheme\\shell\\open\\command',
        '/ve',
        '/d',
        '"$appPath" "%1"',
        '/f'
      ]);

      if (commandResult.exitCode != 0) {
        debugPrint(
            '[UrlSchemeRegistration] Failed to add command: ${commandResult.stderr}');
        return false;
      }

      debugPrint(
          '[UrlSchemeRegistration] Successfully registered URL scheme $_customScheme');
      return true;
    } catch (e) {
      debugPrint('[UrlSchemeRegistration] Error registering URL scheme: $e');
      return false;
    }
  }

  /// Checks if the URL scheme is already registered
  static Future<bool> isSchemeRegistered() async {
    if (kIsWeb) return true;
    if (!Platform.isWindows) {
      return true;
    }

    try {
      final result = await Process.run('reg', [
        'query',
        'HKEY_CURRENT_USER\\Software\\Classes\\$_customScheme',
        '/v',
        'URL Protocol'
      ]);

      return result.exitCode == 0;
    } catch (e) {
      debugPrint(
          '[UrlSchemeRegistration] Error checking scheme registration: $e');
      return false;
    }
  }

  /// Unregisters the custom URL scheme (for cleanup)
  static Future<bool> unregisterUrlScheme() async {
    if (kIsWeb) return true;
    if (!Platform.isWindows) {
      return true;
    }

    try {
      final result = await Process.run('reg', [
        'delete',
        'HKEY_CURRENT_USER\\Software\\Classes\\$_customScheme',
        '/f'
      ]);

      debugPrint(
          '[UrlSchemeRegistration] Unregistered URL scheme: ${result.exitCode == 0 ? "SUCCESS" : "FAILED"}');
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('[UrlSchemeRegistration] Error unregistering URL scheme: $e');
      return false;
    }
  }

  /// Gets the custom scheme used by the app
  static String get customScheme => _customScheme;
}
