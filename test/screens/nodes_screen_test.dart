import 'package:cloudtolocalllm/models/provider_configuration.dart';
import 'package:cloudtolocalllm/screens/nodes/nodes_screen.dart';
import 'package:cloudtolocalllm/services/connection_manager_service.dart';
import 'package:cloudtolocalllm/services/hermes_manager/hermes_gateway_control_service.dart';
import 'package:cloudtolocalllm/services/openclaw_manager/gateway_control_service.dart';
import 'package:cloudtolocalllm/services/provider_discovery_service.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectionManagerService connectionManager;
  late _FakeProviderDiscoveryService discoveryService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    connectionManager = ConnectionManagerService(
      openclawGatewayService: GatewayControlService(
        SettingsPreferenceService(),
      ),
      hermesGatewayService: HermesGatewayControlService(),
      settingsPreferenceService: SettingsPreferenceService(),
      autoDetectOnInitialize: false,
    );
    discoveryService = _FakeProviderDiscoveryService();
  });

  tearDown(() {
    connectionManager.dispose();
  });

  // TODO(zoidbot): Re-enable once NodesScreen integrates ProviderDiscoveryService.
  // Current NodesScreen implementation is a stub with hardcoded data and does not
  // consume ProviderDiscoveryService from the widget tree. These tests are the
  // spec for the intended implementation. Also requires PopOutManager GetIt registration.
  testWidgets('renders discovered runtimes and tailnet devices',
      skip: true,
      (WidgetTester tester) async {
    discoveryService.providers = <ProviderInfo>[
      ProviderInfo(
        id: 'hermes-1',
        name: 'Hermes Agent',
        type: ProviderType.hermes,
        url: 'http://127.0.0.1:8642',
        isAvailable: true,
        version: '1.2.3',
        availableModels: const ['hermes-3'],
        role: ProviderRole.agentRuntime,
      ),
      ProviderInfo(
        id: 'ollama-1',
        name: 'Ollama',
        type: ProviderType.ollama,
        url: 'http://127.0.0.1:11434',
        isAvailable: true,
        version: '0.1.0',
        availableModels: const ['llama3.1', 'qwen2.5'],
        role: ProviderRole.supportModelProvider,
      ),
    ];
    discoveryService.tailnetDevices = <TailscaleDevice>[
      TailscaleDevice(
        name: 'builder-1',
        hostname: 'builder-1.tailnet.local',
        ips: const ['100.64.0.10'],
        isOnline: true,
      ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProviderDiscoveryService>.value(value: discoveryService),
          ChangeNotifierProvider<ConnectionManagerService>.value(
            value: connectionManager,
          ),
        ],
        child: const MaterialApp(home: NodesScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Hermes Agent'), findsOneWidget);
    expect(find.text('Ollama'), findsOneWidget);
    expect(find.text('builder-1'), findsOneWidget);
    expect(find.text('No agent runtime selected'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Add Node'), findsNothing);
  });

  testWidgets('renders empty states when discovery finds nothing',
      skip: true,
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProviderDiscoveryService>.value(value: discoveryService),
          ChangeNotifierProvider<ConnectionManagerService>.value(
            value: connectionManager,
          ),
        ],
        child: const MaterialApp(home: NodesScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No agent runtimes discovered'), findsOneWidget);
    expect(find.text('No support providers discovered'), findsOneWidget);
    expect(find.text('No Tailscale devices discovered'), findsOneWidget);
  });

  testWidgets('surfaces discovery errors',
      skip: true,
      (WidgetTester tester) async {
    discoveryService.providersError = StateError('boom');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProviderDiscoveryService>.value(value: discoveryService),
          ChangeNotifierProvider<ConnectionManagerService>.value(
            value: connectionManager,
          ),
        ],
        child: const MaterialApp(home: NodesScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load discovery data'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
  });
}

class _FakeProviderDiscoveryService extends ProviderDiscoveryService {
  Object? providersError;
  Object? tailscaleError;
  List<ProviderInfo> providers = <ProviderInfo>[];
  List<TailscaleDevice> tailnetDevices = <TailscaleDevice>[];

  @override
  Future<List<ProviderInfo>> scanForProviders() async {
    if (providersError != null) {
      throw providersError!;
    }
    return providers;
  }

  @override
  Future<List<TailscaleDevice>> discoverTailscaleDevices() async {
    if (tailscaleError != null) {
      throw tailscaleError!;
    }
    return tailnetDevices;
  }
}
