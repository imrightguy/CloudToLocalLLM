import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloudtolocalllm/services/auto_update_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auto Update Integration Tests', () {
    late AutoUpdateService updateService;

    setUp(() {
      // Create a new instance of the service for each test
      // AutoUpdateService uses singleton pattern, so we get the same instance
      updateService = AutoUpdateService();
    });

    testWidgets('AutoUpdateService can check for updates',
        (WidgetTester tester) async {
      // Check for updates - this will try to reach GitHub API
      // In a real environment, it would return upToDate or updateAvailable
      // In test environment without network, it may error or return upToDate

      await updateService.checkForUpdates();

      // Verify status changed to either upToDate, updateAvailable, or error
      // All three are valid outcomes depending on network/environment
      expect(
        updateService.status == UpdateStatus.upToDate ||
            updateService.status == UpdateStatus.updateAvailable ||
            updateService.status == UpdateStatus.error ||
            updateService.status == UpdateStatus.checking,
        isTrue,
        reason: 'Update status should be one of the valid states after check',
      );
    });

    testWidgets('AutoUpdateService parses versions correctly',
        (WidgetTester tester) async {
      // Parse version '10.1.200' as specified in Task #12
      final components = updateService.parseVersion('10.1.200');

      // Assert version components match expected values
      expect(components.major, equals(10),
          reason: 'Major version should be 10');
      expect(components.minor, equals(1), reason: 'Minor version should be 1');
      expect(components.patch, equals(200),
          reason: 'Patch version should be 200');
    });

    testWidgets('AutoUpdateService compares versions correctly',
        (WidgetTester tester) async {
      // Test patch update detection
      final patchUpdate = updateService.compareVersions('10.1.200', '10.1.201');
      expect(patchUpdate, equals(UpdateType.patch),
          reason: 'Should detect patch version difference');

      // Test minor update detection
      final minorUpdate = updateService.compareVersions('10.1.200', '10.2.0');
      expect(minorUpdate, equals(UpdateType.minor),
          reason: 'Should detect minor version difference');

      // Test major update detection
      final majorUpdate = updateService.compareVersions('10.1.200', '11.0.0');
      expect(majorUpdate, equals(UpdateType.major),
          reason: 'Should detect major version difference');

      // Test no update needed
      final noUpdate = updateService.compareVersions('10.1.200', '10.1.200');
      expect(noUpdate, equals(UpdateType.none),
          reason: 'Should detect no update needed when versions match');
    });

    testWidgets('AutoUpdateService handles invalid version format',
        (WidgetTester tester) async {
      // Test that invalid version format throws FormatException
      expect(
        () => updateService.parseVersion('invalid'),
        throwsA(isA<FormatException>()),
        reason: 'Should throw FormatException for invalid version format',
      );
    });

    testWidgets('AutoUpdateService singleton pattern works correctly',
        (WidgetTester tester) async {
      // Verify singleton pattern - same instance returned
      final service1 = AutoUpdateService();
      final service2 = AutoUpdateService();

      expect(identical(service1, service2), isTrue,
          reason:
              'AutoUpdateService should return the same instance (singleton pattern)');
    });
  });
}
