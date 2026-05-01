import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final Logger _log = Logger('HermesStreamingService');

/// Service for streaming chat completions from hermes-agent.
///
/// This mirrors the OpenClaw streaming service pattern but connects to
/// hermes-agent's WebSocket endpoint.
class HermesStreamingService {
  final String _baseUrl;
  final String _model;
  final String _apiKey;
  final int _port;

  late WebSocketChannel _channel;
  final StreamController<Map<String, dynamic>> _responseController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isConnected = false;

  /// Create a new Hermes streaming service.
  ///
  /// [baseUrl] is the base URL for hermes-agent (e.g., 'ws://localhost').
  /// [port] is the port hermes-agent gateway is running on.
  /// [model] is the model ID to use.
  /// [apiKey] is the API key for authentication (if required).
  HermesStreamingService({
    String baseUrl = 'ws://localhost',
    int port = 1337,
    String model = 'hermes/model',
    String apiKey = '',
  })  : _baseUrl = baseUrl,
        _port = port,
        _model = model,
        _apiKey = apiKey;

  /// Connect to the hermes-agent gateway.
  Future<void> connect() async {
    final wsUrl = Uri.parse('$_baseUrl:$_port/v1/chat/completions');
    _log.info('Connecting to hermes-agent at $wsUrl');

    try {
      final socket = await WebSocket.connect(wsUrl.toString(), headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      });

      _channel = IOWebSocketChannel(socket);

      _channel.stream.listen(_handleMessage, onError: (error) {
        _log.severe('WebSocket error: $error');
        _isConnected = false;
        _responseController.addError(error);
      }, onDone: () {
        _log.info('WebSocket connection closed');
        _isConnected = false;
      });

      _isConnected = true;
      _log.info('Connected to hermes-agent gateway');
    } catch (e, st) {
      _log.severe('Failed to connect to hermes-agent', e, st);
      rethrow;
    }
  }

  /// Handle incoming messages from the WebSocket.
  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data);
      _responseController.add(message);
    } catch (e, st) {
      _log.warning('Failed to parse WebSocket message', e, st);
    }
  }

  /// Stream chat completions.
  ///
  /// [messages] is a list of message objects.
  /// [model] is the model to use.
  /// [temperature] is the temperature (default 0.7).
  /// [maxTokens] is the maximum tokens to generate (default null).
  Future<void> streamChatCompletion(List<Map<String, dynamic>> messages,
      {String? model, double temperature = 0.7, int? maxTokens}) async {
    if (!_isConnected) {
      throw StateError('Not connected to hermes-agent. Call connect() first.');
    }

    final request = {
      'model': model ?? _model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    };

    _log.fine('Sending chat completion request: $request');
    _channel.sink.add(jsonEncode(request));
  }

  /// Get the response stream.
  Stream<Map<String, dynamic>> get responseStream => _responseController.stream;

  /// Close the WebSocket connection.
  Future<void> close() async {
    _isConnected = false;
    await _channel.sink.close();
    await _responseController.close();
    _log.info('WebSocket connection closed');
  }

  /// Check if the service is connected.
  bool get isConnected => _isConnected;
}
