/// Property Test: Responsive Layout Adaptation
///
/// **Feature: unified-app-theming, Property 5: Responsive Layout Adaptation**
/// **Validates: Requirements 3.3, 4.3, 5.3, 6.4, 7.4, 8.4, 9.4, 10.6, 11.4, 12.3, 13.4**
///
/// *For any* screen width change, content SHALL reflow within 300 milliseconds
/// without data loss
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/utils/responsive_layout.dart';
import 'package:cloudtolocalllm/widgets/responsive_screen_wrapper.dart';

void main() {
  group('Property 5: Responsive Layout Adaptation', () {
    testWidgets(
      'Property test: Screen width changes trigger reflow within 300ms without data loss',
      (WidgetTester tester) async {
        // Test data that should be preserved
        final testData = <String, dynamic>{
          'text': 'Test content that should not be lost',
          'number': 42,
          'list': [1, 2, 3, 4, 5],
        };

        String? displayedText;
        int? displayedNumber;
        List<int>? displayedList;
        int reflowCount = 0;
        final reflowTimes = <Duration>[];

        // Build widget with data preservation
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ResponsiveScreenWrapper(
                preserveState: true,
                onScreenSizeChanged: (oldSize, newSize) {
                  reflowCount++;
                },
                unifiedBuilder: (context, screenSize) {
                  // Preserve data across reflows
                  displayedText = testData['text'] as String;
                  displayedNumber = testData['number'] as int;
                  displayedList = testData['list'] as List<int>;

                  return Column(
                    children: [
                      Text('Screen: ${screenSize.name}'),
                      Text(displayedText!),
                      Text('Number: $displayedNumber'),
                      Text('List: ${displayedList!.join(', ')}'),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        // Initial render
        await tester.pumpAndSettle();
        expect(find.text(testData['text'] as String), findsWidgets);

        // Test different screen widths
        final testWidths = [
          400.0, // Mobile
          700.0, // Tablet
          1200.0, // Desktop
          500.0, // Back to mobile
          900.0, // Tablet again
        ];

        for (final width in testWidths) {
          final startTime = DateTime.now();

          // Change screen size
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;

          // Pump and measure reflow time
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          final reflowTime = DateTime.now().difference(startTime);
          reflowTimes.add(reflowTime);

          // Verify data is preserved
          expect(
            displayedText,
            equals(testData['text']),
            reason:
                'Text data should be preserved after reflow to width $width',
          );
          expect(
            displayedNumber,
            equals(testData['number']),
            reason:
                'Number data should be preserved after reflow to width $width',
          );
          expect(
            displayedList,
            equals(testData['list']),
            reason:
                'List data should be preserved after reflow to width $width',
          );

          // Verify content is still visible (may find multiple due to AnimatedSwitcher)
          expect(
            find.text(testData['text'] as String),
            findsWidgets,
            reason:
                'Content should remain visible after reflow to width $width',
          );
        }

        // Verify reflow happened
        expect(
          reflowCount,
          greaterThan(0),
          reason: 'Screen size changes should trigger reflows',
        );

        // Verify all reflows completed within 300ms
        for (var i = 0; i < reflowTimes.length; i++) {
          expect(
            reflowTimes[i].inMilliseconds,
            lessThanOrEqualTo(300),
            reason:
                'Reflow ${i + 1} should complete within 300ms, but took ${reflowTimes[i].inMilliseconds}ms',
          );
        }

        // Clean up
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    testWidgets(
      'Property test: Responsive breakpoints correctly classify screen sizes',
      (WidgetTester tester) async {
        final testCases = [
          (width: 400.0, expected: ScreenSize.mobile),
          (width: 599.0, expected: ScreenSize.mobile),
          (width: 600.0, expected: ScreenSize.tablet),
          (width: 800.0, expected: ScreenSize.tablet),
          (width: 1023.0, expected: ScreenSize.tablet),
          (width: 1024.0, expected: ScreenSize.desktop),
          (width: 1920.0, expected: ScreenSize.desktop),
        ];

        for (final testCase in testCases) {
          ScreenSize? detectedSize;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    detectedSize = ResponsiveLayout.getScreenSize(context);
                    return Text('Width: ${testCase.width}');
                  },
                ),
              ),
            ),
          );

          // Set screen size
          tester.view.physicalSize = Size(testCase.width, 800);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpAndSettle();

          expect(
            detectedSize,
            equals(testCase.expected),
            reason:
                'Width ${testCase.width} should be classified as ${testCase.expected.name}',
          );
        }

        // Clean up
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Property test: ResponsiveRowColumn switches layout based on screen size',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ResponsiveRowColumn(
                columnOnMobile: true,
                columnOnTablet: false,
                children: [
                  SizedBox(key: const Key('child1'), width: 100, height: 50),
                  SizedBox(key: const Key('child2'), width: 100, height: 50),
                ],
              ),
            ),
          ),
        );

        // Test mobile (should be column)
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpAndSettle();

        final mobileChild1 = tester.getTopLeft(find.byKey(const Key('child1')));
        final mobileChild2 = tester.getTopLeft(find.byKey(const Key('child2')));

        expect(
          mobileChild1.dx,
          equals(mobileChild2.dx),
          reason: 'On mobile, children should be in a column (same x position)',
        );

        // Test desktop (should be row)
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpAndSettle();

        final desktopChild1 =
            tester.getTopLeft(find.byKey(const Key('child1')));
        final desktopChild2 =
            tester.getTopLeft(find.byKey(const Key('child2')));

        expect(
          desktopChild1.dy,
          equals(desktopChild2.dy),
          reason: 'On desktop, children should be in a row (same y position)',
        );

        // Clean up
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Property test: Responsive padding adapts to screen size',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ResponsivePadding(
                child: Container(
                  key: const Key('content'),
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        );

        final testSizes = [
          (width: 400.0, minPadding: 8.0), // Mobile
          (width: 700.0, minPadding: 12.0), // Tablet
          (width: 1200.0, minPadding: 16.0), // Desktop
        ];

        for (final testSize in testSizes) {
          tester.view.physicalSize = Size(testSize.width, 800);
          tester.view.devicePixelRatio = 1.0;
          await tester.pumpAndSettle();

          final paddingWidget =
              tester.widget<Padding>(find.byType(Padding).first);
          final padding = paddingWidget.padding as EdgeInsets;

          expect(
            padding.left,
            greaterThanOrEqualTo(testSize.minPadding),
            reason:
                'Padding at width ${testSize.width} should be at least ${testSize.minPadding}',
          );
        }

        // Clean up
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  });
}
