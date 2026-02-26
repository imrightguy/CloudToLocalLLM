import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

import 'providers/base_provider.dart';
import 'rate_limit_manager.dart';
import 'model_tiers.dart';
import 'avatar/personality_engine.dart';
import 'avatar/evolution_tracker.dart';
import 'conscience_storage_service.dart';
import 'package:cloudtolocalllm/models/avatar/personality_models.dart';
import 'package:cloudtolocalllm/utils/http_constants.dart';

/// Local HTTP Server that mimics OpenAI API and routes to providers
class RouterServer {
  final int port;
  final RateLimitManager rateLimitManager;
  final Map<String, LlmProvider> providers;
  final PersonalityEngine? personalityEngine;
  final EvolutionTracker? evolutionTracker;
  final ConscienceStorageService? conscienceStorage;

  HttpServer? _server;

  RouterServer({
    this.port = 1337,
    required this.rateLimitManager,
    required this.providers,
    this.personalityEngine,
    this.evolutionTracker,
    this.conscienceStorage,
  });

  /// Start the server
  Future<void> start() async {
    final router = Router();

    // GET /v1/models
    router.get('/v1/models', _handleListModels);

    // POST /v1/chat/completions
    router.post('/v1/chat/completions', _handleChatCompletions);

    // GET /health
    router.get('/health', (Request request) => Response.ok('OK'));

    // Avatar Evolution API endpoints
    if (personalityEngine != null) {
      router.get('/avatar/state', _handleGetAvatarState);
      router.post('/avatar/traits', _handleUpdateTraits);
      router.post('/avatar/evolution/request', _handleEvolutionRequest);
      router.post(
          '/api/evolution', _handleEvolutionRequest); // Harmonized endpoint
    }

    // Conscience System API endpoints (Phase 1 - Storage Layer)
    if (conscienceStorage != null) {
      router.post('/api/conscience/thoughts', _handleWriteThought);
      router.get('/api/conscience/thoughts', _handleGetThoughts);
      router.post('/api/conscience/decisions', _handleWriteDecision);
      router.get('/api/conscience/decisions', _handleGetDecisions);
      router.put('/api/conscience/decisions/verdict', _handleSubmitVerdict);
    }

    final handler =
        const Pipeline().addMiddleware(logRequests()).addHandler(router.call);

    _server = await io.serve(handler, InternetAddress.anyIPv4, port);
    debugPrint('LLM Router Server running on port ${_server!.port}');
  }

  /// Stop the server
  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  Response _handleListModels(Request request) {
    final models = ModelRegistry.models.values
        .map((m) => {
              'id': m.id,
              'object': 'model',
              'created': 1677610602,
              'owned_by': m.provider,
            })
        .toList();

    return Response.ok(
      jsonEncode({'object': 'list', 'data': models}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handleChatCompletions(Request request) async {
    try {
      final body = await request.readAsString();
      final completionRequest = CompletionRequest.fromJson(jsonDecode(body));

      final requestedModel = completionRequest.model;

      // 1. Get best available model
      final actualModel =
          await rateLimitManager.getAvailableModel(requestedModel);
      final config = ModelRegistry.get(actualModel);
      final provider = providers[config.provider];

      if (provider == null) {
        return Response.internalServerError(
            body: 'Provider not found for model: $actualModel');
      }

      // 2. Start request tracking
      await rateLimitManager.startRequest(actualModel);

      // 3. Prepare response headers
      final headers = {
        'Content-Type': 'application/json',
        'X-Actual-Model': actualModel,
        if (actualModel != requestedModel) 'X-Switched-Reason': 'rate-limit',
      };

      // 4. Dispatch to provider
      if (completionRequest.stream) {
        return _handleStreaming(
            provider, completionRequest, actualModel, headers);
      } else {
        return _handleNonStreaming(
            provider, completionRequest, actualModel, headers);
      }
    } catch (e) {
      return Response.badRequest(body: 'Error: ${e.toString()}');
    }
  }

  Future<Response> _handleStreaming(
    LlmProvider provider,
    CompletionRequest request,
    String modelId,
    Map<String, String> headers,
  ) async {
    final stream =
        provider.streamCompletion(request).map((event) => event.toSse());

    // Increment usage and decrement on close
    return Response.ok(
      stream,
      headers: {
        ...headers,
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
      context: {
        'onClose': () => rateLimitManager.endRequest(modelId),
      },
    );
  }

  Future<Response> _handleNonStreaming(
    LlmProvider provider,
    CompletionRequest request,
    String modelId,
    Map<String, String> headers,
  ) async {
    try {
      final response = await provider.complete(request);
      return Response.ok(
        jsonEncode(response.toJson()),
        headers: headers,
      );
    } finally {
      await rateLimitManager.endRequest(modelId);
    }
  }

  /// GET /avatar/state - Returns the current avatar personality state
  Future<Response> _handleGetAvatarState(Request request) async {
    if (personalityEngine == null) {
      return Response.notFound('Personality engine not available');
    }

    try {
      final profile = await personalityEngine!.getPersonality();
      return Response.ok(
        jsonEncode({
          'agent_name': profile.agentName,
          'traits': profile.traits.toMap(),
          'evolution_stage': profile.evolutionStage,
          'conversation_count': profile.conversationCount,
          'depth_score': profile.depthScore,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Error: ${e.toString()}');
    }
  }

  /// POST /avatar/traits - Updates avatar personality traits
  Future<Response> _handleUpdateTraits(Request request) async {
    if (personalityEngine == null) {
      return Response.notFound('Personality engine not available');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (!data.containsKey('traits')) {
        return Response.badRequest(body: 'Missing "traits" field');
      }

      final traitsData = data['traits'] as Map<String, dynamic>;
      final traits = PersonalityTraits.fromMap(
        traitsData.map((k, v) => MapEntry(k, (v as num).toDouble())),
      );

      await personalityEngine!.updatePersonality(traits);

      return Response.ok(
        jsonEncode({'status': 'success', 'traits': traits.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(body: 'Error: ${e.toString()}');
    }
  }

  /// POST /avatar/evolution/request - Requests an avatar evolution
  Future<Response> _handleEvolutionRequest(Request request) async {
    if (personalityEngine == null) {
      return Response.notFound('Personality engine not available');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (!data.containsKey('stage')) {
        return Response.badRequest(body: 'Missing "stage" field');
      }

      final requestedStage = data['stage'] as String;
      final reason = data['reason'] as String? ?? 'User request';

      final decision = await personalityEngine!.validateEvolutionRequest(
        requestedStage,
        reason,
      );

      final statusCode =
          decision.approved ? HttpStatus.ok : HttpStatus.badRequest;

      return Response(
        statusCode,
        body: jsonEncode({
          'approved': decision.approved,
          if (decision.newStage != null) 'new_stage': decision.newStage,
          if (decision.reason != null) 'reason': decision.reason,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(body: 'Error: ${e.toString()}');
    }
  }

  // ==========================================================================
  // CONSCIENCE SYSTEM API HANDLERS (Phase 1 - Storage Layer)
  // ==========================================================================

  /// POST /api/conscience/thoughts - Write a thought
  Future<Response> _handleWriteThought(Request request) async {
    if (conscienceStorage == null) {
      return Response.notFound('Conscience storage not available');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (!data.containsKey('agent') ||
          !data.containsKey('thought_type') ||
          !data.containsKey('content')) {
        return Response.badRequest(
            body: 'Missing required fields: agent, thought_type, content');
      }

      final thought = await conscienceStorage!.writeThought(
        agent: data['agent'] as String,
        thoughtType: data['thought_type'] as String,
        content: data['content'] as String,
        channel: data['channel'] as String? ?? 'general',
        metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      );

      return Response.ok(
        jsonEncode({'status': 'success', 'thought': thought}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Error: ${e.toString()}');
    }
  }

  /// GET /api/conscience/thoughts - Read thoughts
  Future<Response> _handleGetThoughts(Request request) async {
    if (conscienceStorage == null) {
      return Response.notFound('Conscience storage not available');
    }

    try {
      final agent = request.url.queryParameters['agent'];
      final channel = request.url.queryParameters['channel'];
      final thoughtType = request.url.queryParameters['thought_type'];
      final limit =
          int.tryParse(request.url.queryParameters['limit'] ?? '50') ?? 50;

      final thoughts = await conscienceStorage!.getThoughts(
        agent: agent,
        channel: channel,
        thoughtType: thoughtType,
        limit: limit,
      );

      return Response.ok(
        jsonEncode({'thoughts': thoughts}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Error: ${e.toString()}');
    }
  }

  /// POST /api/conscience/decisions - Submit a decision for review
  Future<Response> _handleWriteDecision(Request request) async {
    if (conscienceStorage == null) {
      return Response.notFound('Conscience storage not available');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (!data.containsKey('action') || !data.containsKey('risk_level')) {
        return Response.badRequest(
            body: 'Missing required fields: action, risk_level');
      }

      final decision = await conscienceStorage!.writeDecision(
        action: data['action'] as String,
        riskLevel: data['risk_level'] as String,
      );

      return Response.ok(
        jsonEncode({'status': 'success', 'decision': decision}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Error: ${e.toString()}');
    }
  }

  /// GET /api/conscience/decisions - Get decisions
  Future<Response> _handleGetDecisions(Request request) async {
    if (conscienceStorage == null) {
      return Response.notFound('Conscience storage not available');
    }

    try {
      final status = request.url.queryParameters['status'];
      final riskLevel = request.url.queryParameters['risk_level'];
      final limit =
          int.tryParse(request.url.queryParameters['limit'] ?? '50') ?? 50;

      final decisions = await conscienceStorage!.getDecisions(
        status: status,
        riskLevel: riskLevel,
        limit: limit,
      );

      return Response.ok(
        jsonEncode({'decisions': decisions}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Error: ${e.toString()}');
    }
  }

  /// PUT /api/conscience/decisions/verdict - Submit a verdict
  Future<Response> _handleSubmitVerdict(Request request) async {
    if (conscienceStorage == null) {
      return Response.notFound('Conscience storage not available');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (!data.containsKey('decision_id') ||
          !data.containsKey('verdict') ||
          !data.containsKey('reviewer') ||
          !data.containsKey('reasoning')) {
        return Response.badRequest(
            body: 'Missing required fields: '
                'decision_id, verdict, reviewer, reasoning');
      }

      final decision = await conscienceStorage!.submitDecisionVerdict(
        decisionId: data['decision_id'] as String,
        verdict: data['verdict'] as String,
        reviewer: data['reviewer'] as String,
        reasoning: data['reasoning'] as String,
      );

      return Response.ok(
        jsonEncode({'status': 'success', 'decision': decision}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Error: ${e.toString()}');
    }
  }
}
