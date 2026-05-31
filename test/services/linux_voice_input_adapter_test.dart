import 'dart:async';
import 'dart:io';

import 'package:cloudtolocalllm/services/voice/linux_voice_input_adapter_io.dart';
import 'package:cloudtolocalllm/services/voice/voice_input_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommandVoiceTranscriptTranscriber', () {
    test('returns trimmed stdout from the command runner', () async {
      final observedCalls = <List<String>>[];
      final transcriber = CommandVoiceTranscriptTranscriber(
        command: 'fake-whisper',
        arguments: const ['--model', 'base'],
        processRunner: (
          executable,
          arguments, {
          environment,
        }) async {
          observedCalls.add([executable, ...arguments]);
          return ProcessResult(123, 0, '  hello from linux mic  \n', '');
        },
      );
      final audioFile = File('/tmp/fake-audio.wav');

      final transcript = await transcriber.transcribe(audioFile);

      expect(transcript, 'hello from linux mic');
      expect(observedCalls.single, [
        'fake-whisper',
        '--model',
        'base',
        '/tmp/fake-audio.wav',
      ]);
    });
  });

  group('LinuxVoiceInputAdapter', () {
    test('flushes buffered audio into native transcript events', () async {
      final source = FakeVoiceAudioSource();
      final transcribedFiles = <File>[];
      final adapter = LinuxVoiceInputAdapter(
        audioSource: source,
        transcriber: _FakeTranscriber(
          onTranscribe: (file) async {
            transcribedFiles.add(file);
            return '  linux native transcript  ';
          },
        ),
        captureWindow: const Duration(milliseconds: 50),
      );
      final events = <VoiceInputTranscriptEvent>[];
      final subscription = adapter.transcripts.listen(events.add);

      await adapter.start();
      source.emit(List<int>.filled(1024, 7));
      await Future<void>.delayed(Duration.zero);
      await adapter.stop();
      await Future<void>.delayed(Duration.zero);

      expect(source.started, isTrue);
      expect(source.stopped, isTrue);
      expect(transcribedFiles, hasLength(1));
      expect(events, hasLength(1));
      expect(events.single.source, VoiceInputSource.native);
      expect(events.single.text, 'linux native transcript');
      expect(events.single.isFinal, isTrue);

      await subscription.cancel();
      await adapter.dispose();
    });
  });
}

class FakeVoiceAudioSource implements VoiceAudioSource {
  final StreamController<List<int>> _controller =
      StreamController<List<int>>.broadcast();

  bool started = false;
  bool stopped = false;
  bool permissionGranted = true;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    return permissionGranted;
  }

  @override
  Future<Stream<List<int>>> start() async {
    started = true;
    return _controller.stream;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    await _controller.close();
  }

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  void emit(List<int> bytes) {
    _controller.add(bytes);
  }
}

class _FakeTranscriber implements VoiceTranscriptTranscriber {
  _FakeTranscriber({required this.onTranscribe});

  final Future<String?> Function(File file) onTranscribe;

  @override
  Future<String?> transcribe(File audioFile) => onTranscribe(audioFile);
}
