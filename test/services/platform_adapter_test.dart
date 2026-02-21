import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/platform_adapter.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import '../test_config.dart';

void main() {
  group('PlatformAdapter', () {
    late PlatformDetectionService platformService;
    late PlatformAdapter platformAdapter;

    setUp(() {
      TestConfig.initialize();
      platformService = PlatformDetectionService();
      platformAdapter = PlatformAdapter(platformService);
    });

    tearDown(() {
      platformService.dispose();
      TestConfig.cleanup();
    });

    group('Component Building', () {
      testWidgets('should build platform-appropriate button', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildButton(
                onPressed: () {},
                child: const Text('Test Button'),
              ),
            ),
          ),
        );

        expect(find.text('Test Button'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });

      testWidgets('should build platform-appropriate text field',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildTextField(
                label: 'Test Label',
                placeholder: 'Test Placeholder',
              ),
            ),
          ),
        );

        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('should build platform-appropriate switch', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildSwitch(
                value: true,
                onChanged: (value) {},
              ),
            ),
          ),
        );

        expect(find.byType(Switch), findsOneWidget);
      });

      testWidgets('should build platform-appropriate slider', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildSlider(
                value: 0.5,
                onChanged: (value) {},
              ),
            ),
          ),
        );

        expect(find.byType(Slider), findsOneWidget);
      });

      testWidgets('should build platform-appropriate progress indicator',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildProgressIndicator(),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should build platform-appropriate app bar', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: platformAdapter.buildAppBar(
                title: 'Test Title',
              ),
            ),
          ),
        );

        expect(find.text('Test Title'), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
      });

      testWidgets('should build platform-appropriate list tile',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildListTile(
                title: const Text('Test Title'),
                subtitle: const Text('Test Subtitle'),
              ),
            ),
          ),
        );

        expect(find.text('Test Title'), findsOneWidget);
        expect(find.text('Test Subtitle'), findsOneWidget);
        expect(find.byType(ListTile), findsOneWidget);
      });

      testWidgets('should build platform-appropriate card', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildCard(
                child: const Text('Card Content'),
              ),
            ),
          ),
        );

        expect(find.text('Card Content'), findsOneWidget);
        expect(find.byType(Card), findsOneWidget);
      });

      testWidgets('should build platform-appropriate checkbox', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildCheckbox(
                value: true,
                onChanged: (value) {},
              ),
            ),
          ),
        );

        expect(find.byType(Checkbox), findsOneWidget);
      });

      testWidgets('should build platform-appropriate radio button',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildRadio<int>(
                value: 1,
                groupValue: 1,
                onChanged: (value) {},
              ),
            ),
          ),
        );

        expect(find.byType(Radio<int>), findsOneWidget);
      });

      testWidgets('should build platform-appropriate dropdown', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildDropdown<String>(
                value: 'option1',
                items: const [
                  DropdownMenuItem(value: 'option1', child: Text('Option 1')),
                  DropdownMenuItem(value: 'option2', child: Text('Option 2')),
                ],
                onChanged: (value) {},
              ),
            ),
          ),
        );

        expect(find.byType(DropdownButton<String>), findsOneWidget);
      });
    });

    group('Dialog Building', () {
      testWidgets('should show platform-appropriate dialog', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      platformAdapter.showPlatformDialog(
                        context: context,
                        title: 'Test Dialog',
                        content: 'Test Content',
                        confirmText: 'OK',
                        cancelText: 'Cancel',
                      );
                    },
                    child: const Text('Show Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Test Dialog'), findsOneWidget);
        expect(find.text('Test Content'), findsOneWidget);
        expect(find.text('OK'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      });
    });

    group('Component Type Detection', () {
      test('should return correct component type for platform', () {
        final componentType =
            platformAdapter.getComponentType(ComponentType.button);
        expect(componentType, equals('Material'));
      });
    });

    group('Feature Support', () {
      test('should correctly identify supported features', () {
        // These tests depend on the actual platform
        expect(platformAdapter.supportsFeature('notifications'), true);
        expect(platformAdapter.supportsFeature('unknown_feature'), false);
      });

      test('should identify system tray support on desktop', () {
        if (platformService.isDesktop && !platformService.isWeb) {
          expect(platformAdapter.supportsFeature('system_tray'), true);
        } else {
          expect(platformAdapter.supportsFeature('system_tray'), false);
        }
      });

      test('should identify window management support on desktop', () {
        if (platformService.isDesktop && !platformService.isWeb) {
          expect(platformAdapter.supportsFeature('window_management'), true);
        } else {
          expect(platformAdapter.supportsFeature('window_management'), false);
        }
      });

      test('should identify file system support on non-web', () {
        if (!platformService.isWeb) {
          expect(platformAdapter.supportsFeature('file_system'), true);
        } else {
          expect(platformAdapter.supportsFeature('file_system'), false);
        }
      });

      test('should identify biometric auth support on mobile', () {
        if (platformService.isMobile) {
          expect(platformAdapter.supportsFeature('biometric_auth'), true);
        } else {
          expect(platformAdapter.supportsFeature('biometric_auth'), false);
        }
      });
    });

    group('Platform Styling', () {
      test('should provide platform-specific styling', () {
        final styling = platformAdapter.getPlatformStyling();

        expect(styling, isA<Map<String, dynamic>>());
        expect(styling['buttonPadding'], isA<EdgeInsets>());
        expect(styling['inputPadding'], isA<EdgeInsets>());
        expect(styling['borderRadius'], isA<double>());
        expect(styling['elevation'], isA<double>());
      });

      test('should provide different styling for different platforms', () {
        final styling = platformAdapter.getPlatformStyling();

        // Verify that styling values are reasonable
        expect(styling['borderRadius'], greaterThan(0));
        expect(styling['elevation'], greaterThanOrEqualTo(0));
      });
    });

    group('Button Variants', () {
      testWidgets('should build primary button', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildButton(
                onPressed: () {},
                child: const Text('Primary'),
                isPrimary: true,
              ),
            ),
          ),
        );

        expect(find.byType(ElevatedButton), findsOneWidget);
      });

      testWidgets('should build secondary button', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildButton(
                onPressed: () {},
                child: const Text('Secondary'),
                isPrimary: false,
              ),
            ),
          ),
        );

        expect(find.byType(TextButton), findsOneWidget);
      });
    });

    group('TextField Variants', () {
      testWidgets('should build text field with controller', (tester) async {
        final controller = TextEditingController(text: 'Initial Text');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildTextField(
                controller: controller,
                label: 'Label',
              ),
            ),
          ),
        );

        expect(find.text('Initial Text'), findsOneWidget);

        controller.dispose();
      });

      testWidgets('should build obscured text field', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildTextField(
                label: 'Password',
                obscureText: true,
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.obscureText, true);
      });
    });

    group('Progress Indicator Variants', () {
      testWidgets('should build determinate progress indicator',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildProgressIndicator(value: 0.5),
            ),
          ),
        );

        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(indicator.value, equals(0.5));
      });

      testWidgets('should build indeterminate progress indicator',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: platformAdapter.buildProgressIndicator(),
            ),
          ),
        );

        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(indicator.value, isNull);
      });
    });
  });
}
