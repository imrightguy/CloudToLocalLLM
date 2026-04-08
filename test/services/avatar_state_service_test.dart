import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloudtolocalllm/database/drift_local_brain.dart';
import 'package:cloudtolocalllm/services/avatar/avatar_state_service.dart';
import 'package:cloudtolocalllm/services/avatar/personality_engine.dart';
import 'package:cloudtolocalllm/services/avatar/evolution_tracker.dart';
import 'package:cloudtolocalllm/services/avatar/markdown_sync_service.dart';
import 'package:cloudtolocalllm/models/avatar/personality_models.dart';

@GenerateMocks([
  LocalBrain,
  PersonalityEngine,
  EvolutionTracker,
  MarkdownSyncService,
])
import 'avatar_state_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLocalBrain mockDatabase;
  late MockPersonalityEngine mockPersonalityEngine;
  late MockEvolutionTracker mockEvolutionTracker;
  late MockMarkdownSyncService mockMarkdownSyncService;
  late AvatarStateService service;

  setUp(() {
    mockDatabase = MockLocalBrain();
    mockPersonalityEngine = MockPersonalityEngine();
    mockEvolutionTracker = MockEvolutionTracker();
    mockMarkdownSyncService = MockMarkdownSyncService();

    service = AvatarStateService(
      database: mockDatabase,
      personalityEngine: mockPersonalityEngine,
      evolutionTracker: mockEvolutionTracker,
      markdownSyncService: mockMarkdownSyncService,
    );
  });

  tearDown(() {
    service.dispose();
  });

  group('AvatarStateService Initialization', () {
    test('should initialize with dependencies', () {
      expect(service.currentProfile, isNull);
      expect(service.isLoading, isFalse);
      expect(service.error, isNull);
      expect(service.isReady, isFalse);
      expect(service.evolutionStage, equals('curious_explorer'));
      expect(service.agentName, equals('Agent'));
    });

    test('should have correct default traits', () {
      // Check individual traits since PersonalityTraits doesn't override ==
      expect(service.traits.formality,
          equals(PersonalityTraits.defaultTraits.formality));
      expect(
          service.traits.humor, equals(PersonalityTraits.defaultTraits.humor));
      expect(service.traits.enthusiasm,
          equals(PersonalityTraits.defaultTraits.enthusiasm));
      expect(service.traits.empathy,
          equals(PersonalityTraits.defaultTraits.empathy));
    });

    test('should have zero conversation count initially', () {
      expect(service.conversationCount, equals(0));
    });

    test('should have zero depth score initially', () {
      expect(service.depthScore, equals(0.0));
    });
  });

  group('AvatarStateService loadProfile', () {
    test('should load profile successfully', () async {
      final testProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'knowledge_seeker',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 10,
        depthScore: 0.8,
      );

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => testProfile);

      await service.loadProfile();

      expect(service.currentProfile, equals(testProfile));
      expect(service.isLoading, isFalse);
      expect(service.error, isNull);

      verify(mockPersonalityEngine.getPersonality()).called(1);
    });

    test('should set loading state during load', () async {
      final testProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      bool loadingStarted = false;
      service.addListener(() {
        if (service.isLoading && !loadingStarted) {
          loadingStarted = true;
        }
      });

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => testProfile);

      await service.loadProfile();

      expect(loadingStarted, isTrue);
    });

    test('should handle load error', () async {
      final testError = Exception('Database error');
      when(mockPersonalityEngine.getPersonality()).thenThrow(testError);

      await service.loadProfile();

      expect(service.currentProfile, isNull);
      expect(service.isLoading, isFalse);
      expect(service.error, isNotNull);
      expect(service.error, contains('Database error'));
    });

    test('should notify listeners on successful load', () async {
      final testProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      int notifyCount = 0;
      service.addListener(() {
        notifyCount++;
      });

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => testProfile);

      await service.loadProfile();

      expect(notifyCount, greaterThan(0));
    });

    test('should update getters after load', () async {
      final testProfile = ExtendedAvatarProfile(
        agentName: 'NewAgent',
        evolutionStage: 'wise_companion',
        traits: PersonalityTraits(
          formality: 0.8,
          humor: 0.3,
          enthusiasm: 0.7,
          empathy: 0.9,
        ),
        conversationCount: 15,
        depthScore: 0.75,
      );

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => testProfile);

      await service.loadProfile();

      expect(service.agentName, equals('NewAgent'));
      expect(service.evolutionStage, equals('wise_companion'));
      expect(service.conversationCount, equals(15));
      expect(service.depthScore, equals(0.75));
      expect(service.isReady, isTrue);
    });
  });

  group('AvatarStateService updateTraits', () {
    test('should update traits successfully', () async {
      final initialProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      final newTraits = PersonalityTraits(
        formality: 0.9,
        humor: 0.4,
        enthusiasm: 0.6,
        empathy: 0.8,
      );

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => initialProfile);
      when(mockPersonalityEngine.updatePersonality(newTraits))
          .thenAnswer((_) async {});
      when(mockMarkdownSyncService.syncPersonality(any))
          .thenAnswer((_) async {});

      await service.loadProfile();
      await service.updateTraits(newTraits);

      verify(mockPersonalityEngine.updatePersonality(newTraits)).called(1);
      verify(mockMarkdownSyncService.syncPersonality(any)).called(1);
    });

    test('should reload profile after update', () async {
      final initialProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      final newTraits = PersonalityTraits.defaultTraits;

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => initialProfile);
      when(mockPersonalityEngine.updatePersonality(newTraits))
          .thenAnswer((_) async {});
      when(mockMarkdownSyncService.syncPersonality(any))
          .thenAnswer((_) async {});

      await service.loadProfile();
      await service.updateTraits(newTraits);

      // getPersonality should be called at least twice
      // Once for initial load, once for reload
      verify(mockPersonalityEngine.getPersonality())
          .called(greaterThanOrEqualTo(2));
    });

    test('should handle update error', () async {
      final initialProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      final newTraits = PersonalityTraits.defaultTraits;
      final testError = Exception('Update failed');

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => initialProfile);
      when(mockPersonalityEngine.updatePersonality(newTraits))
          .thenThrow(testError);

      await service.loadProfile();

      expect(() => service.updateTraits(newTraits), throwsA(testError));
      expect(service.error, contains('Update failed'));
    });
  });

  group('AvatarStateService updateAgentName', () {
    test('should update agent name successfully', () async {
      final initialProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      const newName = 'NewAgentName';

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => initialProfile);
      when(mockPersonalityEngine.updateAgentName(newName))
          .thenAnswer((_) async {});
      when(mockMarkdownSyncService.syncPersonality(any))
          .thenAnswer((_) async {});

      await service.loadProfile();
      await service.updateAgentName(newName);

      verify(mockPersonalityEngine.updateAgentName(newName)).called(1);
      verify(mockMarkdownSyncService.syncPersonality(any)).called(1);
    });

    test('should reload profile after name update', () async {
      final initialProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      final updatedProfile = ExtendedAvatarProfile(
        agentName: 'UpdatedName',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      const newName = 'UpdatedName';

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => initialProfile);
      when(mockPersonalityEngine.updateAgentName(newName))
          .thenAnswer((_) async {});
      when(mockMarkdownSyncService.syncPersonality(any))
          .thenAnswer((_) async {});

      await service.loadProfile();

      // Mock should return updated profile on subsequent calls
      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => updatedProfile);

      await service.updateAgentName(newName);

      expect(service.agentName, equals('UpdatedName'));
    });

    test('should handle update error', () async {
      final initialProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      const newName = 'NewName';
      final testError = Exception('Name update failed');

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => initialProfile);
      when(mockPersonalityEngine.updateAgentName(newName)).thenThrow(testError);

      await service.loadProfile();

      expect(() => service.updateAgentName(newName), throwsA(testError));
      expect(service.error, contains('Name update failed'));
    });
  });

  group('AvatarStateService requestEvolution', () {
    test('should request evolution successfully', () async {
      final initialProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 5,
        depthScore: 0.6,
      );

      const stage = 'knowledge_seeker';
      const reason = 'Ready to learn';

      final decision = EvolutionDecision(
        approved: true,
        newStage: stage,
        reason: null,
      );

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => initialProfile);
      when(mockPersonalityEngine.validateEvolutionRequest(stage, reason))
          .thenAnswer((_) async => decision);
      when(mockMarkdownSyncService.syncAll(any)).thenAnswer((_) async {});

      await service.loadProfile();
      final result = await service.requestEvolution(stage, reason);

      expect(result.approved, isTrue);
      expect(result.newStage, equals(stage));

      verify(mockPersonalityEngine.validateEvolutionRequest(stage, reason))
          .called(1);
    });

    test('should sync all data on approved evolution', () async {
      final initialProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 5,
        depthScore: 0.6,
      );

      const stage = 'knowledge_seeker';
      const reason = 'Evolution ready';

      final decision = EvolutionDecision(
        approved: true,
        newStage: stage,
        reason: null,
      );

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => initialProfile);
      when(mockPersonalityEngine.validateEvolutionRequest(stage, reason))
          .thenAnswer((_) async => decision);
      when(mockMarkdownSyncService.syncAll(any)).thenAnswer((_) async {});

      await service.loadProfile();
      await service.requestEvolution(stage, reason);

      verify(mockMarkdownSyncService.syncAll(any)).called(1);
    });

    test('should not sync on rejected evolution', () async {
      final initialProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 2,
        depthScore: 0.3,
      );

      const stage = 'knowledge_seeker';
      const reason = 'Not enough conversations';

      final decision = EvolutionDecision(
        approved: false,
        newStage: null,
        reason: 'Need 5 deep conversations',
      );

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => initialProfile);
      when(mockPersonalityEngine.validateEvolutionRequest(stage, reason))
          .thenAnswer((_) async => decision);

      await service.loadProfile();
      await service.requestEvolution(stage, reason);

      verifyNever(mockMarkdownSyncService.syncAll(any));
    });

    test('should handle evolution error', () async {
      final initialProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      const stage = 'knowledge_seeker';
      const reason = 'Test evolution';
      final testError = Exception('Evolution failed');

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => initialProfile);
      when(mockPersonalityEngine.validateEvolutionRequest(stage, reason))
          .thenThrow(testError);

      await service.loadProfile();

      expect(() => service.requestEvolution(stage, reason), throwsA(testError));
      expect(service.error, contains('Evolution failed'));
    });
  });

  group('AvatarStateService trackConversationDepth', () {
    test('should track conversation depth successfully', () async {
      final initialProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => initialProfile);
      when(mockDatabase.addConversationDepthMetrics(any))
          .thenAnswer((_) async {});

      await service.loadProfile();
      await service.trackConversationDepth(
        'conv-1',
        0.8,
        0.7,
        0.9,
      );

      verify(mockDatabase.addConversationDepthMetrics(any)).called(1);
    });

    test('should reload profile after tracking', () async {
      final initialProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => initialProfile);
      when(mockDatabase.addConversationDepthMetrics(any))
          .thenAnswer((_) async {});

      await service.loadProfile();
      await service.trackConversationDepth('conv-1', 0.8, 0.7, 0.9);

      // getPersonality should be called twice (initial load + reload)
      verify(mockPersonalityEngine.getPersonality())
          .called(greaterThanOrEqualTo(2));
    });

    test('should handle tracking error gracefully', () async {
      final initialProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      final testError = Exception('Tracking failed');

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => initialProfile);
      when(mockDatabase.addConversationDepthMetrics(any)).thenThrow(testError);

      await service.loadProfile();
      await service.trackConversationDepth('conv-1', 0.8, 0.7, 0.9);

      expect(service.error, contains('Tracking failed'));
    });
  });

  group('AvatarStateService canEvolve', () {
    test('should check if evolution is possible', () async {
      when(mockEvolutionTracker.hasEvolutionPatterns())
          .thenAnswer((_) async => true);

      final result = await service.canEvolve();

      expect(result, isTrue);
      verify(mockEvolutionTracker.hasEvolutionPatterns()).called(1);
    });

    test('should return false when evolution not possible', () async {
      when(mockEvolutionTracker.hasEvolutionPatterns())
          .thenAnswer((_) async => false);

      final result = await service.canEvolve();

      expect(result, isFalse);
    });
  });

  group('AvatarStateService getEvolutionRequirements', () {
    test('should return evolution requirements', () async {
      final metrics = [
        ConversationDepthMetric(
          id: 'metric-1',
          conversationId: 'conv-1',
          complexityScore: 0.8,
          emotionalDepth: 0.7,
          noveltyScore: 0.9,
          timestamp: DateTime(2025, 1, 1).millisecondsSinceEpoch,
        ),
        ConversationDepthMetric(
          id: 'metric-2',
          conversationId: 'conv-2',
          complexityScore: 0.9,
          emotionalDepth: 0.8,
          noveltyScore: 0.7,
          timestamp: DateTime(2025, 1, 2).millisecondsSinceEpoch,
        ),
      ];

      when(mockDatabase.getDepthMetrics()).thenAnswer((_) async => metrics);

      final result = await service.getEvolutionRequirements();

      expect(result['deep_conversations'], equals(2));
      expect(result['required_deep_conversations'], equals(5));
      expect(result['average_novelty'], equals(0.8));
      expect(result['required_novelty'], equals(0.5));
      expect(result['can_evolve'], isFalse);

      verify(mockDatabase.getDepthMetrics()).called(1);
    });

    test('should handle empty metrics', () async {
      when(mockDatabase.getDepthMetrics()).thenAnswer((_) async => []);

      final result = await service.getEvolutionRequirements();

      expect(result['deep_conversations'], equals(0));
      expect(result['average_novelty'], equals(0.0));
      expect(result['can_evolve'], isFalse);
    });

    test('should return true when requirements met', () async {
      final metrics = List.generate(
          5,
          (i) => ConversationDepthMetric(
                id: 'metric-$i',
                conversationId: 'conv-$i',
                complexityScore: 0.8,
                emotionalDepth: 0.7,
                noveltyScore: 0.9,
                timestamp: DateTime(2025, 1, 1).millisecondsSinceEpoch,
              ));

      when(mockDatabase.getDepthMetrics()).thenAnswer((_) async => metrics);

      final result = await service.getEvolutionRequirements();

      expect(result['can_evolve'], isTrue);
    });
  });

  group('AvatarStateService clearError', () {
    test('should clear error state', () async {
      final testError = Exception('Test error');

      when(mockPersonalityEngine.getPersonality()).thenThrow(testError);

      await service.loadProfile();
      expect(service.error, isNotNull);

      service.clearError();
      expect(service.error, isNull);
    });

    test('should notify listeners when clearing error', () async {
      final testError = Exception('Test error');

      when(mockPersonalityEngine.getPersonality()).thenThrow(testError);

      await service.loadProfile();

      int notifyCount = 0;
      service.addListener(() {
        notifyCount++;
      });

      service.clearError();

      expect(notifyCount, greaterThan(0));
    });
  });

  group('AvatarStateService State Management', () {
    test('should notify listeners on state changes', () async {
      final testProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      int notifyCount = 0;
      service.addListener(() {
        notifyCount++;
      });

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => testProfile);

      await service.loadProfile();

      expect(notifyCount, greaterThan(0));
    });

    test('should handle multiple listener additions', () async {
      final testProfile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      int notifyCount1 = 0;
      int notifyCount2 = 0;

      service.addListener(() => notifyCount1++);
      service.addListener(() => notifyCount2++);

      when(mockPersonalityEngine.getPersonality())
          .thenAnswer((_) async => testProfile);

      await service.loadProfile();

      expect(notifyCount1, greaterThan(0));
      expect(notifyCount2, greaterThan(0));
      expect(notifyCount1, equals(notifyCount2));
    });
  });
}
