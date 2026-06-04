import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/platform_category_filter.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/models/user_model.dart';

import 'package:flutter/foundation.dart';

void main() {
  group('Platform Detection Timing - Property 1', () {
    /// **Feature: platform-settings-screen, Property 1: Platform Detection Timing**
    /// **Validates: Requirements 1.1**
    ///
    /// Property: *For any* settings screen initialization, platform detection
    /// SHALL complete within 100 milliseconds
    ///
    /// This property-based test verifies that platform detection completes
    /// within the required 100ms timing constraint across multiple iterations.

    test(
      'Platform detection completes within 100ms on initialization',
      () async {
        final stopwatch = Stopwatch()..start();

        final filter = PlatformCategoryFilter(
          authService: _createMockAuthService(),
          adminCenterService: null,
          tierService: null,
        );

        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(100),
          reason:
              'Platform detection should complete within 100ms, but took ${stopwatch.elapsedMilliseconds}ms',
        );

        final platformInfo = filter.getPlatformInfo();
        expect(platformInfo, isNotNull);
        expect(platformInfo.containsKey('isWeb'), true);

        filter.dispose();
      },
    );

    test(
      'Multiple sequential platform detections complete within 100ms each',
      () async {
        const int iterations = 10;
        final timings = <int>[];

        for (int i = 0; i < iterations; i++) {
          final stopwatch = Stopwatch()..start();

          final filter = PlatformCategoryFilter(
            authService: _createMockAuthService(),
            adminCenterService: null,
            tierService: null,
          );

          stopwatch.stop();
          timings.add(stopwatch.elapsedMilliseconds);

          expect(
            stopwatch.elapsedMilliseconds,
            lessThan(100),
            reason:
                'Iteration $i: Platform detection should complete within 100ms, but took ${stopwatch.elapsedMilliseconds}ms',
          );

          filter.dispose();
        }

        for (int i = 0; i < timings.length; i++) {
          expect(
            timings[i],
            lessThan(100),
            reason:
                'Iteration $i timing ${timings[i]}ms exceeds 100ms threshold',
          );
        }
      },
    );

    test(
      'Platform detection timing remains under 100ms with rapid successive calls',
      () async {
        const int iterations = 20;
        final timings = <int>[];

        for (int i = 0; i < iterations; i++) {
          final stopwatch = Stopwatch()..start();

          final filter = PlatformCategoryFilter(
            authService: _createMockAuthService(),
            adminCenterService: null,
            tierService: null,
          );

          stopwatch.stop();
          timings.add(stopwatch.elapsedMilliseconds);

          expect(
            stopwatch.elapsedMilliseconds,
            lessThan(100),
            reason:
                'Rapid call $i: Platform detection should complete within 100ms, but took ${stopwatch.elapsedMilliseconds}ms',
          );

          filter.dispose();
        }

        final maxTiming = timings.reduce((a, b) => a > b ? a : b);
        expect(
          maxTiming,
          lessThan(100),
          reason:
              'Maximum timing across rapid calls was $maxTiming ms, exceeds 100ms threshold',
        );
      },
    );

    test(
      'Platform detection timing remains consistent across 100 iterations',
      () async {
        const int iterations = 100;
        final timings = <int>[];
        int exceedCount = 0;

        for (int i = 0; i < iterations; i++) {
          final stopwatch = Stopwatch()..start();

          final filter = PlatformCategoryFilter(
            authService: _createMockAuthService(),
            adminCenterService: null,
            tierService: null,
          );

          stopwatch.stop();
          final elapsed = stopwatch.elapsedMilliseconds;
          timings.add(elapsed);

          if (elapsed >= 100) {
            exceedCount++;
          }

          filter.dispose();
        }

        expect(
          exceedCount,
          0,
          reason:
              '$exceedCount out of $iterations iterations exceeded 100ms threshold',
        );

        final avgTiming = timings.reduce((a, b) => a + b) / timings.length;
        final maxTiming = timings.reduce((a, b) => a > b ? a : b);

        expect(
          maxTiming,
          lessThan(100),
          reason:
              'Maximum timing across 100 iterations was $maxTiming ms, exceeds 100ms threshold',
        );

        expect(
          avgTiming,
          lessThan(50),
          reason:
              'Average timing across 100 iterations was $avgTiming ms, should be well under 100ms',
        );
      },
    );
  });
}

class _MinimalAuthService extends ChangeNotifier implements AuthService {
  @override
  bool get isRestoringSession => false;
  @override
  Future<void> updateDisplayName(String name) async {}
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);
  final ValueNotifier<bool> _areAuthenticatedServicesLoaded =
      ValueNotifier(false);

  @override
  ValueNotifier<bool> get areAuthenticatedServicesLoaded =>
      _areAuthenticatedServicesLoaded;

  @override
  UserModel? get currentUser => null;

  @override
  String get assistantName => 'Test Assistant';

  @override
  void dispose() {
    _isAuthenticated.dispose();
    _isLoading.dispose();
    _areAuthenticatedServicesLoaded.dispose();
    super.dispose();
  }

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getValidatedAccessToken() async => null;

  @override
  Future<bool> handleCallback({String? callbackUrl, String? code}) async =>
      true;

  @override
  Future<void> loginMockDeveloper() async {}

  @override
  bool get isWeb => kIsWeb;

  @override
  Future<void> login({String? tenantId}) async {}

  @override
  Future<void> logout() async {}


  @override
  Future<void> get sessionBootstrapFuture async {}

  @override
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;

  @override
  ValueNotifier<bool> get isLoading => _isLoading;

  @override
  bool get isSessionBootstrapComplete => true;

  @override
  Future<void> init() async {}
}

AuthService _createMockAuthService() {
  return _MinimalAuthService();
}
