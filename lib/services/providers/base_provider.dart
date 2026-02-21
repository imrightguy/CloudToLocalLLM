import 'dart:async';

/// Standard OpenAI-compatible completion request
class CompletionRequest {
  final String model;
  final List<Map<String, dynamic>> messages;
  final bool stream;
  final double? temperature;
  final int? maxTokens;
  final String? user;

  CompletionRequest({
    required this.model,
    required this.messages,
    this.stream = false,
    this.temperature,
    this.maxTokens,
    this.user,
  });

  factory CompletionRequest.fromJson(Map<String, dynamic> json) {
    return CompletionRequest(
      model: json['model'] as String,
      messages: List<Map<String, dynamic>>.from(json['messages'] as List),
      stream: json['stream'] as bool? ?? false,
      temperature: json['temperature'] as double?,
      maxTokens: json['max_tokens'] as int?,
      user: json['user'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'model': model,
        'messages': messages,
        'stream': stream,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'max_tokens': maxTokens,
        if (user != null) 'user': user,
      };
}

/// Standard OpenAI-compatible completion response
class CompletionResponse {
  final String id;
  final String object;
  final int created;
  final String model;
  final List<Choice> choices;
  final Usage? usage;

  CompletionResponse({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
    this.usage,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'object': object,
        'created': created,
        'model': model,
        'choices': choices.map((c) => c.toJson()).toList(),
        if (usage != null) 'usage': usage!.toJson(),
      };
}

class Choice {
  final int index;
  final Message message;
  final String? finishReason;

  Choice({
    required this.index,
    required this.message,
    this.finishReason,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'message': message.toJson(),
        if (finishReason != null) 'finish_reason': finishReason,
      };
}

class Message {
  final String role;
  final String content;

  Message({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };
}

class Usage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  Usage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  Map<String, dynamic> toJson() => {
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': totalTokens,
      };
}

/// SSE event for streaming
class StreamEvent {
  final String? id;
  final String? event;
  final String data;

  StreamEvent({
    this.id,
    this.event,
    required this.data,
  });

  String toSse() {
    final buffer = StringBuffer();
    if (id != null) buffer.writeln('id: $id');
    if (event != null) buffer.writeln('event: $event');
    buffer.writeln('data: $data');
    buffer.writeln();
    return buffer.toString();
  }
}

/// Abstract interface for LLM providers
abstract class LlmProvider {
  String get name;
  String get baseUrl;

  /// Stream completion (for streaming responses)
  Stream<StreamEvent> streamCompletion(CompletionRequest request);

  /// Complete (for non-streaming responses)
  Future<CompletionResponse> complete(CompletionRequest request);
}
