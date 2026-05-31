import 'dart:async';
import 'dart:io';

import 'package:cloudtolocalllm/services/voice/linux_voice_input_adapter_io.dart';
import 'package:cloudtolocalllm/services/voice/voice_input_types.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LinuxVoiceInputAdapter', () {
    test('captures a recording chunk and forwards transcribed text', () async {
      final tempDir = Directory.systemTemp.createTempSync('voice_input_test_');
      addTearDown(() async {
        await tempDir.delete(recursive: true);
      });

      final recorderCommand = File(p.join(tempDir.path, 'ffmpeg'))
        ..writeAsStringSync('fake recorder');
      final transcribeCommand = File(p.join(tempDir.path, 'whisper'))
        ..writeAsStringSync('fake transcriber');

      final adapter = LinuxVoiceInputAdapter(
        processRunner: _fakeProcessRunner,
        recorderCommandPath: recorderCommand.path,
        transcribeCommandPath: transcribeCommand.path,
        captureWindow: const Duration(milliseconds: 10),
        commandTimeout: const Duration(seconds: 1),
        outputDirectory: Directory(p.join(tempDir.path, 'output')),
        trustedRecorderPaths: [recorderCommand.path],
        trustedTranscribePaths: [transcribeCommand.path],
      );

      final received = <VoiceInputTranscriptEvent>[];
      final receivedCompleter = Completer<VoiceInputTranscriptEvent>();
      final subscription = adapter.transcripts.listen((event) {
        received.add(event);
        if (!receivedCompleter.isCompleted) {
          receivedCompleter.complete(event);
          unawaited(adapter.stop());
        }
      });
      addTearDown(subscription.cancel);

      expect(adapter.isSupported, isTrue);
      await adapter.start();

      final event = await receivedCompleter.future.timeout(
        const Duration(seconds: 1),
      );

      expect(event.text, 'hello from the linux microphone');
      expect(event.isFinal, isTrue);
      expect(event.source, VoiceInputSource.native);
      expect(received, isNotEmpty);

      await adapter.stop();
      await adapter.dispose();
    });

    test('is unsupported when trusted commands are unavailable', () async {
      final tempDir = Directory.systemTemp.createTempSync('voice_input_test_');
      addTearDown(() async {
        await tempDir.delete(recursive: true);
      });

      final adapter = LinuxVoiceInputAdapter(
        processRunner: _fakeProcessRunner,
        recorderCommandPath: p.join(tempDir.path, 'missing-ffmpeg'),
        transcribeCommandPath: p.join(tempDir.path, 'missing-whisper'),
        captureWindow: const Duration(milliseconds: 10),
        commandTimeout: const Duration(seconds: 1),
      );

      expect(adapter.isSupported, isFalse);
      await adapter.start();
      expect(adapter.isRunning, isFalse);
      await adapter.dispose();
    });
  });
}

Future<ProcessResult> _fakeProcessRunner(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  bool runInShell = false,
}) async {
  if (executable.endsWith('ffmpeg')) {
    final outputPath = arguments.last;
    await File(outputPath).writeAsBytes(List<int>.filled(32, 1));
    return ProcessResult(0, 0, '', '');
  }

  if (executable.endsWith('whisper')) {
    final outputDir = Directory(arguments[arguments.indexOf('--output_dir') + 1]);
    final audioPath = arguments.first;
    final transcriptPath = File(
      p.join(outputDir.path, '${p.basenameWithoutExtension(audioPath)}.txt'),
    );
    await transcriptPath.writeAsString('  hello from the linux microphone  ');
    return ProcessResult(0, 0, '', '');
  }

  return ProcessResult(0, 1, '', 'unexpected executable: $executable');
}
