import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/database/drift_local_brain.dart';
import 'package:cloudtolocalllm/models/avatar/personality_models.dart';
import 'package:cloudtolocalllm/services/avatar/personality_engine.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([LocalBrain])
import 'personality_engine_test.mocks.dart';

void main() {
  late PersonalityEngine engine;
  late MockLocalBrain mockDb;

  setUp(() {
    mockDb = MockLocalBrain();
    engine = PersonalityEngine(
      database: mockDb,
    );
  });

  group('PersonalityEngine', () {
    test('getPersonality returns current profile', () async {
      final mockProfile = AvatarPersonalityProfile(
        id: 'default',
        agentName: 'TestBot',
        personalityTraits:
            '{"formality":0.7,"humor":0.4,"enthusiasm":0.8,"empathy":0.9}',
        evolutionStage: 'base',
        conversationCount: 10,
        depthScore: 0.5,
        createdAt: 1000,
        updatedAt: 2000,
      );

      when(mockDb.getAvatarProfile()).thenAnswer((_) async => mockProfile);

      final result = await engine.getPersonality();

      expect(result.agentName, equals('TestBot'));
      expect(result.traits.formality, equals(0.7));
      expect(result.traits.humor, equals(0.4));
      expect(result.traits.enthusiasm, equals(0.8));
      expect(result.traits.empathy, equals(0.9));
    });

    test('updatePersonality writes to database', () async {
      final traits = PersonalityTraits(
        formality: 0.8,
        humor: 0.3,
        enthusiasm: 0.7,
        empathy: 0.9,
      );

      when(mockDb.updateAvatarTraits(any)).thenAnswer((_) async {});
      when(mockDb.getAvatarProfile())
          .thenAnswer((_) async => AvatarPersonalityProfile(
                id: 'default',
                agentName: 'TestBot',
                personalityTraits:
                    '{"formality":0.8,"humor":0.3,"enthusiasm":0.7,"empathy":0.9}',
                evolutionStage: 'base',
                conversationCount: 10,
                depthScore: 0.5,
                createdAt: 1000,
                updatedAt: 2000,
              ));

      await engine.updatePersonality(traits);

      verify(mockDb.updateAvatarTraits({
        'formality': 0.8,
        'humor': 0.3,
        'enthusiasm': 0.7,
        'empathy': 0.9,
      })).called(1);
    });

    test('validateEvolutionRequest approves with sufficient depth', () async {
      when(mockDb.getDepthMetrics()).thenAnswer((_) async => [
            ConversationDepthMetric(
              id: '1',
              conversationId: 'conv1',
              complexityScore: 0.8,
              emotionalDepth: 0.7,
              noveltyScore: 0.6,
              timestamp: 1000,
            ),
            ConversationDepthMetric(
              id: '2',
              conversationId: 'conv2',
              complexityScore: 0.75,
              emotionalDepth: 0.8,
              noveltyScore: 0.7,
              timestamp: 2000,
            ),
            ConversationDepthMetric(
              id: '3',
              conversationId: 'conv3',
              complexityScore: 0.8,
              emotionalDepth: 0.7,
              noveltyScore: 0.6,
              timestamp: 3000,
            ),
            ConversationDepthMetric(
              id: '4',
              conversationId: 'conv4',
              complexityScore: 0.75,
              emotionalDepth: 0.8,
              noveltyScore: 0.7,
              timestamp: 4000,
            ),
            ConversationDepthMetric(
              id: '5',
              conversationId: 'conv5',
              complexityScore: 0.8,
              emotionalDepth: 0.7,
              noveltyScore: 0.6,
              timestamp: 5000,
            ),
          ]);

      when(mockDb.getAvatarProfile())
          .thenAnswer((_) async => AvatarPersonalityProfile(
                id: 'default',
                agentName: 'TestBot',
                personalityTraits:
                    '{"formality":0.5,"humor":0.5,"enthusiasm":0.5,"empathy":0.5}',
                evolutionStage: 'base',
                conversationCount: 10,
                depthScore: 0.5,
                createdAt: 1000,
                updatedAt: 2000,
              ));

      when(mockDb.recordEvolution(
        fromStage: anyNamed('fromStage'),
        toStage: anyNamed('toStage'),
        triggerReason: anyNamed('triggerReason'),
        context: anyNamed('context'),
        confirmedBy: anyNamed('confirmedBy'),
      )).thenAnswer((_) async {});

      when(mockDb.updateEvolutionStage(any)).thenAnswer((_) async {});

      final result = await engine.validateEvolutionRequest(
        'curious_explorer',
        'self_reflection',
      );

      expect(result.approved, isTrue);
      expect(result.newStage, equals('curious_explorer'));
    });

    test('validateEvolutionRequest denies with insufficient depth', () async {
      when(mockDb.getDepthMetrics()).thenAnswer((_) async => [
            ConversationDepthMetric(
              id: '1',
              conversationId: 'conv1',
              complexityScore: 0.3,
              emotionalDepth: 0.2,
              noveltyScore: 0.3,
              timestamp: 1000,
            ),
          ]);

      final result = await engine.validateEvolutionRequest(
        'curious_explorer',
        'self_reflection',
      );

      expect(result.approved, isFalse);
      expect(result.reason, contains('Insufficient conversation depth'));
    });
  });
}
