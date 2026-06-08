library;

import 'package:cloudtolocalllm/di/locator.dart';
import 'package:cloudtolocalllm/screens/config/config_screen.dart';
import 'package:cloudtolocalllm/services/auto_update_service.dart';
import 'package:cloudtolocalllm/services/connection_manager_service.dart';
import 'package:cloudtolocalllm/services/hermes_manager/hermes_gateway_control_service.dart';
import 'package:cloudtolocalllm/services/openclaw_manager/gateway_control_service.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart'
    as settings;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late settings.SettingsPreferenceService settingsService;
  late ConnectionManagerService connectionManager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await serviceLocator.reset();

    settingsService = settings.SettingsPreferenceService();
    await settingsService.setActiveBackend(settings.BackendType.hermes);
    serviceLocator.registerSingleton<settings.SettingsPreferenceService>(
      settingsService,
    );

    connectionManager = ConnectionManagerService(
      openclawGatewayService: GatewayControlService(settingsService),
      hermesGatewayService: HermesGatewayControlService(),
      settingsPreferenceService: settingsService,
      autoDetectOnInitialize: false,
    );
  });

  tearDown(() async {
    connectionManager.dispose();
    await serviceLocator.reset();
  });

  Future<void> pumpRuntimeSettings(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/config',
      routes: [
        GoRoute(
          path: '/chat',
          builder: (context, state) => const Scaffold(
            body: Text('Runtime Channel Placeholder'),
          ),
        ),
        GoRoute(
          path: '/config',
          builder: (context, state) => const ConfigScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectionManagerService>.value(
            value: connectionManager,
          ),
          ChangeNotifierProvider<AutoUpdateService>.value(
            value: AutoUpdateService(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  group('Runtime management pane', () {
    testWidgets('Config screen uses runtime and support-provider vocabulary',
        (tester) async {
      await pumpRuntimeSettings(tester);

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Runtime Settings'), findsOneWidget);
      expect(find.text('Active Agent Runtime'), findsOneWidget);
      expect(find.text('Support Model Providers'), findsOneWidget);
      expect(find.text('Preferred Support Provider'), findsOneWidget);
      expect(find.textContaining('Secure channel runtime: Hermes Agent'),
          findsOneWidget);
      expect(find.textContaining('Support providers cannot complete setup'),
          findsOneWidget);

      expect(find.text('LLM Provider'), findsNothing);
      expect(find.text('Primary Provider'), findsNothing);
      expect(find.text('Gateway Backend'), findsNothing);
      expect(find.byIcon(Icons.open_in_new), findsNothing);
    });

    testWidgets('Back button returns to runtime channel route', (tester) async {
      await pumpRuntimeSettings(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Runtime Channel Placeholder'), findsOneWidget);
    });
  });
}
