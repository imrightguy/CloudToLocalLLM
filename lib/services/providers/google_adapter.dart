import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_provider.dart';

/// Google Gemini provider adapter
class GoogleAdapter implements LlmProvider {
  final String apiKey;

  GoogleAdapter({required this.apiKey});

  @override
  String get name => 'google';

  @override
  String get baseUrl =>
      'https://generativelanguage.googleapis.com/v1beta/models';

  @override
  Stream<StreamEvent> streamCompletion(CompletionRequest request) async* {
    final modelId = _mapModelId(request.model);
    final url =
        Uri.parse('$baseUrl/$modelId:streamGenerateContent?key=$apiKey');

    final body = {
      'contents': _mapMessages(request.messages),
      'generationConfig': {
        if (request.temperature != null) 'temperature': request.temperature,
        if (request.maxTokens != null) 'maxOutputTokens': request.maxTokens,
      },
    };

    final client = http.Client();
    try {
      final streamedResponse = await client.send(
        http.Request('POST', url)
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode(body),
      );

      if (streamedResponse.statusCode != 200) {
        throw Exception('Google API error: ${streamedResponse.statusCode}');
      }

      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
        // Gemini streaming returns a JSON array of candidates
        // This is a simplified parser for SSE-like behavior
        try {
          final json = jsonDecode(chunk);
          if (json is List) {
            for (final part in json) {
              yield StreamEvent(
                id: 'google-${DateTime.now().millisecondsSinceEpoch}',
                data: jsonEncode(_transformToOpenAi(part)),
              );
            }
          } else {
            yield StreamEvent(
              id: 'google-${DateTime.now().millisecondsSinceEpoch}',
              data: jsonEncode(_transformToOpenAi(json)),
            );
          }
        } catch (e) {
          // Chunk might be partial, need more robust SSE parsing for production
          continue;
        }
      }
    } finally {
      client.close();
    }
  }

  @override
  Future<CompletionResponse> complete(CompletionRequest request) async {
    final modelId = _mapModelId(request.model);
    final url = Uri.parse('$baseUrl/$modelId:generateContent?key=$apiKey');

    final body = {
      'contents': _mapMessages(request.messages),
      'generationConfig': {
        if (request.temperature != null) 'temperature': request.temperature,
        if (request.maxTokens != null) 'maxOutputTokens': request.maxTokens,
      },
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Google API error: ${response.statusCode} - ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseResponse(json, request.model);
  }

  String _mapModelId(String modelId) {
    if (modelId.contains('gemini-3-flash')) return 'gemini-1.5-flash';
    if (modelId.contains('gemini-3-pro')) return 'gemini-1.5-pro';
    return modelId;
  }

  List<Map<String, dynamic>> _mapMessages(List<Map<String, dynamic>> messages) {
    return messages.map((m) {
      return {
        'role': m['role'] == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': m['content']}
        ]
      };
    }).toList();
  }

  Map<String, dynamic> _transformToOpenAi(Map<String, dynamic> geminiPart) {
    final text =
        geminiPart['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
    return {
      'choices': [
        {
          'delta': {'content': text},
          'finish_reason': geminiPart['candidates']?[0]?['finishReason'],
        }
      ]
    };
  }

  CompletionResponse _parseResponse(Map<String, dynamic> json, String model) {
    final text =
        json['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
    return CompletionResponse(
      id: 'google-${DateTime.now().millisecondsSinceEpoch}',
      object: 'chat.completion',
      created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      model: model,
      choices: [
        Choice(
          index: 0,
          message: Message(role: 'assistant', content: text),
          finishReason: json['candidates']?[0]?['finishReason'],
        )
      ],
      usage:
          null, // Gemini API provides usage in a different field, can extract later
    );
  }
}
