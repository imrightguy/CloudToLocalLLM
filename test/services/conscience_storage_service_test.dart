import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/database/drift_local_brain.dart';
import 'package:cloudtolocalllm/services/conscience_storage_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([LocalBrain])
import 'conscience_storage_service_test.mocks.dart';

void main() {
  late ConscienceStorageService service;
  late MockLocalBrain mockDb;

  setUp(() {
    mockDb = MockLocalBrain();
    service = ConscienceStorageService(database: mockDb);
  });

  group('ConscienceStorageService - Thoughts', () {
    test('writeThought creates new thought with valid data', () async {
      const agent = 'Benjamin';
      const thoughtType = 'review';
      const content = 'I approve this action';
      const channel = 'general';

      when(mockDb.insertThought(any)).thenAnswer((_) async {});

      final result = await service.writeThought(
        agent: agent,
        thoughtType: thoughtType,
        content: content,
        channel: channel,
      );

      expect(result['agent'], equals(agent));
      expect(result['thought_type'], equals(thoughtType));
      expect(result['content'], equals(content));
      expect(result['channel'], equals(channel));
      expect(result['id'], isNotEmpty);
      expect(result['timestamp'], isNotEmpty);
      expect(result['metadata'], isNull);

      verify(mockDb.insertThought(any)).called(1);
    });

    test('writeThought includes metadata when provided', () async {
      const agent = 'Harper';
      const thoughtType = 'research';
      const content = 'Found relevant documentation';
      final metadata = {'source': 'docs', 'confidence': 0.9};

      when(mockDb.insertThought(any)).thenAnswer((_) async {});

      final result = await service.writeThought(
        agent: agent,
        thoughtType: thoughtType,
        content: content,
        metadata: metadata,
      );

      expect(result['metadata'], equals(metadata));
      verify(mockDb.insertThought(any)).called(1);
    });

    test('getThoughts retrieves all thoughts when no filters', () async {
      final mockThoughts = [
        AgentThought(
          id: '1',
          timestamp: DateTime(2024, 1, 1),
          channel: 'general',
          agent: 'Zoidbot',
          thoughtType: 'intention',
          content: 'I will update config',
          metadata: null,
        ),
        AgentThought(
          id: '2',
          timestamp: DateTime(2024, 1, 2),
          channel: 'general',
          agent: 'Benjamin',
          thoughtType: 'review',
          content: 'I approve',
          metadata: null,
        ),
      ];

      when(mockDb.getRecentThoughts(limit: 50))
          .thenAnswer((_) async => mockThoughts);

      final result = await service.getThoughts();

      expect(result.length, equals(2));
      expect(result[0]['agent'], equals('Zoidbot'));
      expect(result[1]['agent'], equals('Benjamin'));

      verify(mockDb.getRecentThoughts(limit: 50)).called(1);
    });

    test('getThoughts filters by agent', () async {
      const agent = 'Benjamin';
      final mockThoughts = [
        AgentThought(
          id: '1',
          timestamp: DateTime(2024, 1, 1),
          channel: 'general',
          agent: agent,
          thoughtType: 'review',
          content: 'I approve',
          metadata: null,
        ),
      ];

      when(mockDb.getThoughtsByAgent(agent, limit: 50))
          .thenAnswer((_) async => mockThoughts);

      final result = await service.getThoughts(agent: agent);

      expect(result.length, equals(1));
      expect(result[0]['agent'], equals(agent));

      verify(mockDb.getThoughtsByAgent(agent, limit: 50)).called(1);
    });

    test('getThoughts filters by channel', () async {
      const channel = 'security';
      final mockThoughts = [
        AgentThought(
          id: '1',
          timestamp: DateTime(2024, 1, 1),
          channel: channel,
          agent: 'Benjamin',
          thoughtType: 'review',
          content: 'This is a security risk',
          metadata: null,
        ),
      ];

      when(mockDb.getThoughtsByChannel(channel, limit: 50))
          .thenAnswer((_) async => mockThoughts);

      final result = await service.getThoughts(channel: channel);

      expect(result.length, equals(1));
      expect(result[0]['channel'], equals(channel));

      verify(mockDb.getThoughtsByChannel(channel, limit: 50)).called(1);
    });

    test('getThoughts filters by thoughtType', () async {
      const thoughtType = 'review';
      final mockThoughts = [
        AgentThought(
          id: '1',
          timestamp: DateTime(2024, 1, 1),
          channel: 'general',
          agent: 'Benjamin',
          thoughtType: thoughtType,
          content: 'I approve',
          metadata: null,
        ),
      ];

      when(mockDb.getThoughtsByType(thoughtType, limit: 50))
          .thenAnswer((_) async => mockThoughts);

      final result = await service.getThoughts(thoughtType: thoughtType);

      expect(result.length, equals(1));
      expect(result[0]['thought_type'], equals(thoughtType));

      verify(mockDb.getThoughtsByType(thoughtType, limit: 50)).called(1);
    });

    test('getThoughts respects custom limit', () async {
      when(mockDb.getRecentThoughts(limit: 10)).thenAnswer((_) async => []);

      await service.getThoughts(limit: 10);

      verify(mockDb.getRecentThoughts(limit: 10)).called(1);
    });

    test('getThoughts decodes metadata JSON', () async {
      final metadata = {'key': 'value'};
      final encodedMetadata = '{"key":"value"}';
      final mockThoughts = [
        AgentThought(
          id: '1',
          timestamp: DateTime(2024, 1, 1),
          channel: 'general',
          agent: 'Zoidbot',
          thoughtType: 'intention',
          content: 'I will update config',
          metadata: encodedMetadata,
        ),
      ];

      when(mockDb.getRecentThoughts(limit: 50))
          .thenAnswer((_) async => mockThoughts);

      final result = await service.getThoughts();

      expect(result[0]['metadata'], equals(metadata));
    });
  });

  group('ConscienceStorageService - Decisions', () {
    test('writeDecision creates pending decision when no verdict', () async {
      const action = 'Update config file';
      const riskLevel = 'medium';

      when(mockDb.insertDecision(any)).thenAnswer((_) async {});

      final result = await service.writeDecision(
        action: action,
        riskLevel: riskLevel,
      );

      expect(result['action'], equals(action));
      expect(result['risk_level'], equals(riskLevel));
      expect(result['status'], equals('pending'));
      expect(result['verdict'], isNull);
      expect(result['reviewer'], isNull);
      expect(result['reasoning'], isNull);

      verify(mockDb.insertDecision(any)).called(1);
    });

    test('writeDecision creates reviewed decision with verdict', () async {
      const action = 'Update config file';
      const riskLevel = 'high';
      const verdict = 'APPROVED';
      const reviewer = 'Benjamin';
      const reasoning = 'Safe change';

      when(mockDb.insertDecision(any)).thenAnswer((_) async {});

      final result = await service.writeDecision(
        action: action,
        riskLevel: riskLevel,
        verdict: verdict,
        reviewer: reviewer,
        reasoning: reasoning,
      );

      expect(result['verdict'], equals(verdict));
      expect(result['reviewer'], equals(reviewer));
      expect(result['reasoning'], equals(reasoning));
      expect(result['status'], equals('reviewed'));

      verify(mockDb.insertDecision(any)).called(1);
    });

    test('submitDecisionVerdict updates existing decision', () async {
      const decisionId = 'decision-123';
      const verdict = 'APPROVED';
      const reviewer = 'Benjamin';
      const reasoning = 'All checks passed';

      final updatedDecision = ConscienceDecision(
        id: decisionId,
        timestamp: DateTime(2024, 1, 1),
        action: 'Update config',
        riskLevel: 'medium',
        verdict: verdict,
        reviewer: reviewer,
        reasoning: reasoning,
        status: 'reviewed',
      );

      when(mockDb.updateDecisionVerdict(
        decisionId,
        verdict,
        reviewer,
        reasoning,
      )).thenAnswer((_) async {});

      when(mockDb.getDecisionById(decisionId))
          .thenAnswer((_) async => updatedDecision);

      final result = await service.submitDecisionVerdict(
        decisionId: decisionId,
        verdict: verdict,
        reviewer: reviewer,
        reasoning: reasoning,
      );

      expect(result['id'], equals(decisionId));
      expect(result['verdict'], equals(verdict));
      expect(result['reviewer'], equals(reviewer));
      expect(result['reasoning'], equals(reasoning));
      expect(result['status'], equals('reviewed'));

      verify(mockDb.updateDecisionVerdict(
        decisionId,
        verdict,
        reviewer,
        reasoning,
      )).called(1);
      verify(mockDb.getDecisionById(decisionId)).called(1);
    });

    test('submitDecisionVerdict throws when decision not found', () async {
      const decisionId = 'nonexistent';

      when(mockDb.updateDecisionVerdict(any, any, any, any))
          .thenAnswer((_) async {});
      when(mockDb.getDecisionById(decisionId)).thenAnswer((_) async => null);

      expect(
        () => service.submitDecisionVerdict(
          decisionId: decisionId,
          verdict: 'APPROVED',
          reviewer: 'Benjamin',
          reasoning: 'OK',
        ),
        throwsStateError,
      );
    });

    test('getDecisions retrieves all when no filters', () async {
      final mockDecisions = [
        ConscienceDecision(
          id: '1',
          timestamp: DateTime(2024, 1, 1),
          action: 'Update config',
          riskLevel: 'medium',
          verdict: 'APPROVED',
          reviewer: 'Benjamin',
          reasoning: 'Safe',
          status: 'reviewed',
        ),
        ConscienceDecision(
          id: '2',
          timestamp: DateTime(2024, 1, 2),
          action: 'Delete file',
          riskLevel: 'high',
          verdict: null,
          reviewer: null,
          reasoning: null,
          status: 'pending',
        ),
      ];

      when(mockDb.getAllDecisions(limit: 50))
          .thenAnswer((_) async => mockDecisions);

      final result = await service.getDecisions();

      expect(result.length, equals(2));
      expect(result[0]['status'], equals('reviewed'));
      expect(result[1]['status'], equals('pending'));

      verify(mockDb.getAllDecisions(limit: 50)).called(1);
    });

    test('getDecisions filters by status', () async {
      const status = 'pending';
      final mockDecisions = [
        ConscienceDecision(
          id: '1',
          timestamp: DateTime(2024, 1, 1),
          action: 'Update config',
          riskLevel: 'medium',
          verdict: null,
          reviewer: null,
          reasoning: null,
          status: status,
        ),
      ];

      when(mockDb.getDecisionsByStatus(status, limit: 50))
          .thenAnswer((_) async => mockDecisions);

      final result = await service.getDecisions(status: status);

      expect(result.length, equals(1));
      expect(result[0]['status'], equals(status));

      verify(mockDb.getDecisionsByStatus(status, limit: 50)).called(1);
    });

    test('getDecisions filters by riskLevel', () async {
      const riskLevel = 'high';
      final mockDecisions = [
        ConscienceDecision(
          id: '1',
          timestamp: DateTime(2024, 1, 1),
          action: 'Delete file',
          riskLevel: riskLevel,
          verdict: null,
          reviewer: null,
          reasoning: null,
          status: 'pending',
        ),
      ];

      when(mockDb.getDecisionsByRiskLevel(riskLevel, limit: 50))
          .thenAnswer((_) async => mockDecisions);

      final result = await service.getDecisions(riskLevel: riskLevel);

      expect(result.length, equals(1));
      expect(result[0]['risk_level'], equals(riskLevel));

      verify(mockDb.getDecisionsByRiskLevel(riskLevel, limit: 50)).called(1);
    });

    test('getDecisions respects custom limit', () async {
      when(mockDb.getAllDecisions(limit: 10)).thenAnswer((_) async => []);

      await service.getDecisions(limit: 10);

      verify(mockDb.getAllDecisions(limit: 10)).called(1);
    });
  });

  group('ConscienceStorageService - Edge Cases', () {
    test('handles empty thought list', () async {
      when(mockDb.getRecentThoughts(limit: 50)).thenAnswer((_) async => []);

      final result = await service.getThoughts();

      expect(result, isEmpty);
      verify(mockDb.getRecentThoughts(limit: 50)).called(1);
    });

    test('handles empty decision list', () async {
      when(mockDb.getAllDecisions(limit: 50)).thenAnswer((_) async => []);

      final result = await service.getDecisions();

      expect(result, isEmpty);
      verify(mockDb.getAllDecisions(limit: 50)).called(1);
    });

    test('generates unique IDs for multiple thoughts', () async {
      when(mockDb.insertThought(any)).thenAnswer((_) async {});

      final thought1 = await service.writeThought(
        agent: 'Agent1',
        thoughtType: 'type1',
        content: 'content1',
      );

      final thought2 = await service.writeThought(
        agent: 'Agent2',
        thoughtType: 'type2',
        content: 'content2',
      );

      expect(thought1['id'], isNotEmpty);
      expect(thought2['id'], isNotEmpty);
      expect(thought1['id'], isNot(equals(thought2['id'])));

      verify(mockDb.insertThought(any)).called(2);
    });

    test('generates unique IDs for multiple decisions', () async {
      when(mockDb.insertDecision(any)).thenAnswer((_) async {});

      final decision1 = await service.writeDecision(
        action: 'action1',
        riskLevel: 'low',
      );

      final decision2 = await service.writeDecision(
        action: 'action2',
        riskLevel: 'medium',
      );

      expect(decision1['id'], isNotEmpty);
      expect(decision2['id'], isNotEmpty);
      expect(decision1['id'], isNot(equals(decision2['id'])));

      verify(mockDb.insertDecision(any)).called(2);
    });
  });
}
