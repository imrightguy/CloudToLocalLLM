import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/agent_event.dart';
import '../../models/streaming_message.dart';
import '../streaming_service.dart';
import '../../utils/logger.dart';

/// Streaming service implementation for Hermes Agent API server.
///
/// Connects to the Hermes built-in OpenAI-compatible HTTP API
/// (default: http://127.0.0.1:8642) and exposes streaming chat
/// through the [StreamingService] interface used by [StreamingChatService].
///
/// **Primary mode:** Uses `/v1/runs` + `/v1/runs/{run_id}/events` for
/// full agent lifecycle events (tool calls, reasoning, structured completion).
/// **Fallback mode:** Uses `/v1/chat/completions` SSE for text-only streaming.
///
/// Endpoints used:
/// - POST /v1/runs               — start an agent run (returns run_id)
/// - GET  /v1/runs/{run_id}/events — SSE stream of agent lifecycle events
/// - POST /v1/chat/completions   — fallback text-only streaming
/// - GET  /v1/models              — list available models
/// - GET  /health                 — health check
class HermesStreamingService extends StreamingService {
  final String _baseUrl;
  final String? _apiKey;

  /// HTTP client — kept alive for connection pooling.
  http.Client? _client;

  /// Cached connection state.
  StreamingConnection _connection = StreamingConnection.disconnected();

  /// Model IDs fetched from Hermes /v1/models endpoint.
  List<String> _modelIds = [];

  /// Stream controller for message bus (required by abstract interface).
  final StreamController<StreamingMessage> _messageController =
      StreamController<StreamingMessage>.broadcast();

  /// Stream controller for agent events (tool calls, lifecycle).
  /// Consumers who want full agent awareness listen here.
  final StreamController<AgentEvent> _agentEventController =
      StreamController<AgentEvent>.broadcast();

  /// Whether to use the full agent runs API (vs text-only chat completions).
  /// Defaults to true for rich agent integration.
  bool _useAgentRuns = true;

  HermesStreamingService({
    String? baseUrl,
    String? apiKey,
  })  : _baseUrl = baseUrl ?? 'http://127.0.0.1:8642',
        _apiKey = apiKey;

  String get baseUrl => _baseUrl;

  /// Stream of structured agent events for consumers who want full
  /// agent awareness (tool calls, reasoning, lifecycle).
  ///
  /// This is in addition to the standard [messageStream] which carries
  /// text/reasoning chunks in the traditional StreamingMessage format.
  Stream<AgentEvent> get agentEventStream => _agentEventController.stream;

  // ---------------------------------------------------------------------------
  // StreamingService interface
  // ---------------------------------------------------------------------------

  @override
  Stream<StreamingMessage> get messageStream => _messageController.stream;

  @override
  StreamingConnection get connection => _connection;

  @override
  Future<void> establishConnection() async {
    _client ??= http.Client();
    try {
      final response = await _client!.get(
        Uri.parse('$_baseUrl/health'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _connection = StreamingConnection.connected(_baseUrl);
        debugPrint('[Hermes] Connected to $_baseUrl');
        await _fetchModels();
        notifyListeners();
      } else {
        _connection = StreamingConnection.error(
          'Health check returned ${response.statusCode}',
          endpoint: _baseUrl,
        );
        notifyListeners();
      }
    } on SocketException {
      _connection = StreamingConnection.error(
        'Cannot reach Hermes at $_baseUrl',
        endpoint: _baseUrl,
      );
      notifyListeners();
    } on TimeoutException {
      _connection = StreamingConnection.error(
        'Connection to $_baseUrl timed out',
        endpoint: _baseUrl,
      );
      notifyListeners();
    } catch (e) {
      _connection = StreamingConnection.error(
        'Connection failed: $e',
        endpoint: _baseUrl,
      );
      notifyListeners();
    }
  }

  @override
  Future<void> closeConnection() async {
    _connection = StreamingConnection.disconnected();
    _client?.close();
    _client = null;
    notifyListeners();
  }

  @override
  Future<bool> testConnection() async {
    try {
      await establishConnection();
      return _connection.isActive;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getAvailableModels() async {
    await _fetchModels();
    return _modelIds;
  }

  @override
  Stream<StreamingMessage> streamResponse({
    required String prompt,
    required String model,
    required String conversationId,
    List<Map<String, String>>? history,
  }) async* {
    if (!_connection.isActive) {
      await establishConnection();
    }

    if (!_connection.isActive) {
      final errorMsg = StreamingMessage.error(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        conversationId: conversationId,
        error: 'Not connected to Hermes',
        sequence: 0,
      );
      _messageController.add(errorMsg);
      yield errorMsg;
      return;
    }

    // Try agent runs first (full structured events), fall back to chat completions
    if (_useAgentRuns) {
      yield* _streamViaAgentRuns(
        prompt: prompt,
        model: model,
        conversationId: conversationId,
        history: history,
      );
    } else {
      yield* _streamViaChatCompletions(
        prompt: prompt,
        model: model,
        conversationId: conversationId,
        history: history,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Agent Runs mode — full structured events
  // ---------------------------------------------------------------------------

  /// Stream using /v1/runs + /v1/runs/{run_id}/events.
  ///
  /// This is the primary path for Hermes integration. It gives access to:
  /// - Tool call lifecycle (started, completed)
  /// - Reasoning/thinking content
  /// - Structured text deltas
  /// - Run completion with usage stats
  Stream<StreamingMessage> _streamViaAgentRuns({
    required String prompt,
    required String model,
    required String conversationId,
    List<Map<String, String>>? history,
  }) async* {
    final client = _client ?? http.Client();
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    int sequence = 0;

    // Build input payload
    final input = <Map<String, String>>[];
    if (history != null) {
      for (final entry in history) {
        input.add({
          'role': entry['role'] ?? 'user',
          'content': entry['content'] ?? '',
        });
      }
    }
    input.add({'role': 'user', 'content': prompt});

    final body = jsonEncode({
      'input': input,
      'model': model == 'default' ? 'hermes-agent' : model,
      'session_id': conversationId, // Map app conversation → Hermes session
    });

    _connection = StreamingConnection.streaming(_baseUrl);
    notifyListeners();

    // Step 1: Start the run
    String? runId;
    try {
      final response = await client
          .post(
            Uri.parse('$_baseUrl/v1/runs'),
            headers: _headers(),
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 202) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        runId = json['run_id'] as String?;
      } else if (response.statusCode == 404) {
        // /v1/runs not available — fall back to chat completions
        appLogger.warning(
          '[Hermes] /v1/runs returned 404, falling back to chat completions',
        );
        _useAgentRuns = false;
        yield* _streamViaChatCompletions(
          prompt: prompt,
          model: model,
          conversationId: conversationId,
          history: history,
        );
        return;
      } else {
        final errorBody = response.body;
        appLogger.error(
          '[Hermes] startRun error ${response.statusCode}: $errorBody',
        );
        final errorMsg = StreamingMessage.error(
          id: messageId,
          conversationId: conversationId,
          error:
              'Hermes run start failed (${response.statusCode}): $errorBody',
          sequence: sequence++,
        );
        _messageController.add(errorMsg);
        yield errorMsg;
        return;
      }
    } on TimeoutException {
      appLogger.warning(
        '[Hermes] startRun timed out, falling back to chat completions',
      );
      _useAgentRuns = false;
      yield* _streamViaChatCompletions(
        prompt: prompt,
        model: model,
        conversationId: conversationId,
        history: history,
      );
      return;
    } catch (e) {
      appLogger.warning(
        '[Hermes] startRun failed: $e, falling back to chat completions',
      );
      _useAgentRuns = false;
      yield* _streamViaChatCompletions(
        prompt: prompt,
        model: model,
        conversationId: conversationId,
        history: history,
      );
      return;
    }

    if (runId == null) {
      final errorMsg = StreamingMessage.error(
        id: messageId,
        conversationId: conversationId,
        error: 'Hermes did not return a run_id',
        sequence: sequence++,
      );
      _messageController.add(errorMsg);
      yield errorMsg;
      return;
    }

    appLogger.info('[Hermes] Agent run started: $runId');

    // Step 2: Stream events from the run
    try {
      final request = http.Request(
        'GET',
        Uri.parse('$_baseUrl/v1/runs/$runId/events'),
      )..headers.addAll(_headers());

      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 600),
      );

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        appLogger.error(
          '[Hermes] run events error ${streamedResponse.statusCode}: $errorBody',
        );
        final errorMsg = StreamingMessage.error(
          id: messageId,
          conversationId: conversationId,
          error:
              'Hermes run events failed (${streamedResponse.statusCode}): $errorBody',
          sequence: sequence++,
        );
        _messageController.add(errorMsg);
        yield errorMsg;
        return;
      }

      // Parse SSE events
      String buffer = '';
      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
        // ignore: use_string_buffers
        buffer += chunk;
        while (buffer.contains('\n\n')) {
          final eventEnd = buffer.indexOf('\n\n');
          final eventBlock = buffer.substring(0, eventEnd);
          buffer = buffer.substring(eventEnd + 2);

          for (final line in eventBlock.split('\n')) {
            if (!line.startsWith('data: ')) continue;
            final data = line.substring(6).trim();
            if (data.startsWith(':')) continue; // SSE comment/keepalive

            try {
              final eventJson = jsonDecode(data) as Map<String, dynamic>;
              final agentEvent = AgentEvent.fromJson(eventJson);

              // Emit on the agent event stream (for consumers that want
              // full tool call awareness)
              _agentEventController.add(agentEvent);

              // Also emit as StreamingMessage for backward compatibility
              // with StreamingChatService's text/reasoning pipeline
              final sm = _agentEventToStreamingMessage(
                agentEvent: agentEvent,
                messageId: messageId,
                conversationId: conversationId,
                sequence: sequence++,
                model: model,
              );
              if (sm != null) {
                _messageController.add(sm);
                yield sm;
              }
            } catch (e) {
              appLogger.warning('[Hermes] Failed to parse run event: $e');
            }
          }
        }
      }

      // Signal completion
      final completeMsg = StreamingMessage.complete(
        id: messageId,
        conversationId: conversationId,
        sequence: sequence,
        model: model,
      );
      _messageController.add(completeMsg);
      yield completeMsg;

      _connection = StreamingConnection.connected(_baseUrl);
      notifyListeners();
    } on TimeoutException {
      final errorMsg = StreamingMessage.error(
        id: messageId,
        conversationId: conversationId,
        error: 'Hermes run events timed out',
        sequence: sequence++,
      );
      _messageController.add(errorMsg);
      yield errorMsg;
    } on SocketException catch (e) {
      _connection = StreamingConnection.error(
        'Connection lost: $e',
        endpoint: _baseUrl,
      );
      notifyListeners();
      final errorMsg = StreamingMessage.error(
        id: messageId,
        conversationId: conversationId,
        error: 'Connection lost during agent run: $e',
        sequence: sequence++,
      );
      _messageController.add(errorMsg);
      yield errorMsg;
    } catch (e) {
      appLogger.error('[Hermes] agent run stream error', error: e);
      final errorMsg = StreamingMessage.error(
        id: messageId,
        conversationId: conversationId,
        error: 'Agent run stream error: $e',
        sequence: sequence++,
      );
      _messageController.add(errorMsg);
      yield errorMsg;
    }
  }

  /// Convert an [AgentEvent] to a [StreamingMessage] for backward compatibility
  /// with the text/reasoning pipeline in StreamingChatService.
  ///
  /// Returns null for events that don't produce text/reasoning output
  /// (tool.started, tool.completed are emitted only on agentEventStream).
  StreamingMessage? _agentEventToStreamingMessage({
    required AgentEvent agentEvent,
    required String messageId,
    required String conversationId,
    required int sequence,
    required String model,
  }) {
    return switch (agentEvent) {
      AgentMessageDelta(:final delta) when delta.isNotEmpty =>
        StreamingMessage.chunk(
          id: messageId,
          conversationId: conversationId,
          chunk: delta,
          sequence: sequence,
          model: model,
        ),
      AgentReasoningAvailable(:final text) when text.isNotEmpty =>
        StreamingMessage.chunk(
          id: messageId,
          conversationId: conversationId,
          chunk: '',
          reasoning: text,
          sequence: sequence,
          model: model,
        ),
      AgentRunFailed(:final error) => StreamingMessage.error(
          id: messageId,
          conversationId: conversationId,
          error: error,
          sequence: sequence,
        ),
      // Tool events and run.completed are handled via agentEventStream.
      // run.completed produces a final text chunk with the output.
      AgentRunCompleted(:final output) when output.isNotEmpty =>
        StreamingMessage.chunk(
          id: messageId,
          conversationId: conversationId,
          chunk: output,
          sequence: sequence,
          model: model,
        ),
      // Skip tool events, empty events, and unknown events in the
      // text stream — they're only on agentEventStream.
      _ => null,
    };
  }

  // ---------------------------------------------------------------------------
  // Chat Completions mode — text-only fallback
  // ---------------------------------------------------------------------------

  /// Stream using /v1/chat/completions SSE (text-only, no tool awareness).
  Stream<StreamingMessage> _streamViaChatCompletions({
    required String prompt,
    required String model,
    required String conversationId,
    List<Map<String, String>>? history,
  }) async* {
    final client = _client ?? http.Client();
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    int sequence = 0;

    // Build OpenAI-format messages array
    final messages = <Map<String, dynamic>>[];
    if (history != null) {
      for (final entry in history) {
        messages.add({
          'role': entry['role'] ?? 'user',
          'content': entry['content'] ?? '',
        });
      }
    }
    messages.add({'role': 'user', 'content': prompt});

    final body = jsonEncode({
      'model': model == 'default' ? 'hermes-agent' : model,
      'messages': messages,
      'stream': true,
    });

    _connection = StreamingConnection.streaming(_baseUrl);
    notifyListeners();

    try {
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/v1/chat/completions'),
      )
        ..headers.addAll(_headers())
        ..body = body;

      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 300),
      );

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        appLogger.error(
          '[Hermes] API error ${streamedResponse.statusCode}: $errorBody',
        );
        final errorMsg = StreamingMessage.error(
          id: messageId,
          conversationId: conversationId,
          error: 'Hermes API error ${streamedResponse.statusCode}: $errorBody',
          sequence: sequence++,
        );
        _messageController.add(errorMsg);
        yield errorMsg;
        return;
      }

      // Parse SSE stream
      String buffer = '';
      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
        // ignore: use_string_buffers
        buffer += chunk;
        while (buffer.contains('\n\n')) {
          final eventEnd = buffer.indexOf('\n\n');
          final eventBlock = buffer.substring(0, eventEnd);
          buffer = buffer.substring(eventEnd + 2);

          for (final line in eventBlock.split('\n')) {
            if (!line.startsWith('data: ')) continue;
            final data = line.substring(6).trim();
            if (data == '[DONE]') continue;

            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final choices = json['choices'] as List<dynamic>?;
              if (choices == null || choices.isEmpty) continue;

              final delta =
                  choices[0]['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;

              if (content != null && content.isNotEmpty) {
                final msg = StreamingMessage.chunk(
                  id: messageId,
                  conversationId: conversationId,
                  chunk: content,
                  sequence: sequence++,
                  model: model,
                );
                _messageController.add(msg);
                yield msg;
              }

              // Check for reasoning/thinking content
              final reasoning = delta?['reasoning_content'] as String?;
              if (reasoning != null && reasoning.isNotEmpty) {
                final msg = StreamingMessage.chunk(
                  id: messageId,
                  conversationId: conversationId,
                  chunk: '',
                  reasoning: reasoning,
                  sequence: sequence++,
                  model: model,
                );
                _messageController.add(msg);
                yield msg;
              }
            } catch (_) {
              // Skip malformed SSE data lines
            }
          }
        }
      }

      // Signal completion
      final completeMsg = StreamingMessage.complete(
        id: messageId,
        conversationId: conversationId,
        sequence: sequence,
        model: model,
      );
      _messageController.add(completeMsg);
      yield completeMsg;

      _connection = StreamingConnection.connected(_baseUrl);
      notifyListeners();
    } on TimeoutException {
      final errorMsg = StreamingMessage.error(
        id: messageId,
        conversationId: conversationId,
        error: 'Hermes request timed out',
        sequence: sequence++,
      );
      _messageController.add(errorMsg);
      yield errorMsg;
    } on SocketException catch (e) {
      _connection = StreamingConnection.error(
        'Connection lost: $e',
        endpoint: _baseUrl,
      );
      notifyListeners();
      final errorMsg = StreamingMessage.error(
        id: messageId,
        conversationId: conversationId,
        error: 'Connection lost: $e',
        sequence: sequence++,
      );
      _messageController.add(errorMsg);
      yield errorMsg;
    } catch (e) {
      appLogger.error('[Hermes] streamResponse error', error: e);
      final errorMsg = StreamingMessage.error(
        id: messageId,
        conversationId: conversationId,
        error: 'Stream error: $e',
        sequence: sequence++,
      );
      _messageController.add(errorMsg);
      yield errorMsg;
    }
  }

  // ---------------------------------------------------------------------------
  // Non-streaming completion (for simpler use cases)
  // ---------------------------------------------------------------------------

  /// Send a non-streaming chat completion request to Hermes.
  Future<String?> complete({
    required String prompt,
    String model = 'hermes-agent',
    List<Map<String, String>>? history,
  }) async {
    if (!_connection.isActive) {
      await establishConnection();
    }

    final client = _client ?? http.Client();
    final messages = <Map<String, dynamic>>[];
    if (history != null) {
      for (final entry in history) {
        messages.add({
          'role': entry['role'] ?? 'user',
          'content': entry['content'] ?? '',
        });
      }
    }
    messages.add({'role': 'user', 'content': prompt});

    final response = await client
        .post(
          Uri.parse('$_baseUrl/v1/chat/completions'),
          headers: _headers(),
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'stream': false,
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      appLogger.error(
        '[Hermes] complete error ${response.statusCode}: ${response.body}',
      );
      return null;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>?;
    if (choices != null && choices.isNotEmpty) {
      return choices[0]['message']?['content'] as String?;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Direct run API access (for advanced consumers)
  // ---------------------------------------------------------------------------

  /// Trigger a Hermes run and get a run_id for SSE event streaming.
  ///
  /// Returns the run_id. Use [streamRunEvents] to consume the event stream.
  Future<String?> startRun({
    required String input,
    String? instructions,
    String? previousResponseId,
    String? sessionId,
  }) async {
    if (!_connection.isActive) {
      await establishConnection();
    }

    final client = _client ?? http.Client();
    final body = <String, dynamic>{
      'input': input,
    };
    if (instructions != null) body['instructions'] = instructions;
    if (previousResponseId != null) {
      body['previous_response_id'] = previousResponseId;
    }
    if (sessionId != null) body['session_id'] = sessionId;

    final response = await client
        .post(
          Uri.parse('$_baseUrl/v1/runs'),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 202) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['run_id'] as String?;
    }
    appLogger.error(
      '[Hermes] startRun error ${response.statusCode}: ${response.body}',
    );
    return null;
  }

  /// Stream structured events from a Hermes run.
  Stream<AgentEvent> streamRunEvents(String runId) async* {
    final client = _client ?? http.Client();
    final request = http.Request(
      'GET',
      Uri.parse('$_baseUrl/v1/runs/$runId/events'),
    )..headers.addAll(_headers());

    final streamedResponse = await client.send(request).timeout(
      const Duration(seconds: 600),
    );

    if (streamedResponse.statusCode != 200) {
      yield AgentRunFailed(
        runId: runId,
        timestamp: DateTime.now().millisecondsSinceEpoch / 1000,
        error: 'Failed to connect to run events stream',
      );
      return;
    }

    String buffer = '';
    await for (final chunk
        in streamedResponse.stream.transform(utf8.decoder)) {
      // ignore: use_string_buffers
      buffer += chunk;
      while (buffer.contains('\n\n')) {
        final eventEnd = buffer.indexOf('\n\n');
        final eventBlock = buffer.substring(0, eventEnd);
        buffer = buffer.substring(eventEnd + 2);

        for (final line in eventBlock.split('\n')) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data.startsWith(':')) continue; // SSE comment/keepalive

          try {
            final event = AgentEvent.fromJson(
              jsonDecode(data) as Map<String, dynamic>,
            );
            yield event;

            // Terminal events close the stream
            if (event is AgentRunCompleted || event is AgentRunFailed) {
              return;
            }
          } catch (_) {
            // Skip malformed events
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    };
    if (_apiKey != null && _apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_apiKey';
    }
    return headers;
  }

  Future<void> _fetchModels() async {
    try {
      final client = _client ?? http.Client();
      final response = await client
          .get(
            Uri.parse('$_baseUrl/v1/models'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as List? ?? [];
        _modelIds = data
            .map((m) => (m as Map<String, dynamic>)['id'] as String)
            .toList();
        debugPrint('[Hermes] Fetched ${_modelIds.length} models: $_modelIds');
      }
    } catch (e) {
      appLogger.warning('[Hermes] Failed to fetch models: $e');
    }
  }

  @override
  void dispose() {
    _messageController.close();
    _agentEventController.close();
    _client?.close();
    super.dispose();
  }
}
