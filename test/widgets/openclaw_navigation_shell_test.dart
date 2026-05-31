import 'package:cloudtolocalllm/di/locator.dart' as di;
import 'package:cloudtolocalllm/models/instance.dart';
import 'package:cloudtolocalllm/screens/instances/instances_screen.dart';
import 'package:cloudtolocalllm/services/connection_manager_service.dart';
import 'package:cloudtolocalllm/services/hermes_manager/hermes_gateway_control_service.dart';
import 'package:cloudtolocalllm/services/openclaw_manager/gateway_control_service.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';
import 'package:cloudtolocalllm/widgets/navigation/openclaw_navigation_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNavigationConnectionManager extends ConnectionManagerService {
  _FakeNavigationConnectionManager()
      : super(
          openclawGatewayService: GatewayControlService(
            SettingsPreferenceService(),
          ),
          hermesGatewayService: HermesGatewayControlService(),
        );

  @override
  Future<bool> testConnection() async => true;

  @override
  Map<String, dynamic> getGatewayStatus() => <String, dynamic>{
        'state': 'connected',
        'isRunning': true,
        'isConnected': true,
        'backend': 'hermes',
        'backendLabel': 'Hermes Agent',
      };

  @override
  bool isGatewayHealthy() => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  late _FakeNavigationConnectionManager connectionManager;

  setUp(() {
    connectionManager = _FakeNavigationConnectionManager();
    if (di.serviceLocator.isRegistered<ConnectionManagerService>()) {
      di.serviceLocator.unregister<ConnectionManagerService>();
    }
    di.serviceLocator.registerSingleton<ConnectionManagerService>(
      connectionManager,
    );
  });

  tearDown(() async {
    if (di.serviceLocator.isRegistered<ConnectionManagerService>()) {
      di.serviceLocator.unregister<ConnectionManagerService>();
    }
    connectionManager.dispose();
  });

  testWidgets('OpenClawNavigationShell exposes the management shell labels',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/instances',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MultiProvider(
              providers: [
                ChangeNotifierProvider<ConnectionManagerService>.value(
                  value: connectionManager,
                ),
              ],
              child: OpenClawNavigationShell(navigationShell: navigationShell),
            );
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/chat',
                  builder: (context, state) => const Scaffold(
                    body: Text('Chat placeholder'),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/overview',
                  builder: (context, state) => const Scaffold(
                    body: Text('Overview placeholder'),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/channels',
                  builder: (context, state) => const Scaffold(
                    body: Text('Channels placeholder'),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/instances',
                  builder: (context, state) => const InstancesScreen(
                    loadInstancesData: _loadInstancesData,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Runtime Management'), findsOneWidget);
    expect(find.text('Instances'), findsWidgets);
    expect(find.text('Nodes'), findsOneWidget);
    expect(find.text('Config'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
  });
}

Future<InstancesScreenData> _loadInstancesData() async {
  return InstancesScreenData(
    gatewayState: GatewayInstanceState(
      status: 'running',
      startedAt: DateTime(2026, 1, 2, 10),
      port: 18789,
    ),
    modelInstances: [
      const ModelInstanceState(
        modelId: 'hermes-agent',
        alias: 'Hermes Agent',
        contextWindow: 128000,
        maxTokens: 16000,
        pricingInput: 0,
        pricingOutput: 0,
        isPrimary: true,
      ),
    ],
  );
}
