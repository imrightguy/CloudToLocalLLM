import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_provider.dart';

/// Zhipu AI (GLM) provider adapter
class ZhipuAdapter implements LlmProvider {
  final String apiKey;

  ZhipuAdapter({required this.apiKey});

  @override
  String get name => 'zhipu';

  @override
  String get baseUrl => 'https://open.bigmodel.cn/api/paas/v4';

  @override
  Stream<StreamEvent> streamCompletion(CompletionRequest request) async* {
    final url = Uri.parse('$baseUrl/chat/completions');

    final body = {
      'model': _mapModelId(request.model),
      'messages': request.messages,
      'stream': true,
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.maxTokens != null) 'max_tokens': request.maxTokens,
    };

    final client = http.Client();
    try {
      final streamedResponse = await client.send(
        http.Request('POST', url)
          ..headers['Authorization'] = 'Bearer $apiKey'
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode(body),
      );

      if (streamedResponse.statusCode != 200) {
        throw Exception('Zhipu API error: ${streamedResponse.statusCode}');
      }

      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') return;

            yield StreamEvent(
              id: 'zhipu-${DateTime.now().millisecondsSinceEpoch}',
              data: data,
            );
          }
        }
      }
    } finally {
      client.close();
    }
  }

  @override
  Future<CompletionResponse> complete(CompletionRequest request) async {
    final url = Uri.parse('$baseUrl/chat/completions');

    final body = {
      'model': _mapModelId(request.model),
      'messages': request.messages,
      'stream': false,
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.maxTokens != null) 'max_tokens': request.maxTokens,
    };

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Zhipu API error: ${response.statusCode} - ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    return _parseResponse(json);
  }

  /// Map internal model IDs to Zhipu model IDs
  String _mapModelId(String modelId) {
    // Zhipu uses same IDs as our internal naming
    return modelId;
  }

  CompletionResponse _parseResponse(Map<String, dynamic> json) {
    return CompletionResponse(
      id: json['id'] as String,
      object: json['object'] as String,
      created: json['created'] as int,
      model: json['model'] as String,
      choices: (json['choices'] as List)
          .map((c) => Choice(
                index: c['index'] as int,
                message: Message(
                  role: c['message']['role'] as String,
                  content: c['message']['content'] as String,
                ),
                finishReason: c['finish_reason'] as String?,
              ))
          .toList(),
      usage: json['usage'] != null
          ? Usage(
              promptTokens: json['usage']['prompt_tokens'] as int,
              completionTokens: json['usage']['completion_tokens'] as int,
              totalTokens: json['usage']['total_tokens'] as int,
            )
          : null,
    );
  }
}
