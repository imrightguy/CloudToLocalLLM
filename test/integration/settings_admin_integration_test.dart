import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zoidbot/services/settings_preference_service.dart';
import 'package:zoidbot/services/provider_configuration_manager.dart';
import 'package:zoidbot/models/provider_configuration.dart';
import '../test_config.dart';

void main() {
  group('Settings Admin and Provider Integration Tests', () {
    late SettingsPreferenceService settingsService;
    late ProviderConfigurationManager providerManager;

    setUp(() async {
      TestConfig.initialize();
      SharedPreferences.setMockInitialValues({});
      settingsService = SettingsPreferenceService();
      providerManager = ProviderConfigurationManager();
    });

    tearDown(() async {
      TestConfig.cleanup();
    });

    group('Provider Configuration Manager Integration', () {
      test('should initialize provider manager', () async {
        await providerManager.initialize();
        expect(providerManager.isInitialized, true);
      });

      test('should add and retrieve Ollama provider configuration', () async {
        await providerManager.initialize();

        // Create Ollama provider configuration
        final config = OllamaProviderConfiguration(
          providerId: 'ollama_local',
          baseUrl: 'http://localhost',
          port: 11434,
        );

        await providerManager.setConfiguration(config);
        final provider = providerManager.getConfiguration('ollama_local');

        expect(provider, isNotNull);
        expect(provider?.providerId, 'ollama_local');
        expect(provider?.providerType, 'ollama');
      });

      test('should set preferred provider', () async {
        await providerManager.initialize();

        // Create and set provider
        final config = OllamaProviderConfiguration(
          providerId: 'ollama_local',
          baseUrl: 'http://localhost',
          port: 11434,
        );

        await providerManager.setConfiguration(config);
        await providerManager.setPreferredProvider('ollama_local');

        expect(providerManager.preferredProviderId, 'ollama_local');
      });

      test('should remove provider configuration', () async {
        await providerManager.initialize();

        // Add provider
        final config = OllamaProviderConfiguration(
          providerId: 'ollama_local',
          baseUrl: 'http://localhost',
          port: 11434,
        );

        await providerManager.setConfiguration(config);
        var providers = providerManager.configurations;
        expect(providers.any((p) => p.providerId == 'ollama_local'), true);

        // Remove provider
        await providerManager.removeConfiguration('ollama_local');
        providers = providerManager.configurations;
        expect(providers.any((p) => p.providerId == 'ollama_local'), false);
      });

      test('should support multiple providers', () async {
        await providerManager.initialize();

        // Add multiple providers
        final ollamaConfig = OllamaProviderConfiguration(
          providerId: 'ollama_local',
          baseUrl: 'http://localhost',
          port: 11434,
        );

        final lmStudioConfig = LMStudioProviderConfiguration(
          providerId: 'lm_studio_local',
          baseUrl: 'http://localhost',
          port: 1234,
        );

        await providerManager.setConfiguration(ollamaConfig);
        await providerManager.setConfiguration(lmStudioConfig);

        final providers = providerManager.configurations;
        expect(providers.length, greaterThanOrEqualTo(2));
        expect(providers.any((p) => p.providerId == 'ollama_local'), true);
        expect(providers.any((p) => p.providerId == 'lm_studio_local'), true);
      });

      test('should persist provider configuration across restarts', () async {
        await providerManager.initialize();

        // Add provider
        final config = OllamaProviderConfiguration(
          providerId: 'ollama_local',
          baseUrl: 'http://localhost',
          port: 11434,
        );

        await providerManager.setConfiguration(config);

        // Simulate service restart
        final newManager = ProviderConfigurationManager();
        await newManager.initialize();
        final provider = newManager.getConfiguration('ollama_local');

        expect(provider, isNotNull);
        expect(provider?.providerId, 'ollama_local');
      });
    });

    group('Settings and Provider Manager Integration', () {
      test('should coordinate settings and provider configuration', () async {
        await providerManager.initialize();

        // Set general settings
        await settingsService.setTheme('dark');
        await settingsService.setLanguage('es');

        // Add provider
        final config = OllamaProviderConfiguration(
          providerId: 'ollama_local',
          baseUrl: 'http://localhost',
          port: 11434,
        );

        await providerManager.setConfiguration(config);
        await providerManager.setPreferredProvider('ollama_local');

        // Verify both are persisted
        expect(await settingsService.getTheme(), 'dark');
        expect(await settingsService.getLanguage(), 'es');
        expect(providerManager.preferredProviderId, 'ollama_local');
      });

      test('should handle concurrent settings and provider updates', () async {
        await providerManager.initialize();

        final config = OllamaProviderConfiguration(
          providerId: 'ollama_local',
          baseUrl: 'http://localhost',
          port: 11434,
        );

        final futures = [
          settingsService.setTheme('dark'),
          settingsService.setLanguage('es'),
          settingsService.setAnalyticsEnabled(false),
          providerManager.setConfiguration(config),
        ];

        await Future.wait(futures);

        // Verify all operations completed
        expect(await settingsService.getTheme(), 'dark');
        expect(await settingsService.getLanguage(), 'es');
        expect(await settingsService.isAnalyticsEnabled(), false);

        final providers = providerManager.configurations;
        expect(providers.any((p) => p.providerId == 'ollama_local'), true);
      });
    });

    group('Cross-Platform Settings Compatibility', () {
      test('should maintain compatible settings across platforms', () async {
        // Set general settings that should work on all platforms
        await settingsService.setTheme('dark');
        await settingsService.setLanguage('en');
        await settingsService.setAnalyticsEnabled(false);

        // Verify settings are accessible
        expect(await settingsService.getTheme(), 'dark');
        expect(await settingsService.getLanguage(), 'en');
        expect(await settingsService.isAnalyticsEnabled(), false);
      });

      test('should handle platform-specific settings gracefully', () async {
        // Desktop settings should be accessible on all platforms
        await settingsService.setLaunchOnStartupEnabled(true);
        await settingsService.setMinimizeToTrayEnabled(true);
        await settingsService.setAlwaysOnTopEnabled(true);

        expect(await settingsService.isLaunchOnStartupEnabled(), true);
        expect(await settingsService.isMinimizeToTrayEnabled(), true);
        expect(await settingsService.isAlwaysOnTopEnabled(), true);

        // Mobile settings should be accessible on all platforms
        await settingsService.setBiometricAuthEnabled(true);
        await settingsService.setNotificationsEnabled(false);

        expect(await settingsService.isBiometricAuthEnabled(), true);
        expect(await settingsService.isNotificationsEnabled(), false);
      });

      test('should preserve settings when switching between platforms',
          () async {
        // Set various settings
        await settingsService.setTheme('dark');
        await settingsService.setLanguage('es');
        await settingsService.setAnalyticsEnabled(false);
        await settingsService.setLaunchOnStartupEnabled(true);

        // Simulate platform switch by creating new service instance
        final newService = SettingsPreferenceService();

        // Verify all settings are preserved
        expect(await newService.getTheme(), 'dark');
        expect(await newService.getLanguage(), 'es');
        expect(await newService.isAnalyticsEnabled(), false);
        expect(await newService.isLaunchOnStartupEnabled(), true);
      });
    });

    group('Settings Persistence and Recovery', () {
      test('should recover from partial data loss', () async {
        // Set multiple settings
        await settingsService.setTheme('dark');
        await settingsService.setLanguage('es');
        await settingsService.setAnalyticsEnabled(false);

        // Simulate service restart
        final newService = SettingsPreferenceService();

        // Verify recovery
        expect(await newService.getTheme(), 'dark');
        expect(await newService.getLanguage(), 'es');
        expect(await newService.isAnalyticsEnabled(), false);

        // Unset settings should have defaults
        expect(await newService.isLaunchOnStartupEnabled(), false);
      });

      test('should handle corrupted settings gracefully', () async {
        // Set valid settings
        await settingsService.setTheme('dark');

        // Try to set invalid settings (should throw)
        expect(
          () => settingsService.setTheme('invalid'),
          throwsA(isA<ArgumentError>()),
        );

        // Valid settings should still be intact
        expect(await settingsService.getTheme(), 'dark');
      });

      test('should maintain data consistency across operations', () async {
        await providerManager.initialize();

        // Perform multiple operations
        await settingsService.setTheme('dark');
        await settingsService.setLanguage('es');

        final config = OllamaProviderConfiguration(
          providerId: 'ollama_local',
          baseUrl: 'http://localhost',
          port: 11434,
        );

        await providerManager.setConfiguration(config);

        // Verify consistency
        expect(await settingsService.getTheme(), 'dark');
        expect(await settingsService.getLanguage(), 'es');

        final provider = providerManager.getConfiguration('ollama_local');
        expect(provider, isNotNull);
      });
    });

    group('Provider Configuration Validation', () {
      test('should validate provider configuration', () async {
        await providerManager.initialize();

        final validConfig = OllamaProviderConfiguration(
          providerId: 'ollama_local',
          baseUrl: 'http://localhost',
          port: 11434,
        );

        // Should not throw for valid config
        await providerManager.setConfiguration(validConfig);
        final provider = providerManager.getConfiguration('ollama_local');
        expect(provider, isNotNull);
      });

      test('should handle provider configuration updates', () async {
        await providerManager.initialize();

        final initialConfig = OllamaProviderConfiguration(
          providerId: 'ollama_local',
          baseUrl: 'http://localhost',
          port: 11434,
        );

        await providerManager.setConfiguration(initialConfig);

        // Update configuration
        final updatedConfig = OllamaProviderConfiguration(
          providerId: 'ollama_local',
          baseUrl: 'http://192.168.1.100',
          port: 11434,
        );

        await providerManager.setConfiguration(updatedConfig);

        final provider = providerManager.getConfiguration('ollama_local');
        expect(provider?.baseUrl, 'http://192.168.1.100');
      });
    });

    group('Error Handling and Recovery', () {
      test('should handle provider manager errors gracefully', () async {
        await providerManager.initialize();

        try {
          // Try to get non-existent provider
          final provider = providerManager.getConfiguration('non_existent');
          expect(provider, isNull);
        } catch (e) {
          fail('Should not throw: $e');
        }
      });

      test('should handle settings service errors gracefully', () async {
        try {
          // Try to set invalid theme
          await settingsService.setTheme('invalid');
          fail('Should throw ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
        }
      });

      test('should maintain consistency after errors', () async {
        // Set valid setting
        await settingsService.setTheme('dark');

        // Try invalid operation
        try {
          await settingsService.setTheme('invalid');
        } catch (e) {
          // Expected
        }

        // Valid setting should still be intact
        expect(await settingsService.getTheme(), 'dark');
      });
    });

    group('End-to-End Settings Flow', () {
      test('should complete full settings configuration workflow', () async {
        await providerManager.initialize();

        // 1. Set general preferences
        await settingsService.setTheme('dark');
        await settingsService.setLanguage('es');

        // 2. Configure privacy settings
        await settingsService.setAnalyticsEnabled(false);
        await settingsService.setCrashReportingEnabled(false);

        // 3. Configure desktop settings
        await settingsService.setLaunchOnStartupEnabled(true);
        await settingsService.setAlwaysOnTopEnabled(true);

        // 4. Add and configure providers
        final ollamaConfig = OllamaProviderConfiguration(
          providerId: 'ollama_local',
          baseUrl: 'http://localhost',
          port: 11434,
        );

        await providerManager.setConfiguration(ollamaConfig);
        await providerManager.setPreferredProvider('ollama_local');

        // 5. Verify all settings are persisted
        expect(await settingsService.getTheme(), 'dark');
        expect(await settingsService.getLanguage(), 'es');
        expect(await settingsService.isAnalyticsEnabled(), false);
        expect(await settingsService.isCrashReportingEnabled(), false);
        expect(await settingsService.isLaunchOnStartupEnabled(), true);
        expect(await settingsService.isAlwaysOnTopEnabled(), true);
        expect(providerManager.preferredProviderId, 'ollama_local');
      });

      test('should restore full settings configuration after restart',
          () async {
        await providerManager.initialize();

        // Set comprehensive configuration
        await settingsService.setTheme('dark');
        await settingsService.setLanguage('es');
        await settingsService.setAnalyticsEnabled(false);
        await settingsService.setLaunchOnStartupEnabled(true);

        final config = OllamaProviderConfiguration(
          providerId: 'ollama_local',
          baseUrl: 'http://localhost',
          port: 11434,
        );

        await providerManager.setConfiguration(config);
        await providerManager.setPreferredProvider('ollama_local');

        // Simulate restart
        final newSettingsService = SettingsPreferenceService();
        final newProviderManager = ProviderConfigurationManager();
        await newProviderManager.initialize();

        // Verify all settings restored
        expect(await newSettingsService.getTheme(), 'dark');
        expect(await newSettingsService.getLanguage(), 'es');
        expect(await newSettingsService.isAnalyticsEnabled(), false);
        expect(await newSettingsService.isLaunchOnStartupEnabled(), true);
        expect(newProviderManager.preferredProviderId, 'ollama_local');
      });
    });
  });
}
