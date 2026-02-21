import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/widgets/settings/mobile_settings_category.dart';

void main() {
  group('MobileSettingsCategory', () {
    setUp(() {
      // No setup needed for basic widget tests
    });

    testWidgets('renders mobile settings category',
        (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(800, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileSettingsCategory(
              categoryId: 'mobile',
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.byType(MobileSettingsCategory), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('displays all mobile settings toggles',
        (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(800, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileSettingsCategory(
              categoryId: 'mobile',
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.text('Biometric Authentication'), findsOneWidget);
      expect(find.text('Enable Notifications'), findsOneWidget);
      expect(find.text('Notification Sound'), findsOneWidget);
      expect(find.text('Vibration'), findsOneWidget);
    });

    testWidgets('displays accessibility note', (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(800, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileSettingsCategory(
              categoryId: 'mobile',
              isActive: true,
            ),
          ),
        ),
      );

      expect(
        find.text(
          'All touch targets are optimized for mobile accessibility (minimum 44x44 pixels)',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays save and cancel buttons',
        (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(800, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileSettingsCategory(
              categoryId: 'mobile',
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('renders with scrollable content', (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(800, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileSettingsCategory(
              categoryId: 'mobile',
              isActive: true,
            ),
          ),
        ),
      );

      // Verify the widget renders with scrollable content
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('has all required settings groups',
        (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(800, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileSettingsCategory(
              categoryId: 'mobile',
              isActive: true,
            ),
          ),
        ),
      );

      // Verify all settings groups are present
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Configure biometric authentication and security'),
          findsOneWidget);
      expect(find.text('Control notification preferences'), findsOneWidget);
    });

    testWidgets('displays descriptions for all settings',
        (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(800, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileSettingsCategory(
              categoryId: 'mobile',
              isActive: true,
            ),
          ),
        ),
      );

      // Verify descriptions are displayed
      expect(
        find.text('Use Face ID, Touch ID, or Fingerprint to unlock the app'),
        findsOneWidget,
      );
      expect(find.text('Receive notifications from the application'),
          findsOneWidget);
      expect(find.text('Play sound when notifications arrive'), findsOneWidget);
      expect(find.text('Vibrate when notifications arrive'), findsOneWidget);
    });
  });
}
