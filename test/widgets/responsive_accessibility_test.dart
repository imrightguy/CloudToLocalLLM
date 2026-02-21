import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/utils/responsive_layout.dart';
import 'package:cloudtolocalllm/utils/accessibility_helpers.dart';

void main() {
  group('ResponsiveLayout Tests', () {
    testWidgets('ResponsiveLayout provides screen size detection',
        (WidgetTester tester) async {
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(400, 800);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final isMobile = ResponsiveLayout.isMobile(context);
                return Text(isMobile ? 'mobile' : 'not-mobile');
              },
            ),
          ),
        ),
      );

      expect(find.text('mobile'), findsOneWidget);
    });

    testWidgets('getResponsivePadding returns correct values',
        (WidgetTester tester) async {
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(400, 800);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final padding = ResponsiveLayout.getResponsivePadding(context);
                return Text('${padding.top}');
              },
            ),
          ),
        ),
      );

      expect(find.text('12.0'), findsOneWidget);
    });

    testWidgets('getResponsiveColumnCount returns correct values',
        (WidgetTester tester) async {
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(400, 800);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final columnCount =
                    ResponsiveLayout.getResponsiveColumnCount(context);
                return Text('$columnCount');
              },
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('ResponsiveWidget rebuilds on screen size change',
        (WidgetTester tester) async {
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(400, 800);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveWidget(
              builder: (context, screenSize) {
                return Text(screenSize.toString());
              },
            ),
          ),
        ),
      );

      expect(find.text('ScreenSize.mobile'), findsOneWidget);
    });

    testWidgets('ResponsiveContainer applies responsive padding',
        (WidgetTester tester) async {
      addTearDown(
          tester.binding.platformDispatcher.views.first.resetPhysicalSize);
      tester.binding.platformDispatcher.views.first.physicalSize =
          const Size(400, 800);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveContainer(
              child: const Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Content'), findsOneWidget);
    });
  });

  group('AccessibilityHelpers Tests', () {
    test('meetsContrastRequirement returns true for sufficient contrast', () {
      final foreground = Colors.black;
      final background = Colors.white;

      final meets =
          AccessibilityHelpers.meetsContrastRequirement(foreground, background);

      expect(meets, true);
    });

    test('meetsContrastRequirement returns false for insufficient contrast',
        () {
      final foreground = Colors.grey.shade400;
      final background = Colors.grey.shade300;

      final meets =
          AccessibilityHelpers.meetsContrastRequirement(foreground, background);

      expect(meets, false);
    });

    test('getSemanticLabel includes description when provided', () {
      final label = AccessibilityHelpers.getSemanticLabel(
        'Save',
        description: 'Save all changes',
      );

      expect(label, 'Save. Save all changes');
    });

    test('getSemanticLabel returns label only when no description', () {
      final label = AccessibilityHelpers.getSemanticLabel('Save');

      expect(label, 'Save');
    });
  });

  group('AccessibleTextInput Tests', () {
    testWidgets('renders with label and description',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleTextInput(
              label: 'Email',
              description: 'Enter your email address',
              value: '',
            ),
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Enter your email address'), findsOneWidget);
    });

    testWidgets('displays error message when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleTextInput(
              label: 'Email',
              value: '',
              errorMessage: 'Invalid email',
            ),
          ),
        ),
      );

      expect(find.text('Invalid email'), findsWidgets);
    });

    testWidgets('calls onChanged when text is entered',
        (WidgetTester tester) async {
      String changedValue = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleTextInput(
              label: 'Email',
              value: '',
              onChanged: (value) => changedValue = value,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'test@example.com');
      await tester.pumpAndSettle();

      expect(changedValue, 'test@example.com');
    });
  });

  group('AccessibleToggle Tests', () {
    testWidgets('renders with label and description',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleToggle(
              label: 'Enable Notifications',
              description: 'Receive notifications for updates',
              value: false,
            ),
          ),
        ),
      );

      expect(find.text('Enable Notifications'), findsOneWidget);
      expect(find.text('Receive notifications for updates'), findsOneWidget);
    });

    testWidgets('calls onChanged when toggled', (WidgetTester tester) async {
      bool toggleValue = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleToggle(
              label: 'Enable Notifications',
              value: toggleValue,
              onChanged: (value) => toggleValue = value,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(toggleValue, true);
    });
  });

  group('AccessibleButton Tests', () {
    testWidgets('renders with label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleButton(
              label: 'Save',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleButton(
              label: 'Save',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(pressed, true);
    });

    testWidgets('shows loading state when isLoading is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleButton(
              label: 'Save',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AccessibleDropdown Tests', () {
    testWidgets('renders with label and items', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleDropdown<String>(
              label: 'Theme',
              items: [
                const DropdownMenuItem(value: 'light', child: Text('Light')),
                const DropdownMenuItem(value: 'dark', child: Text('Dark')),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Theme'), findsOneWidget);
    });

    testWidgets('calls onChanged when item is selected',
        (WidgetTester tester) async {
      String selectedValue = 'light';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleDropdown<String>(
              label: 'Theme',
              value: 'light',
              items: [
                const DropdownMenuItem(value: 'light', child: Text('Light')),
                const DropdownMenuItem(value: 'dark', child: Text('Dark')),
              ],
              onChanged: (value) => selectedValue = value ?? 'light',
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();

      expect(selectedValue, 'dark');
    });
  });
}
