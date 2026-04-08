import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloudtolocalllm/database/drift_local_brain.dart';
import 'package:cloudtolocalllm/services/avatar/personality_engine.dart';
import 'package:cloudtolocalllm/models/avatar/personality_models.dart';

@GenerateMocks([LocalBrain])
import 'personality_engine_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLocalBrain mockDatabase;
  late PersonalityEngine service;

  setUp(() {
    mockDatabase = MockLocalBrain();
    service = PersonalityEngine(database: mockDatabase);
  });

  group('PersonalityEngine Initialization', () {
    test('should initialize with dependencies', () {
      expect(service, isNotNull);
    });
  });

  group('PersonalityEngine getPersonality', () {
    test('should load personality from database', () async {
      final profile = AvatarPersonalityProfile(
        id: '1',
        agentName: 'TestAgent',
        personalityTraits:
            '{"formality":0.5,"humor":0.6,"enthusiasm":0.7,"empathy":0.8}',
        evolutionStage: 'knowledge_seeker',
        conversationCount: 10,
        depthScore: 0.75,
      );

      when(mockDatabase.getAvatarProfile()).thenAnswer((_) async => profile);

      final result = await service.getPersonality();

      expect(result.agentName, equals('TestAgent'));
      expect(result.evolutionStage, equals('knowledge_seeker'));
      expect(result.conversationCount, equals(10));
      expect(result.depthScore, equals(0.75));

      verify(mockDatabase.getAvatarProfile()).called(1);
    });

    test('should parse personality traits from JSON', () async {
      final profile = AvatarPersonalityProfile(
        id: '1',
        agentName: 'Agent',
        personalityTraits:
            '{"formality":0.8,"humor":0.4,"enthusiasm":0.6,"empathy":0.9}',
        evolutionStage: 'curious_explorer',
        conversationCount: 0,
        depthScore: 0.0,
      );

      when(mockDatabase.getAvatarProfile()).thenAnswer((_) async => profile);

      final result = await service.getPersonality();

      expect(result.traits.formality, equals(0.8));
      expect(result.traits.humor, equals(0.4));
      expect(result.traits.enthusiasm, equals(0.6));
      expect(result.traits.empathy, equals(0.9));
    });

    test('should throw StateError on database failure', () async {
      when(mockDatabase.getAvatarProfile())
          .thenThrow(Exception('Database error'));

      expect(() => service.getPersonality(), throwsA(isA<StateError>()));
    });
  });

  group('PersonalityEngine updatePersonality', () {
    test('should update personality traits', () async {
      final traits = PersonalityTraits(
        formality: 0.9,
        humor: 0.5,
        enthusiasm: 0.7,
        empathy: 0.85,
      );

      when(mockDatabase.updateAvatarTraits(any)).thenAnswer((_) async {});

      await service.updatePersonality(traits);

      verify(mockDatabase.updateAvatarTraits(any)).called(1);
    });

    test('should propagate database errors', () async {
      final traits = PersonalityTraits.defaultTraits;
      final testError = Exception('Update failed');

      when(mockDatabase.updateAvatarTraits(any)).thenThrow(testError);

      expect(() => service.updatePersonality(traits), throwsA(testError));
    });
  });

  group('PersonalityEngine updateAgentName', () {
    test('should update agent name', () async {
      const newName = 'NewAgent';

      when(mockDatabase.updateAgentName(newName)).thenAnswer((_) async {});

      await service.updateAgentName(newName);

      verify(mockDatabase.updateAgentName(newName)).called(1);
    });

    test('should propagate database errors', () async {
      const newName = 'Agent';
      final testError = Exception('Name update failed');

      when(mockDatabase.updateAgentName(newName)).thenThrow(testError);

      expect(() => service.updateAgentName(newName), throwsA(testError));
    });
  });

  group('PersonalityEngine validateEvolutionRequest', () {
    test('should approve valid evolution request with sufficient metrics',
        () async {
      const stage = 'knowledge_seeker';
      const reason = 'Ready to evolve';

      final profile = AvatarPersonalityProfile(
        id: '1',
        agentName: 'Agent',
        personalityTraits: '{}',
        evolutionStage: 'curious_explorer',
        conversationCount: 5,
        depthScore: 0.7,
      );

      final metrics = List.generate(
          5,
          (i) => ConversationDepthMetric(
                id: 'metric-$i',
                conversationId: 'conv-$i',
                complexityScore: 0.8,
                emotionalDepth: 0.7,
                noveltyScore: 0.9,
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ));

      when(mockDatabase.getAvatarProfile()).thenAnswer((_) async => profile);
      when(mockDatabase.getDepthMetrics()).thenAnswer((_) async => metrics);
      when(mockDatabase.recordEvolution(
        fromStage: anyNamed('fromStage'),
        toStage: anyNamed('toStage'),
        triggerReason: anyNamed('triggerReason'),
        context: anyNamed('context'),
        confirmedBy: anyNamed('confirmedBy'),
      )).thenAnswer((_) async {});
      when(mockDatabase.updateEvolutionStage(any)).thenAnswer((_) async {});

      final result = await service.validateEvolutionRequest(stage, reason);

      expect(result.approved, isTrue);
      expect(result.newStage, equals(stage));
      expect(result.reason, isNull);

      verify(mockDatabase.getDepthMetrics()).called(1);
      verify(mockDatabase.recordEvolution(
        fromStage: anyNamed('fromStage'),
        toStage: anyNamed('toStage'),
        triggerReason: anyNamed('triggerReason'),
        context: anyNamed('context'),
        confirmedBy: anyNamed('confirmedBy'),
      )).called(1);
      verify(mockDatabase.updateEvolutionStage(stage)).called(1);
    });

    test('should reject invalid evolution stage', () async {
      const stage = 'invalid_stage';
      const reason = 'Testing';

      final result = await service.validateEvolutionRequest(stage, reason);

      expect(result.approved, isFalse);
      expect(result.reason, contains('Invalid evolution stage'));

      verifyNever(mockDatabase.getDepthMetrics());
      verifyNever(mockDatabase.getAvatarProfile());
    });

    test('should reject evolution with insufficient deep conversations',
        () async {
      const stage = 'knowledge_seeker';
      const reason = 'Not ready';

      final metrics = List.generate(
          3,
          (i) => ConversationDepthMetric(
                id: 'metric-$i',
                conversationId: 'conv-$i',
                complexityScore: 0.8,
                emotionalDepth: 0.7,
                noveltyScore: 0.9,
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ));

      when(mockDatabase.getDepthMetrics()).thenAnswer((_) async => metrics);

      final result = await service.validateEvolutionRequest(stage, reason);

      expect(result.approved, isFalse);
      expect(result.reason, contains('need 5+ deep conversations'));
      expect(result.reason, contains('current: 3'));
    });

    test('should reject evolution with low average novelty', () async {
      const stage = 'knowledge_seeker';
      const reason = 'Testing novelty';

      final metrics = List.generate(
          5,
          (i) => ConversationDepthMetric(
                id: 'metric-$i',
                conversationId: 'conv-$i',
                complexityScore: 0.8,
                emotionalDepth: 0.7,
                noveltyScore: 0.3,
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ));

      when(mockDatabase.getDepthMetrics()).thenAnswer((_) async => metrics);

      final result = await service.validateEvolutionRequest(stage, reason);

      expect(result.approved, isFalse);
      expect(result.reason, contains('avg novelty > 0.5'));
    });

    test('should handle valid evolution stages', () async {
      const validStages = [
        'curious_explorer',
        'knowledge_seeker',
        'wise_companion',
        'enlightened_guide',
      ];

      for (final stage in validStages) {
        final profile = AvatarPersonalityProfile(
          id: '1',
          agentName: 'Agent',
          personalityTraits: '{}',
          evolutionStage: 'curious_explorer',
          conversationCount: 0,
          depthScore: 0.0,
        );

        final metrics = List.generate(
            5,
            (i) => ConversationDepthMetric(
                  id: 'metric-$i',
                  conversationId: 'conv-$i',
                  complexityScore: 0.8,
                  emotionalDepth: 0.7,
                  noveltyScore: 0.9,
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                ));

        when(mockDatabase.getAvatarProfile()).thenAnswer((_) async => profile);
        when(mockDatabase.getDepthMetrics()).thenAnswer((_) async => metrics);
        when(mockDatabase.recordEvolution(
          fromStage: anyNamed('fromStage'),
          toStage: anyNamed('toStage'),
          triggerReason: anyNamed('triggerReason'),
          context: anyNamed('context'),
          confirmedBy: anyNamed('confirmedBy'),
        )).thenAnswer((_) async {});
        when(mockDatabase.updateEvolutionStage(any)).thenAnswer((_) async {});

        final result = await service.validateEvolutionRequest(stage, 'test');

        expect(result.approved, isTrue);
        expect(result.newStage, equals(stage));
      }
    });

    test('should record evolution with context information', () async {
      const stage = 'knowledge_seeker';
      const reason = 'Ready to evolve';

      final profile = AvatarPersonalityProfile(
        id: '1',
        agentName: 'Agent',
        personalityTraits: '{}',
        evolutionStage: 'curious_explorer',
        conversationCount: 5,
        depthScore: 0.7,
      );

      final metrics = List.generate(
          5,
          (i) => ConversationDepthMetric(
                id: 'metric-$i',
                conversationId: 'conv-$i',
                complexityScore: 0.8,
                emotionalDepth: 0.7,
                noveltyScore: 0.9,
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ));

      when(mockDatabase.getAvatarProfile()).thenAnswer((_) async => profile);
      when(mockDatabase.getDepthMetrics()).thenAnswer((_) async => metrics);
      when(mockDatabase.recordEvolution(
        fromStage: anyNamed('fromStage'),
        toStage: anyNamed('toStage'),
        triggerReason: anyNamed('triggerReason'),
        context: anyNamed('context'),
        confirmedBy: anyNamed('confirmedBy'),
      )).thenAnswer((_) async {});
      when(mockDatabase.updateEvolutionStage(any)).thenAnswer((_) async {});

      await service.validateEvolutionRequest(stage, reason);

      verify(mockDatabase.recordEvolution(
        fromStage: anyNamed('fromStage'),
        toStage: anyNamed('toStage'),
        triggerReason: anyNamed('triggerReason'),
        context: anyNamed('context'),
        confirmedBy: anyNamed('confirmedBy'),
      )).called(1);
    });

    test('should propagate database errors during validation', () async {
      const stage = 'knowledge_seeker';
      const reason = 'Test';

      when(mockDatabase.getDepthMetrics())
          .thenThrow(Exception('Database error'));

      expect(() => service.validateEvolutionRequest(stage, reason),
          throwsA(isA<StateError>()));
    });
  });
}
