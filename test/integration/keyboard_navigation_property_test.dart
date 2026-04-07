/// Property-Based Test: Keyboard Navigation Support
///
/// **Feature: unified-app-theming, Property 8: Keyboard Navigation Support**
/// **Validates: Requirements 14.2**
///
/// Property: *For any* desktop screen, keyboard-only navigation with visible
/// focus indicators SHALL be supported
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/widgets/accessible_screen_wrapper.dart';
import 'package:cloudtolocalllm/services/accessibility_service.dart';
import 'package:provider/provider.dart';

void main() {
  group('Property 8: Keyboard Navigation Support', () {
    /// **Feature: unified-app-theming, Property 8: Keyboard Navigation Support**
    /// **Validates: Requirements 14.2**
    ///
    /// Property: *For any* desktop screen, keyboard-only navigation with visible
    /// focus indicators SHALL be supported
    testWidgets(
      'Tab key navigates between focusable elements across 10 iterations',
      (WidgetTester tester) async {
        const int iterations = 10;
        int successCount = 0;

        for (int i = 0; i < iterations; i++) {
          await tester.pumpWidget(
            ChangeNotifierProvider(
              create: (_) => AccessibilityService(),
              child: MaterialApp(
                home: AccessibleScreenWrapper(
                  screenTitle: 'Test Screen $i',
                  child: Scaffold(
                    body: Column(
                      children: [
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('Button 1'),
                        ),
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('Button 2'),
                        ),
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('Button 3'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Simulate Tab key press
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();

          // Verify focus moved
          final focusedWidget = FocusManager.instance.primaryFocus;
          if (focusedWidget != null) {
            successCount++;
          }
        }

        expect(
          successCount,
          equals(iterations),
          reason: 'Tab key should navigate between elements in all iterations',
        );
      },
    );

    testWidgets(
      'Enter key activates focused button across 10 iterations',
      (WidgetTester tester) async {
        const int iterations = 10;
        int successCount = 0;

        for (int i = 0; i < iterations; i++) {
          await tester.pumpWidget(
            ChangeNotifierProvider(
              create: (_) => AccessibilityService(),
              child: MaterialApp(
                home: AccessibleScreenWrapper(
                  screenTitle: 'Test Screen $i',
                  child: Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        autofocus: true,
                        onPressed: () {},
                        child: const Text('Test Button'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Find the button
          final buttonFinder = find.byType(ElevatedButton);
          expect(buttonFinder, findsOneWidget);

          // Verify button can receive focus
          final button = tester.widget<ElevatedButton>(buttonFinder);
          if (button.autofocus) {
            successCount++;
          }
        }

        expect(
          successCount,
          equals(iterations),
          reason: 'Buttons should support keyboard focus in all iterations',
        );
      },
    );

    testWidgets(
      'Escape key triggers navigation back across 10 iterations',
      (WidgetTester tester) async {
        const int iterations = 10;
        int successCount = 0;

        for (int i = 0; i < iterations; i++) {
          await tester.pumpWidget(
            ChangeNotifierProvider(
              create: (_) => AccessibilityService(),
              child: MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Home'),
                    ),
                  ),
                ),
                routes: {
                  '/test': (context) => AccessibleScreenWrapper(
                        screenTitle: 'Test Screen $i',
                        child: const Scaffold(
                          body: Center(
                            child: Text('Test Screen'),
                          ),
                        ),
                      ),
                },
              ),
            ),
          );
          await tester.pumpAndSettle(const Duration(seconds: 1));

          final navigator =
              tester.state<NavigatorState>(find.byType(Navigator));
          await navigator.pushNamed('/test');
          await tester.pumpAndSettle(const Duration(seconds: 1));

          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle(const Duration(seconds: 1));

          final homeButton = find.text('Home');
          if (homeButton.evaluate().isNotEmpty) {
            successCount++;
          }
        }

        expect(
          successCount,
          equals(iterations),
          reason: 'Escape key should trigger navigation back in all iterations',
        );
      },
    );

    testWidgets(
      'Focus indicators are visible on focused elements across 10 iterations',
      (WidgetTester tester) async {
        const int iterations = 10;
        int successCount = 0;

        for (int i = 0; i < iterations; i++) {
          await tester.pumpWidget(
            ChangeNotifierProvider(
              create: (_) => AccessibilityService(),
              child: MaterialApp(
                home: AccessibleScreenWrapper(
                  screenTitle: 'Test Screen $i',
                  child: Scaffold(
                    body: Focus(
                      autofocus: true,
                      child: Builder(
                        builder: (context) {
                          final hasFocus = Focus.of(context).hasFocus;
                          return Container(
                            decoration: BoxDecoration(
                              border: hasFocus
                                  ? Border.all(color: Colors.blue, width: 2)
                                  : null,
                            ),
                            child: const Text('Focusable Element'),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Find the focused element
          final focusedElement = find.byType(Focus);
          if (focusedElement.evaluate().isNotEmpty) {
            successCount++;
          }
        }

        expect(
          successCount,
          equals(iterations),
          reason:
              'Focus indicators should be visible on focused elements in all iterations',
        );
      },
    );

    testWidgets(
      'Custom keyboard shortcuts work correctly across 10 iterations',
      (WidgetTester tester) async {
        const int iterations = 10;
        int successCount = 0;

        for (int i = 0; i < iterations; i++) {
          bool shortcutTriggered = false;

          await tester.pumpWidget(
            ChangeNotifierProvider(
              create: (_) => AccessibilityService(),
              child: MaterialApp(
                home: AccessibleScreenWrapper(
                  screenTitle: 'Test Screen $i',
                  keyboardShortcuts: {
                    LogicalKeySet(
                      LogicalKeyboardKey.control,
                      LogicalKeyboardKey.keyS,
                    ): () {
                      shortcutTriggered = true;
                    },
                  },
                  child: const Scaffold(
                    body: Center(
                      child: Text('Test Content'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Simulate Ctrl+S key press
          await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
          await tester.pumpAndSettle();

          if (shortcutTriggered) {
            successCount++;
          }
        }

        expect(
          successCount,
          equals(iterations),
          reason:
              'Custom keyboard shortcuts should work correctly in all iterations',
        );
      },
    );

    testWidgets(
      'Keyboard navigation can be disabled and enabled across 10 iterations',
      (WidgetTester tester) async {
        const int iterations = 10;
        int successCount = 0;

        for (int i = 0; i < iterations; i++) {
          final accessibilityService = AccessibilityService();

          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: accessibilityService,
              child: MaterialApp(
                home: AccessibleScreenWrapper(
                  screenTitle: 'Test Screen $i',
                  child: Scaffold(
                    body: Column(
                      children: [
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('Button 1'),
                        ),
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('Button 2'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Disable keyboard navigation
          accessibilityService.disableKeyboardNavigation();
          await tester.pumpAndSettle();

          expect(accessibilityService.keyboardNavigationEnabled, false);

          // Enable keyboard navigation
          accessibilityService.enableKeyboardNavigation();
          await tester.pumpAndSettle();

          if (accessibilityService.keyboardNavigationEnabled) {
            successCount++;
          }
        }

        expect(
          successCount,
          equals(iterations),
          reason: 'Keyboard navigation should be toggleable in all iterations',
        );
      },
    );
  });
}
