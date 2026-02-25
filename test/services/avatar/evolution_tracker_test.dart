import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/database/drift_local_brain.dart' as db;
import 'package:cloudtolocalllm/database/drift_local_brain.dart';
import 'package:cloudtolocalllm/models/conversation.dart' as models;
import 'package:cloudtolocalllm/models/message.dart' as msg;
import 'package:cloudtolocalllm/services/avatar/evolution_tracker.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([LocalBrain])
import 'evolution_tracker_test.mocks.dart';

void main() {
  late EvolutionTracker tracker;
  late MockLocalBrain mockDb;

  setUp(() {
    mockDb = MockLocalBrain();
    tracker = EvolutionTracker(database: mockDb);
  });

  group('EvolutionTracker', () {
    test('trackConversation stores depth metrics', () async {
      final conversation = models.Conversation(
        id: 'conv1',
        title: 'Test Conversation',
        messages: [
          msg.Message.user(content: 'Hello, how are you?'),
          msg.Message.assistant(
            content: 'I am doing well, thank you for asking!',
            model: 'glm-4',
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(mockDb.addConversationDepthMetrics(any)).thenAnswer((_) async {});

      await tracker.trackConversation(conversation);

      verify(mockDb.addConversationDepthMetrics(argThat(
        isA<db.ConversationDepthMetricsCompanion>()
            .having((m) => m.conversationId.value, 'conversationId', 'conv1')
            .having((m) => m.complexityScore.value, 'complexityScore',
                greaterThan(0.0))
            .having((m) => m.emotionalDepth.value, 'emotionalDepth',
                greaterThanOrEqualTo(0.0))
            .having(
                (m) => m.noveltyScore.value, 'noveltyScore', greaterThan(0.0)),
      ))).called(1);
    });

    test('hasEvolutionPatterns returns true with sufficient depth', () async {
      when(mockDb.getDepthMetrics()).thenAnswer((_) async => [
            db.ConversationDepthMetric(
              id: '1',
              conversationId: 'conv1',
              complexityScore: 0.8,
              emotionalDepth: 0.7,
              noveltyScore: 0.6,
              timestamp: 1000,
            ),
            db.ConversationDepthMetric(
              id: '2',
              conversationId: 'conv2',
              complexityScore: 0.75,
              emotionalDepth: 0.8,
              noveltyScore: 0.7,
              timestamp: 2000,
            ),
            db.ConversationDepthMetric(
              id: '3',
              conversationId: 'conv3',
              complexityScore: 0.8,
              emotionalDepth: 0.7,
              noveltyScore: 0.6,
              timestamp: 3000,
            ),
            db.ConversationDepthMetric(
              id: '4',
              conversationId: 'conv4',
              complexityScore: 0.75,
              emotionalDepth: 0.8,
              noveltyScore: 0.7,
              timestamp: 4000,
            ),
            db.ConversationDepthMetric(
              id: '5',
              conversationId: 'conv5',
              complexityScore: 0.8,
              emotionalDepth: 0.7,
              noveltyScore: 0.6,
              timestamp: 5000,
            ),
          ]);

      final result = await tracker.hasEvolutionPatterns();

      expect(result, isTrue);
    });

    test('hasEvolutionPatterns returns false with insufficient depth',
        () async {
      when(mockDb.getDepthMetrics()).thenAnswer((_) async => [
            db.ConversationDepthMetric(
              id: '1',
              conversationId: 'conv1',
              complexityScore: 0.3,
              emotionalDepth: 0.2,
              noveltyScore: 0.3,
              timestamp: 1000,
            ),
            db.ConversationDepthMetric(
              id: '2',
              conversationId: 'conv2',
              complexityScore: 0.4,
              emotionalDepth: 0.3,
              noveltyScore: 0.2,
              timestamp: 2000,
            ),
          ]);

      final result = await tracker.hasEvolutionPatterns();

      expect(result, isFalse);
    });

    test('hasEvolutionPatterns returns false with low average novelty',
        () async {
      when(mockDb.getDepthMetrics()).thenAnswer((_) async => [
            db.ConversationDepthMetric(
              id: '1',
              conversationId: 'conv1',
              complexityScore: 0.8,
              emotionalDepth: 0.7,
              noveltyScore: 0.3,
              timestamp: 1000,
            ),
            db.ConversationDepthMetric(
              id: '2',
              conversationId: 'conv2',
              complexityScore: 0.8,
              emotionalDepth: 0.7,
              noveltyScore: 0.3,
              timestamp: 2000,
            ),
            db.ConversationDepthMetric(
              id: '3',
              conversationId: 'conv3',
              complexityScore: 0.8,
              emotionalDepth: 0.7,
              noveltyScore: 0.4,
              timestamp: 3000,
            ),
            db.ConversationDepthMetric(
              id: '4',
              conversationId: 'conv4',
              complexityScore: 0.8,
              emotionalDepth: 0.7,
              noveltyScore: 0.3,
              timestamp: 4000,
            ),
            db.ConversationDepthMetric(
              id: '5',
              conversationId: 'conv5',
              complexityScore: 0.8,
              emotionalDepth: 0.7,
              noveltyScore: 0.3,
              timestamp: 5000,
            ),
          ]);

      final result = await tracker.hasEvolutionPatterns();

      expect(result, isFalse);
    });

    test('calculateComplexity scores higher for longer messages', () async {
      final shortConversation = models.Conversation(
        id: 'conv1',
        title: 'Short',
        messages: [
          msg.Message.user(content: 'Hi'),
          msg.Message.assistant(content: 'Hello', model: 'glm-4'),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final longConversation = models.Conversation(
        id: 'conv2',
        title: 'Long',
        messages: [
          msg.Message.user(
              content: 'Can you explain how machine learning works in detail?'),
          msg.Message.assistant(
            content:
                'Machine learning is a subset of artificial intelligence that focuses on building systems that can learn from and make decisions based on data.',
            model: 'glm-4',
          ),
          msg.Message.user(content: 'What about neural networks?'),
          msg.Message.assistant(
            content:
                'Neural networks are computing systems inspired by biological neural networks that constitute animal brains.',
            model: 'glm-4',
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final shortScore =
          await tracker.calculateComplexity(shortConversation.messages);
      final longScore =
          await tracker.calculateComplexity(longConversation.messages);

      expect(longScore, greaterThan(shortScore));
    });

    test('calculateComplexity detects technical terms', () async {
      final technicalConversation = models.Conversation(
        id: 'conv1',
        title: 'Technical',
        messages: [
          msg.Message.user(content: 'How do I implement a REST API?'),
          msg.Message.assistant(
            content:
                'You can use Express.js with TypeScript to build a RESTful API with proper HTTP methods.',
            model: 'glm-4',
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final score =
          await tracker.calculateComplexity(technicalConversation.messages);

      expect(score, greaterThan(0.3));
    });

    test('calculateEmotionalDepth detects empathetic language', () async {
      final empatheticConversation = models.Conversation(
        id: 'conv1',
        title: 'Empathetic',
        messages: [
          msg.Message.user(content: 'I feel really sad today.'),
          msg.Message.assistant(
            content:
                'I understand how you feel. It is okay to feel sad sometimes. I am here for you.',
            model: 'glm-4',
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final score = await tracker
          .calculateEmotionalDepth(empatheticConversation.messages);

      expect(score, greaterThan(0.3));
    });

    test('calculateNovelty rewards vocabulary diversity', () async {
      final diverseConversation = models.Conversation(
        id: 'conv1',
        title: 'Diverse',
        messages: [
          msg.Message.user(content: 'Tell me about quantum physics.'),
          msg.Message.assistant(
            content:
                'Quantum physics explores the behavior of matter and energy at atomic scales.',
            model: 'glm-4',
          ),
          msg.Message.user(content: 'What about machine learning?'),
          msg.Message.assistant(
            content:
                'Machine learning algorithms can recognize patterns in data.',
            model: 'glm-4',
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repetitiveConversation = models.Conversation(
        id: 'conv2',
        title: 'Repetitive',
        messages: [
          msg.Message.user(content: 'Hello.'),
          msg.Message.assistant(content: 'Hello. How are you?', model: 'glm-4'),
          msg.Message.user(content: 'Hello.'),
          msg.Message.assistant(content: 'Hello. How are you?', model: 'glm-4'),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final diverseScore =
          await tracker.calculateNovelty(diverseConversation.messages);
      final repetitiveScore =
          await tracker.calculateNovelty(repetitiveConversation.messages);

      expect(diverseScore, greaterThan(repetitiveScore));
    });
  });
}
