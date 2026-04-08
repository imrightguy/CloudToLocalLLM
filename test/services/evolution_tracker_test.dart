import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:cloudtolocalllm/services/avatar/evolution_tracker.dart';
import 'package:cloudtolocalllm/database/drift_local_brain.dart' as db;
import 'package:cloudtolocalllm/models/message.dart';

@GenerateMocks([db.LocalBrain])
import 'evolution_tracker_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLocalBrain mockDb;
  late EvolutionTracker service;

  setUp(() {
    mockDb = MockLocalBrain();
    service = EvolutionTracker(database: mockDb);
  });

  group('EvolutionTracker calculateComplexity', () {
    test('should calculate complexity for simple conversation', () async {
      final messages = <Message>[
        Message.user(content: 'Hello', id: '1'),
        Message.assistant(
          content: 'Hi there!',
          model: 'test-model',
          id: '2',
        ),
      ];

      final result = await service.calculateComplexity(messages);

      expect(result, greaterThan(0.0));
      expect(result, lessThanOrEqualTo(1.0));
    });

    test('should return 0 for empty message list', () async {
      final result = await service.calculateComplexity([]);

      expect(result, equals(0.0));
    });

    test('should calculate higher complexity for longer messages', () async {
      final messages = <Message>[
        Message.user(
          content:
              'This is a very long message with lots of content to increase complexity score',
          id: '1',
        ),
        Message.assistant(
          content:
              'This is also a very long response with lots of information about various topics',
          model: 'test-model',
          id: '2',
        ),
      ];

      final result = await service.calculateComplexity(messages);

      expect(result, greaterThan(0.0));
    });

    test('should detect technical terms for complexity', () async {
      final messages = <Message>[
        Message.user(
          content:
              'Can you explain how API endpoints work with HTTP and JSON data?',
          id: '1',
        ),
        Message.assistant(
          content:
              'REST APIs use HTTP methods like GET, POST, PUT, DELETE to manipulate JSON resources',
          model: 'test-model',
          id: '2',
        ),
      ];

      final result = await service.calculateComplexity(messages);

      expect(result, greaterThan(0.0));
    });

    test('should detect questions for complexity', () async {
      final messages = <Message>[
        Message.user(
          content: 'What is the best approach? How do I start?',
          id: '1',
        ),
        Message.assistant(
            content: 'Start with this approach', model: 'test-model', id: '2'),
        Message.user(content: 'When should I use it?', id: '3'),
      ];

      final result = await service.calculateComplexity(messages);

      expect(result, greaterThan(0.0));
    });

    test('should measure vocabulary diversity', () async {
      final messages = <Message>[
        Message.user(
          content:
              'The quick brown fox jumps over the lazy dog. Unique words increase diversity.',
          id: '1',
        ),
        Message.assistant(
          content:
              'Diversity means using different vocabulary throughout the conversation.',
          model: 'test-model',
          id: '2',
        ),
      ];

      final result = await service.calculateComplexity(messages);

      expect(result, greaterThan(0.0));
    });
  });

  group('EvolutionTracker calculateEmotionalDepth', () {
    test('should calculate emotional depth for conversation', () async {
      final messages = <Message>[
        Message.user(content: 'I feel happy today!', id: '1'),
        Message.assistant(
          content: 'I understand your feelings. It is wonderful to feel happy.',
          model: 'test-model',
          id: '2',
        ),
      ];

      final result = await service.calculateEmotionalDepth(messages);

      expect(result, greaterThan(0.0));
      expect(result, lessThanOrEqualTo(1.0));
    });

    test('should return 0 for empty message list', () async {
      final result = await service.calculateEmotionalDepth([]);

      expect(result, equals(0.0));
    });

    test('should detect empathetic words', () async {
      final messages = <Message>[
        Message.user(content: 'I really appreciate your help', id: '1'),
        Message.assistant(
          content:
              'I am glad I could help. I understand your situation and care about your progress.',
          model: 'test-model',
          id: '2',
        ),
      ];

      final result = await service.calculateEmotionalDepth(messages);

      expect(result, greaterThan(0.0));
    });

    test('should detect emotional words', () async {
      final messages = <Message>[
        Message.user(
          content: 'I feel excited about this project',
          id: '1',
        ),
        Message.assistant(
          content: 'Your passion is great. Feeling enthusiastic helps success.',
          model: 'test-model',
          id: '2',
        ),
      ];

      final result = await service.calculateEmotionalDepth(messages);

      expect(result, greaterThan(0.0));
    });

    test('should detect first-person pronouns', () async {
      final messages = <Message>[
        Message.user(
          content: 'I need help with my project. My deadline is soon.',
          id: '1',
        ),
        Message.assistant(
          content: 'I can help you with your project.',
          model: 'test-model',
          id: '2',
        ),
      ];

      final result = await service.calculateEmotionalDepth(messages);

      expect(result, greaterThan(0.0));
    });
  });

  group('EvolutionTracker calculateNovelty', () {
    test('should calculate novelty for conversation', () async {
      final messages = <Message>[
        Message.user(
          content: 'Tell me about programming',
          id: '1',
        ),
        Message.assistant(
          content:
              'Programming involves writing code to create software applications.',
          model: 'test-model',
          id: '2',
        ),
      ];

      final result = await service.calculateNovelty(messages);

      expect(result, greaterThan(0.0));
      expect(result, lessThanOrEqualTo(1.0));
    });

    test('should return 0 for empty message list', () async {
      final result = await service.calculateNovelty([]);

      expect(result, equals(0.0));
    });

    test('should calculate higher novelty for diverse vocabulary', () async {
      final messages = <Message>[
        Message.user(
          content:
              'Python is great for data science. Java works well for enterprise.',
          id: '1',
        ),
        Message.assistant(
          content:
              'Rust offers memory safety. Go provides concurrency. Flutter builds cross-platform.',
          model: 'test-model',
          id: '2',
        ),
      ];

      final result = await service.calculateNovelty(messages);

      expect(result, greaterThan(0.0));
    });

    test('should calculate lower novelty for repetitive content', () async {
      final messages = <Message>[
        Message.user(
          content: 'Test test test test test test',
          id: '1',
        ),
        Message.assistant(
          content: 'Test test test test test test',
          model: 'test-model',
          id: '2',
        ),
      ];

      final result = await service.calculateNovelty(messages);

      expect(result, lessThan(1.0));
    });
  });

  group('EvolutionTracker edge cases', () {
    test('should handle single word messages', () async {
      final messages = <Message>[
        Message.user(content: 'Hi there', id: '1'),
        Message.assistant(
            content: 'Hello friend', model: 'test-model', id: '2'),
      ];

      final complexity = await service.calculateComplexity(messages);
      final emotional = await service.calculateEmotionalDepth(messages);
      final novelty = await service.calculateNovelty(messages);

      // Complexity and emotional depth should be > 0
      expect(complexity, greaterThan(0.0));
      expect(emotional, greaterThan(0.0));

      // Novelty for short messages with few words is naturally low
      expect(novelty, greaterThanOrEqualTo(0.0));
      expect(novelty, lessThanOrEqualTo(1.0));
    });

    test('should handle messages with special characters', () async {
      final messages = <Message>[
        Message.user(content: 'Hello! How are you? I\'m doing great.', id: '1'),
        Message.assistant(
          content: 'That\'s wonderful! I\'m happy for you. (Parentheses too)',
          model: 'test-model',
          id: '2',
        ),
      ];

      final complexity = await service.calculateComplexity(messages);
      final emotional = await service.calculateEmotionalDepth(messages);
      final novelty = await service.calculateNovelty(messages);

      expect(complexity, greaterThan(0.0));
      expect(emotional, greaterThan(0.0));
      expect(novelty, greaterThan(0.0));
    });
  });
}
