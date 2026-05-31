import 'package:cloudtolocalllm/services/hermes_manager/main_chat_timeline_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MainChatTimelineSanitizer', () {
    test('drops unknown and secret-like metadata keys', () {
      final sanitized = MainChatTimelineSanitizer.sanitizeMetadata(
        const <String, Object?>{
          'status': 'completed',
          'model': 'gpt-5',
          'attempts': 3,
          'maxAttempts': 5,
          'dedupKey': 'task-1',
          'notify': 'onComplete',
          'wakeGate': 'manual',
          'parentTaskId': 'parent-1',
          'contextFrom': 'conversation-1',
          'exitCode': 0,
          'token': 'abc123',
          'password': 'secret',
          'api_key': 'key-123',
          'authorization': 'Bearer xyz',
          'rawLog': 'do not keep',
          'promptFile': '/tmp/prompt.md',
          'outputFile': '/tmp/output.md',
          'logFile': '/tmp/log.md',
          'metaFile': '/tmp/meta.json',
          'runnerFile': '/tmp/runner.sh',
          'unknown': 'drop me',
        },
      );

      expect(sanitized, containsPair('status', 'completed'));
      expect(sanitized, containsPair('model', 'gpt-5'));
      expect(sanitized, containsPair('attempts', 3));
      expect(sanitized, containsPair('maxAttempts', 5));
      expect(sanitized, containsPair('dedupKey', 'task-1'));
      expect(sanitized, containsPair('notify', 'onComplete'));
      expect(sanitized, containsPair('wakeGate', 'manual'));
      expect(sanitized, containsPair('parentTaskId', 'parent-1'));
      expect(sanitized, containsPair('contextFrom', 'conversation-1'));
      expect(sanitized, containsPair('exitCode', 0));
      expect(sanitized.containsKey('token'), isFalse);
      expect(sanitized.containsKey('password'), isFalse);
      expect(sanitized.containsKey('api_key'), isFalse);
      expect(sanitized.containsKey('authorization'), isFalse);
      expect(sanitized.containsKey('rawLog'), isFalse);
      expect(sanitized.containsKey('promptFile'), isFalse);
      expect(sanitized.containsKey('outputFile'), isFalse);
      expect(sanitized.containsKey('logFile'), isFalse);
      expect(sanitized.containsKey('metaFile'), isFalse);
      expect(sanitized.containsKey('runnerFile'), isFalse);
      expect(sanitized.containsKey('unknown'), isFalse);
    });
  });
}
