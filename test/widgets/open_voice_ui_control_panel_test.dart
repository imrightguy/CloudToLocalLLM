import 'package:cloudtolocalllm/services/connection_manager_service.dart';
import 'package:cloudtolocalllm/services/hermes_manager/hermes_gateway_control_service.dart';
import 'package:cloudtolocalllm/services/openclaw_manager/gateway_control_service.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';
import 'package:cloudtolocalllm/services/voice/voice_conversation_service.dart';
import 'package:cloudtolocalllm/services/voice/local_voice_input_service.dart';
import 'package:cloudtolocalllm/widgets/voice/open_voice_ui_control_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConnectionManager extends ConnectionManagerService {
  _FakeConnectionManager()
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

  testWidgets('renders voice backend controls and resets voice state',
      (tester) async {
    final connectionManager = _FakeConnectionManager();
    final voiceService = VoiceConversationService();
    final localVoice = LocalVoiceInputService(
      voiceConversationService: voiceService,
    );
    voiceService.noteWakePhrase('Zoidbot, are you there?');

    await tester.pumpWidget(
      MultiProvider(
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
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OpenVoiceUIControlPanel(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('OpenVoiceUI Control'), findsOneWidget);
    expect(find.text('Hermes Agent'), findsWidgets);
    expect(find.text('Voice mode'), findsOneWidget);
    expect(find.text('Reset voice'), findsOneWidget);
    expect(find.text('Backend'), findsOneWidget);
    expect(find.text('State'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reset voice'));
    await tester.pump();

    expect(voiceService.snapshot.mode, VoiceConversationMode.idle);
    expect(voiceService.snapshot.isEngaged, isFalse);
  });
}
