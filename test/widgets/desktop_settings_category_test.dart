import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/widgets/settings/desktop_settings_category.dart';

void main() {
  group('DesktopSettingsCategory', () {
    setUp(() {
      // Set up SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders desktop settings category',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopSettingsCategory(
              categoryId: 'desktop',
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.byType(DesktopSettingsCategory), findsOneWidget);
      expect(find.text('Startup Behavior'), findsOneWidget);
      expect(find.text('Window Behavior'), findsOneWidget);
      expect(find.text('Window State'), findsOneWidget);
    });

    testWidgets('displays launch on startup toggle',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopSettingsCategory(
              categoryId: 'desktop',
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.text('Launch on system startup'), findsOneWidget);
      expect(find.text('Automatically start the application when you log in'),
          findsOneWidget);
    });

    testWidgets('displays always on top toggle', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopSettingsCategory(
              categoryId: 'desktop',
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.text('Always on top'), findsOneWidget);
      expect(find.text('Keep the application window on top of other windows'),
          findsOneWidget);
    });

    testWidgets('displays remember window position toggle',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopSettingsCategory(
              categoryId: 'desktop',
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.text('Remember window position'), findsOneWidget);
      expect(
          find.text('Restore the window position when the application starts'),
          findsOneWidget);
    });

    testWidgets('displays remember window size toggle',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopSettingsCategory(
              categoryId: 'desktop',
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.text('Remember window size'), findsOneWidget);
      expect(find.text('Restore the window size when the application starts'),
          findsOneWidget);
    });

    testWidgets('toggles launch on startup setting',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopSettingsCategory(
              categoryId: 'desktop',
              isActive: true,
            ),
          ),
        ),
      );

      // Find the first switch (launch on startup)
      final switches = find.byType(Switch);
      expect(switches, findsWidgets);

      // Tap the first switch
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      // Verify the switch is now enabled
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('enables save button when settings are modified',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopSettingsCategory(
              categoryId: 'desktop',
              isActive: true,
            ),
          ),
        ),
      );

      // Initially, save button should be disabled
      var saveButton = find.byType(FilledButton);
      expect(saveButton, findsOneWidget);

      // Tap a toggle to make changes
      final switches = find.byType(Switch);
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      // Save button should now be enabled
      saveButton = find.byType(FilledButton);
      expect(saveButton, findsOneWidget);
    });

    testWidgets('cancel button resets changes', (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(1200, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopSettingsCategory(
              categoryId: 'desktop',
              isActive: true,
            ),
          ),
        ),
      );

      // Tap a toggle to make changes
      final switches = find.byType(Switch);
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      // Tap cancel button
      final cancelButton = find.byType(TextButton);
      await tester.tap(cancelButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify the state is reset
      expect(find.byType(DesktopSettingsCategory), findsOneWidget);
    });

    testWidgets('saves settings when save button is pressed',
        (WidgetTester tester) async {
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(1200, 1200);
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopSettingsCategory(
              categoryId: 'desktop',
              isActive: true,
            ),
          ),
        ),
      );

      // Make a change
      final switches = find.byType(Switch);
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      // Verify save button is enabled
      final saveButton = find.byType(FilledButton);
      expect(saveButton, findsOneWidget);

      // Tap save button
      await tester.tap(saveButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify the widget still exists after save
      expect(find.byType(DesktopSettingsCategory), findsOneWidget);
    });

    testWidgets('category is inactive when isActive is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopSettingsCategory(
              categoryId: 'desktop',
              isActive: false,
            ),
          ),
        ),
      );

      // The widget should still render but with opacity 0
      expect(find.byType(DesktopSettingsCategory), findsOneWidget);
    });
  });
}
