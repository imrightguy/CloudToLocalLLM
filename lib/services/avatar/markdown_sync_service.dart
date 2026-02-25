import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm/database/drift_local_brain.dart';
import 'package:cloudtolocalllm/models/avatar/personality_models.dart';

/// Service for synchronizing avatar data to markdown files.
///
/// Provides portable backup of personality, memory, and context data
/// that can be shared with OpenClaw Gateway and used as a fallback
/// when Drift database is unavailable.
class MarkdownSyncService {
  final LocalBrain _database;
  final String _markdownPath;

  MarkdownSyncService({
    required LocalBrain database,
    required String markdownPath,
  })  : _database = database,
        _markdownPath = markdownPath;

  /// Synchronizes personality data to markdown file
  Future<void> syncPersonality(ExtendedAvatarProfile profile) async {
    final timestamp = DateTime.now().toIso8601String();
    final md = '''---
agent_name: ${profile.agentName}
formality: ${profile.traits.formality}
humor: ${profile.traits.humor}
enthusiasm: ${profile.traits.enthusiasm}
empathy: ${profile.traits.empathy}
evolution_stage: ${profile.evolutionStage}
conversation_count: ${profile.conversationCount}
depth_score: ${profile.depthScore}
last_updated: $timestamp
---

# ${profile.agentName} Personality

## Traits
- Formality: ${(profile.traits.formality * 100).toInt()}%
- Humor: ${(profile.traits.humor * 100).toInt()}%
- Enthusiasm: ${(profile.traits.enthusiasm * 100).toInt()}%
- Empathy: ${(profile.traits.empathy * 100).toInt()}%

## Evolution Stage: ${profile.evolutionStage}
- Conversations: ${profile.conversationCount}
- Depth Score: ${profile.depthScore.toStringAsFixed(2)}

## Evolution History
${await _getEvolutionHistoryMarkdown()}

## Depth Metrics
${await _getDepthMetricsMarkdown()}
''';

    await _writeMarkdownFile('personality.md', md);
    debugPrint('[MarkdownSync] Personality synced to markdown');
  }

  /// Synchronizes memory entries to markdown file
  Future<void> syncMemory() async {
    final memories = await _database.getAllAvatarMemoryEntries();

    final md = '''---
synced_at: ${DateTime.now().toIso8601String()}
total_entries: ${memories.length}
---

# Avatar Memory

## High Importance Memories
${_formatMemoryEntries(memories.where((m) => m.importance >= 80).toList())}

## Medium Importance Memories
${_formatMemoryEntries(memories.where((m) => m.importance >= 50 && m.importance < 80).toList())}

## All Memories
${_formatMemoryEntries(memories)}
''';

    await _writeMarkdownFile('memory.md', md);
    debugPrint(
        '[MarkdownSync] Memory synced to markdown (${memories.length} entries)');
  }

  /// Synchronizes context information to markdown file
  Future<void> syncContext() async {
    final profile = await _database.getAvatarProfile();
    final metrics = await _database.getDepthMetrics();

    final avgComplexity = metrics.isEmpty
        ? 0.0
        : metrics.map((m) => m.complexityScore).reduce((a, b) => a + b) /
            metrics.length;
    final avgEmotional = metrics.isEmpty
        ? 0.0
        : metrics.map((m) => m.emotionalDepth).reduce((a, b) => a + b) /
            metrics.length;
    final avgNovelty = metrics.isEmpty
        ? 0.0
        : metrics.map((m) => m.noveltyScore).reduce((a, b) => a + b) /
            metrics.length;

    final md = '''---
synced_at: ${DateTime.now().toIso8601String()}
agent_name: ${profile.agentName}
evolution_stage: ${profile.evolutionStage}
---

# Avatar Context

## Profile Summary
- **Agent Name**: ${profile.agentName}
- **Evolution Stage**: ${profile.evolutionStage}
- **Conversations**: ${profile.conversationCount}
- **Depth Score**: ${profile.depthScore.toStringAsFixed(2)}

## Conversation Patterns
- **Average Complexity**: ${avgComplexity.toStringAsFixed(2)}
- **Average Emotional Depth**: ${avgEmotional.toStringAsFixed(2)}
- **Average Novelty**: ${avgNovelty.toStringAsFixed(2)}
- **Total Conversations Tracked**: ${metrics.length}

## Evolution History
${await _getEvolutionHistoryMarkdown()}
''';

    await _writeMarkdownFile('context.md', md);
    debugPrint('[MarkdownSync] Context synced to markdown');
  }

  /// Synchronizes all avatar data to markdown files
  Future<void> syncAll(ExtendedAvatarProfile profile) async {
    await syncPersonality(profile);
    await syncMemory();
    await syncContext();
    debugPrint('[MarkdownSync] All data synced to markdown');
  }

  /// Loads personality from markdown file (fallback for database unavailable)
  Future<ExtendedAvatarProfile?> loadPersonalityFromMarkdown() async {
    try {
      final file = File('$_markdownPath/personality.md');
      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      final traits = _parseTraitsFromMarkdown(content);

      // Parse basic fields
      final agentNameMatch = RegExp(r'agent_name:\s*(.+)').firstMatch(content);
      final evolutionStageMatch =
          RegExp(r'evolution_stage:\s*(.+)').firstMatch(content);
      final conversationCountMatch =
          RegExp(r'conversation_count:\s*(\d+)').firstMatch(content);
      final depthScoreMatch =
          RegExp(r'depth_score:\s*(\d+\.?\d*)').firstMatch(content);

      return ExtendedAvatarProfile(
        agentName: agentNameMatch?.group(1)?.trim() ?? 'Agent',
        traits: traits ?? PersonalityTraits.defaultTraits,
        evolutionStage: evolutionStageMatch?.group(1)?.trim() ?? 'base',
        conversationCount:
            int.tryParse(conversationCountMatch?.group(1) ?? '0') ?? 0,
        depthScore: double.tryParse(depthScoreMatch?.group(1) ?? '0.0') ?? 0.0,
      );
    } catch (e) {
      debugPrint('[MarkdownSync] Error loading personality from markdown: $e');
      return null;
    }
  }

  /// Writes content to a markdown file in the skills directory
  Future<void> _writeMarkdownFile(String filename, String content) async {
    final directory = Directory(_markdownPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final file = File('$_markdownPath/$filename');
    await file.writeAsString(content);
  }

  /// Formats memory entries as markdown list
  String _formatMemoryEntries(List<AvatarMemoryEntry> memories) {
    if (memories.isEmpty) {
      return 'None\n';
    }

    return memories.map((m) => '''### ${m.memoryKey}
- **Type**: ${m.memoryType}
- **Value**: ${m.memoryValue}
- **Importance**: ${m.importance}/100
- **Last Accessed**: ${m.lastAccessed.toIso8601String()}
- **Tags**: ${m.tags ?? 'None'}
''').join('\n');
  }

  /// Gets evolution history as markdown
  Future<String> _getEvolutionHistoryMarkdown() async {
    final history = await _database.getEvolutionHistory();

    if (history.isEmpty) {
      return 'No evolution history yet.\n';
    }

    return history.map((e) => '''### ${e.toStage}
- **From**: ${e.fromStage}
- **Trigger**: ${e.triggerReason}
- **Confirmed By**: ${e.confirmedBy}
- **At**: ${DateTime.fromMillisecondsSinceEpoch(e.triggeredAt).toIso8601String()}
${e.context != null ? '- **Context**: ${e.context}' : ''}
''').join('\n');
  }

  /// Gets depth metrics as markdown
  Future<String> _getDepthMetricsMarkdown() async {
    final metrics = await _database.getDepthMetrics();

    if (metrics.isEmpty) {
      return 'No depth metrics yet.\n';
    }

    return metrics
        .take(10) // Show last 10
        .map((m) => '''### Conversation ${m.conversationId}
- **Complexity**: ${m.complexityScore.toStringAsFixed(2)}
- **Emotional Depth**: ${m.emotionalDepth.toStringAsFixed(2)}
- **Novelty**: ${m.noveltyScore.toStringAsFixed(2)}
- **At**: ${DateTime.fromMillisecondsSinceEpoch(m.timestamp).toIso8601String()}
''')
        .join('\n');
  }

  /// Parses traits from markdown frontmatter or content
  PersonalityTraits? _parseTraitsFromMarkdown(String content) {
    final formalityMatch =
        RegExp(r'formality:\s*(\d+\.?\d*)').firstMatch(content);
    final humorMatch = RegExp(r'humor:\s*(\d+\.?\d*)').firstMatch(content);
    final enthusiasmMatch =
        RegExp(r'enthusiasm:\s*(\d+\.?\d*)').firstMatch(content);
    final empathyMatch = RegExp(r'empathy:\s*(\d+\.?\d*)').firstMatch(content);

    final formality = double.tryParse(formalityMatch?.group(1) ?? '');
    final humor = double.tryParse(humorMatch?.group(1) ?? '');
    final enthusiasm = double.tryParse(enthusiasmMatch?.group(1) ?? '');
    final empathy = double.tryParse(empathyMatch?.group(1) ?? '');

    if (formality == null ||
        humor == null ||
        enthusiasm == null ||
        empathy == null) {
      return null;
    }

    return PersonalityTraits(
      formality: formality,
      humor: humor,
      enthusiasm: enthusiasm,
      empathy: empathy,
    );
  }

  /// Checks if markdown files exist
  Future<bool> hasMarkdownBackup() async {
    final personalityFile = File('$_markdownPath/personality.md');
    return await personalityFile.exists();
  }

  /// Clears all markdown files
  Future<void> clearMarkdownFiles() async {
    final directory = Directory(_markdownPath);
    if (await directory.exists()) {
      final files = directory.listSync();
      for (var file in files) {
        if (file.path.endsWith('.md')) {
          await file.delete();
        }
      }
      debugPrint('[MarkdownSync] Markdown files cleared');
    }
  }
}
