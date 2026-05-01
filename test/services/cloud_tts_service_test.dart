import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/voice/cloud_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudTtsRequest', () {
    test('parses OpenAI-compatible speech request defaults', () {
      final request = CloudTtsRequest.fromJson({'input': 'hello there'});

      expect(request.input, 'hello there');
      expect(request.model, 'cloudtolocalllm-edge-tts');
      expect(request.voice, 'en-US-GuyNeural');
      expect(request.responseFormat, 'mp3');
    });

    test('normalizes opus aliases', () {
      final request = CloudTtsRequest.fromJson({
        'input': 'hello there',
        'response_format': 'ogg',
      });

      expect(request.responseFormat, 'opus');
    });

    test('rejects missing input', () {
      expect(
        () => CloudTtsRequest.fromJson({'voice': 'en-US-GuyNeural'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('CloudTtsService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ctllm_tts_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('invokes edge-tts-compatible command and returns mp3 output',
        () async {
      final service = CloudTtsService(
        outputDirectory: tempDir,
        processRunner: (executable, arguments,
            {environment, runInShell = false}) async {
          expect(executable, 'edge-tts');
          final outputIndex = arguments.indexOf('--write-media');
          expect(outputIndex, greaterThan(-1));
          final outputPath = arguments[outputIndex + 1];
          await File(outputPath).writeAsBytes(<int>[0, 1, 2, 3]);
          return ProcessResult(42, 0, '', '');
        },
      );

      final result = await service.synthesize(
        const CloudTtsRequest(input: 'CloudToLocalLLM voice works.'),
      );

      expect(result.contentType, 'audio/mpeg');
      expect(result.path.endsWith('.mp3'), isTrue);
      expect(await File(result.path).length(), 4);
    });
  });
}
