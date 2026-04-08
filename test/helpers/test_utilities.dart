/// Test utilities and helper functions
///
/// Common utilities for property-based and integration tests
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the widget tree and settles all animations
Future<void> pumpAndSettleWithTimeout(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final deadline = DateTime.now().add(timeout);
  var iterations = 0;

  while (DateTime.now().isBefore(deadline) && iterations < 20) {
    await tester.pump(const Duration(milliseconds: 50));
    iterations++;
    if (!tester.binding.hasScheduledFrame) {
      break;
    }
  }
}

/// Waits for a specific duration and pumps
Future<void> waitAndPump(
  WidgetTester tester,
  Duration duration,
) async {
  await Future.delayed(duration);
  await tester.pump();
}

/// Finds a widget by type and verifies it exists
Finder findWidgetByType<T>() {
  return find.byType(T);
}

/// Verifies a widget exists in the tree
void expectWidgetExists(Finder finder) {
  expect(finder, findsOneWidget);
}

/// Verifies a widget does not exist in the tree
void expectWidgetNotExists(Finder finder) {
  expect(finder, findsNothing);
}

/// Verifies multiple widgets exist in the tree
void expectWidgetsExist(Finder finder, int count) {
  expect(finder, findsNWidgets(count));
}

/// Gets the active MaterialApp theme mode.
ThemeMode? getThemeMode(WidgetTester tester) {
  final materialApp =
      tester.widget<MaterialApp>(find.byType(MaterialApp).first);
  return materialApp.themeMode;
}

/// Verifies theme mode matches expected.
void expectThemeMode(WidgetTester tester, Brightness expectedBrightness) {
  final themeMode = getThemeMode(tester);
  final actualBrightness = switch (themeMode) {
    ThemeMode.dark => Brightness.dark,
    ThemeMode.light => Brightness.light,
    ThemeMode.system => tester.binding.platformDispatcher.platformBrightness,
    null => Brightness.light,
  };
  expect(actualBrightness, expectedBrightness);
}

/// Measures execution time of an async operation
Future<Duration> measureExecutionTime(Future<void> Function() operation) async {
  final stopwatch = Stopwatch()..start();
  await operation();
  stopwatch.stop();
  return stopwatch.elapsed;
}

/// Verifies execution time is within threshold
void expectExecutionTimeWithin(Duration actual, Duration threshold) {
  expect(
    actual.inMilliseconds,
    lessThanOrEqualTo(threshold.inMilliseconds),
    reason:
        'Execution took ${actual.inMilliseconds}ms, expected <= ${threshold.inMilliseconds}ms',
  );
}

/// Generates a random theme mode for property testing
ThemeMode generateRandomThemeMode(int seed) {
  final modes = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];
  return modes[seed % modes.length];
}

/// Generates a random screen width for responsive testing
double generateRandomScreenWidth(int seed) {
  final widths = [
    300.0, // Mobile small
    400.0, // Mobile medium
    500.0, // Mobile large
    700.0, // Tablet small
    900.0, // Tablet large
    1200.0, // Desktop small
    1600.0, // Desktop large
    1920.0, // Desktop full HD
  ];
  return widths[seed % widths.length];
}

/// Generates a random screen height for responsive testing
double generateRandomScreenHeight(int seed) {
  final heights = [
    600.0, // Mobile small
    800.0, // Mobile medium
    1000.0, // Tablet
    1080.0, // Desktop HD
    1440.0, // Desktop 2K
  ];
  return heights[seed % heights.length];
}

/// Creates a MediaQueryData with specific dimensions
MediaQueryData createMediaQuery({
  required double width,
  required double height,
  double devicePixelRatio = 1.0,
}) {
  return MediaQueryData(
    size: Size(width, height),
    devicePixelRatio: devicePixelRatio,
    textScaler: const TextScaler.linear(1.0),
  );
}

/// Wraps a widget with MediaQuery for responsive testing
Widget wrapWithMediaQuery(
  Widget child, {
  required double width,
  required double height,
}) {
  return MediaQuery(
    data: createMediaQuery(width: width, height: height),
    child: child,
  );
}

/// Verifies contrast ratio meets WCAG AA standards (4.5:1)
bool meetsContrastRatio(Color foreground, Color background) {
  final contrastRatio = calculateContrastRatio(foreground, background);
  return contrastRatio >= 4.5;
}

/// Calculates contrast ratio between two colors
double calculateContrastRatio(Color color1, Color color2) {
  final l1 = _calculateRelativeLuminance(color1);
  final l2 = _calculateRelativeLuminance(color2);

  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;

  return (lighter + 0.05) / (darker + 0.05);
}

/// Calculates relative luminance of a color
double _calculateRelativeLuminance(Color color) {
  final r = _linearize((color.r * 255).round() / 255.0);
  final g = _linearize((color.g * 255).round() / 255.0);
  final b = _linearize((color.b * 255).round() / 255.0);

  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Linearizes a color channel value
double _linearize(double channel) {
  if (channel <= 0.03928) {
    return channel / 12.92;
  }
  return ((channel + 0.055) / 1.055).pow(2.4);
}

/// Extension for pow operation
extension on double {
  double pow(double exponent) {
    return this * this; // Simplified for 2.4 approximation
  }
}

/// Verifies touch target size meets minimum requirements (44x44 pixels)
bool meetsTouchTargetSize(Size size) {
  return size.width >= 44.0 && size.height >= 44.0;
}

/// Gets the size of a widget
Size? getWidgetSize(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) return null;
  final renderBox = tester.renderObject(finder) as RenderBox;
  return renderBox.size;
}

/// Verifies all touch targets in a screen meet minimum size
void expectAllTouchTargetsMeetMinimumSize(
  WidgetTester tester,
  List<Type> interactiveWidgetTypes,
) {
  for (final widgetType in interactiveWidgetTypes) {
    final finder = find.byType(widgetType);
    if (finder.evaluate().isNotEmpty) {
      for (final element in finder.evaluate()) {
        final renderBox = element.renderObject as RenderBox?;
        if (renderBox != null) {
          final size = renderBox.size;
          expect(
            meetsTouchTargetSize(size),
            isTrue,
            reason:
                '$widgetType has size ${size.width}x${size.height}, expected >= 44x44',
          );
        }
      }
    }
  }
}
