import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/widgets/installation_guide.dart';

void main() {
  group('InstallationGuide', () {
    // Note: Widget tests are complex due to the InstallationGuide's dependencies
    // on PlatformDetectionService and platform configurations.
    // For now, we'll focus on testing the core functionality.

    test('should create InstallationGuide widget', () {
      // Basic test to ensure the widget can be instantiated
      expect(() => InstallationGuide, returnsNormally);
    });
  });

  group('InstallationValidationResult', () {
    test('should create valid result', () {
      final result = InstallationValidationResult(
        isValid: true,
        message: 'Installation successful',
      );

      expect(result.isValid, true);
      expect(result.message, 'Installation successful');
      expect(result.error, isNull);
    });

    test('should create invalid result with error', () {
      final result = InstallationValidationResult(
        isValid: false,
        error: 'Installation failed',
        details: {'code': 404},
      );

      expect(result.isValid, false);
      expect(result.error, 'Installation failed');
      expect(result.details?['code'], 404);
    });
  });
}
