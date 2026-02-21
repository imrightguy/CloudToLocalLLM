import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../config/app_config.dart';
import '../models/streaming_message.dart';
import 'streaming_service.dart';
import 'auth_service.dart';

/// Shared WebSocket connection for streaming
class _SharedWebSocket {
  static _SharedWebSocket? _instance;
  WebSocketChannel? _channel;
  bool _isConnected = false;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  String? _authToken;
  String? _gatewayToken; // OpenClaw Gateway token for local connections
  String? _gatewayPassword; // OpenClaw Gateway password for local connections

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _isConnected;

  static _SharedWebSocket get instance {
    _instance ??= _instance = _SharedWebSocket._();
    return _instance!;
  }

  _SharedWebSocket._();

  /// Set the OpenClaw Gateway token
  void setGatewayToken(String? token) {
    _gatewayToken = token;
  }

  /// Set the OpenClaw Gateway password
  void setGatewayPassword(String? password) {
    _gatewayPassword = password;
  }

  Future<void> connect(String baseUrl, {String? authToken}) async {
    if (_channel != null && _isConnected) return;

    _authToken = authToken ?? '';

    final wsUrl = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');

    _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/'));
    await _channel!.ready;

    // Listen and broadcast messages
    _channel!.stream.listen(
      (data) {
        final msg = jsonDecode(data.toString());
        _messageController.add(msg);
      },
      onError: (e) {
        debugPrint('☁ [_SharedWebSocket] Error: $e');
        _isConnected = false;
      },
      onDone: () {
        debugPrint('☁ [_SharedWebSocket] Connection closed');
        _isConnected = false;
      },
    );

    // Check if this is a local connection
    final isLocalConnection = wsUrl.contains('127.0.0.1') ||
        wsUrl.contains('localhost') ||
        wsUrl.contains('::1');

    // Build handshake request
    final Map<String, dynamic> handshake;

    if (!isLocalConnection && _authToken != null && _authToken!.isNotEmpty) {
      // Cloud connection with OAuth
      handshake = {
        'type': 'req',
        'id': 'connect-${DateTime.now().millisecondsSinceEpoch}',
        'method': 'connect',
        'params': {
          'minProtocol': 3,
          'maxProtocol': 3,
          'client': {
            'id': 'cli',
            'version': '10.1.187',
            'platform': 'linux',
            'mode': 'cli'
          },
          'role': 'operator',
          'scopes': ['operator.read', 'operator.write'],
          'caps': [],
          'auth': {'token': _authToken},
          'locale': 'en-US',
          'userAgent': 'CloudToLocalLLM/10.1.187',
        }
      };
    } else {
      // Local connection with gateway password from secure storage
      if (_gatewayPassword == null || _gatewayPassword!.isEmpty) {
        throw Exception(
            'OpenClaw Gateway password not configured. Please add it in Settings > OpenClaw Gateway.');
      }

      handshake = {
        'type': 'req',
        'id': 'connect-${DateTime.now().millisecondsSinceEpoch}',
        'method': 'connect',
        'params': {
          'minProtocol': 3,
          'maxProtocol': 3,
          'client': {
            'id': 'cli',
            'version': '10.1.187',
            'platform': 'linux',
            'mode': 'cli'
          },
          'role': 'operator',
          'scopes': ['operator.read', 'operator.write'],
          'caps': [],
          'auth': {'password': _gatewayPassword},
          'locale': 'en-US',
          'userAgent': 'CloudToLocalLLM/10.1.187',
        }
      };
    }

    debugPrint(
        '☁ [_SharedWebSocket] Handshake: ${isLocalConnection ? "local" : "cloud"}');
    _channel!.sink.add(jsonEncode(handshake));
    // Don't set _isConnected until handshake completes

    debugPrint('☁ [_SharedWebSocket] Handshake sent, waiting for hello-ok');

    // Wait for hello-ok response
    try {
      await for (final msg
          in _messageController.stream.timeout(Duration(seconds: 10))) {
        if (msg['type'] == 'res' && msg['payload']?['type'] == 'hello-ok') {
          debugPrint('☁ [_SharedWebSocket] Handshake complete');
          _isConnected = true;
          break;
        }
      }
    } catch (e) {
      debugPrint('☁ [_SharedWebSocket] Handshake timeout/error: $e');
    }
  }

  void send(Map<String, dynamic> msg) {
    _channel?.sink.add(jsonEncode(msg));
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }
}

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
  })  : _baseUrl = baseUrl ??
            AppConfig.defaultGatewayUrl, // Use local OpenClaw gateway
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
    // Use shared WebSocket connection
    final ws = _SharedWebSocket.instance;

    if (!ws.isConnected) {
      // Get auth token from auth service
      String? token;
      try {
        token = await _authService.getAccessToken();
      } catch (e) {
        debugPrint('☁ [CloudStreaming] ⚠ Failed to get access token: $e');
        // Continue without token - some providers may not require authentication
      }
      await ws.connect(_baseUrl, authToken: token ?? '');
    }

    _connection = _connection.copyWith(
      state: StreamingConnectionState.streaming,
      lastActivity: DateTime.now(),
    );
    notifyListeners();

    final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    final idempotencyKey = 'chat-$requestId';
    int sequence = 0;
    String? runId;

    try {
      debugPrint('☁ [CloudStreaming] Starting chat.send for model: $model');

      // Send chat.send request with correct OpenClaw protocol params
      final chatRequest = {
        'type': 'req',
        'id': requestId,
        'method': 'chat.send',
        'params': {
          'sessionKey': 'global',
          'message': prompt,
          'idempotencyKey': idempotencyKey,
        }
      };

      ws.send(chatRequest);

      // Listen for responses
      await for (final msg in ws.messages) {
        // Handle chat.send response (acknowledgment with runId)
        if (msg['type'] == 'res' && msg['id'] == requestId) {
          if (msg['ok'] == true) {
            runId = msg['payload']?['runId'];
            debugPrint('☁ [CloudStreaming] Chat started, runId: $runId');
          } else {
            throw Exception(msg['error']?['message'] ?? 'Chat request failed');
          }
        }

        // Handle chat events (streaming text and final message)
        if (msg['type'] == 'event' && msg['event'] == 'chat') {
          final payload = msg['payload'] as Map<String, dynamic>?;
          final eventRunId = payload?['runId'] as String?;
          final state = payload?['state'] as String?;

          // Only process events for our run
          if (runId != null && eventRunId == runId) {
            if (state == 'final') {
              // Extract final message content
              final message = payload?['message'] as Map<String, dynamic>?;
              final content = message?['content'] as List?;
              if (content != null) {
                for (final block in content) {
                  if (block is Map && block['type'] == 'text') {
                    final text = block['text'] as String? ?? '';
                    if (text.isNotEmpty) {
                      final chunk = StreamingMessage.chunk(
                        id: messageId,
                        conversationId: conversationId,
                        chunk: text,
                        sequence: sequence++,
                        model: model,
                      );
                      yield chunk;
                      _messageSubject.add(chunk);
                    }
                  }
                }
              }

              // Send complete message
              final completeMessage = StreamingMessage.complete(
                id: messageId,
                conversationId: conversationId,
                sequence: sequence,
                model: model,
              );
              yield completeMessage;
              _messageSubject.add(completeMessage);
              break;
            } else if (state == 'error') {
              throw Exception(payload?['errorMessage'] ?? 'Chat error');
            }
          }
        }
      }

      _connection = _connection.copyWith(
        state: StreamingConnectionState.connected,
        lastActivity: DateTime.now(),
      );
      notifyListeners();

      debugPrint('☁ [CloudStreaming] Stream completed');
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

  /// Set the OpenClaw Gateway password
  void setGatewayPassword(String? password) {
    _SharedWebSocket.instance.setGatewayPassword(password);
  }

  /// Set the OpenClaw Gateway token
  void setGatewayToken(String? token) {
    _SharedWebSocket.instance.setGatewayToken(token);
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
