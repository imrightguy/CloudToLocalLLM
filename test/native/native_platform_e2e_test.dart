// Native platform E2E test - requires app to be running or integration test
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Native Platform E2E Tests', () {
    testWidgets('Screenshot capture test', (WidgetTester tester) async {
      const guiChannel = MethodChannel('cloudtolocallm/gui_automation');

      // Build a minimal widget to initialize platform channels
      await tester.pumpWidget(MaterialApp(home: Container()));
      await tester.pumpAndSettle();

      // Test screenshot
      final result = await guiChannel.invokeMethod('takeScreenshot', {
        'path': '/tmp/e2e_screenshot.ppm',
      });

      debugPrint('Screenshot result: $result');
      expect(result, isTrue);
    });

    testWidgets('Get windows test', (WidgetTester tester) async {
      const windowChannel = MethodChannel('cloudtolocallm/window_manager');

      await tester.pumpWidget(MaterialApp(home: Container()));
      await tester.pumpAndSettle();

      final result = await windowChannel.invokeMethod('getWindows');

      debugPrint('Windows result: $result');
      expect(result, isA<List>());
      expect((result as List).isNotEmpty, isTrue);
    });

    testWidgets('Keypress test', (WidgetTester tester) async {
      const guiChannel = MethodChannel('cloudtolocallm/gui_automation');

      await tester.pumpWidget(MaterialApp(home: Container()));
      await tester.pumpAndSettle();

      final result = await guiChannel.invokeMethod('executeAction', {
        'action': 'keypress(space)',
      });

      debugPrint('Keypress result: $result');
      expect(result, contains('successfully'));
    });
  });
}
