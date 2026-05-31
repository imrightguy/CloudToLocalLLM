import 'package:cloudtolocalllm/screens/home/home_layout.dart';
import 'package:cloudtolocalllm/services/connection_manager_service.dart';
import 'package:cloudtolocalllm/services/hermes_manager/hermes_gateway_control_service.dart';
import 'package:cloudtolocalllm/services/openclaw_manager/gateway_control_service.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart' hide BackendType;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectionManagerService connectionManager;
  late SettingsPreferenceService settingsPreferenceService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settingsPreferenceService = SettingsPreferenceService();
    connectionManager = ConnectionManagerService(
      openclawGatewayService:
          GatewayControlService(settingsPreferenceService),
      hermesGatewayService: HermesGatewayControlService(),
      settingsPreferenceService: settingsPreferenceService,
    );
    connectionManager.switchBackend(BackendType.hermes);
  });

  tearDown(() {
    connectionManager.dispose();
  });

  testWidgets('Manual setup wizard trigger routes to /setup',
      (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(
          path: '/chat',
          builder: (context, state) => Scaffold(
            body: RuntimeChannelHeader(
              connectionManager: connectionManager,
              showVerboseTimelineEvents: false,
              onRefresh: () {},
              onConfigure: () {},
              onVerboseTimelineChanged: (_) {},
            ),
          ),
        ),
        GoRoute(
          path: '/setup',
          builder: (context, state) => const Scaffold(
            body: Text('Setup wizard destination'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(OutlinedButton, 'Run Setup Wizard'),
      findsOneWidget,
      reason: 'Manual setup trigger should be rendered in the runtime header.',
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Run Setup Wizard'));
    await tester.pumpAndSettle();

    expect(
      find.text('Setup wizard destination'),
      findsOneWidget,
      reason: 'Tapping Run Setup Wizard should navigate to /setup.',
    );
  });

  testWidgets('toggles verbose timeline mode and keeps setup shortcut visible',
      (WidgetTester tester) async {
    var showVerboseTimelineEvents = false;

    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(
          path: '/chat',
          builder: (context, state) => StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: RuntimeChannelHeader(
                  connectionManager: connectionManager,
                  showVerboseTimelineEvents: showVerboseTimelineEvents,
                  onRefresh: () {},
                  onConfigure: () {},
                  onVerboseTimelineChanged: (value) {
                    setState(() {
                      showVerboseTimelineEvents = value;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(OutlinedButton, 'Run Setup Wizard'),
      findsOneWidget,
    );
    expect(find.text('Compact'), findsOneWidget);
    expect(find.text('Verbose'), findsOneWidget);
    expect(showVerboseTimelineEvents, isFalse);

    await tester.tap(find.text('Verbose'));
    await tester.pumpAndSettle();

    expect(showVerboseTimelineEvents, isTrue);
  });
}
