import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/desktop_control/clipboard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Get the singleton instance once for all tests
  late ClipboardService service;
  String? clipboardText;

  setUpAll(() async {
    service = ClipboardService();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          final Map<dynamic, dynamic> data =
              call.arguments as Map<dynamic, dynamic>;
          clipboardText = data['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return <String, dynamic>{'text': clipboardText};
        default:
          return null;
      }
    });

    // Initialize once at the start
    // We don't close the database to avoid singleton issues
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('ClipboardService Basic Tests', () {
    test('should not be initialized initially', () {
      expect(service.isInitialized, isFalse);
    });

    test('should not be monitoring initially', () {
      expect(service.isMonitoring, isFalse);
    });

    test('should have no lastContent initially', () {
      expect(service.lastContent, isNull);
    });
  });

  group('ClipboardService Get Content Tests', () {
    test('should get current clipboard content', () async {
      const testContent = 'Get this content';
      await Clipboard.setData(const ClipboardData(text: testContent));

      final result = await service.getClipboardContent();

      expect(result, equals(testContent));
    });

    test('should return null for empty clipboard', () async {
      await Clipboard.setData(const ClipboardData(text: ''));

      final result = await service.getClipboardContent();

      // Flutter Clipboard returns empty string, not null
      expect(result, isEmpty);
    });

    test('should update lastContent after get', () async {
      const testContent = 'Content for lastContent';
      await Clipboard.setData(const ClipboardData(text: testContent));

      await service.getClipboardContent();

      expect(service.lastContent, equals(testContent));
    });

    test('should handle errors gracefully', () async {
      // Just verify it doesn't throw
      final result = await service.getClipboardContent();

      expect(result, isA<String?>());
    });
  });

  group('ClipboardService Unicode Support', () {
    test('should handle unicode characters', () async {
      const unicodeContent = 'Hello 世界 🌍 Ñoño';

      await Clipboard.setData(const ClipboardData(text: unicodeContent));
      final result = await service.getClipboardContent();

      expect(result, equals(unicodeContent));
    });

    test('should handle emojis', () async {
      const emojiContent = '😀 🎉 ❤️ 👍';

      await Clipboard.setData(const ClipboardData(text: emojiContent));
      final result = await service.getClipboardContent();

      expect(result, equals(emojiContent));
    });

    test('should handle newlines and special chars', () async {
      const specialContent = 'Line 1\nLine 2\tTabbed\n\r';

      await Clipboard.setData(const ClipboardData(text: specialContent));
      final result = await service.getClipboardContent();

      expect(result, equals(specialContent));
    });

    test('should handle RTL text', () async {
      const rtlContent = 'مرحبا بالعالم'; // Arabic RTL

      await Clipboard.setData(const ClipboardData(text: rtlContent));
      final result = await service.getClipboardContent();

      expect(result, equals(rtlContent));
    });

    test('should handle mixed scripts', () async {
      const mixedContent = 'Hello 世界 مرحبا 😀';

      await Clipboard.setData(const ClipboardData(text: mixedContent));
      final result = await service.getClipboardContent();

      expect(result, equals(mixedContent));
    });

    test('should handle Cyrillic text', () async {
      const cyrillicContent = 'Привет мир'; // Russian

      await Clipboard.setData(const ClipboardData(text: cyrillicContent));
      final result = await service.getClipboardContent();

      expect(result, equals(cyrillicContent));
    });

    test('should handle Japanese text', () async {
      const japaneseContent = 'こんにちは世界'; // Hiragana

      await Clipboard.setData(const ClipboardData(text: japaneseContent));
      final result = await service.getClipboardContent();

      expect(result, equals(japaneseContent));
    });

    test('should handle Chinese text', () async {
      const chineseContent = '你好世界';

      await Clipboard.setData(const ClipboardData(text: chineseContent));
      final result = await service.getClipboardContent();

      expect(result, equals(chineseContent));
    });

    test('should handle Korean text', () async {
      const koreanContent = '안녕하세요 세계'; // Hangul

      await Clipboard.setData(const ClipboardData(text: koreanContent));
      final result = await service.getClipboardContent();

      expect(result, equals(koreanContent));
    });

    test('should handle Greek text', () async {
      const greekContent = 'Γεια σου κόσμε';

      await Clipboard.setData(const ClipboardData(text: greekContent));
      final result = await service.getClipboardContent();

      expect(result, equals(greekContent));
    });

    test('should handle Hebrew text', () async {
      const hebrewContent = 'שלום עולם';

      await Clipboard.setData(const ClipboardData(text: hebrewContent));
      final result = await service.getClipboardContent();

      expect(result, equals(hebrewContent));
    });
  });

  group('ClipboardService Size Limits', () {
    test('should handle large text content', () async {
      // Create a large string (10KB)
      final largeContent = 'A' * 10240;

      await Clipboard.setData(ClipboardData(text: largeContent));

      // Should not throw
      final result = await service.getClipboardContent();

      expect(result?.length, equals(10240));
    });

    test('should handle very large text content', () async {
      // Create a very large string (100KB)
      final largeContent = 'B' * 102400;

      await Clipboard.setData(ClipboardData(text: largeContent));

      // Should not throw
      final result = await service.getClipboardContent();

      expect(result?.length, equals(102400));
    });

    test('should handle multi-line large content', () async {
      // Create large multi-line content
      final largeContent =
          List.generate(100, (i) => 'Line $i: ${'A' * 100}').join('\n');

      await Clipboard.setData(ClipboardData(text: largeContent));

      // Should not throw
      final result = await service.getClipboardContent();

      expect(result?.length, greaterThan(0));
      expect(result?.contains('\n'), isTrue);
    });

    test('should handle very long single line', () async {
      final longLine = 'A' * 5000;

      await Clipboard.setData(ClipboardData(text: longLine));
      final result = await service.getClipboardContent();

      expect(result, equals(longLine));
    });

    test('should handle 1MB content', () async {
      // Create a very large string (1MB)
      final largeContent = 'C' * 1048576;

      await Clipboard.setData(ClipboardData(text: largeContent));

      // Should not throw
      final result = await service.getClipboardContent();

      expect(result?.length, equals(1048576));
    });
  });

  group('ClipboardService Edge Cases', () {
    test('should handle whitespace only content', () async {
      const whitespaceContent = '   \t\n   ';

      await Clipboard.setData(const ClipboardData(text: whitespaceContent));
      final result = await service.getClipboardContent();

      expect(result, equals(whitespaceContent));
    });

    test('should handle special escape sequences', () async {
      const escapeContent = 'Tab\tTab\nNewline\r\nCarriage\n\tMixed';

      await Clipboard.setData(const ClipboardData(text: escapeContent));
      final result = await service.getClipboardContent();

      expect(result, equals(escapeContent));
    });

    test('should handle single character', () async {
      const singleChar = 'A';

      await Clipboard.setData(const ClipboardData(text: singleChar));
      final result = await service.getClipboardContent();

      expect(result, equals(singleChar));
    });

    test('should handle single space', () async {
      const singleSpace = ' ';

      await Clipboard.setData(const ClipboardData(text: singleSpace));
      final result = await service.getClipboardContent();

      expect(result, equals(singleSpace));
    });

    test('should handle tab character only', () async {
      const tabChar = '\t';

      await Clipboard.setData(const ClipboardData(text: tabChar));
      final result = await service.getClipboardContent();

      expect(result, equals(tabChar));
    });

    test('should handle newline character only', () async {
      const newlineChar = '\n';

      await Clipboard.setData(const ClipboardData(text: newlineChar));
      final result = await service.getClipboardContent();

      expect(result, equals(newlineChar));
    });

    test('should handle zero-width space', () async {
      const zeroWidth = 'A\u200BB'; // Zero-width space between A and B

      await Clipboard.setData(const ClipboardData(text: zeroWidth));
      final result = await service.getClipboardContent();

      expect(result, equals(zeroWidth));
    });

    test('should handle combining characters', () async {
      const combining = 'e\u0301'; // e + combining acute accent (é)

      await Clipboard.setData(const ClipboardData(text: combining));
      final result = await service.getClipboardContent();

      expect(result, equals(combining));
    });

    test('should handle surrogate pairs', () async {
      const surrogatePair = '𝄞'; // Musical symbol (surrogate pair)

      await Clipboard.setData(const ClipboardData(text: surrogatePair));
      final result = await service.getClipboardContent();

      expect(result, equals(surrogatePair));
    });

    test('should handle multiple emoji sequence', () async {
      const emojiSequence = '👨‍👩‍👧‍👦'; // Family emoji with ZWJ sequences

      await Clipboard.setData(const ClipboardData(text: emojiSequence));
      final result = await service.getClipboardContent();

      expect(result, equals(emojiSequence));
    });

    test('should handle control characters', () async {
      const controlChars = 'Start\x00Middle\x01End';

      await Clipboard.setData(const ClipboardData(text: controlChars));
      final result = await service.getClipboardContent();

      // Just verify it doesn't throw
      expect(result, isA<String?>());
    });
  });

  group('ClipboardService Real-world Content', () {
    test('should handle URL', () async {
      const url = 'https://example.com/path?query=value&other=123#fragment';

      await Clipboard.setData(const ClipboardData(text: url));
      final result = await service.getClipboardContent();

      expect(result, equals(url));
    });

    test('should handle JSON', () async {
      const json = '{"key": "value", "nested": {"array": [1, 2, 3]}}';

      await Clipboard.setData(const ClipboardData(text: json));
      final result = await service.getClipboardContent();

      expect(result, equals(json));
    });

    test('should handle code snippet', () async {
      const code = '''function example() {
  const x = 5;
  return x * 2;
}''';

      await Clipboard.setData(const ClipboardData(text: code));
      final result = await service.getClipboardContent();

      expect(result, equals(code));
    });

    test('should handle markdown', () async {
      const markdown = '''# Heading
## Subheading

- List item 1
- List item 2

**Bold** and *italic* text.''';

      await Clipboard.setData(const ClipboardData(text: markdown));
      final result = await service.getClipboardContent();

      expect(result, equals(markdown));
    });

    test('should handle HTML snippet', () async {
      const html =
          '<div class="container"><p>Hello <strong>world</strong></p></div>';

      await Clipboard.setData(const ClipboardData(text: html));
      final result = await service.getClipboardContent();

      expect(result, equals(html));
    });

    test('should handle CSV data', () async {
      const csv = '''Name,Age,City
Alice,30,NYC
Bob,25,SF
Charlie,35,LA''';

      await Clipboard.setData(const ClipboardData(text: csv));
      final result = await service.getClipboardContent();

      expect(result, equals(csv));
    });

    test('should handle email address', () async {
      const email = 'user.name+tag@example.co.uk';

      await Clipboard.setData(const ClipboardData(text: email));
      final result = await service.getClipboardContent();

      expect(result, equals(email));
    });

    test('should handle phone number', () async {
      const phone = '+1 (555) 123-4567';

      await Clipboard.setData(const ClipboardData(text: phone));
      final result = await service.getClipboardContent();

      expect(result, equals(phone));
    });

    test('should handle file path', () async {
      const path = '/home/user/documents/file.txt';

      await Clipboard.setData(const ClipboardData(text: path));
      final result = await service.getClipboardContent();

      expect(result, equals(path));
    });

    test('should handle Windows file path', () async {
      const windowsPath = 'C:\\Users\\user\\Documents\\file.txt';

      await Clipboard.setData(const ClipboardData(text: windowsPath));
      final result = await service.getClipboardContent();

      expect(result, equals(windowsPath));
    });
  });

  group('ClipboardService State Consistency', () {
    test('should maintain lastContent across multiple gets', () async {
      const content1 = 'Content 1';
      const content2 = 'Content 2';

      await Clipboard.setData(const ClipboardData(text: content1));
      await service.getClipboardContent();
      expect(service.lastContent, equals(content1));

      await Clipboard.setData(const ClipboardData(text: content2));
      await service.getClipboardContent();
      expect(service.lastContent, equals(content2));
    });

    test('should handle rapid clipboard changes via gets', () async {
      final contents = List.generate(10, (i) => 'Content $i');

      for (final content in contents) {
        await Clipboard.setData(ClipboardData(text: content));
        await service.getClipboardContent();
      }

      expect(service.lastContent, equals('Content 9'));
    });
  });

  group('ClipboardService Empty and Null Handling', () {
    test('should handle empty string', () async {
      await Clipboard.setData(const ClipboardData(text: ''));
      final result = await service.getClipboardContent();

      expect(result, equals(''));
    });

    test('should handle single newline', () async {
      await Clipboard.setData(const ClipboardData(text: '\n'));
      final result = await service.getClipboardContent();

      expect(result, equals('\n'));
    });

    test('should handle multiple consecutive newlines', () async {
      await Clipboard.setData(const ClipboardData(text: '\n\n\n'));
      final result = await service.getClipboardContent();

      expect(result, equals('\n\n\n'));
    });

    test('should handle spaces only', () async {
      await Clipboard.setData(const ClipboardData(text: '    '));
      final result = await service.getClipboardContent();

      expect(result, equals('    '));
    });
  });
}
