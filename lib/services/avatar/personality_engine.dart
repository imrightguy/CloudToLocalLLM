import 'dart:convert';
import 'package:cloudtolocalllm/database/drift_local_brain.dart';
import 'package:cloudtolocalllm/models/avatar/personality_models.dart';

class PersonalityEngine {
  final LocalBrain _database;

  PersonalityEngine({
    required LocalBrain database,
  }) : _database = database;

  Future<ExtendedAvatarProfile> getPersonality() async {
    try {
      final profile = await _database.getAvatarProfile();
      final traitsMap =
          jsonDecode(profile.personalityTraits) as Map<String, dynamic>;
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
    } catch (e) {
      throw StateError('Failed to load personality: $e');
    }
  }

  Future<void> updatePersonality(PersonalityTraits traits) async {
    await _database.updateAvatarTraits(traits.toMap());
  }

  Future<void> updateAgentName(String name) async {
    await _database.updateAgentName(name);
  }

  Future<EvolutionDecision> validateEvolutionRequest(
    String requestedStage,
    String reason,
  ) async {
    if (!_isValidStage(requestedStage)) {
      return EvolutionDecision(
        approved: false,
        reason: 'Invalid evolution stage: $requestedStage',
      );
    }

    try {
      final metrics = await _database.getDepthMetrics();

      final deepConversations =
          metrics.where((m) => m.complexityScore > 0.7).length;
      final avgNovelty = metrics.isEmpty
          ? 0.0
          : metrics.map((m) => m.noveltyScore).reduce((a, b) => a + b) /
              metrics.length;

      if (deepConversations >= 5 && avgNovelty > 0.5) {
        final profile = await _database.getAvatarProfile();
        await _database.recordEvolution(
          fromStage: profile.evolutionStage,
          toStage: requestedStage,
          triggerReason: reason,
          context:
              '$deepConversations deep conversations, ${avgNovelty.toStringAsFixed(2)} avg novelty',
          confirmedBy: 'collaborative',
        );

        await _database.updateEvolutionStage(requestedStage);

        return EvolutionDecision(
          approved: true,
          newStage: requestedStage,
        );
      }

      return EvolutionDecision(
        approved: false,
        reason:
            'Insufficient conversation depth: need 5+ deep conversations (current: $deepConversations) and avg novelty > 0.5 (current: ${avgNovelty.toStringAsFixed(2)})',
      );
    } catch (e) {
      throw StateError('Failed to validate evolution: $e');
    }
  }

  bool _isValidStage(String stage) {
    const validStages = [
      'curious_explorer',
      'knowledge_seeker',
      'wise_companion',
      'enlightened_guide'
    ];
    return validStages.contains(stage);
  }
}
