import 'package:cloudtolocalllm/services/connection_manager_service.dart';
import 'package:cloudtolocalllm/services/hermes_manager/hermes_gateway_control_service.dart';
import 'package:cloudtolocalllm/services/openclaw_manager/gateway_control_service.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart'
    hide BackendType;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ConnectionManagerService runtime session', () {
    late ConnectionManagerService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = ConnectionManagerService(
        openclawGatewayService: GatewayControlService(
          SettingsPreferenceService(),
        ),
        hermesGatewayService: HermesGatewayControlService(),
        settingsPreferenceService: SettingsPreferenceService(),
        autoDetectOnInitialize: false,
      );
      await service.initialize();
    });

    tearDown(() {
      service.dispose();
    });

    test('does not assume OpenClaw before a runtime is selected', () {
      expect(service.activeBackend, isNull);
      expect(service.preferredConnectionType, isNull);
      expect(service.getStreamingService(), isNull);
      expect(service.isGatewayHealthy(), isFalse);
    });

    test('Hermes selection exposes the runtime streaming service', () {
      service.configureHermesRuntime(url: 'http://127.0.0.1:8642');
      service.setPreferredConnectionType(ConnectionType.hermes);

      expect(service.activeBackend, BackendType.hermes);
      expect(service.preferredConnectionType, 'hermes');
      expect(service.getStreamingService(), isNotNull);
    });

    test(
        'legacy local selection clears the runtime instead of selecting a model provider',
        () {
      service.configureHermesRuntime(url: 'http://127.0.0.1:8642');
      service.setPreferredConnectionType(ConnectionType.hermes);

      service.setPreferredConnectionType(ConnectionType.local);

      expect(service.activeBackend, isNull);
      expect(service.getStreamingService(), isNull);
    });
  });
}
