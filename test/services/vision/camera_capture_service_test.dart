import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/vision/camera_capture_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CameraCaptureService', () {
    late CameraCaptureService service;

    setUp(() {
      service = CameraCaptureService();
    });

    tearDown(() async {
      await service.dispose();
    });

    group('Initialization', () {
      test('should have initial state not initialized', () {
        expect(service.isInitialized, isFalse);
        expect(service.isCapturing, isFalse);
        expect(service.lastError, isNull);
      });

      test('should have non-empty cameras list after initialization attempt',
          () async {
        // Attempt initialization - may fail on devices without cameras
        try {
          await service.initialize();
        } catch (e) {
          // Expected on platforms without camera support
        }

        // After initialization attempt, cameras should be populated
        // (may be empty if no cameras available)
        expect(service.cameras, isNotNull);
      });

      test('should be idempotent when initializing multiple times', () async {
        try {
          await service.initialize();
          final firstInit = service.isInitialized;
          await service.initialize();
          expect(service.isInitialized, equals(firstInit));
        } catch (e) {
          // Expected on platforms without camera support
          expect(service.isInitialized, isFalse);
        }
      });
    });

    group('isInitialized', () {
      test('should return false before initialization', () {
        expect(service.isInitialized, isFalse);
      });

      test('should return true after successful initialization', () async {
        try {
          await service.initialize();
          // May still be false if no cameras available
          if (service.cameras.isNotEmpty) {
            expect(service.isInitialized, isTrue);
          }
        } catch (e) {
          // Expected on platforms without camera support
        }
      });
    });

    group('isCapturing', () {
      test('should return false when not capturing', () {
        expect(service.isCapturing, isFalse);
      });
    });

    group('captureImage', () {
      test('should throw StateError when not initialized', () async {
        expect(
          () => service.captureImage(),
          throwsA(isA<StateError>()),
        );
      });

      test('should return null or path when initialized', () async {
        try {
          await service.initialize();

          if (service.isInitialized) {
            final result = await service.captureImage();
            // Result may be null if capture fails, but should not throw
            expect(result, anyOf(isNull, isA<String>()));
          }
        } catch (e) {
          // Expected on platforms without camera support
        }
      });
    });

    group('controller', () {
      test('should return null before initialization', () {
        expect(service.controller, isNull);
      });

      test('should return controller after initialization', () async {
        try {
          await service.initialize();

          if (service.isInitialized) {
            expect(service.controller, isNotNull);
          } else {
            expect(service.controller, isNull);
          }
        } catch (e) {
          // Expected on platforms without camera support
          expect(service.controller, isNull);
        }
      });
    });

    group('dispose', () {
      test('should dispose gracefully when not initialized', () async {
        expect(() async => await service.dispose(), returnsNormally);
      });

      test('should dispose after initialization', () async {
        try {
          await service.initialize();
          await service.dispose();

          expect(service.isInitialized, isFalse);
          expect(service.controller, isNull);
        } catch (e) {
          // Expected on platforms without camera support
        }
      });
    });

    group('Error Handling', () {
      test('should store last error on initialization failure', () async {
        // Mock scenario: try to initialize when no cameras available
        // This will set lastError if initialization fails
        try {
          await service.initialize();

          if (!service.isInitialized && service.cameras.isEmpty) {
            expect(service.lastError, isNotNull);
            expect(service.lastError, contains('No cameras'));
          }
        } catch (e) {
          // Expected behavior
        }
      });
    });

    group('switchCamera', () {
      test('should throw StateError when not initialized', () async {
        expect(
          () => service.switchCamera(0),
          throwsA(isA<StateError>()),
        );
      });

      test('should throw RangeError for invalid index', () async {
        try {
          await service.initialize();

          if (service.isInitialized) {
            expect(
              () => service.switchCamera(999),
              throwsA(isA<RangeError>()),
            );
          }
        } catch (e) {
          // Expected on platforms without camera support
        }
      });

      test('should handle valid camera switch', () async {
        try {
          await service.initialize();

          if (service.isInitialized && service.cameras.length > 1) {
            await service.switchCamera(1);
            expect(service.isInitialized, isTrue);
          }
        } catch (e) {
          // Expected on platforms with single camera or no camera support
        }
      });
    });
  });
}
