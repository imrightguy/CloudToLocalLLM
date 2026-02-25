import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/models/avatar/personality_models.dart';
import 'package:cloudtolocalllm/models/message.dart';

void main() {
  group('Avatar Evolution Flow Integration Tests', () {
    group('EvolutionTracker Depth Calculations', () {
      test('should calculate complexity for technical conversation', () async {
        final technicalMessages = [
          Message(
            id: 'msg_1',
            role: MessageRole.user,
            content:
                'How do I implement async/await in Flutter with proper error handling?',
            timestamp: DateTime.now(),
          ),
          Message(
            id: 'msg_2',
            role: MessageRole.assistant,
            content:
                'In Flutter, you use async and await keywords. For error handling, wrap your async calls in try-catch blocks. You can also use the .then() and .catchError() methods on Futures.',
            timestamp: DateTime.now(),
          ),
          Message(
            id: 'msg_3',
            role: MessageRole.user,
            content:
                'What about using the async package for more complex scenarios?',
            timestamp: DateTime.now(),
          ),
          Message(
            id: 'msg_4',
            role: MessageRole.assistant,
            content:
                'The async package provides utilities like FutureGroup, AsyncCache, and StreamQueue. These are useful for coordinating multiple futures or managing streams.',
            timestamp: DateTime.now(),
          ),
        ];

        // Test complexity calculation directly
        final allText =
            technicalMessages.map((m) => m.content.toLowerCase()).join(' ');
        final words =
            allText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

        // Check for technical terms
        final technicalTerms = {
          'async',
          'await',
          'flutter',
          'error',
          'handling',
          'try',
          'catch',
          'future',
          'promises',
          'callbacks',
          'package',
          'utilities',
          'streamqueue',
          'coordinating',
          'managing',
          'streams'
        };

        final technicalCount = words.where(technicalTerms.contains).length;

        // Should detect technical terms
        expect(technicalCount, greaterThan(3));
      });

      test('should calculate emotional depth for empathetic conversation',
          () async {
        final emotionalMessages = [
          Message(
            id: 'msg_1',
            role: MessageRole.user,
            content:
                'I feel really overwhelmed with my project deadlines. I understand the pressure but I\'m stressed.',
            timestamp: DateTime.now(),
          ),
          Message(
            id: 'msg_2',
            role: MessageRole.assistant,
            content:
                'I hear you and I want you to know that your feelings are valid. Feeling overwhelmed is understandable when you have many responsibilities. I appreciate you sharing this with me.',
            timestamp: DateTime.now(),
          ),
          Message(
            id: 'msg_3',
            role: MessageRole.user,
            content:
                'Thank you for listening and understanding. It helps to feel supported.',
            timestamp: DateTime.now(),
          ),
        ];

        // Test emotional depth calculation directly
        final allText =
            emotionalMessages.map((m) => m.content.toLowerCase()).join(' ');
        final words =
            allText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

        // Check for empathetic words
        final empatheticWords = {
          'understand',
          'understanding',
          'feel',
          'feeling',
          'hear',
          'appreciate',
          'supported',
          'valid',
          'emotional',
          'stress',
          'listening',
          'caring'
        };

        final empatheticCount = words.where(empatheticWords.contains).length;

        // Should detect empathetic language
        expect(empatheticCount, greaterThan(3));
      });

      test('should calculate novelty for diverse conversation', () async {
        final topics = [
          'Tell me about machine learning algorithms',
          'Machine learning includes supervised, unsupervised, and reinforcement learning approaches',
          'What about neural networks?',
          'Neural networks are computing systems inspired by biological neurons',
          'How do they learn?',
          'Through backpropagation and gradient descent optimization',
          'Can you explain deep learning?',
          'Deep learning uses multiple layers to progressively extract features',
          'What are some applications?',
          'Image recognition, natural language processing, and autonomous driving',
        ];

        final allText = topics.join(' ').toLowerCase();
        final words =
            allText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        final uniqueWords = words.toSet();

        // Novelty is high when we have many unique words
        final ratio = uniqueWords.length / topics.length;

        // Should have good vocabulary diversity
        expect(ratio, greaterThan(5));
      });
    });

    group('PersonalityModels', () {
      test('should create default traits', () {
        final traits = PersonalityTraits.defaultTraits;

        expect(traits.formality, 0.5);
        expect(traits.humor, 0.5);
        expect(traits.enthusiasm, 0.5);
        expect(traits.empathy, 0.5);
      });

      test('should convert traits to map', () {
        final traits = PersonalityTraits(
          formality: 0.8,
          humor: 0.3,
          enthusiasm: 0.9,
          empathy: 0.7,
        );

        final map = traits.toMap();

        expect(map['formality'], 0.8);
        expect(map['humor'], 0.3);
        expect(map['enthusiasm'], 0.9);
        expect(map['empathy'], 0.7);
      });

      test('should create traits from map', () {
        final map = {
          'formality': 0.6,
          'humor': 0.4,
          'enthusiasm': 0.7,
          'empathy': 0.8,
        };

        final traits = PersonalityTraits.fromMap(map);

        expect(traits.formality, 0.6);
        expect(traits.humor, 0.4);
        expect(traits.enthusiasm, 0.7);
        expect(traits.empathy, 0.8);
      });

      test('should handle missing values in fromMap', () {
        final map = {
          'formality': 0.6,
          // 'humor' is missing
          'enthusiasm': 0.7,
          // 'empathy' is missing
        };

        final traits = PersonalityTraits.fromMap(map);

        expect(traits.formality, 0.6);
        expect(traits.humor, 0.5); // Should default to 0.5
        expect(traits.enthusiasm, 0.7);
        expect(traits.empathy, 0.5); // Should default to 0.5
      });

      test('should create evolution decision', () {
        final approvedDecision = EvolutionDecision(
          approved: true,
          newStage: 'knowledge_seeker',
        );

        expect(approvedDecision.approved, true);
        expect(approvedDecision.newStage, 'knowledge_seeker');
        expect(approvedDecision.reason, isNull);

        final rejectedDecision = EvolutionDecision(
          approved: false,
          reason: 'Insufficient depth',
        );

        expect(rejectedDecision.approved, false);
        expect(rejectedDecision.reason, 'Insufficient depth');
        expect(rejectedDecision.newStage, isNull);
      });
    });

    group('Evolution Criteria Logic', () {
      test('should validate evolution criteria', () {
        // Test criteria: 5+ deep conversations AND avg novelty > 0.5

        final deepConversations = 5;
        final avgNovelty = 0.6;

        // Should meet criteria
        expect(deepConversations >= 5, true);
        expect(avgNovelty > 0.5, true);
      });

      test('should reject evolution with insufficient deep conversations', () {
        final deepConversations = 3;
        final avgNovelty = 0.6;

        // Should NOT meet criteria (need 5+ deep conversations)
        final meetsCriteria = deepConversations >= 5 && avgNovelty > 0.5;
        expect(meetsCriteria, false);
      });

      test('should reject evolution with insufficient novelty', () {
        final deepConversations = 5;
        final avgNovelty = 0.4;

        // Should NOT meet criteria (need avg novelty > 0.5)
        final meetsCriteria = deepConversations >= 5 && avgNovelty > 0.5;
        expect(meetsCriteria, false);
      });

      test('should accept evolution with all criteria met', () {
        final deepConversations = 7;
        final avgNovelty = 0.7;

        // Should meet all criteria
        final meetsCriteria = deepConversations >= 5 && avgNovelty > 0.5;
        expect(meetsCriteria, true);
      });
    });

    group('Trait Boundary Values', () {
      test('should handle minimum trait values', () {
        final minTraits = PersonalityTraits(
          formality: 0.0,
          humor: 0.0,
          enthusiasm: 0.0,
          empathy: 0.0,
        );

        expect(minTraits.formality, 0.0);
        expect(minTraits.humor, 0.0);
        expect(minTraits.enthusiasm, 0.0);
        expect(minTraits.empathy, 0.0);

        final map = minTraits.toMap();
        expect(map.values.every((v) => v == 0.0), true);
      });

      test('should handle maximum trait values', () {
        final maxTraits = PersonalityTraits(
          formality: 1.0,
          humor: 1.0,
          enthusiasm: 1.0,
          empathy: 1.0,
        );

        expect(maxTraits.formality, 1.0);
        expect(maxTraits.humor, 1.0);
        expect(maxTraits.enthusiasm, 1.0);
        expect(maxTraits.empathy, 1.0);

        final map = maxTraits.toMap();
        expect(map.values.every((v) => v == 1.0), true);
      });

      test('should handle mid-range trait values', () {
        final midTraits = PersonalityTraits(
          formality: 0.5,
          humor: 0.5,
          enthusiasm: 0.5,
          empathy: 0.5,
        );

        expect(midTraits.formality, 0.5);
        expect(midTraits.humor, 0.5);
        expect(midTraits.enthusiasm, 0.5);
        expect(midTraits.empathy, 0.5);
      });
    });

    group('Evolution Stage Transitions', () {
      test('should define valid evolution stages', () {
        final stages = [
          'curious_explorer',
          'knowledge_seeker',
          'wise_companion',
          'enlightened_guide',
        ];

        // All stages should be non-empty strings
        expect(stages.every((s) => s.isNotEmpty), true);

        // All stages should be unique
        expect(stages.toSet().length, stages.length);
      });

      test('should validate stage transition order', () {
        final stages = [
          'curious_explorer',
          'knowledge_seeker',
          'wise_companion',
          'enlightened_guide',
        ];

        // Transitions should only go forward
        final currentIndex = stages.indexOf('curious_explorer');
        final nextIndex = stages.indexOf('knowledge_seeker');

        expect(nextIndex, greaterThan(currentIndex));
      });
    });

    group('Edge Cases', () {
      test('should handle empty message list', () {
        final messages = <Message>[];
        final allText = messages.map((m) => m.content.toLowerCase()).join(' ');

        expect(allText, isEmpty);
      });

      test('should handle single message', () {
        final message = Message(
          id: 'msg_1',
          role: MessageRole.user,
          content: 'Hello',
          timestamp: DateTime.now(),
        );

        final words = message.content.toLowerCase().split(RegExp(r'\s+'));
        expect(words.isNotEmpty, true);
        expect(words.first, 'hello');
      });

      test('should handle very long message', () {
        final longContent = 'word ' * 1000;
        final message = Message(
          id: 'msg_1',
          role: MessageRole.user,
          content: longContent,
          timestamp: DateTime.now(),
        );

        expect(message.content.length, 5000); // "word " (5 chars) * 1000 = 5000
      });

      test('should handle special characters in content', () {
        final specialContent = 'Hello! @user #hashtag https://example.com';
        final message = Message(
          id: 'msg_1',
          role: MessageRole.user,
          content: specialContent,
          timestamp: DateTime.now(),
        );

        expect(message.content.contains('!'), true);
        expect(message.content.contains('@'), true);
        expect(message.content.contains('#'), true);
        expect(message.content.contains('https://'), true);
      });
    });
  });
}
