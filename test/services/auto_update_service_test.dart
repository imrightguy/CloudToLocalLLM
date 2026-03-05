import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/auto_update_service.dart';

void main() {
  group('AutoUpdateService', () {
    late AutoUpdateService service;

    setUp(() {
      service = AutoUpdateService();
    });

    test('parses semantic version correctly', () {
      final components = service.parseVersion('10.1.200');

      expect(components.major, equals(10));
      expect(components.minor, equals(1));
      expect(components.patch, equals(200));
    });

    test('parses semantic version with single digit components', () {
      final components = service.parseVersion('1.2.3');

      expect(components.major, equals(1));
      expect(components.minor, equals(2));
      expect(components.patch, equals(3));
    });

    test('throws FormatException for invalid version format', () {
      expect(
        () => service.parseVersion('1.2'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for version with too many components', () {
      expect(
        () => service.parseVersion('1.2.3.4'),
        throwsA(isA<FormatException>()),
      );
    });

    test('compares versions and returns major update type', () {
      final updateType = service.compareVersions('10.1.200', '11.0.0');

      expect(updateType, equals(UpdateType.major));
    });

    test('compares versions and returns minor update type', () {
      final updateType = service.compareVersions('10.1.200', '10.2.0');

      expect(updateType, equals(UpdateType.minor));
    });

    test('compares versions and returns patch update type', () {
      final updateType = service.compareVersions('10.1.200', '10.1.201');

      expect(updateType, equals(UpdateType.patch));
    });

    test('compares versions and returns none when up to date', () {
      final updateType = service.compareVersions('10.1.200', '10.1.200');

      expect(updateType, equals(UpdateType.none));
    });

    test('compares versions correctly when latest is older', () {
      final updateType = service.compareVersions('10.1.200', '10.1.199');

      expect(updateType, equals(UpdateType.none));
    });

    test('VersionComponents toString returns correct format', () {
      final components = const VersionComponents(
        major: 10,
        minor: 1,
        patch: 200,
      );

      expect(components.toString(), equals('10.1.200'));
    });

    test('service initializes with upToDate status', () {
      expect(service.status, equals(UpdateStatus.upToDate));
      expect(service.updateInfo, isNull);
      expect(service.errorMessage, isNull);
    });

    test('service is singleton', () {
      final service1 = AutoUpdateService();
      final service2 = AutoUpdateService();

      expect(identical(service1, service2), isTrue);
    });
  });
}
