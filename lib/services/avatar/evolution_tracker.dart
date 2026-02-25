import 'package:cloudtolocalllm/database/drift_local_brain.dart';
import 'package:cloudtolocalllm/models/conversation.dart' as models;
import 'package:cloudtolocalllm/models/message.dart' as msg;

/// Depth metrics for a conversation.
class DepthMetrics {
  final double complexity;
  final double emotional;
  final double novelty;

  const DepthMetrics({
    required this.complexity,
    required this.emotional,
    required this.novelty,
  });

  @override
  String toString() =>
      'DepthMetrics(complexity: $complexity, emotional: $emotional, novelty: $novelty)';
}

/// Tracks conversation depth and evolution patterns.
class EvolutionTracker {
  final LocalBrain _database;

  // Technical terms for complexity detection
  static const Set<String> _technicalTerms = {
    'api',
    'rest',
    'http',
    'https',
    'json',
    'xml',
    'sql',
    'nosql',
    'database',
    'algorithm',
    'function',
    'variable',
    'class',
    'method',
    'interface',
    'async',
    'await',
    'promise',
    'callback',
    'array',
    'object',
    'string',
    'integer',
    'boolean',
    'float',
    'double',
    'null',
    'undefined',
    'react',
    'vue',
    'angular',
    'flutter',
    'dart',
    'javascript',
    'typescript',
    'python',
    'java',
    'rust',
    'go',
    'cpp',
    'c++',
    'html',
    'css',
    'docker',
    'kubernetes',
    'git',
    'github',
    'gitlab',
    'ci/cd',
    'devops',
    'cloud',
    'aws',
    'azure',
    'gcp',
    'serverless',
    'microservices',
    'monolith',
    'frontend',
    'backend',
    'fullstack',
    'ui',
    'ux',
    'debug',
    'compile',
    'runtime',
    'middleware',
    'framework',
    'library',
    'package',
    'module',
    'import',
    'export',
    'component',
    'state',
    'props',
    'hook',
    'context',
    'redux',
    'mobx',
    'router',
    'navigation',
    'authentication',
    'authorization',
    'oauth',
    'jwt',
    'session',
    'cookie',
    'cache',
    'redis',
    'mongodb',
    'mysql',
    'postgresql',
    'sqlite',
    'orm',
    'prisma',
    'sequelize',
    'migration',
    'deployment',
    'testing',
    'unit',
    'integration',
    'e2e',
    'tdd',
    'bdd',
    'agile',
    'scrum',
    'kanban',
    'code',
    'review',
    'refactor',
    'pattern',
    'architecture',
    'design',
    'system',
    'network',
    'protocol',
    'tcp',
    'udp',
    'ip',
    'dns',
    'ssl',
    'tls',
    'ssh',
    'ftp',
    'smtp',
    'websocket',
    'graphql',
  };

  // Empathetic words for emotional depth detection
  static const Set<String> _empatheticWords = {
    'understand',
    'understanding',
    'feel',
    'feeling',
    'sorry',
    'apologize',
    'empathy',
    'sympathy',
    'compassion',
    'care',
    'caring',
    'support',
    'appreciate',
    'thankful',
    'listen',
    'listening',
    'hear',
    'validate',
    'acknowledge',
    'recognize',
    'respect',
    'honour',
    'accept',
    'emotional',
    'emotion',
    'sad',
    'happy',
    'joy',
    'excited',
    'worried',
    'anxious',
    'stressed',
    'overwhelmed',
    'confident',
    'proud',
    'disappointed',
    'frustrated',
    'confused',
    'uncertain',
    'hopeful',
    'blessed',
    'loved',
    'cared',
    'valued',
    'understood',
    'heard',
    'supported',
    'helped',
    'comfort',
    'comfortable',
    'safe',
    'secure',
    'trust',
    'believe',
    'hope',
    'wish',
    'dream',
    'desire',
    'passion',
    'purpose',
    'meaning',
    'connection',
    'relationship',
    'friend',
    'family',
    'love',
    'kindness',
    'generous',
  };

  EvolutionTracker({required LocalBrain database}) : _database = database;

  /// Analyzes and stores depth metrics for a conversation.
  Future<void> trackConversation(models.Conversation conversation) async {
    final messages = conversation.messages;
    if (messages.isEmpty) {
      return;
    }

    final complexity = await calculateComplexity(messages);
    final emotional = await calculateEmotionalDepth(messages);
    final novelty = await calculateNovelty(messages);

    await _database.addConversationDepthMetrics(
      ConversationDepthMetricsCompanion.insert(
        id: _generateId(),
        conversationId: conversation.id,
        complexityScore: complexity,
        emotionalDepth: emotional,
        noveltyScore: novelty,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Calculates conversation complexity based on multiple factors.
  /// Returns a score between 0.0 and 1.0.
  Future<double> calculateComplexity(List<msg.Message> messages) async {
    if (messages.isEmpty) return 0.0;

    double score = 0.0;
    int factors = 0;

    // Factor 1: Average message length (0-1, normalized at 500 chars)
    final avgLength =
        messages.map((m) => m.content.length).reduce((a, b) => a + b) /
            messages.length;
    score += (avgLength / 500).clamp(0.0, 1.0);
    factors++;

    // Factor 2: Vocabulary diversity (unique word ratio)
    final allText = messages.map((m) => m.content.toLowerCase()).join(' ');
    final words = _extractWords(allText);
    if (words.isNotEmpty) {
      final uniqueWords = words.toSet();
      final diversity = uniqueWords.length / words.length;
      score += diversity;
      factors++;
    }

    // Factor 3: Question count (normalized at 3 questions)
    final questionCount =
        messages.where((m) => m.content.trim().endsWith('?')).length;
    score += (questionCount / 3).clamp(0.0, 1.0);
    factors++;

    // Factor 4: Technical terms (normalized at 5 terms)
    final technicalCount =
        words.where((w) => _technicalTerms.contains(w)).length;
    score += (technicalCount / 5).clamp(0.0, 1.0);
    factors++;

    return factors > 0 ? score / factors : 0.0;
  }

  /// Calculates emotional depth based on empathetic language.
  /// Returns a score between 0.0 and 1.0.
  Future<double> calculateEmotionalDepth(List<msg.Message> messages) async {
    if (messages.isEmpty) return 0.0;

    double score = 0.0;
    int factors = 0;

    final allText = messages.map((m) => m.content.toLowerCase()).join(' ');
    final words = _extractWords(allText);

    if (words.isEmpty) return 0.0;

    // Factor 1: Empathetic words (normalized at 5 words)
    final empatheticCount =
        words.where((w) => _empatheticWords.contains(w)).length;
    score += (empatheticCount / 5).clamp(0.0, 1.0);
    factors++;

    // Factor 2: First-person pronouns indicate personal sharing
    final firstPersonCount = words
        .where((w) =>
            w == 'i' ||
            w == 'my' ||
            w == 'me' ||
            w == 'myself' ||
            w == 'our' ||
            w == 'we')
        .length;
    score += (firstPersonCount / 10).clamp(0.0, 1.0);
    factors++;

    // Factor 3: Emotional words
    final emotionalWords = [
      'feel',
      'feeling',
      'felt',
      'emotional',
      'emotion',
      'sad',
      'happy',
      'excited',
      'worried',
      'anxious',
      'stressed',
      'overwhelmed',
      'confident',
      'proud',
      'disappointed',
      'frustrated',
      'confused',
      'hopeful',
      'grateful',
      'loved',
      'cared',
      'blessed',
      'joy',
      'passion',
      'desire',
    ];
    final emotionalCount = words.where(emotionalWords.contains).length;
    score += (emotionalCount / 5).clamp(0.0, 1.0);
    factors++;

    return factors > 0 ? score / factors : 0.0;
  }

  /// Calculates novelty based on vocabulary diversity vs message count.
  /// Returns a score between 0.0 and 1.0.
  Future<double> calculateNovelty(List<msg.Message> messages) async {
    if (messages.isEmpty) return 0.0;

    final allText = messages.map((m) => m.content.toLowerCase()).join(' ');
    final words = _extractWords(allText);

    if (words.isEmpty) return 0.0;

    final uniqueWords = words.toSet();

    // Novelty is high when we have many unique words relative to message count
    // This indicates diverse topics and new information
    final ratio = uniqueWords.length /
        (messages.length * 10); // Expect ~10 unique words per message

    // Normalize: 0.5 is average, 1.0+ is excellent
    return (ratio * 2).clamp(0.0, 1.0);
  }

  /// Returns true if evolution patterns are detected.
  /// Criteria: 5+ deep conversations AND average novelty > 0.5
  Future<bool> hasEvolutionPatterns() async {
    final metrics = await _database.getDepthMetrics();

    if (metrics.isEmpty) return false;

    // Count deep conversations (complexity > 0.7)
    final deepConversations =
        metrics.where((m) => m.complexityScore > 0.7).length;

    if (deepConversations < 5) return false;

    // Calculate average novelty
    final avgNovelty =
        metrics.map((m) => m.noveltyScore).reduce((a, b) => a + b) /
            metrics.length;

    return avgNovelty > 0.5;
  }

  /// Extracts all words from text, removing punctuation.
  List<String> _extractWords(String text) {
    return text
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  /// Generates a unique ID for depth metrics.
  String _generateId() {
    return 'depth_${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
  }

  /// Generates a random string for ID generation.
  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final sb = StringBuffer();
    for (var i = 0; i < length; i++) {
      sb.write(chars[(random + i) % chars.length]);
    }
    return sb.toString();
  }
}
