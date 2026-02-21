import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/models/user_setup_status.dart';

void main() {
  group('SetupStatusService', () {
    // Note: Full service tests would require mocking AuthService and storage
    // For now, we'll focus on testing the models and basic functionality
  });

  group('UserSetupStatus', () {
    test('should create new user status', () {
      const userId = 'test-user-123';
      final status = UserSetupStatus.newUser(userId);

      expect(status.userId, userId);
      expect(status.isFirstTimeUser, true);
      expect(status.setupCompleted, false);
      expect(status.requiresSetup, true);
      expect(status.hasActiveDesktopConnection, false);
      expect(status.setupVersion, '1.0.0');
      expect(status.preferences, isEmpty);
    });

    test('should create completed setup status', () {
      const userId = 'test-user-123';
      final status = UserSetupStatus.completed(
        userId,
        hasActiveDesktopConnection: true,
        preferences: {'theme': 'dark'},
      );

      expect(status.userId, userId);
      expect(status.isFirstTimeUser, false);
      expect(status.setupCompleted, true);
      expect(status.requiresSetup, false);
      expect(status.hasActiveDesktopConnection, true);
      expect(status.setupCompletedAt, isNotNull);
      expect(status.preferences['theme'], 'dark');
    });

    test('should detect recently completed setup', () {
      const userId = 'test-user-123';
      final status = UserSetupStatus.completed(userId);

      expect(status.isRecentlyCompleted, true);
    });

    test('should handle preferences correctly', () {
      final status = UserSetupStatus.newUser('test-user');
      final updatedStatus = status.copyWith(
        preferences: {'theme': 'dark', 'language': 'en', 'notifications': true},
      );

      expect(updatedStatus.getPreference<String>('theme'), 'dark');
      expect(updatedStatus.getPreference<String>('language'), 'en');
      expect(updatedStatus.getPreference<bool>('notifications'), true);
      expect(
        updatedStatus.getPreference<String>('unknown', 'default'),
        'default',
      );
      expect(updatedStatus.hasPreference('theme'), true);
      expect(updatedStatus.hasPreference('unknown'), false);
    });

    test('should convert to/from JSON correctly', () {
      final original = UserSetupStatus.completed(
        'test-user-123',
        hasActiveDesktopConnection: true,
        preferences: {'theme': 'dark', 'language': 'en'},
      );

      final json = original.toJson();
      final restored = UserSetupStatus.fromJson(json);

      expect(restored.userId, original.userId);
      expect(restored.isFirstTimeUser, original.isFirstTimeUser);
      expect(restored.setupCompleted, original.setupCompleted);
      expect(
        restored.hasActiveDesktopConnection,
        original.hasActiveDesktopConnection,
      );
      expect(restored.preferences, original.preferences);
      expect(restored.setupVersion, original.setupVersion);
    });

    test('should validate setup status correctly', () {
      final validStatus = UserSetupStatus.completed('test-user');
      expect(validStatus.isValid, true);
      expect(validStatus.validationErrors, isEmpty);

      final invalidStatus = UserSetupStatus(
        userId: '', // Invalid empty userId
        isFirstTimeUser: false,
        setupCompleted: true,
        setupCompletedAt: null, // Invalid: completed but no timestamp
        lastUpdated: DateTime.now(),
        hasActiveDesktopConnection: false,
        setupVersion: '', // Invalid empty version
        preferences: {},
      );

      expect(invalidStatus.isValid, false);
      expect(invalidStatus.validationErrors, isNotEmpty);
      expect(
        invalidStatus.validationErrors.length,
        3,
      ); // userId, setupCompletedAt, setupVersion
    });

    test('should create status summary correctly', () {
      final status = UserSetupStatus.completed(
        'test-user-123',
        preferences: {'theme': 'dark'},
      );

      final summary = status.statusSummary;

      expect(summary['userId'], 'test-user-123');
      expect(summary['isFirstTimeUser'], false);
      expect(summary['setupCompleted'], true);
      expect(summary['requiresSetup'], false);
      expect(summary['preferenceCount'], 1);
      expect(summary['setupVersion'], '1.0.0');
      expect(summary.containsKey('lastUpdated'), true);
      expect(summary.containsKey('setupCompletedAt'), true);
    });

    test('should handle copyWith correctly', () {
      final original = UserSetupStatus.newUser('test-user');
      final updated = original.copyWith(
        setupCompleted: true,
        setupCompletedAt: DateTime.now(),
        hasActiveDesktopConnection: true,
        preferences: {'theme': 'dark'},
      );

      expect(updated.userId, original.userId); // Unchanged
      expect(updated.isFirstTimeUser, original.isFirstTimeUser); // Unchanged
      expect(updated.setupCompleted, true); // Changed
      expect(updated.hasActiveDesktopConnection, true); // Changed
      expect(updated.preferences['theme'], 'dark'); // Changed
      expect(updated.setupCompletedAt, isNotNull); // Changed
    });

    test('should use extension methods correctly', () {
      final status = UserSetupStatus.newUser('test-user').copyWith(
        preferences: {
          'preferredPlatform': 'windows',
          'skippedValidation': true,
          'showAdvancedOptions': false,
          'language': 'es',
          'analyticsEnabled': false,
        },
      );

      expect(status.preferredPlatform, 'windows');
      expect(status.hasSkippedValidation, true);
      expect(status.showAdvancedOptions, false);
      expect(status.preferredLanguage, 'es');
      expect(status.analyticsEnabled, false);
    });

    test('should handle extension method defaults correctly', () {
      final status = UserSetupStatus.newUser('test-user');

      expect(status.preferredPlatform, isNull);
      expect(status.hasSkippedValidation, false); // Default
      expect(status.showAdvancedOptions, false); // Default
      expect(status.preferredLanguage, 'en'); // Default
      expect(status.analyticsEnabled, true); // Default
    });
  });
}
