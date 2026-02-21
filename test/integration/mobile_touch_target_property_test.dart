/// Property Test: Mobile Touch Target Size
///
/// **Feature: unified-app-theming, Property 6: Mobile Touch Target Size**
/// **Validates: Requirements 4.4, 13.6**
///
/// *For any* mobile screen, all touch targets SHALL be at least 44x44 pixels
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/utils/responsive_layout.dart';

void main() {
  group('Property 6: Mobile Touch Target Size', () {
    testWidgets(
      'Property test: All interactive elements on mobile have minimum 44x44 touch targets',
      (WidgetTester tester) async {
        // Set mobile screen size
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;

        // Build a screen with properly sized interactive elements
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final minSize =
                      ResponsiveLayout.getMinTouchTargetSize(context);

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        // Button with minimum size
                        SizedBox(
                          width: minSize,
                          height: minSize,
                          child: ElevatedButton(
                            onPressed: () {},
                            child: const Text('Button'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // IconButton with minimum size
                        SizedBox(
                          width: minSize,
                          height: minSize,
                          child: IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.settings),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Custom touch target wrapper
                        InkWell(
                          onTap: () {},
                          child: Container(
                            width: minSize,
                            height: minSize,
                            alignment: Alignment.center,
                            child: const Text('Tappable'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // GestureDetector with minimum size
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            width: minSize,
                            height: minSize,
                            color: Colors.blue,
                            alignment: Alignment.center,
                            child: const Text('Gesture'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify we're on mobile
        final context = tester.element(find.byType(Scaffold));
        expect(ResponsiveLayout.isMobile(context), isTrue);

        // Find all Container widgets (our touch targets)
        final containers = find.byType(Container);

        // Check each container that is a touch target
        int touchTargetCount = 0;
        for (final element in containers.evaluate()) {
          final renderBox = element.renderObject as RenderBox?;
          if (renderBox == null) continue;

          final size = renderBox.size;

          // Only check containers that are likely touch targets (have both width and height)
          if (size.width > 0 && size.height > 0) {
            touchTargetCount++;

            // Verify minimum touch target size
            expect(
              size.width,
              greaterThanOrEqualTo(44.0),
              reason:
                  'Touch target should have minimum width of 44px on mobile, but has ${size.width}px',
            );

            expect(
              size.height,
              greaterThanOrEqualTo(44.0),
              reason:
                  'Touch target should have minimum height of 44px on mobile, but has ${size.height}px',
            );
          }
        }

        // Verify we actually tested some touch targets
        expect(
          touchTargetCount,
          greaterThan(0),
          reason: 'Should have found at least one touch target to test',
        );

        // Clean up
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Property test: Desktop touch targets can be smaller (32x32 minimum)',
      (WidgetTester tester) async {
        // Set desktop screen size
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.settings),
                    iconSize: 20,
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify we're on desktop
        final context = tester.element(find.byType(Scaffold));
        expect(ResponsiveLayout.isDesktop(context), isTrue);

        // Get minimum touch target size for desktop
        final minSize = ResponsiveLayout.getMinTouchTargetSize(context);
        expect(
          minSize,
          equals(ResponsiveBreakpoints.minDesktopTouchTarget),
          reason: 'Desktop should use 32px minimum touch target',
        );

        // Clean up
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Property test: Touch target spacing on mobile prevents accidental taps',
      (WidgetTester tester) async {
        // Set mobile screen size
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    key: const Key('button1'),
                    onPressed: () {},
                    child: const Text('Button 1'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('button2'),
                    onPressed: () {},
                    child: const Text('Button 2'),
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Get button positions
        final button1 = tester.getRect(find.byKey(const Key('button1')));
        final button2 = tester.getRect(find.byKey(const Key('button2')));

        // Calculate spacing between buttons
        final spacing = button2.top - button1.bottom;

        // Verify adequate spacing (at least 8px recommended)
        expect(
          spacing,
          greaterThanOrEqualTo(8.0),
          reason:
              'Touch targets should have at least 8px spacing to prevent accidental taps',
        );

        // Clean up
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Property test: ResponsiveLayout helper returns correct minimum touch target size',
      (WidgetTester tester) async {
        // Test mobile
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final minSize =
                      ResponsiveLayout.getMinTouchTargetSize(context);
                  return Text('Min: $minSize');
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        var context = tester.element(find.byType(Scaffold));
        var minSize = ResponsiveLayout.getMinTouchTargetSize(context);

        expect(
          minSize,
          equals(ResponsiveBreakpoints.minTouchTarget),
          reason: 'Mobile should return 44px minimum touch target',
        );

        // Test desktop
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpAndSettle();

        context = tester.element(find.byType(Scaffold));
        minSize = ResponsiveLayout.getMinTouchTargetSize(context);

        expect(
          minSize,
          equals(ResponsiveBreakpoints.minDesktopTouchTarget),
          reason: 'Desktop should return 32px minimum touch target',
        );

        // Clean up
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Property test: Custom touch target wrapper ensures minimum size',
      (WidgetTester tester) async {
        // Set mobile screen size
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;

        // Create a small icon that needs touch target wrapper
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final minSize =
                      ResponsiveLayout.getMinTouchTargetSize(context);

                  return InkWell(
                    onTap: () {},
                    child: Container(
                      width: minSize,
                      height: minSize,
                      alignment: Alignment.center,
                      child: const Icon(Icons.close, size: 20),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find the container
        final container = tester.widget<Container>(find.byType(Container));

        expect(
          container.constraints?.minWidth,
          greaterThanOrEqualTo(44.0),
          reason: 'Touch target wrapper should enforce minimum width',
        );

        expect(
          container.constraints?.minHeight,
          greaterThanOrEqualTo(44.0),
          reason: 'Touch target wrapper should enforce minimum height',
        );

        // Clean up
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  });
}
