import 'package:cloudtolocalllm/services/hermes_manager/local_think_artifact_preview_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalThinkArtifactPreviewService', () {
    test('builds scoped default prefixes from HOME and Windows home env', () {
      final prefixes = LocalThinkArtifactPreviewService
          .buildDefaultAllowedPathPrefixes(environment: const <String, String>{
        'HOME': '/home/christopher',
        'USERPROFILE': r'C:\Users\Christopher',
        'HOMEDRIVE': 'C:',
        'HOMEPATH': r'\Users\Christopher',
      });

      expect(prefixes, <String>[
        '/home/christopher/.hermes/local-think/',
        'C:/Users/Christopher/.hermes/local-think/',
      ]);
    });

    test('keeps already-scoped environment prefixes normalized and deduped', () {
      final prefixes = LocalThinkArtifactPreviewService
          .buildDefaultAllowedPathPrefixes(environment: const <String, String>{
        'HOME': '/home/christopher/.hermes/local-think',
        'USERPROFILE': r'C:\Users\Christopher\.hermes\local-think\',
        'HOMEDRIVE': 'C:',
        'HOMEPATH': r'\Users\Christopher',
      });

      expect(prefixes, <String>[
        '/home/christopher/.hermes/local-think/',
        'C:/Users/Christopher/.hermes/local-think/',
      ]);
    });

    test('returns null for null and empty paths', () async {
      final service = LocalThinkArtifactPreviewService(
        textReader: (_) async => 'unused',
        allowedPathPrefixes: const <String>['/tmp/local-think/'],
      );

      expect(await service.previewFinalFile(null), isNull);
      expect(await service.previewFinalFile(''), isNull);
      expect(await service.previewFinalFile('   '), isNull);
    });

    test('rejects paths outside allowed prefixes', () async {
      var readCount = 0;
      final service = LocalThinkArtifactPreviewService(
        textReader: (_) async {
          readCount += 1;
          return 'secret';
        },
        allowedPathPrefixes: const <String>['/tmp/local-think/'],
      );

      final preview = await service.previewFinalFile('/tmp/other/job.final.md');

      expect(preview, isNull);
      expect(readCount, 0);
    });

    test('rejects non final markdown files', () async {
      var readCount = 0;
      final service = LocalThinkArtifactPreviewService(
        textReader: (_) async {
          readCount += 1;
          return 'raw log';
        },
        allowedPathPrefixes: const <String>['/tmp/local-think/'],
      );

      expect(
        await service.previewFinalFile('/tmp/local-think/job/run.log'),
        isNull,
      );
      expect(
        await service.previewFinalFile('/tmp/local-think/job/output.json'),
        isNull,
      );
      expect(readCount, 0);
    });

    test('rejects parent traversal inside allowed artifact prefixes', () async {
      var readCount = 0;
      final service = LocalThinkArtifactPreviewService(
        textReader: (_) async {
          readCount += 1;
          return 'should not be read';
        },
        allowedPathPrefixes: const <String>['/tmp/local-think/'],
      );

      final preview = await service.previewFinalFile(
        '/tmp/local-think/job/../secret.final.md',
      );

      expect(preview, isNull);
      expect(readCount, 0);
    });

    test('reads allowed final markdown through injected reader', () async {
      final reads = <String>[];
      final service = LocalThinkArtifactPreviewService(
        textReader: (path) async {
          reads.add(path);
          return 'A useful final summary.';
        },
        allowedPathPrefixes: const <String>['/tmp/local-think/'],
      );

      final preview = await service.previewFinalFile(
        '/tmp/local-think/job/job.final.md',
      );

      expect(preview, 'A useful final summary.');
      expect(reads, <String>['/tmp/local-think/job/job.final.md']);
    });

    test('accepts windows-style separators when prefix and file stay scoped',
        () async {
      final reads = <String>[];
      final service = LocalThinkArtifactPreviewService(
        textReader: (path) async {
          reads.add(path);
          return 'Windows-safe summary.';
        },
        allowedPathPrefixes: const <String>['C:\\Users\\rightguy\\.hermes\\local-think'],
      );

      final preview = await service.previewFinalFile(
        'C:\\Users\\rightguy\\.hermes\\local-think\\job\\job.final.md',
      );

      expect(preview, 'Windows-safe summary.');
      expect(reads, <String>[
        'C:\\Users\\rightguy\\.hermes\\local-think\\job\\job.final.md',
      ]);
    });

    test('rejects windows-style parent traversal inside allowed prefixes',
        () async {
      var readCount = 0;
      final service = LocalThinkArtifactPreviewService(
        textReader: (_) async {
          readCount += 1;
          return 'should not be read';
        },
        allowedPathPrefixes: const <String>['C:\\Users\\rightguy\\.hermes\\local-think'],
      );

      final preview = await service.previewFinalFile(
        'C:\\Users\\rightguy\\.hermes\\local-think\\job\\..\\secret.final.md',
      );

      expect(preview, isNull);
      expect(readCount, 0);
    });

    test('truncates long text with an ellipsis', () async {
      final service = LocalThinkArtifactPreviewService(
        textReader: (_) async => 'abcdef',
        maxChars: 4,
        allowedPathPrefixes: const <String>['/tmp/local-think/'],
      );

      final preview = await service.previewFinalFile(
        '/tmp/local-think/job/job.final.md',
      );

      expect(preview, 'abcd...');
    });

    test('redacts obvious secret values', () async {
      final service = LocalThinkArtifactPreviewService(
        textReader: (_) async => '''
api_key=abc123
token: secret-token
password = hunter2
Authorization: Bearer ***
Authorization: Bearer eyJsecret.payload
''',
        allowedPathPrefixes: const <String>['/tmp/local-think/'],
      );

      final preview = await service.previewFinalFile(
        '/tmp/local-think/job/job.final.md',
      );

      expect(preview, contains('api_key=[REDACTED]'));
      expect(preview, contains('token: [REDACTED]'));
      expect(preview, contains('password = [REDACTED]'));
      expect(preview, contains('Bearer [REDACTED]'));
      expect(preview, isNot(contains('abc123')));
      expect(preview, isNot(contains('secret-token')));
      expect(preview, isNot(contains('hunter2')));
      expect(preview, isNot(contains('eyJsecret.payload')));
    });

    test('treats read failure as null', () async {
      final service = LocalThinkArtifactPreviewService(
        textReader: (_) async => throw StateError('cannot read'),
        allowedPathPrefixes: const <String>['/tmp/local-think/'],
      );

      final preview = await service.previewFinalFile(
        '/tmp/local-think/job/job.final.md',
      );

      expect(preview, isNull);
    });

    test('normalizes silent files to a quiet skip preview', () async {
      final service = LocalThinkArtifactPreviewService(
        textReader: (_) async => '[SILENT] no visible work',
        allowedPathPrefixes: const <String>['/tmp/local-think/'],
      );

      final preview = await service.previewFinalFile(
        '/tmp/local-think/job/job.final.md',
      );

      expect(preview, 'Silent wake-gate skip.');
    });
  });
}
