import 'package:cloudtolocalllm/services/voice/local_voice_input_service.dart';
import 'package:cloudtolocalllm/services/voice/voice_conversation_service.dart';
import 'package:cloudtolocalllm/widgets/voice/voice_conversation_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('VoiceConversationStatusCard', () {
    late VoiceConversationService voiceConversationService;
    late DevVoiceInputAdapter devInputAdapter;
    late LocalVoiceInputService localVoiceInputService;

    setUp(() {
      voiceConversationService = VoiceConversationService(
        config: const VoiceConversationConfig(
          engagedHold: Duration(seconds: 5),
        ),
      );
      devInputAdapter = DevVoiceInputAdapter();
      localVoiceInputService = LocalVoiceInputService(
        voiceConversationService: voiceConversationService,
        adapter: devInputAdapter,
        isWeb: false,
      );
    });

    tearDown(() async {
      await localVoiceInputService.dispose();
      await devInputAdapter.dispose();
      voiceConversationService.dispose();
    });

    testWidgets('submits dev transcript through local voice input service',
        (tester) async {
      await tester.pumpWidget(
        _wrapCard(
          voiceConversationService: voiceConversationService,
          localVoiceInputService: localVoiceInputService,
        ),
      );

      expect(find.text('microphone ready'), findsOneWidget);
      expect(
        find.text('Ready for a wake phrase or a local transcript.'),
        findsOneWidget,
      );
      expect(find.text('local demo only (offline)'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('voice-dev-transcript-field')),
        'Zoidbot can you hear this dev path?',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('voice-dev-transcript-submit')),
      );
      await tester
          .tap(find.byKey(const ValueKey('voice-dev-transcript-submit')));
      await tester.pump();

      expect(find.text('microphone active'), findsOneWidget);

      expect(
        voiceConversationService.snapshot.lastUserTranscript,
        'Zoidbot can you hear this dev path?',
      );
      expect(voiceConversationService.snapshot.mode,
          VoiceConversationMode.speaking);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('voice-dev-transcript-field')),
            )
            .controller
            ?.text,
        isEmpty,
      );
      expect(find.text('Zoidbot can you hear this dev path?'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 900));

      expect(voiceConversationService.snapshot.mode,
          VoiceConversationMode.engaged);

      voiceConversationService.reset();
      await tester.pump();
    });

    testWidgets('hold countdown updates while conversation remains engaged',
        (tester) async {
      await tester.pumpWidget(
        _wrapCard(
          voiceConversationService: voiceConversationService,
          localVoiceInputService: localVoiceInputService,
        ),
      );

      voiceConversationService.noteWakePhrase('Zoidbot are you there?');
      await tester.pump();

      final initialValue = _secondsRemaining(tester);

      await tester.pump(const Duration(seconds: 3));

      final laterValue = _secondsRemaining(tester);
      expect(laterValue, lessThan(initialValue));

      voiceConversationService.reset();
      await tester.pump();
    });

    testWidgets('blank dev transcript does not update voice state',
        (tester) async {
      await tester.pumpWidget(
        _wrapCard(
          voiceConversationService: voiceConversationService,
          localVoiceInputService: localVoiceInputService,
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('voice-dev-transcript-field')),
        '   ',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('voice-dev-transcript-submit')),
      );
      await tester
          .tap(find.byKey(const ValueKey('voice-dev-transcript-submit')));
      await tester.pump();

      expect(voiceConversationService.snapshot.lastUserTranscript, isEmpty);
      expect(
          voiceConversationService.snapshot.mode, VoiceConversationMode.idle);
    });
  });
}

Widget _wrapCard({
  required VoiceConversationService voiceConversationService,
  required LocalVoiceInputService localVoiceInputService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<VoiceConversationService>.value(
        value: voiceConversationService,
      ),
      Provider<LocalVoiceInputService>.value(
        value: localVoiceInputService,
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: VoiceConversationStatusCard(showDemoControls: true),
        ),
      ),
    ),
  );
}

int _secondsRemaining(WidgetTester tester) {
  final textWidget =
      tester.widget<Text>(find.byKey(const ValueKey('voice-hold-until-value')));
  final text = textWidget.data ?? textWidget.textSpan?.toPlainText();
  expect(text, isNotNull);
  final match = RegExp(r'^(\d+)s$').firstMatch(text!);
  expect(match, isNotNull);
  return int.parse(match!.group(1)!);
}
