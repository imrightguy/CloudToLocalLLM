import 'package:flutter/material.dart';
import '../../services/avatar/avatar_state_service.dart';
import '../../di/locator.dart' as di;
import '../../database/drift_local_brain.dart';

/// Screen for displaying avatar achievements
///
/// Shows unlocked and locked achievements with progress indicators.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late AvatarStateService _avatarStateService;
  late LocalBrain _localBrain;
  bool _isLoading = true;
  String? _errorMessage;

  List<Achievement> _unlockedAchievements = [];
  Map<String, AchievementProgress> _progressMap = {};

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Initialize services
  Future<void> _initializeServices() async {
    try {
      _avatarStateService = di.serviceLocator.get<AvatarStateService>();
      _localBrain = di.serviceLocator.get<LocalBrain>();

      await _loadAchievements();
      await _loadProgress();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load achievements: $e';
        });
      }
    }
  }

  /// Load all achievements from database
  Future<void> _loadAchievements() async {
    try {
      _unlockedAchievements = await _localBrain.getUnlockedAchievements();
    } catch (e) {
      debugPrint('Error loading achievements: $e');
    }
  }

  /// Load achievement progress based on avatar state
  Future<void> _loadProgress() async {
    final avatarState = _avatarStateService.currentProfile;
    if (avatarState == null) {
      return;
    }

    final conversationCount = avatarState.conversationCount;
    final depthScore = avatarState.depthScore;
    final evolutionStage = avatarState.evolutionStage;

    setState(() {
      _progressMap = {
        'first_chat': AchievementProgress(
          completed: true,
          progress: 1.0,
          currentValue: 1,
          requiredValue: 1,
        ),
        'deep_conversations_5': AchievementProgress(
          completed: conversationCount >= 5,
          progress: (conversationCount / 5).clamp(0.0, 1.0),
          currentValue: conversationCount,
          requiredValue: 5,
        ),
        'deep_conversations_15': AchievementProgress(
          completed: conversationCount >= 15,
          progress: (conversationCount / 15).clamp(0.0, 1.0),
          currentValue: conversationCount,
          requiredValue: 15,
        ),
        'deep_conversations_30': AchievementProgress(
          completed: conversationCount >= 30,
          progress: (conversationCount / 30).clamp(0.0, 1.0),
          currentValue: conversationCount,
          requiredValue: 30,
        ),
        'high_novelty': AchievementProgress(
          completed: depthScore >= 0.6,
          progress: (depthScore / 0.6).clamp(0.0, 1.0),
          currentValue: (depthScore * 100).toInt(),
          requiredValue: 60,
          isPercentage: true,
        ),
        'knowledge_seeker': AchievementProgress(
          completed: evolutionStage == 'knowledge_seeker' ||
              evolutionStage == 'wise_companion' ||
              evolutionStage == 'enlightened_guide',
          progress: 0.0,
          currentValue: 0,
          requiredValue: 1,
        ),
        'wise_companion': AchievementProgress(
          completed: evolutionStage == 'wise_companion' ||
              evolutionStage == 'enlightened_guide',
          progress: 0.0,
          currentValue: 0,
          requiredValue: 1,
        ),
        'enlightened_guide': AchievementProgress(
          completed: evolutionStage == 'enlightened_guide',
          progress: 0.0,
          currentValue: 0,
          requiredValue: 1,
        ),
      };
    });
  }

  /// Get achievement metadata
  AchievementMetadata _getAchievementMetadata(String achievementId) {
    switch (achievementId) {
      case 'first_chat':
        return AchievementMetadata(
          title: 'First Conversation',
          description: 'Complete your first conversation with the avatar',
          icon: Icons.chat_bubble_outline,
          color: Colors.blue,
        );
      case 'deep_conversations_5':
        return AchievementMetadata(
          title: 'Getting to Know You',
          description: 'Have 5 deep conversations',
          icon: Icons.auto_awesome,
          color: Colors.green,
        );
      case 'deep_conversations_15':
        return AchievementMetadata(
          title: 'Deep Thinker',
          description: 'Have 15 deep conversations',
          icon: Icons.psychology,
          color: Colors.purple,
        );
      case 'deep_conversations_30':
        return AchievementMetadata(
          title: 'Conversational Master',
          description: 'Have 30 deep conversations',
          icon: Icons.school,
          color: Colors.orange,
        );
      case 'high_novelty':
        return AchievementMetadata(
          title: 'Novelty Seeker',
          description: 'Maintain high novelty in conversations (60%+)',
          icon: Icons.explore,
          color: Colors.teal,
        );
      case 'knowledge_seeker':
        return AchievementMetadata(
          title: 'Knowledge Seeker',
          description: 'Evolve your avatar to the Knowledge Seeker stage',
          icon: Icons.trending_up,
          color: Colors.indigo,
        );
      case 'wise_companion':
        return AchievementMetadata(
          title: 'Wise Companion',
          description: 'Evolve your avatar to the Wise Companion stage',
          icon: Icons.stars,
          color: Colors.amber,
        );
      case 'enlightened_guide':
        return AchievementMetadata(
          title: 'Enlightened Guide',
          description: 'Evolve your avatar to the Enlightened Guide stage',
          icon: Icons.workspace_premium,
          color: Colors.redAccent,
        );
      default:
        return AchievementMetadata(
          title: achievementId,
          description: '',
          icon: Icons.emoji_events,
          color: Colors.grey,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Achievements')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Achievements')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeServices,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final avatarState = _avatarStateService.currentProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats card
            _buildStatsCard(),
            const SizedBox(height: 24),

            // Unlocked achievements
            _buildSectionHeader('Unlocked', Icons.check_circle, Colors.green),
            const SizedBox(height: 12),
            if (_unlockedAchievements.isEmpty)
              _buildEmptyState(
                  'No achievements unlocked yet. Start conversing!')
            else
              ..._unlockedAchievements.map((achievement) {
                final metadata =
                    _getAchievementMetadata(achievement.achievementId);
                return _buildAchievementCard(
                  achievement: achievement,
                  metadata: metadata,
                  isUnlocked: true,
                );
              }),

            const SizedBox(height: 32),

            // Locked achievements
            _buildSectionHeader('Locked', Icons.lock, Colors.grey),
            const SizedBox(height: 12),
            ..._progressMap.entries.where((entry) {
              final achievementId = entry.key;
              final isUnlocked = _unlockedAchievements
                  .any((a) => a.achievementId == achievementId);
              return !isUnlocked;
            }).map((entry) {
              final metadata = _getAchievementMetadata(entry.key);
              final progress = entry.value;
              return _buildAchievementCard(
                achievement: Achievement(
                  id: -1,
                  avatarId: avatarState?.agentName ?? 'default',
                  achievementId: entry.key,
                  achievementType: 'progress',
                  title: metadata.title,
                  description: metadata.description,
                  earnedAt: DateTime.now(),
                ),
                metadata: metadata,
                isUnlocked: false,
                progress: progress,
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Build stats card
  Widget _buildStatsCard() {
    final unlockedCount = _unlockedAchievements.length;
    final totalCount = _progressMap.length;
    final percentage =
        totalCount > 0 ? (unlockedCount / totalCount * 100).toInt() : 0;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Achievement Progress',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$unlockedCount of $totalCount unlocked',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$percentage%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: unlockedCount / totalCount,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build section header
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }

  /// Build empty state
  Widget _buildEmptyState(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build achievement card
  Widget _buildAchievementCard({
    required Achievement achievement,
    required AchievementMetadata metadata,
    required bool isUnlocked,
    AchievementProgress? progress,
  }) {
    return Card(
      elevation: isUnlocked ? 3 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? metadata.color.withValues(alpha: 0.2)
                    : Colors.grey[200],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isUnlocked ? metadata.color : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: Icon(
                metadata.icon,
                size: 32,
                color: isUnlocked ? metadata.color : Colors.grey[400],
              ),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metadata.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metadata.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  if (!isUnlocked && progress != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress.progress,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                metadata.color.withValues(alpha: 0.8),
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          progress.isPercentage
                              ? '${progress.currentValue}%'
                              : '${progress.currentValue}/${progress.requiredValue}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: metadata.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isUnlocked && achievement.unlockedAt != null)
                    Text(
                      'Unlocked ${_formatDate(achievement.unlockedAt!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                ],
              ),
            ),
            // Status icon
            if (isUnlocked)
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }

  /// Format date
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'today';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Achievement metadata
class AchievementMetadata {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  AchievementMetadata({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

/// Achievement progress
class AchievementProgress {
  final bool completed;
  final double progress;
  final int currentValue;
  final int requiredValue;
  final bool isPercentage;

  AchievementProgress({
    required this.completed,
    required this.progress,
    required this.currentValue,
    required this.requiredValue,
    this.isPercentage = false,
  });
}
