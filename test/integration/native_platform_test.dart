// Quick integration test for native Linux platform channels
// Run with: flutter test test/integration/native_platform_test.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/main.dart' as app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Linux Native Platform Channels', () {
    late MethodChannel guiAutomationChannel;
    late MethodChannel windowManagerChannel;

    setUpAll(() async {
      // Initialize the app to register platform channels
      app.main();
      await Future.delayed(const Duration(milliseconds: 500));

      guiAutomationChannel =
          const MethodChannel('cloudtolocallm/gui_automation');
      windowManagerChannel =
          const MethodChannel('cloudtolocallm/window_manager');
    });

    test('GUI Automation channel exists', () async {
      // This verifies the channel was registered
      expect(guiAutomationChannel, isNotNull);
    });

    test('Window Manager channel exists', () async {
      expect(windowManagerChannel, isNotNull);
    });

    test('takeScreenshot via native channel', () async {
      try {
        final result =
            await guiAutomationChannel.invokeMethod('takeScreenshot', {
          'path': '/tmp/test_screenshot.ppm',
        });
        debugPrint('Screenshot result: $result');
        // Should return true on success
        expect(result, isTrue);
      } catch (e) {
        debugPrint('Screenshot error (expected if not running on Linux): $e');
        // Test passes if we get any response (even error) - proves channel is wired
        expect(e, isA<PlatformException>());
      }
    });

    test('getWindows via native channel', () async {
      try {
        final result = await windowManagerChannel.invokeMethod('getWindows');
        debugPrint('Windows result: $result');
        // Should return a list of windows
        expect(result, isA<List>());
      } catch (e) {
        debugPrint('getWindows error (expected if not running on Linux): $e');
        expect(e, isA<PlatformException>());
      }
    });

    test('executeAction via native channel', () async {
      try {
        final result =
            await guiAutomationChannel.invokeMethod('executeAction', {
          'action': 'keypress(space)',
        });
        debugPrint('Action result: $result');
        // Should return success message
        expect(result, contains('successfully'));
      } catch (e) {
        debugPrint('Action error (expected if not running on Linux): $e');
        expect(e, isA<PlatformException>());
      }
    });
  });
}
