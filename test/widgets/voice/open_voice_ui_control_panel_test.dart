import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';
import 'package:cloudtolocalllm/services/connection_manager_service.dart';
import 'package:cloudtolocalllm/services/openclaw_manager/gateway_control_service.dart';
import 'package:cloudtolocalllm/services/hermes_manager/hermes_gateway_control_service.dart';
import 'package:cloudtolocalllm/services/voice/voice_conversation_service.dart';
import 'package:cloudtolocalllm/services/voice/local_voice_input_service.dart';
import 'package:cloudtolocalllm/widgets/voice/open_voice_ui_control_panel.dart';

Widget buildWidget() {
  final settings = SettingsPreferenceService();
  final openclawGateway = GatewayControlService(settings);
  final hermesGateway = HermesGatewayControlService();
  final connService = ConnectionManagerService(
    openclawGatewayService: openclawGateway,
    hermesGatewayService: hermesGateway,
    autoDetectOnInitialize: false,
  );
  final voiceService = VoiceConversationService();
  final localVoice = LocalVoiceInputService(
    voiceConversationService: voiceService,
  );

  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<ConnectionManagerService>.value(
              value: connService,
            ),
            ChangeNotifierProvider<VoiceConversationService>.value(
              value: voiceService,
            ),
            ChangeNotifierProvider<LocalVoiceInputService>.value(
              value: localVoice,
            ),
          ],
          child: const OpenVoiceUIControlPanel(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows title and backend labels', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();

    expect(find.text('OpenVoiceUI Control'), findsOneWidget);
    expect(find.text('Backend'), findsOneWidget);
    expect(find.text('State'), findsOneWidget);
    expect(find.text('Voice mode'), findsOneWidget);
    expect(find.text('Listening'), findsOneWidget);
  });

  testWidgets('shows backend toggle buttons', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();

    expect(find.text('OpenClaw'), findsOneWidget);
    expect(find.text('Hermes Agent'), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Reset voice'), findsOneWidget);
  });

  testWidgets('shows transcript preview sections', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();

    expect(find.text('Last heard'), findsOneWidget);
    expect(find.text('Last reply'), findsOneWidget);
    expect(find.text('No voice input yet'), findsOneWidget);
    expect(find.text('No voice reply yet'), findsOneWidget);
  });

  testWidgets('shows description text', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();

    expect(
      find.text(
        'Voice front-end, agent control, and backend switching in one place.',
      ),
      findsOneWidget,
    );
  });
}
