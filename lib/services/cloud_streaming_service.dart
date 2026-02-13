import 'dart:async';
import 'dart:convert';
import 'dart:convert' as convert;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../config/app_config.dart';
import '../models/streaming_message.dart';
import 'streaming_service.dart';
import 'auth_service.dart';

/// Cloud streaming service implementation
///
/// Handles streaming communication with cloud Ollama proxy through WebSocket
/// and HTTP streaming protocols.
class CloudStreamingService extends StreamingService {
  final String _baseUrl;
  final StreamingConfig _config;
  final AuthService _authService;
  final Dio _dio = Dio();

  StreamingConnection _connection = StreamingConnection.disconnected();
  final BehaviorSubject<StreamingMessage> _messageSubject =
      BehaviorSubject<StreamingMessage>();

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  CloudStreamingService({
    String? baseUrl,
    StreamingConfig? config,
    required AuthService authService,
  })  : _baseUrl = baseUrl ?? AppConfig.cloudGatewayUrl,
        _config = config ?? StreamingConfig.cloud(),
        _authService = authService {
    _setupDio();
    if (kDebugMode) {
      debugPrint('☁ [CloudStreaming] Service initialized');
      debugPrint('☁ [CloudStreaming] Base URL: $_baseUrl');
      debugPrint('☁ [CloudStreaming] Config: $_config');
    }
  }

  void _setupDio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = _config.connectionTimeout;
    _dio.options.receiveTimeout = _config.streamTimeout;
  }

  @override
  StreamingConnection get connection => _connection;

  @override
  Stream<StreamingMessage> get messageStream => _messageSubject.stream;

  @override
  Future<void> establishConnection() async {
    if (_connection.isActive) {
      debugPrint('☁ [CloudStreaming] Connection already active');
      return;
    }

    _connection = StreamingConnection.connecting(_baseUrl);
    notifyListeners();

    try {
      final stopwatch = Stopwatch()..start();

      // Test basic connectivity first
      // final headers = await _getHeaders();
      // final response = await _dio.get(
      //   '/models',
      //   options: Options(headers: headers),
      // );

      stopwatch.stop();

      // if (response.statusCode == 200) {
      _connection = StreamingConnection.connected(_baseUrl).copyWith(
        latency: Duration(milliseconds: stopwatch.elapsedMilliseconds),
      );

      if (_config.enableHeartbeat) {
        _startHeartbeat();
      }

      notifyListeners();

      debugPrint(
        '☁ [CloudStreaming] Connected to OpenClaw Gateway '
        '(${stopwatch.elapsedMilliseconds}ms)',
      );
      // } else {
      //   throw StreamingException(
      //     'Failed to connect: HTTP ${response.statusCode}',
      //     code: 'HTTP_ERROR',
      //   );
      // }
    } catch (e) {
      _connection = StreamingConnection.error(
        'Connection failed: $e',
        endpoint: _baseUrl,
      );
      notifyListeners();

      debugPrint('☁ [CloudStreaming] Connection error: $e');
      rethrow;
    }
  }

  @override
  Future<void> closeConnection() async {
    debugPrint('☁ [CloudStreaming] Closing connection');

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _channel?.sink.close();
    _channel = null;

    _connection = StreamingConnection.disconnected();
    notifyListeners();
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

    _connection = _connection.copyWith(
      state: StreamingConnectionState.streaming,
      lastActivity: DateTime.now(),
    );
    notifyListeners();

    final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    int sequence = 0;

    try {
      final messages = [
        if (history != null) ...history,
        {'role': 'user', 'content': prompt},
      ];

      final requestBody = {
        'model': model,
        'messages': messages,
        'stream': true,
      };

      debugPrint('☁ [CloudStreaming] Starting stream for model: $model');

      final baseHeaders = await _getHeaders();
      final endpoint = _baseUrl.endsWith('/v1')
          ? '/chat/completions'
          : '/v1/chat/completions';

      final response = await _dio.post(
        endpoint,
        data: requestBody,
        options: Options(
          headers: {
            ...baseHeaders,
            'Accept': 'text/event-stream',
          },
          responseType: ResponseType.stream,
        ),
      );

      if (response.statusCode != 200) {
        throw StreamingException(
          'Stream request failed: HTTP ${response.statusCode}',
          code: 'STREAM_ERROR',
        );
      }

      // Process streaming response (OpenAI SSE format)
      // Using LineSplitter ensures we handle partial packets correctly
      // We use .cast<List<int>>() to satisfy the type system for Utf8Decoder
      final stream = response.data.stream.cast<List<int>>();
      final lineStream = stream
          .transform(convert.utf8.decoder)
          .transform(const convert.LineSplitter());

      await for (final line in lineStream) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;
        if (!trimmedLine.startsWith('data: ')) continue;

        final dataStr = trimmedLine.substring(6).trim();
        if (dataStr == '[DONE]') break;

        try {
          final data = json.decode(dataStr);
          final delta = data['choices']?[0]?['delta'];
          if (delta == null) continue;

          final content = delta['content'] as String?;
          final reasoning = delta['reasoning_content'] as String?;

          if (kDebugMode) {
            debugPrint(
                '☁ [CloudStreaming] Chunk - Content: ${content?.length ?? "null"}, Reasoning: ${reasoning?.length ?? "null"}');
          }

          if ((content != null && content.isNotEmpty) ||
              (reasoning != null && reasoning.isNotEmpty)) {
            final message = StreamingMessage.chunk(
              id: messageId,
              conversationId: conversationId,
              chunk: content ?? '',
              reasoning: reasoning,
              sequence: sequence++,
              model: model,
            );

            yield message;
            _messageSubject.add(message);
          }
        } catch (e) {
          debugPrint('☁ [CloudStreaming] Error parsing SSE line: $e');
        }
      }

      final completeMessage = StreamingMessage.complete(
        id: messageId,
        conversationId: conversationId,
        sequence: sequence,
        model: model,
      );

      yield completeMessage;
      _messageSubject.add(completeMessage);

      _connection = _connection.copyWith(
        state: StreamingConnectionState.connected,
        lastActivity: DateTime.now(),
      );
      notifyListeners();
    } catch (e) {
      final errorMessage = StreamingMessage.error(
        id: messageId,
        conversationId: conversationId,
        error: e.toString(),
        sequence: sequence,
      );

      yield errorMessage;
      _messageSubject.add(errorMessage);

      _connection = StreamingConnection.error(
        'Streaming failed: $e',
        endpoint: _baseUrl,
      );
      notifyListeners();

      debugPrint('☁ [CloudStreaming] Stream error: $e');
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      await establishConnection();
      return _connection.isActive;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<String>> getAvailableModels() async {
    if (!_connection.isActive) {
      await establishConnection();
    }

    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '/tags',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final models = (data['models'] as List?)
                ?.map((model) => model['name'] as String)
                .toList() ??
            [];

        debugPrint('☁ [CloudStreaming] Found ${models.length} models');
        return models;
      } else {
        throw StreamingException(
          'Failed to get models: HTTP ${response.statusCode}',
          code: 'HTTP_ERROR',
        );
      }
    } catch (e) {
      debugPrint('☁ [CloudStreaming] Error getting models: $e');
      return [];
    }
  }

  /// Get headers for HTTP requests
  Future<Map<String, String>> _getHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Use local token if on localhost, otherwise use auth service
    if (_baseUrl.contains('127.0.0.1') || _baseUrl.contains('localhost')) {
      headers['Authorization'] = 'Bearer your-token-here';
    } else if (_authService.isAuthenticated.value) {
      final accessToken = await _authService.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    return headers;
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_channel != null) {
        _channel!.sink.add(
          json.encode({
            'type': 'ping',
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
      }
    });
  }

  @override
  void dispose() {
    debugPrint('☁ [CloudStreaming] Disposing service');
    closeConnection();
    _messageSubject.close();
    _dio.close();
    super.dispose();
  }
}
