import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/base_provider.dart';

/// Hermes Agent provider adapter.
///
/// Talks to the Hermes built-in OpenAI-compatible HTTP API server
/// (default: http://127.0.0.1:8642/v1/chat/completions).
/// Implements [LlmProvider] so it plugs into the existing [RouterServer]
/// alongside Google, Moonshot, Zhipu, etc.
class HermesProviderAdapter implements LlmProvider {
  final String _hermesBaseUrl;
  final String? apiKey;

  /// Reusable HTTP client for connection pooling.
  http.Client? _client;

  HermesProviderAdapter({
    String baseUrl = 'http://127.0.0.1:8642',
    this.apiKey,
  }) : _hermesBaseUrl = baseUrl;

  @override
  String get name => 'hermes';

  @override
  String get baseUrl => '$_hermesBaseUrl/v1';

  // ---------------------------------------------------------------------------
  // LlmProvider interface
  // ---------------------------------------------------------------------------

  @override
  Stream<StreamEvent> streamCompletion(CompletionRequest request) async* {
    _client ??= http.Client();

    final body = jsonEncode({
      'model': request.model == 'default' ? 'hermes-agent' : request.model,
      'messages': request.messages,
      'stream': true,
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.maxTokens != null) 'max_tokens': request.maxTokens,
      if (request.user != null) 'user': request.user,
    });

    try {
      final httpRequest =
          http.Request('POST', Uri.parse('$_hermesBaseUrl/v1/chat/completions'))
            ..headers.addAll(_headers())
            ..body = body;

      final streamedResponse = await _client!.send(httpRequest);

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        throw Exception(
          'Hermes API error ${streamedResponse.statusCode}: $errorBody',
        );
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
            if (data == '[DONE]') continue;

            try {
              // Forward the raw SSE data — it's already in OpenAI format
              yield StreamEvent(
                id: 'hermes-${DateTime.now().millisecondsSinceEpoch}',
                data: data,
              );
            } catch (_) {
              // Skip malformed lines
            }
          }
        }
      }
    } finally {
      // Keep client alive for pooling
    }
  }

  @override
  Future<CompletionResponse> complete(CompletionRequest request) async {
    _client ??= http.Client();

    final body = jsonEncode({
      'model': request.model == 'default' ? 'hermes-agent' : request.model,
      'messages': request.messages,
      'stream': false,
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.maxTokens != null) 'max_tokens': request.maxTokens,
      if (request.user != null) 'user': request.user,
    });

    final response = await _client!.post(
      Uri.parse('$_hermesBaseUrl/v1/chat/completions'),
      headers: _headers(),
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Hermes API error ${response.statusCode}: ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseResponse(json, request.model);
  }

  /// Dispose of the HTTP client.
  void dispose() {
    _client?.close();
    _client = null;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (apiKey != null && apiKey!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  CompletionResponse _parseResponse(Map<String, dynamic> json, String model) {
    final choices = json['choices'] as List<dynamic>?;
    Choice? choice;
    if (choices != null && choices.isNotEmpty) {
      final c = choices[0] as Map<String, dynamic>;
      final message = c['message'] as Map<String, dynamic>?;
      choice = Choice(
        index: c['index'] as int? ?? 0,
        message: Message(
          role: message?['role'] as String? ?? 'assistant',
          content: message?['content'] as String? ?? '',
        ),
        finishReason: c['finish_reason'] as String?,
      );
    }

    final usageJson = json['usage'] as Map<String, dynamic>?;
    Usage? usage;
    if (usageJson != null) {
      usage = Usage(
        promptTokens: usageJson['prompt_tokens'] as int? ?? 0,
        completionTokens: usageJson['completion_tokens'] as int? ?? 0,
        totalTokens: usageJson['total_tokens'] as int? ?? 0,
      );
    }

    return CompletionResponse(
      id: json['id'] as String? ??
          'hermes-${DateTime.now().millisecondsSinceEpoch}',
      object: json['object'] as String? ?? 'chat.completion',
      created: json['created'] as int? ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
      model: json['model'] as String? ?? model,
      choices: choice != null ? [choice] : [],
      usage: usage,
    );
  }
}
