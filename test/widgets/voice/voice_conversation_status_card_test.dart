import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/voice/voice_conversation_service.dart';
import 'package:cloudtolocalllm/services/voice/local_voice_input_service.dart';
import 'package:cloudtolocalllm/widgets/voice/voice_conversation_status_card.dart';

Widget buildWidget(VoiceConversationService service, {bool showDemoControls = false}) {
  return MaterialApp(
    home: Scaffold(
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider<VoiceConversationService>.value(
            value: service,
          ),
          ChangeNotifierProvider<LocalVoiceInputService>.value(
            value: LocalVoiceInputService(
              voiceConversationService: service,
            ),
          ),
        ],
        child: VoiceConversationStatusCard(
          showDemoControls: showDemoControls,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows idle state by default', (tester) async {
    final service = VoiceConversationService();
    addTearDown(service.dispose);

    await tester.pumpWidget(buildWidget(service));

    expect(find.text('idle'), findsOneWidget);
    expect(find.text('Voice Conversation'), findsOneWidget);
    expect(find.text('No transcript yet'), findsOneWidget);
    expect(find.text('No reply yet'), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);
    expect(find.text('no'), findsOneWidget);
  });

  testWidgets('shows demo controls only when showDemoControls is true', (tester) async {
    final service = VoiceConversationService();
    addTearDown(service.dispose);

    await tester.pumpWidget(buildWidget(service, showDemoControls: false));

    expect(find.text('Demo controls'), findsNothing);
    expect(find.text('Wake'), findsNothing);
    await tester.pump();
  });

  testWidgets('shows demo controls when enabled', (tester) async {
    final service = VoiceConversationService();
    addTearDown(service.dispose);

    await tester.pumpWidget(buildWidget(service, showDemoControls: true));

    expect(find.text('Demo controls'), findsOneWidget);
    expect(find.text('Wake'), findsOneWidget);
    expect(find.text('User line'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
  });

  testWidgets('still shows voice state without demo controls', (tester) async {
    final service = VoiceConversationService();
    addTearDown(service.dispose);

    await tester.pumpWidget(buildWidget(service, showDemoControls: false));

    expect(find.text('Voice Conversation'), findsOneWidget);
    expect(find.text('idle'), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);
  });

  testWidgets('shows engaged state after wake phrase', (tester) async {
    final service = VoiceConversationService();
    addTearDown(service.dispose);

    await tester.pumpWidget(buildWidget(service));
    service.noteWakePhrase('Zoidbot, you there?');
    await tester.pump();

    expect(find.text('engaged'), findsOneWidget);
    expect(find.text('yes'), findsOneWidget);

    // Let the hold timer expire so dispose doesn't trigger pending timer error
    await tester.pump(const Duration(seconds: 25));
  });

  testWidgets('shows speaking state after assistant reply', (tester) async {
    final service = VoiceConversationService();
    addTearDown(service.dispose);

    await tester.pumpWidget(buildWidget(service));

    service.noteWakePhrase('Hello');
    service.noteAssistantReply("Yeah, I'm here.");
    await tester.pump();

    expect(find.text('speaking'), findsOneWidget);

    // Let the hold timer expire so dispose doesn't trigger pending timer error
    await tester.pump(const Duration(seconds: 25));
  });

  testWidgets('shows live bridge info when connected', (tester) async {
    final service = VoiceConversationService();
    addTearDown(service.dispose);

    await tester.pumpWidget(buildWidget(service));

    service.applyExternalSnapshot(
      mode: VoiceConversationMode.listening,
      liveBridgeConnected: true,
      liveBridgeStatus: 'live Hermes bridge',
      lastUserTranscript: 'Can you hear me?',
      lastAssistantReply: 'Loud and clear.',
    );
    await tester.pump();

    expect(find.text('live Hermes bridge'), findsOneWidget);
    expect(find.text('listening'), findsOneWidget);
    expect(find.text('Can you hear me?'), findsOneWidget);
    expect(find.text('Loud and clear.'), findsOneWidget);
  });

  testWidgets('shows mic status chip', (tester) async {
    final service = VoiceConversationService();
    addTearDown(service.dispose);

    await tester.pumpWidget(buildWidget(service));
    await tester.pump();

    expect(find.text('Mic'), findsOneWidget);
    expect(find.text('OFF'), findsOneWidget);
  });
}
