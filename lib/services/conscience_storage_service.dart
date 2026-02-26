import 'dart:convert';
import 'package:cloudtolocalllm/database/drift_local_brain.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class ConscienceStorageService {
  final LocalBrain _database;
  final Uuid _uuid = const Uuid();

  ConscienceStorageService({
    required LocalBrain database,
  }) : _database = database;

  Future<Map<String, dynamic>> writeThought({
    required String agent,
    required String thoughtType,
    required String content,
    String channel = 'general',
    Map<String, dynamic>? metadata,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _database.insertThought(AgentThoughtsCompanion.insert(
      id: id,
      timestamp: Value(now),
      channel: Value(channel),
      agent: agent,
      thoughtType: thoughtType,
      content: content,
      metadata: Value(metadata != null ? jsonEncode(metadata) : null),
    ));

    return {
      'id': id,
      'timestamp': now.toIso8601String(),
      'channel': channel,
      'agent': agent,
      'thought_type': thoughtType,
      'content': content,
      'metadata': metadata,
    };
  }

  Future<List<Map<String, dynamic>>> getThoughts({
    String? agent,
    String? channel,
    String? thoughtType,
    int limit = 50,
  }) async {
    List<AgentThought> thoughts;

    if (agent != null) {
      thoughts = await _database.getThoughtsByAgent(agent, limit: limit);
    } else if (channel != null) {
      thoughts = await _database.getThoughtsByChannel(channel, limit: limit);
    } else if (thoughtType != null) {
      thoughts = await _database.getThoughtsByType(thoughtType, limit: limit);
    } else {
      thoughts = await _database.getRecentThoughts(limit: limit);
    }

    return thoughts.map(_thoughtToMap).toList();
  }

  Future<Map<String, dynamic>> writeDecision({
    required String action,
    required String riskLevel,
    String? verdict,
    String? reviewer,
    String? reasoning,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final status = verdict != null ? 'reviewed' : 'pending';

    await _database.insertDecision(ConscienceDecisionsCompanion.insert(
      id: id,
      timestamp: Value(now),
      action: action,
      riskLevel: riskLevel,
      verdict: Value(verdict),
      reviewer: Value(reviewer),
      reasoning: Value(reasoning),
      status: Value(status),
    ));

    return {
      'id': id,
      'timestamp': now.toIso8601String(),
      'action': action,
      'risk_level': riskLevel,
      'verdict': verdict,
      'reviewer': reviewer,
      'reasoning': reasoning,
      'status': status,
    };
  }

  Future<Map<String, dynamic>> submitDecisionVerdict({
    required String decisionId,
    required String verdict,
    required String reviewer,
    required String reasoning,
  }) async {
    await _database.updateDecisionVerdict(
        decisionId, verdict, reviewer, reasoning);

    final decision = await _database.getDecisionById(decisionId);
    if (decision == null) {
      throw StateError('Decision not found: $decisionId');
    }

    return _decisionToMap(decision);
  }

  Future<List<Map<String, dynamic>>> getDecisions({
    String? status,
    String? riskLevel,
    int limit = 50,
  }) async {
    List<ConscienceDecision> decisions;

    if (status != null) {
      decisions = await _database.getDecisionsByStatus(status, limit: limit);
    } else if (riskLevel != null) {
      decisions =
          await _database.getDecisionsByRiskLevel(riskLevel, limit: limit);
    } else {
      decisions = await _database.getAllDecisions(limit: limit);
    }

    return decisions.map(_decisionToMap).toList();
  }

  Map<String, dynamic> _thoughtToMap(AgentThought thought) {
    return {
      'id': thought.id,
      'timestamp': thought.timestamp.toIso8601String(),
      'channel': thought.channel,
      'agent': thought.agent,
      'thought_type': thought.thoughtType,
      'content': thought.content,
      'metadata':
          thought.metadata != null ? jsonDecode(thought.metadata!) : null,
    };
  }

  Map<String, dynamic> _decisionToMap(ConscienceDecision decision) {
    return {
      'id': decision.id,
      'timestamp': decision.timestamp.toIso8601String(),
      'action': decision.action,
      'risk_level': decision.riskLevel,
      'verdict': decision.verdict,
      'reviewer': decision.reviewer,
      'reasoning': decision.reasoning,
      'status': decision.status,
    };
  }
}
