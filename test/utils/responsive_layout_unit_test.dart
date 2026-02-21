import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/utils/responsive_layout.dart';

void main() {
  group('ResponsiveBreakpoints', () {
    test('Mobile breakpoint is 600', () {
      expect(ResponsiveBreakpoints.mobile, 600);
    });

    test('Tablet breakpoint is 1024', () {
      expect(ResponsiveBreakpoints.tablet, 1024);
    });

    test('Desktop breakpoint is 1024', () {
      expect(ResponsiveBreakpoints.desktop, 1024);
    });

    test('Minimum touch target is 44', () {
      expect(ResponsiveBreakpoints.minTouchTarget, 44);
    });

    test('Minimum desktop touch target is 32', () {
      expect(ResponsiveBreakpoints.minDesktopTouchTarget, 32);
    });
  });

  group('ScreenSize enum', () {
    test('Has mobile value', () {
      expect(ScreenSize.mobile, isNotNull);
    });

    test('Has tablet value', () {
      expect(ScreenSize.tablet, isNotNull);
    });

    test('Has desktop value', () {
      expect(ScreenSize.desktop, isNotNull);
    });
  });
}
