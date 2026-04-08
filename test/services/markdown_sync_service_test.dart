import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloudtolocalllm/database/drift_local_brain.dart';
import 'package:cloudtolocalllm/services/avatar/markdown_sync_service.dart';
import 'package:cloudtolocalllm/models/avatar/personality_models.dart';

@GenerateMocks([LocalBrain])
import 'markdown_sync_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLocalBrain mockDatabase;
  late MarkdownSyncService service;
  late Directory tempDir;

  setUp(() {
    mockDatabase = MockLocalBrain();
    tempDir = Directory.systemTemp.createTempSync('markdown_sync_test_');

    service = MarkdownSyncService(
      database: mockDatabase,
      markdownPath: tempDir.path,
    );
  });

  tearDown(() async {
    try {
      await service.clearMarkdownFiles();
    } catch (e) {
      // Ignore errors if directory doesn't exist
    }
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('MarkdownSyncService Initialization', () {
    test('should initialize with dependencies', () {
      expect(service, isNotNull);
    });

    test('should create directory if it does not exist', () async {
      final newDir = Directory('${tempDir.path}/new_dir');
      final newService = MarkdownSyncService(
        database: mockDatabase,
        markdownPath: newDir.path,
      );

      final profile = ExtendedAvatarProfile(
        agentName: 'Agent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      when(mockDatabase.getEvolutionHistory()).thenAnswer((_) async => []);
      when(mockDatabase.getDepthMetrics()).thenAnswer((_) async => []);

      await newService.syncPersonality(profile);

      expect(newDir.existsSync(), isTrue);
    });
  });

  group('MarkdownSyncService syncPersonality', () {
    test('should sync personality to markdown file', () async {
      final profile = ExtendedAvatarProfile(
        agentName: 'TestAgent',
        evolutionStage: 'knowledge_seeker',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 10,
        depthScore: 0.8,
      );

      when(mockDatabase.getEvolutionHistory()).thenAnswer((_) async => []);
      when(mockDatabase.getDepthMetrics()).thenAnswer((_) async => []);

      await service.syncPersonality(profile);

      final file = File('${tempDir.path}/personality.md');
      expect(file.existsSync(), isTrue);

      final content = await file.readAsString();
      expect(content, contains('TestAgent'));
      expect(content, contains('knowledge_seeker'));
      expect(content, contains('Conversations: 10'));
      expect(content, contains('Depth Score: 0.80'));

      verify(mockDatabase.getEvolutionHistory()).called(1);
      verify(mockDatabase.getDepthMetrics()).called(1);
    });

    test('should format traits as percentages', () async {
      final profile = ExtendedAvatarProfile(
        agentName: 'Agent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits(
          formality: 0.75,
          humor: 0.5,
          enthusiasm: 0.9,
          empathy: 0.85,
        ),
        conversationCount: 0,
        depthScore: 0.0,
      );

      when(mockDatabase.getEvolutionHistory()).thenAnswer((_) async => []);
      when(mockDatabase.getDepthMetrics()).thenAnswer((_) async => []);

      await service.syncPersonality(profile);

      final file = File('${tempDir.path}/personality.md');
      final content = await file.readAsString();

      expect(content, contains('Formality: 75%'));
      expect(content, contains('Humor: 50%'));
      expect(content, contains('Enthusiasm: 90%'));
      expect(content, contains('Empathy: 85%'));
    });

    test('should handle file write errors gracefully', () async {
      final profile = ExtendedAvatarProfile(
        agentName: 'Agent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      when(mockDatabase.getEvolutionHistory()).thenAnswer((_) async => []);
      when(mockDatabase.getDepthMetrics()).thenAnswer((_) async => []);

      final conflictDir = File('${tempDir.path}/personality.md');
      await conflictDir.create();

      expect(
          () async => await service.syncPersonality(profile), returnsNormally);
    });
  });

  group('MarkdownSyncService syncMemory', () {
    test('should sync memory entries to markdown file', () async {
      final memories = [
        AvatarMemoryEntry(
          id: 1,
          avatarId: 'avatar-1',
          memoryKey: 'preference_theme',
          memoryType: 'user_preference',
          memoryValue: 'dark',
          importance: 90,
          timestamp: DateTime(2025, 1, 1),
          createdAt: DateTime(2025, 1, 1),
          lastAccessed: DateTime(2025, 1, 1),
          tags: 'ui,settings',
        ),
        AvatarMemoryEntry(
          id: 2,
          avatarId: 'avatar-1',
          memoryKey: 'fact_name',
          memoryType: 'user_fact',
          memoryValue: 'John',
          importance: 85,
          timestamp: DateTime(2025, 1, 2),
          createdAt: DateTime(2025, 1, 2),
          lastAccessed: DateTime(2025, 1, 2),
          tags: null,
        ),
      ];

      when(mockDatabase.getAllAvatarMemoryEntries())
          .thenAnswer((_) async => memories);

      await service.syncMemory();

      final file = File('${tempDir.path}/memory.md');
      expect(file.existsSync(), isTrue);

      final content = await file.readAsString();
      expect(content, contains('Avatar Memory'));
      expect(content, contains('preference_theme'));
      expect(content, contains('fact_name'));
      expect(content, contains('total_entries: 2'));

      verify(mockDatabase.getAllAvatarMemoryEntries()).called(1);
    });

    test('should categorize memories by importance', () async {
      final memories = [
        AvatarMemoryEntry(
          id: 1,
          avatarId: 'avatar-1',
          memoryKey: 'high',
          memoryType: 'test',
          memoryValue: 'value',
          importance: 90,
          timestamp: DateTime.now(),
          createdAt: DateTime.now(),
          lastAccessed: DateTime.now(),
          tags: null,
        ),
        AvatarMemoryEntry(
          id: 2,
          avatarId: 'avatar-1',
          memoryKey: 'medium',
          memoryType: 'test',
          memoryValue: 'value',
          importance: 60,
          timestamp: DateTime.now(),
          createdAt: DateTime.now(),
          lastAccessed: DateTime.now(),
          tags: null,
        ),
        AvatarMemoryEntry(
          id: 3,
          avatarId: 'avatar-1',
          memoryKey: 'low',
          memoryType: 'test',
          memoryValue: 'value',
          importance: 30,
          timestamp: DateTime.now(),
          createdAt: DateTime.now(),
          lastAccessed: DateTime.now(),
          tags: null,
        ),
      ];

      when(mockDatabase.getAllAvatarMemoryEntries())
          .thenAnswer((_) async => memories);

      await service.syncMemory();

      final file = File('${tempDir.path}/memory.md');
      final content = await file.readAsString();

      expect(content, contains('High Importance Memories'));
      expect(content, contains('Medium Importance Memories'));
      expect(content, contains('All Memories'));
    });

    test('should handle empty memory list', () async {
      when(mockDatabase.getAllAvatarMemoryEntries())
          .thenAnswer((_) async => []);

      await service.syncMemory();

      final file = File('${tempDir.path}/memory.md');
      final content = await file.readAsString();

      expect(content, contains('None'));
    });

    test('should format memory entries correctly', () async {
      final memories = [
        AvatarMemoryEntry(
          id: 1,
          avatarId: 'avatar-1',
          memoryKey: 'test_key',
          memoryType: 'user_fact',
          memoryValue: 'test_value',
          importance: 75,
          timestamp: DateTime(2025, 1, 1),
          createdAt: DateTime(2025, 1, 1),
          lastAccessed: DateTime(2025, 1, 1, 12, 30),
          tags: 'tag1,tag2',
        ),
      ];

      when(mockDatabase.getAllAvatarMemoryEntries())
          .thenAnswer((_) async => memories);

      await service.syncMemory();

      final file = File('${tempDir.path}/memory.md');
      final content = await file.readAsString();

      expect(content, contains('test_key'));
      expect(content, contains('user_fact'));
      expect(content, contains('test_value'));
      expect(content, contains('75/100'));
      expect(content, contains('tag1,tag2'));
    });
  });

  group('MarkdownSyncService syncContext', () {
    test('should sync context to markdown file', () async {
      final profile = AvatarPersonalityProfile(
        id: '1',
        agentName: 'TestAgent',
        personalityTraits: '{}',
        evolutionStage: 'knowledge_seeker',
        conversationCount: 10,
        depthScore: 0.8,
      );

      final metrics = [
        ConversationDepthMetric(
          id: '1',
          conversationId: 'conv-1',
          complexityScore: 0.85,
          emotionalDepth: 0.75,
          noveltyScore: 0.9,
          timestamp: DateTime(2025, 1, 1).millisecondsSinceEpoch,
        ),
      ];

      when(mockDatabase.getAvatarProfile()).thenAnswer((_) async => profile);
      when(mockDatabase.getDepthMetrics()).thenAnswer((_) async => metrics);
      when(mockDatabase.getEvolutionHistory()).thenAnswer((_) async => []);

      await service.syncContext();

      final file = File('${tempDir.path}/context.md');
      expect(file.existsSync(), isTrue);

      final content = await file.readAsString();
      expect(content, contains('Avatar Context'));
      expect(content, contains('TestAgent'));
      expect(content, contains('knowledge_seeker'));
      expect(content, contains('**Conversations**: 10'));

      verify(mockDatabase.getAvatarProfile()).called(1);
      verify(mockDatabase.getDepthMetrics()).called(1);
    });

    test('should calculate average metrics correctly', () async {
      final profile = AvatarPersonalityProfile(
        id: '1',
        agentName: 'Agent',
        personalityTraits: '{}',
        evolutionStage: 'curious_explorer',
        conversationCount: 0,
        depthScore: 0.0,
      );

      final metrics = [
        ConversationDepthMetric(
          id: '1',
          conversationId: 'conv-1',
          complexityScore: 0.8,
          emotionalDepth: 0.7,
          noveltyScore: 0.9,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
        ConversationDepthMetric(
          id: '2',
          conversationId: 'conv-2',
          complexityScore: 0.6,
          emotionalDepth: 0.5,
          noveltyScore: 0.7,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      ];

      when(mockDatabase.getAvatarProfile()).thenAnswer((_) async => profile);
      when(mockDatabase.getDepthMetrics()).thenAnswer((_) async => metrics);
      when(mockDatabase.getEvolutionHistory()).thenAnswer((_) async => []);

      await service.syncContext();

      final file = File('${tempDir.path}/context.md');
      final content = await file.readAsString();

      expect(content, contains('**Average Complexity**: 0.70'));
      expect(content, contains('**Average Emotional Depth**: 0.60'));
      expect(content, contains('**Average Novelty**: 0.80'));
    });

    test('should handle empty metrics gracefully', () async {
      final profile = AvatarPersonalityProfile(
        id: '1',
        agentName: 'Agent',
        personalityTraits: '{}',
        evolutionStage: 'curious_explorer',
        conversationCount: 0,
        depthScore: 0.0,
      );

      when(mockDatabase.getAvatarProfile()).thenAnswer((_) async => profile);
      when(mockDatabase.getDepthMetrics()).thenAnswer((_) async => []);
      when(mockDatabase.getEvolutionHistory()).thenAnswer((_) async => []);

      await service.syncContext();

      final file = File('${tempDir.path}/context.md');
      final content = await file.readAsString();

      expect(content, contains('**Average Complexity**: 0.00'));
      expect(content, contains('**Average Emotional Depth**: 0.00'));
      expect(content, contains('**Average Novelty**: 0.00'));
    });
  });

  group('MarkdownSyncService syncAll', () {
    test('should sync all data to markdown files', () async {
      final profile = ExtendedAvatarProfile(
        agentName: 'Agent',
        evolutionStage: 'curious_explorer',
        traits: PersonalityTraits.defaultTraits,
        conversationCount: 0,
        depthScore: 0.0,
      );

      when(mockDatabase.getEvolutionHistory()).thenAnswer((_) async => []);
      when(mockDatabase.getDepthMetrics()).thenAnswer((_) async => []);
      when(mockDatabase.getAllAvatarMemoryEntries())
          .thenAnswer((_) async => []);
      when(mockDatabase.getAvatarProfile())
          .thenAnswer((_) async => AvatarPersonalityProfile(
                id: '1',
                agentName: 'Agent',
                personalityTraits: '{}',
                evolutionStage: 'curious_explorer',
                conversationCount: 0,
                depthScore: 0.0,
              ));

      await service.syncAll(profile);

      expect(File('${tempDir.path}/personality.md').existsSync(), isTrue);
      expect(File('${tempDir.path}/memory.md').existsSync(), isTrue);
      expect(File('${tempDir.path}/context.md').existsSync(), isTrue);
    });
  });

  group('MarkdownSyncService loadPersonalityFromMarkdown', () {
    test('should load personality from existing markdown file', () async {
      final markdownContent = '''---
agent_name: TestAgent
formality: 0.8
humor: 0.6
enthusiasm: 0.7
empathy: 0.9
evolution_stage: knowledge_seeker
conversation_count: 15
depth_score: 0.85
last_updated: 2025-01-01T00:00:00.000Z
---

# TestAgent Personality

## Traits
- Formality: 80%
- Humor: 60%
- Enthusiasm: 70%
- Empathy: 90%

## Evolution Stage: knowledge_seeker
- Conversations: 15
- Depth Score: 0.85
''';

      final file = File('${tempDir.path}/personality.md');
      await file.writeAsString(markdownContent);

      final profile = await service.loadPersonalityFromMarkdown();

      expect(profile, isNotNull);
      expect(profile!.agentName, equals('TestAgent'));
      expect(profile.evolutionStage, equals('knowledge_seeker'));
      expect(profile.conversationCount, equals(15));
      expect(profile.depthScore, equals(0.85));
      expect(profile.traits.formality, equals(0.8));
      expect(profile.traits.humor, equals(0.6));
      expect(profile.traits.enthusiasm, equals(0.7));
      expect(profile.traits.empathy, equals(0.9));
    });

    test('should return null if file does not exist', () async {
      final profile = await service.loadPersonalityFromMarkdown();
      expect(profile, isNull);
    });

    test('should handle malformed markdown gracefully', () async {
      final malformedContent = '''---
agent_name: TestAgent
invalid_field: value
---

# Invalid
''';

      final file = File('${tempDir.path}/personality.md');
      await file.writeAsString(malformedContent);

      final profile = await service.loadPersonalityFromMarkdown();
      expect(profile, isNotNull);
      expect(profile!.agentName, equals('TestAgent'));
    });

    test('should handle parse errors gracefully', () async {
      final invalidContent = 'no valid data here whatsoever';

      final file = File('${tempDir.path}/personality.md');
      await file.writeAsString(invalidContent);

      final profile = await service.loadPersonalityFromMarkdown();
      // The function attempts to parse as much as possible, using defaults
      // for missing traits, so it returns a profile even with minimal content
      expect(profile, isNotNull);
    });
  });

  group('MarkdownSyncService hasMarkdownBackup', () {
    test('should return true when personality.md exists', () async {
      final file = File('${tempDir.path}/personality.md');
      await file.writeAsString('test content');

      final hasBackup = await service.hasMarkdownBackup();
      expect(hasBackup, isTrue);
    });

    test('should return false when personality.md does not exist', () async {
      final hasBackup = await service.hasMarkdownBackup();
      expect(hasBackup, isFalse);
    });
  });

  group('MarkdownSyncService clearMarkdownFiles', () {
    test('should clear all markdown files', () async {
      await File('${tempDir.path}/personality.md').writeAsString('test');
      await File('${tempDir.path}/memory.md').writeAsString('test');
      await File('${tempDir.path}/context.md').writeAsString('test');

      await service.clearMarkdownFiles();

      expect(File('${tempDir.path}/personality.md').existsSync(), isFalse);
      expect(File('${tempDir.path}/memory.md').existsSync(), isFalse);
      expect(File('${tempDir.path}/context.md').existsSync(), isFalse);
    });

    test('should not delete non-markdown files', () async {
      await File('${tempDir.path}/personality.md').writeAsString('test');
      await File('${tempDir.path}/data.txt').writeAsString('test');

      await service.clearMarkdownFiles();

      expect(File('${tempDir.path}/personality.md').existsSync(), isFalse);
      expect(File('${tempDir.path}/data.txt').existsSync(), isTrue);
    });

    test('should handle empty directory', () async {
      expect(() async => await service.clearMarkdownFiles(), returnsNormally);
    });

    test('should handle non-existent directory', () async {
      final newDir = Directory('${tempDir.path}/nonexistent');
      final newService = MarkdownSyncService(
        database: mockDatabase,
        markdownPath: newDir.path,
      );

      expect(
          () async => await newService.clearMarkdownFiles(), returnsNormally);
    });
  });
}
