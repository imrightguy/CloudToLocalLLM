import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/services/platform_category_filter.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';

import 'package:cloudtolocalllm/models/settings_category.dart';
import 'package:cloudtolocalllm/models/user_model.dart';
import '../test_config.dart';

// Simple mock AuthService for testing
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
  Future<void> loginMockDeveloper() async {} 

  @override
  Future<String?> getAccessToken() => Future.value(null);

  @override
  Future<String?> getValidatedAccessToken() => Future.value(null);

  @override
  Future<bool> handleCallback({String? callbackUrl, String? code}) async =>
      true;

  @override
  void dispose() {
    isAuthenticated.dispose();
    isLoading.dispose();
    areAuthenticatedServicesLoaded.dispose();
    super.dispose();
  }
}

void main() {
  group('PlatformCategoryFilter', () {
    late PlatformCategoryFilter platformCategoryFilter;
    late _MockAuthService mockAuthService;

    setUp(() {
      TestConfig.initialize();
      mockAuthService = _MockAuthService();

      platformCategoryFilter = PlatformCategoryFilter(
        authService: mockAuthService,
        adminCenterService: null,
      );
    });

    tearDown(() {
      platformCategoryFilter.dispose();
      mockAuthService.dispose();
      TestConfig.cleanup();
    });

    group('Platform Detection', () {
      test('should initialize with platform detection', () {
        expect(platformCategoryFilter.isWeb, isNotNull);
        expect(platformCategoryFilter.isDesktop, isNotNull);
        expect(platformCategoryFilter.isMobile, isNotNull);
      });

      test('should provide platform information', () {
        final platformInfo = platformCategoryFilter.getPlatformInfo();

        expect(platformInfo, isNotEmpty);
        expect(platformInfo.containsKey('isWeb'), true);
        expect(platformInfo.containsKey('isWindows'), true);
        expect(platformInfo.containsKey('isLinux'), true);
        expect(platformInfo.containsKey('isAndroid'), true);
        expect(platformInfo.containsKey('isIOS'), true);
        expect(platformInfo.containsKey('isDesktop'), true);
        expect(platformInfo.containsKey('isMobile'), true);
      });

      test('should have mutually exclusive desktop and mobile flags', () {
        final platformInfo = platformCategoryFilter.getPlatformInfo();
        final isDesktop = platformInfo['isDesktop'] as bool;
        final isMobile = platformInfo['isMobile'] as bool;

        // Desktop and mobile should not both be true
        expect(isDesktop && isMobile, false);
      });
    });

    group('Admin Status Detection', () {
      test('should detect non-admin user by default', () async {
        final isAdmin = await platformCategoryFilter.isAdminUser();

        expect(isAdmin, false);
      });

      test('should cache admin status for performance', () async {
        // First call
        final isAdmin1 = await platformCategoryFilter.isAdminUser();
        expect(isAdmin1, false);

        // Second call should return cached value
        final isAdmin2 = await platformCategoryFilter.isAdminUser();
        expect(isAdmin2, false);
      });
    });

    group('Premium Status Detection', () {
      test('should detect non-premium user by default', () async {
        final isPremium = await platformCategoryFilter.isPremiumUser();

        expect(isPremium, false);
      });

      test('should cache premium status for performance', () async {
        // First call
        final isPremium1 = await platformCategoryFilter.isPremiumUser();
        expect(isPremium1, false);

        // Second call should return cached value
        final isPremium2 = await platformCategoryFilter.isPremiumUser();
        expect(isPremium2, false);
      });
    });

    group('Category Visibility - Platform Based', () {
      test('should show general category on all platforms', () async {
        final isVisible = await platformCategoryFilter.isCategoryVisible(
          SettingsCategoryIds.general,
        );

        expect(isVisible, true);
      });

      test('should hide local LLM providers category on all platforms',
          () async {
        final isVisible = await platformCategoryFilter.isCategoryVisible(
          SettingsCategoryIds.localLLMProviders,
        );

        expect(isVisible, false);
      });

      test('should show account category on all platforms', () async {
        final isVisible = await platformCategoryFilter.isCategoryVisible(
          SettingsCategoryIds.account,
        );

        expect(isVisible, true);
      });

      test('should show privacy category on all platforms', () async {
        final isVisible = await platformCategoryFilter.isCategoryVisible(
          SettingsCategoryIds.privacy,
        );

        expect(isVisible, true);
      });
    });

    group('Category Visibility - Role Based', () {
      test('should hide admin center for non-admin users', () async {
        final isVisible = await platformCategoryFilter.isCategoryVisible(
          SettingsCategoryIds.adminCenter,
        );

        expect(isVisible, false);
      });

      test('should hide premium features for non-premium users', () async {
        final isVisible = await platformCategoryFilter.isCategoryVisible(
          SettingsCategoryIds.premiumFeatures,
        );

        expect(isVisible, false);
      });
    });

    group('Visible Categories Filtering', () {
      test('should return non-empty list of visible categories', () async {
        final allCategories = [
          BaseSettingsCategory(
            id: SettingsCategoryIds.general,
            title: 'General',
            icon: Icons.tune,
            isVisible: true,
            contentBuilder: (context) => const SizedBox(),
          ),
          BaseSettingsCategory(
            id: SettingsCategoryIds.account,
            title: 'Account',
            icon: Icons.person,
            isVisible: true,
            contentBuilder: (context) => const SizedBox(),
          ),
          BaseSettingsCategory(
            id: SettingsCategoryIds.adminCenter,
            title: 'Admin Center',
            icon: Icons.admin_panel_settings,
            isVisible: true,
            contentBuilder: (context) => const SizedBox(),
            requiresAdmin: true,
          ),
        ];

        final visibleCategories =
            await platformCategoryFilter.getVisibleCategories(allCategories);

        // Should not include admin center for non-admin users
        expect(
          visibleCategories.any((c) => c.id == SettingsCategoryIds.adminCenter),
          false,
        );

        // Should include general and account
        expect(
          visibleCategories.any((c) => c.id == SettingsCategoryIds.general),
          true,
        );
        expect(
          visibleCategories.any((c) => c.id == SettingsCategoryIds.account),
          true,
        );
      });

      test('should sort categories by priority', () async {
        final allCategories = [
          BaseSettingsCategory(
            id: SettingsCategoryIds.privacy,
            title: 'Privacy',
            icon: Icons.privacy_tip,
            isVisible: true,
            contentBuilder: (context) => const SizedBox(),
            priority: 30,
          ),
          BaseSettingsCategory(
            id: SettingsCategoryIds.general,
            title: 'General',
            icon: Icons.tune,
            isVisible: true,
            contentBuilder: (context) => const SizedBox(),
            priority: 0,
          ),
          BaseSettingsCategory(
            id: SettingsCategoryIds.account,
            title: 'Account',
            icon: Icons.person,
            isVisible: true,
            contentBuilder: (context) => const SizedBox(),
            priority: 20,
          ),
        ];

        final visibleCategories =
            await platformCategoryFilter.getVisibleCategories(allCategories);

        expect(visibleCategories.length, 3);
        expect(visibleCategories[0].id, SettingsCategoryIds.general);
        expect(visibleCategories[1].id, SettingsCategoryIds.account);
        expect(visibleCategories[2].id, SettingsCategoryIds.privacy);
      });
    });

    group('User Role Information', () {
      test('should provide user role information', () async {
        final roleInfo = await platformCategoryFilter.getUserRoleInfo();

        expect(roleInfo, isNotEmpty);
        expect(roleInfo.containsKey('isAdmin'), true);
        expect(roleInfo.containsKey('isPremium'), true);
        expect(roleInfo.containsKey('isAuthenticated'), true);
      });
    });

    group('Notification Behavior', () {
      test('should have listener support', () {
        var listenerCalled = false;
        platformCategoryFilter.addListener(() {
          listenerCalled = true;
        });

        // Verify listener was added
        expect(listenerCalled, false); // Not called yet

        // Trigger a notification
        platformCategoryFilter.notifyListeners();

        // Listener should have been called
        expect(listenerCalled, true);
      });
    });

    group('Edge Cases', () {
      test('should handle empty category list', () async {
        final visibleCategories =
            await platformCategoryFilter.getVisibleCategories([]);

        expect(visibleCategories, isEmpty);
      });

      test('should handle null admin center service', () async {
        final mockAuth = _MockAuthService();
        final filter = PlatformCategoryFilter(
          authService: mockAuth,
          adminCenterService: null,
        );

        final isAdmin = await filter.isAdminUser();

        expect(isAdmin, false);

        filter.dispose();
        mockAuth.dispose();
      });

      test('should handle rapid category visibility checks', () async {
        final futures = [
          platformCategoryFilter.isCategoryVisible(
            SettingsCategoryIds.general,
          ),
          platformCategoryFilter.isCategoryVisible(
            SettingsCategoryIds.account,
          ),
          platformCategoryFilter.isCategoryVisible(
            SettingsCategoryIds.adminCenter,
          ),
        ];

        final results = await Future.wait(futures);

        expect(results.length, 3);
        expect(results[0], true); // general
        expect(results[1], true); // account
        expect(results[2], false); // admin center (not admin)
      });
    });
  });

  group('CategoryVisibilityRules', () {
    group('Platform Visibility', () {
      test('should show general category on all platforms', () {
        expect(
          CategoryVisibilityRules.isVisibleOnPlatform(
            SettingsCategoryIds.general,
            isWeb: true,
            isWindows: false,
            isLinux: false,
            isAndroid: false,
            isIOS: false,
          ),
          true,
        );

        expect(
          CategoryVisibilityRules.isVisibleOnPlatform(
            SettingsCategoryIds.general,
            isWeb: false,
            isWindows: true,
            isLinux: false,
            isAndroid: false,
            isIOS: false,
          ),
          true,
        );
      });

      test('should show desktop category only on desktop platforms', () {
        expect(
          CategoryVisibilityRules.isVisibleOnPlatform(
            SettingsCategoryIds.desktop,
            isWeb: false,
            isWindows: true,
            isLinux: false,
            isAndroid: false,
            isIOS: false,
          ),
          true,
        );

        expect(
          CategoryVisibilityRules.isVisibleOnPlatform(
            SettingsCategoryIds.desktop,
            isWeb: true,
            isWindows: false,
            isLinux: false,
            isAndroid: false,
            isIOS: false,
          ),
          false,
        );

        expect(
          CategoryVisibilityRules.isVisibleOnPlatform(
            SettingsCategoryIds.desktop,
            isWeb: false,
            isWindows: false,
            isLinux: false,
            isAndroid: true,
            isIOS: false,
          ),
          false,
        );
      });

      test('should show mobile category only on mobile platforms', () {
        expect(
          CategoryVisibilityRules.isVisibleOnPlatform(
            SettingsCategoryIds.mobile,
            isWeb: false,
            isWindows: false,
            isLinux: false,
            isAndroid: true,
            isIOS: false,
          ),
          true,
        );

        expect(
          CategoryVisibilityRules.isVisibleOnPlatform(
            SettingsCategoryIds.mobile,
            isWeb: false,
            isWindows: true,
            isLinux: false,
            isAndroid: false,
            isIOS: false,
          ),
          false,
        );
      });
    });

    group('User Role Visibility', () {
      test('should show admin center only for admin users', () {
        expect(
          CategoryVisibilityRules.isVisibleForUserRole(
            categoryId: SettingsCategoryIds.adminCenter,
            isAdminUser: true,
            isPremiumUser: false,
          ),
          true,
        );

        expect(
          CategoryVisibilityRules.isVisibleForUserRole(
            categoryId: SettingsCategoryIds.adminCenter,
            isAdminUser: false,
            isPremiumUser: false,
          ),
          false,
        );
      });

      test('should show premium features only for premium users', () {
        expect(
          CategoryVisibilityRules.isVisibleForUserRole(
            categoryId: SettingsCategoryIds.premiumFeatures,
            isAdminUser: false,
            isPremiumUser: true,
          ),
          true,
        );

        expect(
          CategoryVisibilityRules.isVisibleForUserRole(
            categoryId: SettingsCategoryIds.premiumFeatures,
            isAdminUser: false,
            isPremiumUser: false,
          ),
          false,
        );
      });

      test('should show general categories for all users', () {
        expect(
          CategoryVisibilityRules.isVisibleForUserRole(
            categoryId: SettingsCategoryIds.general,
            isAdminUser: false,
            isPremiumUser: false,
          ),
          true,
        );

        expect(
          CategoryVisibilityRules.isVisibleForUserRole(
            categoryId: SettingsCategoryIds.general,
            isAdminUser: true,
            isPremiumUser: true,
          ),
          true,
        );
      });
    });
  });
}
