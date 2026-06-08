import 'package:cloudtolocalllm/di/locator.dart' as di;
import 'package:cloudtolocalllm/screens/dashboard/overview_screen.dart';
import 'package:cloudtolocalllm/services/connection_manager_service.dart';
import 'package:cloudtolocalllm/services/hermes_manager/hermes_gateway_control_service.dart';
import 'package:cloudtolocalllm/services/openclaw_manager/gateway_control_service.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';
import 'package:cloudtolocalllm/services/voice/voice_conversation_service.dart';
import 'package:cloudtolocalllm/services/voice/local_voice_input_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeOverviewConnectionManager extends ConnectionManagerService {
  _FakeOverviewConnectionManager()
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
        'openclaw': <String, dynamic>{
          'state': 'stopped',
          'isRunning': false,
        },
        'hermes': <String, dynamic>{
          'state': 'running',
          'isRunning': true,
        },
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  late VoiceConversationService voiceService;
  late _FakeOverviewConnectionManager connectionManager;

  setUp(() {
    voiceService = VoiceConversationService();
    connectionManager = _FakeOverviewConnectionManager();

    if (di.serviceLocator.isRegistered<VoiceConversationService>()) {
      di.serviceLocator.unregister<VoiceConversationService>();
    }
    di.serviceLocator.registerSingleton<VoiceConversationService>(
      voiceService,
    );
  });

  tearDown(() async {
    if (di.serviceLocator.isRegistered<VoiceConversationService>()) {
      di.serviceLocator.unregister<VoiceConversationService>();
    }
    voiceService.dispose();
  });

  // Re-enabled — DI registered in setUp (#424).
  testWidgets('overview voice section exposes demo controls', (tester) async {
    final localVoice = LocalVoiceInputService(
      voiceConversationService: voiceService,
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            return MultiProvider(
              providers: [
                ChangeNotifierProvider<ConnectionManagerService>.value(
                  value: connectionManager,
                ),
                ChangeNotifierProvider<VoiceConversationService>.value(
                  value: voiceService,
                ),
                ChangeNotifierProvider<LocalVoiceInputService>.value(
                  value: localVoice,
                ),
              ],
              child: const OverviewScreen(),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.pumpAndSettle();

    expect(find.text('Voice Companion'), findsOneWidget);
    // VoiceConversationStatusCard and OpenVoiceUIControlPanel should render
    // since VoiceConversationService is registered in GetIt.
    expect(find.text('OpenVoiceUI Control'), findsOneWidget);
  });
}
