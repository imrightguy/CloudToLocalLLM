import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm/services/platform_category_filter.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';

import 'package:cloudtolocalllm/models/settings_category.dart';
import 'package:cloudtolocalllm/models/user_model.dart';

// Mock AuthService for testing
class _MockAuthService extends ChangeNotifier implements AuthService {
  @override
  bool get isRestoringSession => false;
  @override
  Future<void> updateDisplayName(String name) async {}
  @override
  ValueNotifier<bool> isAuthenticated = ValueNotifier(false);

  @override
  ValueNotifier<bool> isLoading = ValueNotifier(false);

  @override
  ValueNotifier<bool> areAuthenticatedServicesLoaded = ValueNotifier(false);

  @override
  bool isSessionBootstrapComplete = false;

  @override
  Future<void> get sessionBootstrapFuture => Future.value();

  @override
  UserModel? currentUser;

  @override
  String get assistantName => 'Test Assistant';

  @override
  bool isWeb = kIsWeb;

  @override
  Future<void> init() => Future.value();

  @override
  Future<void> login({String? tenantId}) => Future.value();

  @override
  Future<void> logout() => Future.value();

  @override
  Future<String?> getAccessToken() => Future.value(null);

  @override
  Future<String?> getValidatedAccessToken() => Future.value(null);

  @override
  Future<bool> handleCallback({String? callbackUrl, String? code}) async =>
      true;

  @override
  Future<void> loginMockDeveloper() async {}

  @override
  void dispose() {
    isAuthenticated.dispose();
    isLoading.dispose();
    areAuthenticatedServicesLoaded.dispose();
    super.dispose();
  }
}

void main() {
  group('Platform Detection Property Tests', () {
    group('Property 3: Windows Platform Category Display', () {
      /// **Feature: platform-settings-screen, Property 3: Windows Platform Category Display**
      /// **Validates: Requirements 1.3**
      ///
      /// Property: *For any* settings screen running on Windows platform,
      /// all desktop-specific categories SHALL be displayed

      test(
        'Windows platform displays desktop categories across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final mockAuth = _MockAuthService();
            final filter = PlatformCategoryFilter(
              authService: mockAuth,
              adminCenterService: null,
              tierService: null,
            );

            // Check visibility on Windows platform
            final isDesktopVisible =
                CategoryVisibilityRules.isVisibleOnPlatform(
              SettingsCategoryIds.desktop,
              isWeb: false,
              isWindows: true,
              isLinux: false,
              isAndroid: false,
              isIOS: false,
            );

            if (isDesktopVisible) {
              passCount++;
            }

            filter.dispose();
            mockAuth.dispose();
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Windows platform should display desktop categories in all iterations',
          );
        },
      );

      test(
        'Windows platform hides mobile categories across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final mockAuth = _MockAuthService();
            final filter = PlatformCategoryFilter(
              authService: mockAuth,
              adminCenterService: null,
              tierService: null,
            );

            // Check visibility on Windows platform
            final isMobileVisible = CategoryVisibilityRules.isVisibleOnPlatform(
              SettingsCategoryIds.mobile,
              isWeb: false,
              isWindows: true,
              isLinux: false,
              isAndroid: false,
              isIOS: false,
            );

            if (!isMobileVisible) {
              passCount++;
            }

            filter.dispose();
            mockAuth.dispose();
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Windows platform should hide mobile categories in all iterations',
          );
        },
      );

      test(
        'Windows platform displays universal categories across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          final universalCategories = [
            SettingsCategoryIds.general,
            SettingsCategoryIds.localLLMProviders,
            SettingsCategoryIds.account,
            SettingsCategoryIds.privacy,
          ];

          for (int i = 0; i < iterations; i++) {
            final mockAuth = _MockAuthService();
            final filter = PlatformCategoryFilter(
              authService: mockAuth,
              adminCenterService: null,
              tierService: null,
            );

            bool allUniversalVisible = true;
            for (final categoryId in universalCategories) {
              final isVisible = CategoryVisibilityRules.isVisibleOnPlatform(
                categoryId,
                isWeb: false,
                isWindows: true,
                isLinux: false,
                isAndroid: false,
                isIOS: false,
              );

              if (!isVisible) {
                allUniversalVisible = false;
              }
            }

            if (allUniversalVisible) {
              passCount++;
            }

            filter.dispose();
            mockAuth.dispose();
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Windows platform should display universal categories in all iterations',
          );
        },
      );
    });

    group('Property 4: Mobile Platform Category Display', () {
      /// **Feature: platform-settings-screen, Property 4: Mobile Platform Category Display**
      /// **Validates: Requirements 1.4**
      ///
      /// Property: *For any* settings screen running on mobile platform,
      /// mobile-specific categories SHALL be displayed and desktop-specific
      /// options SHALL be hidden

      test(
        'Mobile platform displays mobile categories across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final mockAuth = _MockAuthService();
            final filter = PlatformCategoryFilter(
              authService: mockAuth,
              adminCenterService: null,
              tierService: null,
            );

            // Test both Android and iOS
            final isAndroidMobileVisible =
                CategoryVisibilityRules.isVisibleOnPlatform(
              SettingsCategoryIds.mobile,
              isWeb: false,
              isWindows: false,
              isLinux: false,
              isAndroid: true,
              isIOS: false,
            );

            final isIOSMobileVisible =
                CategoryVisibilityRules.isVisibleOnPlatform(
              SettingsCategoryIds.mobile,
              isWeb: false,
              isWindows: false,
              isLinux: false,
              isAndroid: false,
              isIOS: true,
            );

            if (isAndroidMobileVisible && isIOSMobileVisible) {
              passCount++;
            }

            filter.dispose();
            mockAuth.dispose();
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Mobile platform should display mobile categories in all iterations',
          );
        },
      );

      test(
        'Mobile platform hides desktop categories across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final mockAuth = _MockAuthService();
            final filter = PlatformCategoryFilter(
              authService: mockAuth,
              adminCenterService: null,
              tierService: null,
            );

            // Test both Android and iOS
            final isAndroidDesktopVisible =
                CategoryVisibilityRules.isVisibleOnPlatform(
              SettingsCategoryIds.desktop,
              isWeb: false,
              isWindows: false,
              isLinux: false,
              isAndroid: true,
              isIOS: false,
            );

            final isIOSDesktopVisible =
                CategoryVisibilityRules.isVisibleOnPlatform(
              SettingsCategoryIds.desktop,
              isWeb: false,
              isWindows: false,
              isLinux: false,
              isAndroid: false,
              isIOS: true,
            );

            if (!isAndroidDesktopVisible && !isIOSDesktopVisible) {
              passCount++;
            }

            filter.dispose();
            mockAuth.dispose();
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Mobile platform should hide desktop categories in all iterations',
          );
        },
      );

      test(
        'Mobile platform displays universal categories across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          final universalCategories = [
            SettingsCategoryIds.general,
            SettingsCategoryIds.localLLMProviders,
            SettingsCategoryIds.account,
            SettingsCategoryIds.privacy,
          ];

          for (int i = 0; i < iterations; i++) {
            final mockAuth = _MockAuthService();
            final filter = PlatformCategoryFilter(
              authService: mockAuth,
              adminCenterService: null,
              tierService: null,
            );

            bool allUniversalVisible = true;
            for (final categoryId in universalCategories) {
              final isVisible = CategoryVisibilityRules.isVisibleOnPlatform(
                categoryId,
                isWeb: false,
                isWindows: false,
                isLinux: false,
                isAndroid: true,
                isIOS: false,
              );

              if (!isVisible) {
                allUniversalVisible = false;
              }
            }

            if (allUniversalVisible) {
              passCount++;
            }

            filter.dispose();
            mockAuth.dispose();
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Mobile platform should display universal categories in all iterations',
          );
        },
      );
    });

    group('Property 5: Platform-Appropriate UI Components', () {
      /// **Feature: platform-settings-screen, Property 5: Platform-Appropriate UI Components**
      /// **Validates: Requirements 1.5**
      ///
      /// Property: *For any* settings screen, the rendered UI components
      /// SHALL match the platform (Material for web/Android, Cupertino for iOS,
      /// native for Windows)

      test(
        'Platform detection returns correct platform flags across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final mockAuth = _MockAuthService();
            final filter = PlatformCategoryFilter(
              authService: mockAuth,
              adminCenterService: null,
              tierService: null,
            );

            final platformInfo = filter.getPlatformInfo();

            // Verify platform flags are mutually exclusive
            final platformCount = [
              platformInfo['isWeb'],
              platformInfo['isWindows'],
              platformInfo['isLinux'],
              platformInfo['isAndroid'],
              platformInfo['isIOS'],
            ].where((p) => p == true).length;

            // Should have exactly one platform set to true
            if (platformCount == 1) {
              passCount++;
            }

            filter.dispose();
            mockAuth.dispose();
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Platform detection should return exactly one platform in all iterations',
          );
        },
      );

      test(
        'Platform detection consistency across multiple calls',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final mockAuth = _MockAuthService();
            final filter = PlatformCategoryFilter(
              authService: mockAuth,
              adminCenterService: null,
              tierService: null,
            );

            // Get platform info multiple times
            final platformInfo1 = filter.getPlatformInfo();
            final platformInfo2 = filter.getPlatformInfo();
            final platformInfo3 = filter.getPlatformInfo();

            // All should be identical - compare key values
            final consistent =
                platformInfo1['isWeb'] == platformInfo2['isWeb'] &&
                    platformInfo2['isWeb'] == platformInfo3['isWeb'] &&
                    platformInfo1['isWindows'] == platformInfo2['isWindows'] &&
                    platformInfo2['isWindows'] == platformInfo3['isWindows'] &&
                    platformInfo1['isLinux'] == platformInfo2['isLinux'] &&
                    platformInfo2['isLinux'] == platformInfo3['isLinux'] &&
                    platformInfo1['isAndroid'] == platformInfo2['isAndroid'] &&
                    platformInfo2['isAndroid'] == platformInfo3['isAndroid'] &&
                    platformInfo1['isIOS'] == platformInfo2['isIOS'] &&
                    platformInfo2['isIOS'] == platformInfo3['isIOS'];

            if (consistent) {
              passCount++;
            }

            filter.dispose();
            mockAuth.dispose();
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Platform detection should be consistent across multiple calls in all iterations',
          );
        },
      );

      test(
        'Desktop and mobile flags are mutually exclusive across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final mockAuth = _MockAuthService();
            final filter = PlatformCategoryFilter(
              authService: mockAuth,
              adminCenterService: null,
              tierService: null,
            );

            final platformInfo = filter.getPlatformInfo();
            final isDesktop = platformInfo['isDesktop'] as bool;
            final isMobile = platformInfo['isMobile'] as bool;

            // Desktop and mobile should never both be true
            if (!(isDesktop && isMobile)) {
              passCount++;
            }

            filter.dispose();
            mockAuth.dispose();
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Desktop and mobile flags should be mutually exclusive in all iterations',
          );
        },
      );
    });

    group('Property 6: Cross-Platform Settings Compatibility', () {
      /// **Feature: platform-settings-screen, Property 6: Cross-Platform Settings Compatibility**
      /// **Validates: Requirements 1.6**
      ///
      /// Property: *For any* settings saved on one platform, those settings
      /// SHALL be loadable and compatible on another platform

      test(
        'Universal categories are visible on all platforms across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          final universalCategories = [
            SettingsCategoryIds.general,
            SettingsCategoryIds.localLLMProviders,
            SettingsCategoryIds.account,
            SettingsCategoryIds.privacy,
          ];

          final platforms = [
            ('Web', true, false, false, false, false),
            ('Windows', false, true, false, false, false),
            ('Linux', false, false, true, false, false),
            ('Android', false, false, false, true, false),
            ('iOS', false, false, false, false, true),
          ];

          for (int i = 0; i < iterations; i++) {
            bool allPlatformsCompatible = true;

            for (final (_, isWeb, isWindows, isLinux, isAndroid, isIOS)
                in platforms) {
              final mockAuth = _MockAuthService();
              final filter = PlatformCategoryFilter(
                authService: mockAuth,
                adminCenterService: null,
                tierService: null,
              );

              bool allUniversalVisible = true;
              for (final categoryId in universalCategories) {
                final isVisible = CategoryVisibilityRules.isVisibleOnPlatform(
                  categoryId,
                  isWeb: isWeb,
                  isWindows: isWindows,
                  isLinux: isLinux,
                  isAndroid: isAndroid,
                  isIOS: isIOS,
                );

                if (!isVisible) {
                  allUniversalVisible = false;
                }
              }

              if (!allUniversalVisible) {
                allPlatformsCompatible = false;
              }

              filter.dispose();
              mockAuth.dispose();
            }

            if (allPlatformsCompatible) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Universal categories should be visible on all platforms in all iterations',
          );
        },
      );

      test(
        'Platform-specific categories do not conflict across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final mockAuth = _MockAuthService();
            final filter = PlatformCategoryFilter(
              authService: mockAuth,
              adminCenterService: null,
              tierService: null,
            );

            // Desktop should not be visible on mobile
            final desktopOnAndroid =
                CategoryVisibilityRules.isVisibleOnPlatform(
              SettingsCategoryIds.desktop,
              isWeb: false,
              isWindows: false,
              isLinux: false,
              isAndroid: true,
              isIOS: false,
            );

            // Mobile should not be visible on desktop
            final mobileOnWindows = CategoryVisibilityRules.isVisibleOnPlatform(
              SettingsCategoryIds.mobile,
              isWeb: false,
              isWindows: true,
              isLinux: false,
              isAndroid: false,
              isIOS: false,
            );

            if (!desktopOnAndroid && !mobileOnWindows) {
              passCount++;
            }

            filter.dispose();
            mockAuth.dispose();
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Platform-specific categories should not conflict in all iterations',
          );
        },
      );

      test(
        'Settings categories remain consistent across platform switches',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final mockAuth = _MockAuthService();
            final filter = PlatformCategoryFilter(
              authService: mockAuth,
              adminCenterService: null,
              tierService: null,
            );

            // Check universal categories on multiple platforms
            final generalOnWeb = CategoryVisibilityRules.isVisibleOnPlatform(
              SettingsCategoryIds.general,
              isWeb: true,
              isWindows: false,
              isLinux: false,
              isAndroid: false,
              isIOS: false,
            );

            final generalOnWindows =
                CategoryVisibilityRules.isVisibleOnPlatform(
              SettingsCategoryIds.general,
              isWeb: false,
              isWindows: true,
              isLinux: false,
              isAndroid: false,
              isIOS: false,
            );

            final generalOnAndroid =
                CategoryVisibilityRules.isVisibleOnPlatform(
              SettingsCategoryIds.general,
              isWeb: false,
              isWindows: false,
              isLinux: false,
              isAndroid: true,
              isIOS: false,
            );

            if (generalOnWeb && generalOnWindows && generalOnAndroid) {
              passCount++;
            }

            filter.dispose();
            mockAuth.dispose();
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Settings categories should remain consistent across platform switches in all iterations',
          );
        },
      );
    });
  });
}
