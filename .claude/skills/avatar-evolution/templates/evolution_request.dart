/// Avatar Evolution Request Template
///
/// Demonstrates how to request avatar evolution with validation
///
/// Usage:
/// ```dart
/// await requestAvatarEvolution();
/// ```
///
/// See: lib/services/avatar/personality_engine.dart

import 'package:cloudtolocalllm/services/avatar/personality_engine.dart';

/// Request avatar evolution to the next stage
///
/// Evolution requires meeting conversation depth and novelty criteria.
/// Both user and AI must approve the evolution request.
Future<void> requestAvatarEvolution() async {
  final engine = PersonalityEngine();

  // Get current state
  final currentState = await engine.getPersonality();
  print('Current stage: ${currentState.evolutionStage}');
  print('Agent name: ${currentState.agentName}');

  // Check evolution prerequisites
  final criteria = await engine.getEvolutionCriteria();
  print('\n📊 Evolution Criteria:');
  print('  Deep conversations: ${criteria.deepConversationCount}');
  print('  Average novelty: ${criteria.averageNoveltyScore.toStringAsFixed(2)}');
  print('  Total conversations: ${criteria.totalConversationCount}');

  // Define target stage
  const targetStage = EvolutionStage.knowledgeSeeker;

  // Provide reasoning for evolution
  const reason = 'User has demonstrated consistent deep learning patterns. '
      'Completed ${criteria.deepConversationCount} deep conversations '
      'with average novelty score of ${criteria.averageNoveltyScore.toStringAsFixed(2)}. '
      'Ready to advance to next stage of development.';

  print('\n🎯 Target Stage: $targetStage');
  print('Reason: $reason');
  print('');

  // Request evolution
  final decision = await engine.validateEvolutionRequest(
    targetStage,
    reason,
  );

  if (decision.approved) {
    print('✅ Evolution approved!');
    print('   New stage: ${decision.newStage}');
    print('   Reason: ${decision.approvalReason}');

    // Apply evolution
    await engine.applyEvolution(decision.newStage);

    // Verify evolution
    final updatedState = await engine.getPersonality();
    print('\n✅ Evolution applied successfully!');
    print('   New stage: ${updatedState.evolutionStage}');
    print('   Evolved at: ${updatedState.lastEvolutionAt}');

    // Optional: Celebrate with UI feedback
    print('\n🎉 Avatar evolved! Notify user of achievement.');
  } else {
    print('❌ Evolution not ready');
    print('   Reason: ${decision.denialReason}');

    if (decision.suggestions != null && decision.suggestions!.isNotEmpty) {
      print('\n💡 Suggestions:');
      for (final suggestion in decision.suggestions!) {
        print('   • $suggestion');
      }
    }
  }
}

/// Check if evolution is possible without requesting
Future<bool> canEvolve() async {
  final engine = PersonalityEngine();
  final criteria = await engine.getEvolutionCriteria();

  // Define stage requirements
  final requirements = {
    EvolutionStage.knowledgeSeeker: EvolutionRequirements(
      deepConversations: 5,
      averageNovelty: 0.5,
    ),
    EvolutionStage.wiseCompanion: EvolutionRequirements(
      deepConversations: 15,
      averageNovelty: 0.6,
    ),
    EvolutionStage.enlightenedGuide: EvolutionRequirements(
      deepConversations: 30,
      averageNovelty: 0.7,
    ),
  };

  final currentStage = await engine.getCurrentStage();
  final req = requirements[currentStage];

  return criteria.deepConversationCount >= req.deepConversations &&
         criteria.averageNoveltyScore >= req.averageNovelty;
}

/// Evolution stage requirements
class EvolutionRequirements {
  final int deepConversations;
  final double averageNovelty;

  const EvolutionRequirements({
    required this.deepConversations,
    required this.averageNovelty,
  });
}

/// Example usage with retry logic
Future<void> requestEvolutionWithRetry() async {
  const maxRetries = 3;
  int attempts = 0;

  while (attempts < maxRetries) {
    attempts++;

    try {
      await requestAvatarEvolution();
      return; // Success, exit
    } catch (e) {
      print('Attempt $attempts failed: $e');

      if (attempts >= maxRetries) {
        print('Max retries reached. Evolution request failed.');
        rethrow;
      }

      // Wait before retry
      await Future.delayed(const Duration(seconds: 2));
    }
  }
}

/// Get evolution progress percentage
Future<double> getEvolutionProgress() async {
  final engine = PersonalityEngine();
  final criteria = await engine.getEvolutionCriteria();
  final currentStage = await engine.getCurrentStage();

  // Define milestones for next stage
  final milestones = {
    EvolutionStage.curiousExplorer: EvolutionRequirements(
      deepConversations: 5,
      averageNovelty: 0.5,
    ),
    EvolutionStage.knowledgeSeeker: EvolutionRequirements(
      deepConversations: 15,
      averageNovelty: 0.6,
    ),
    EvolutionStage.wiseCompanion: EvolutionRequirements(
      deepConversations: 30,
      averageNovelty: 0.7,
    ),
  };

  final req = milestones[currentStage];

  // Calculate progress (0.0 to 1.0)
  final conversationProgress =
      criteria.deepConversationCount / req.deepConversations;
  final noveltyProgress =
      criteria.averageNoveltyScore / req.averageNovelty;

  // Average of both metrics
  return ((conversationProgress + noveltyProgress) / 2).clamp(0.0, 1.0);
}
