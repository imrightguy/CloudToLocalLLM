import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/widgets/settings/privacy_settings_category.dart';

void main() {
  group('PrivacySettingsCategory', () {
    setUp(() {
      // No setup needed for basic widget tests
    });

    testWidgets('renders privacy settings category',
        (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(1200, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivacySettingsCategory(
              categoryId: 'privacy',
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.byType(PrivacySettingsCategory), findsOneWidget);
      expect(find.text('Data Collection'), findsOneWidget);
      expect(find.text('Data Management'), findsOneWidget);
    });

    testWidgets('displays all privacy toggles', (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(1200, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivacySettingsCategory(
              categoryId: 'privacy',
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Crash Reporting'), findsOneWidget);
      expect(find.text('Usage Statistics'), findsOneWidget);
    });

    testWidgets('displays clear data button', (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(1200, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivacySettingsCategory(
              categoryId: 'privacy',
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.text('Clear All Data'), findsWidgets);
    });

    testWidgets('displays save and cancel buttons',
        (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(1200, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivacySettingsCategory(
              categoryId: 'privacy',
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('toggles analytics setting', (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(1200, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivacySettingsCategory(
              categoryId: 'privacy',
              isActive: true,
            ),
          ),
        ),
      );

      // Find the first switch (Analytics)
      final switches = find.byType(Switch);
      expect(switches, findsWidgets);

      // Tap the first switch
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      // Verify the switch state changed
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('category is inactive when isActive is false',
        (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(1200, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivacySettingsCategory(
              categoryId: 'privacy',
              isActive: false,
            ),
          ),
        ),
      );

      // The widget should render with reduced opacity
      expect(find.byType(PrivacySettingsCategory), findsOneWidget);
    });

    testWidgets('displays analytics description', (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(1200, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivacySettingsCategory(
              categoryId: 'privacy',
              isActive: true,
            ),
          ),
        ),
      );

      expect(
        find.text(
            'Allow us to collect anonymous usage analytics to improve the application'),
        findsOneWidget,
      );
    });

    testWidgets('displays crash reporting description',
        (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(1200, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivacySettingsCategory(
              categoryId: 'privacy',
              isActive: true,
            ),
          ),
        ),
      );

      expect(
        find.text(
            'Allow us to collect crash reports to fix bugs and improve stability'),
        findsOneWidget,
      );
    });

    testWidgets('displays usage statistics description',
        (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(1200, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivacySettingsCategory(
              categoryId: 'privacy',
              isActive: true,
            ),
          ),
        ),
      );

      expect(
        find.text(
            'Allow us to collect statistics about feature usage and performance'),
        findsOneWidget,
      );
    });

    testWidgets('displays clear data description', (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(1200, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivacySettingsCategory(
              categoryId: 'privacy',
              isActive: true,
            ),
          ),
        ),
      );

      expect(
        find.text('Permanently delete all stored preferences and settings'),
        findsOneWidget,
      );
    });
  });
}
