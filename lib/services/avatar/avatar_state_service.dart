import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm/database/drift_local_brain.dart';
import 'package:cloudtolocalllm/services/avatar/personality_engine.dart';
import 'package:cloudtolocalllm/services/avatar/evolution_tracker.dart';
import 'package:cloudtolocalllm/services/avatar/markdown_sync_service.dart';
import 'package:cloudtolocalllm/models/avatar/personality_models.dart';

/// Centralized service for managing avatar state across the application.
///
/// Provides reactive state management via ChangeNotifier and integrates with
/// PersonalityEngine and EvolutionTracker for avatar evolution.
class AvatarStateService extends ChangeNotifier {
  final LocalBrain _database;
  final PersonalityEngine _personalityEngine;
  final EvolutionTracker _evolutionTracker;
  final MarkdownSyncService _markdownSyncService;

  ExtendedAvatarProfile? _currentProfile;
  bool _isLoading = false;
  String? _error;

  AvatarStateService({
    required LocalBrain database,
    required PersonalityEngine personalityEngine,
    required EvolutionTracker evolutionTracker,
    required MarkdownSyncService markdownSyncService,
  })  : _database = database,
        _personalityEngine = personalityEngine,
        _evolutionTracker = evolutionTracker,
        _markdownSyncService = markdownSyncService;

  // Getters
  ExtendedAvatarProfile? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Returns true if the avatar service is ready (profile loaded)
  bool get isReady => _currentProfile != null && !_isLoading;

  /// Returns the current evolution stage
  String get evolutionStage =>
      _currentProfile?.evolutionStage ?? 'curious_explorer';

  /// Returns the agent name
  String get agentName => _currentProfile?.agentName ?? 'Agent';

  /// Returns the current personality traits
  PersonalityTraits get traits =>
      _currentProfile?.traits ?? PersonalityTraits.defaultTraits;

  /// Returns the conversation count
  int get conversationCount => _currentProfile?.conversationCount ?? 0;

  /// Returns the depth score
  double get depthScore => _currentProfile?.depthScore ?? 0.0;

  /// Loads the current avatar profile from the database
  Future<void> loadProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final profile = await _personalityEngine.getPersonality();
      _currentProfile = profile;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading avatar profile: $e');
    }
  }

  /// Updates the personality traits
  Future<void> updateTraits(PersonalityTraits traits) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _personalityEngine.updatePersonality(traits);
      await loadProfile(); // Reload to get updated state

      // Sync to markdown
      if (_currentProfile != null) {
        await _markdownSyncService.syncPersonality(_currentProfile!);
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error updating traits: $e');
      rethrow;
    }
  }

  /// Updates the agent name
  Future<void> updateAgentName(String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _personalityEngine.updateAgentName(name);
      await loadProfile(); // Reload to get updated state

      // Sync to markdown
      if (_currentProfile != null) {
        await _markdownSyncService.syncPersonality(_currentProfile!);
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error updating agent name: $e');
      rethrow;
    }
  }

  /// Requests an evolution to a new stage
  Future<EvolutionDecision> requestEvolution(
      String stage, String reason) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final decision =
          await _personalityEngine.validateEvolutionRequest(stage, reason);
      await loadProfile(); // Reload to get updated stage

      // Sync all data to markdown if evolution approved
      if (decision.approved && _currentProfile != null) {
        await _markdownSyncService.syncAll(_currentProfile!);
      }

      return decision;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error requesting evolution: $e');
      rethrow;
    }
  }

  /// Tracks depth metrics for a conversation
  Future<void> trackConversationDepth(
    String conversationId,
    double complexity,
    double emotional,
    double novelty,
  ) async {
    try {
      final randomSuffix = DateTime.now().microsecond.toRadixString(16);
      final id = 'depth_${DateTime.now().millisecondsSinceEpoch}_$randomSuffix';

      await _database.addConversationDepthMetrics(
        ConversationDepthMetricsCompanion.insert(
          id: id,
          conversationId: conversationId,
          complexityScore: complexity,
          emotionalDepth: emotional,
          noveltyScore: novelty,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Reload profile to check for evolution patterns
      await loadProfile();
    } catch (e) {
      debugPrint('Error tracking conversation depth: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Checks if evolution is possible based on conversation patterns
  Future<bool> canEvolve() async {
    return await _evolutionTracker.hasEvolutionPatterns();
  }

  /// Returns the evolution requirements
  Future<Map<String, dynamic>> getEvolutionRequirements() async {
    final metrics = await _database.getDepthMetrics();

    final deepConversations =
        metrics.where((m) => m.complexityScore > 0.7).length;
    final avgNovelty = metrics.isEmpty
        ? 0.0
        : metrics.map((m) => m.noveltyScore).reduce((a, b) => a + b) /
            metrics.length;

    return {
      'deep_conversations': deepConversations,
      'required_deep_conversations': 5,
      'average_novelty': avgNovelty,
      'required_novelty': 0.5,
      'can_evolve': deepConversations >= 5 && avgNovelty > 0.5,
    };
  }

  /// Clears any error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
