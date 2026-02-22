import 'dart:io';
import 'dart:convert';
import 'package:cloudtolocalllm/database/drift_local_brain.dart';
import 'package:cloudtolocalllm/models/avatar/personality_models.dart';

class PersonalityEngine {
  final LocalBrain _database;
  final String _markdownPath;

  PersonalityEngine({
    required LocalBrain database,
    required String markdownPath,
  })  : _database = database,
        _markdownPath = markdownPath;

  Future<ExtendedAvatarProfile> getPersonality() async {
    final profile = await _database.getAvatarProfile();
    final traitsMap = jsonDecode(profile.personalityTraits) as Map<String, dynamic>;
    final traits = PersonalityTraits.fromMap(
      traitsMap.map((k, v) => MapEntry(k, (v as num).toDouble())),
    );

    return ExtendedAvatarProfile(
      agentName: profile.agentName,
      traits: traits,
      evolutionStage: profile.evolutionStage,
      conversationCount: profile.conversationCount,
      depthScore: profile.depthScore,
    );
  }

  Future<void> updatePersonality(PersonalityTraits traits) async {
    await _database.updateAvatarTraits(traits.toMap());
    final profile = await getPersonality();
    await _syncToMarkdown(profile);
  }

  Future<void> updateAgentName(String name) async {
    await _database.updateAgentName(name);
    final profile = await getPersonality();
    await _syncToMarkdown(profile);
  }

  Future<EvolutionDecision> validateEvolutionRequest(
    String requestedStage,
    String reason,
  ) async {
    // Get depth metrics
    final metrics = await _database.getDepthMetrics();

    // Assess readiness
    final deepConversations = metrics.where((m) => m.complexityScore > 0.7).length;
    final avgNovelty = metrics.isEmpty
        ? 0.0
        : metrics.map((m) => m.noveltyScore).reduce((a, b) => a + b) / metrics.length;

    // Evolution criteria:
    // - At least 5 deep conversations (complexity > 0.7)
    // - Average novelty > 0.5
    if (deepConversations >= 5 && avgNovelty > 0.5) {
      // Record evolution
      final profile = await _database.getAvatarProfile();
      await _database.recordEvolution(
        fromStage: profile.evolutionStage,
        toStage: requestedStage,
        triggerReason: reason,
        context: '$deepConversations deep conversations, ${avgNovelty.toStringAsFixed(2)} avg novelty',
        confirmedBy: 'collaborative',
      );

      // Update stage
      await _database.updateEvolutionStage(requestedStage);

      // Sync to markdown
      await _syncToMarkdown(await getPersonality());

      return EvolutionDecision(
        approved: true,
        newStage: requestedStage,
      );
    }

    return EvolutionDecision(
      approved: false,
      reason: 'Insufficient conversation depth: need 5+ deep conversations (current: $deepConversations) and avg novelty > 0.5 (current: ${avgNovelty.toStringAsFixed(2)})',
    );
  }

  Future<void> _syncToMarkdown(ExtendedAvatarProfile profile) async {
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
Conversations: ${profile.conversationCount}
Depth Score: ${profile.depthScore.toStringAsFixed(2)}
''';

    final directory = Directory(_markdownPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final file = File('$_markdownPath/personality.md');
    await file.writeAsString(md);
  }
}
