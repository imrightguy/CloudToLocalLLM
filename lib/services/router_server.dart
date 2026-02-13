import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

import 'providers/base_provider.dart';
import 'rate_limit_manager.dart';
import 'model_tiers.dart';

/// Local HTTP Server that mimics OpenAI API and routes to providers
class RouterServer {
  final int port;
  final RateLimitManager rateLimitManager;
  final Map<String, LlmProvider> providers;

  HttpServer? _server;

  RouterServer({
    this.port = 1337,
    required this.rateLimitManager,
    required this.providers,
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
}
