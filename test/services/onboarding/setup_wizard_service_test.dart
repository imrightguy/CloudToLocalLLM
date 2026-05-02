import 'package:cloudtolocalllm/models/provider_configuration.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/services/onboarding/setup_wizard_service.dart';
import 'package:cloudtolocalllm/services/provider_configuration_manager.dart';
import 'package:cloudtolocalllm/services/provider_discovery_service.dart';
import 'package:cloudtolocalllm/services/setup_status_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SetupWizardService P0-1 hardening', () {
    late _FakeProviderDiscoveryService discovery;
    late _FakeSetupStatusService setupStatus;
    late _FakeProviderConfigurationManager configManager;
    late SetupWizardService service;

    setUp(() {
      discovery = _FakeProviderDiscoveryService();
      setupStatus = _FakeSetupStatusService();
      configManager = _FakeProviderConfigurationManager();
      service = SetupWizardService(discovery, setupStatus, configManager);
    });

    test('provider scan failure maps message and resets loading', () async {
      discovery.scanError = Exception('socket timeout details');

      await service.scanForProviders();

      expect(service.state.isLoading, isFalse);
      expect(
        service.state.errorMessage,
        'Could not scan for providers. Make sure local services are running and try again.',
      );
      expect(service.state.errorMessage, isNot(contains('socket timeout')));
    });

    test('tailscale discovery failure maps message and resets loading',
        () async {
      discovery.tailscaleError = Exception('tailscale command failed');

      await service.discoverTailscaleDevices();

      expect(service.state.isLoading, isFalse);
      expect(
        service.state.errorMessage,
        'Could not discover Tailscale devices. Make sure Tailscale is running and authenticated, then try again.',
      );
      expect(service.state.errorMessage, isNot(contains('command failed')));
    });

    test('complete setup validation failure is deterministic and not loading',
        () async {
      final bool success = await service.completeSetup();

      expect(success, isFalse);
      expect(service.state.isLoading, isFalse);
      expect(
        service.state.errorMessage,
        'Select an agent runtime before completing setup.',
      );
    });

    test('complete setup persistence failure is deterministic and not loading',
        () async {
      service.selectProvider(_customRuntimeProvider());
      configManager.throwOnSave = true;

      final bool success = await service.completeSetup();

      expect(success, isFalse);
      expect(service.state.isLoading, isFalse);
      expect(
        service.state.errorMessage,
        'Setup could not be completed right now. Please verify your settings and try again.',
      );
    });

    test('invalid custom URL is rejected before persistence', () async {
      service.selectProvider(_customRuntimeProvider());
      service.setCustomUrl('not-a-valid-url');

      final bool success = await service.completeSetup();

      expect(success, isFalse);
      expect(service.state.isLoading, isFalse);
      expect(
        service.state.errorMessage,
        'Enter a valid custom URL that starts with http:// or https://.',
      );
      expect(configManager.saveProviderCallCount, 0);
    });

    test('blank custom URL is rejected before persistence in custom mode',
        () async {
      service.selectConnectionMethod(ConnectionMethod.custom);
      service.selectProvider(_customRuntimeProvider());
      service.setCustomUrl('   ');

      final bool success = await service.completeSetup();

      expect(success, isFalse);
      expect(service.state.isLoading, isFalse);
      expect(
        service.state.errorMessage,
        'Enter a valid custom URL that starts with http:// or https://.',
      );
      expect(configManager.saveProviderCallCount, 0);
    });

    test('stale custom URL does not block Hermes runtime completion', () async {
      service.selectConnectionMethod(ConnectionMethod.custom);
      service.selectProvider(_customRuntimeProvider());
      service.setCustomUrl('not-a-valid-url');

      service.selectConnectionMethod(ConnectionMethod.hermes);
      service.setHermesUrl('http://127.0.0.1:8642');

      final bool success = await service.completeSetup();

      expect(success, isTrue);
      expect(service.state.isLoading, isFalse);
      expect(service.state.errorMessage, isNull);
      expect(configManager.saveProviderCallCount, 1);
      expect(configManager.lastSavedUrl, 'http://127.0.0.1:8642');
    });

    test('local model provider cannot complete runtime setup', () async {
      service.selectConnectionMethod(ConnectionMethod.local);
      service.selectProvider(_localProvider());

      final bool success = await service.completeSetup();

      expect(success, isFalse);
      expect(service.state.isLoading, isFalse);
      expect(
        service.state.errorMessage,
        'Ollama, LM Studio, and raw model providers are support model providers. Select Hermes, OpenClaw, or a compatible agent runtime to complete setup.',
      );
      expect(configManager.saveProviderCallCount, 0);
    });

    test('provider scan selects Hermes before OpenClaw and excludes support',
        () async {
      discovery.runtimeProviders = [
        _openClawRuntimeProvider(),
        _hermesRuntimeProvider(),
      ];

      await service.scanForProviders();

      expect(service.state.discoveredProviders, hasLength(2));
      expect(service.state.selectedProvider?.type, ProviderType.hermes);
    });
  });
}

ProviderInfo _customRuntimeProvider() {
  return const ProviderInfo(
    id: 'custom_provider',
    name: 'Custom Runtime',
    type: ProviderType.custom,
    url: 'https://example.com',
    isLocal: false,
    isAvailable: true,
    role: ProviderRole.agentRuntime,
  );
}

ProviderInfo _localProvider() {
  return const ProviderInfo(
    id: 'local_lm_studio',
    name: 'LM Studio',
    type: ProviderType.lmStudio,
    url: 'http://127.0.0.1:1234',
    isLocal: true,
    isAvailable: true,
    role: ProviderRole.supportModelProvider,
  );
}

ProviderInfo _openClawRuntimeProvider() {
  return const ProviderInfo(
    id: 'openclaw_runtime',
    name: 'OpenClaw Gateway',
    type: ProviderType.openclaw,
    url: 'http://127.0.0.1:18789',
    isLocal: true,
    isAvailable: true,
    role: ProviderRole.agentRuntime,
  );
}

ProviderInfo _hermesRuntimeProvider() {
  return const ProviderInfo(
    id: 'hermes_runtime',
    name: 'Hermes Agent',
    type: ProviderType.hermes,
    url: 'http://127.0.0.1:8642',
    isLocal: true,
    isAvailable: true,
    role: ProviderRole.agentRuntime,
  );
}

class _FakeProviderDiscoveryService extends ProviderDiscoveryService {
  Object? scanError;
  Object? tailscaleError;
  List<ProviderInfo> runtimeProviders = <ProviderInfo>[];

  @override
  Future<List<ProviderInfo>> scanForAgentRuntimes() async {
    if (scanError != null) {
      throw scanError!;
    }
    return runtimeProviders;
  }

  @override
  Future<List<TailscaleDevice>> discoverTailscaleDevices() async {
    if (tailscaleError != null) {
      throw tailscaleError!;
    }
    return <TailscaleDevice>[];
  }
}

class _FakeProviderConfigurationManager extends ProviderConfigurationManager {
  bool throwOnSave = false;
  int saveProviderCallCount = 0;
  String? lastSavedUrl;

  @override
  Future<void> saveProvider({
    required String name,
    required ProviderType type,
    required String url,
    required bool isLocal,
    bool isDefault = false,
    String? version,
    ProviderRole? role,
  }) async {
    saveProviderCallCount += 1;
    lastSavedUrl = url;
    if (throwOnSave) {
      throw Exception('save failed');
    }
  }

  @override
  Future<List<ProviderInfo>> getAllProviders() async {
    return <ProviderInfo>[];
  }
}

class _FakeSetupStatusService extends SetupStatusService {
  _FakeSetupStatusService()
      : super(
          authService: _FakeAuthService(),
          storage: InMemorySetupStatusStorage(),
        );

  @override
  Future<void> markSetupComplete(String userId) async {}
}

class _FakeAuthService extends ChangeNotifier implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
