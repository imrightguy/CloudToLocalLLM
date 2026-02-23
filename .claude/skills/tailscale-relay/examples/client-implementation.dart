/// Tailscale Relay Client Implementation Example
///
/// Demonstrates how to connect to the Tailscale Relay WebSocket endpoint
/// from a Flutter application for streaming LLM responses.
///
/// Usage:
/// ```dart
/// final client = TailscaleRelayClient(
///   relayUrl: 'ws://localhost:3002',
///   jwtToken: userJwtToken,
///   targetIp: '100.100.100.100',
/// );
///
/// await client.sendRequest({
///   'model': 'llama2',
///   'prompt': 'Hello, world!',
///   'stream': true,
/// });
/// ```

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class TailscaleRelayClient {
  /// Relay server URL (e.g., 'ws://localhost:3002')
  final String relayUrl;

  /// JWT authentication token
  final String jwtToken;

  /// Target device IP address (Tailscale IP)
  final String targetIp;

  /// Connection timeout duration
  final Duration connectionTimeout;

  WebSocketChannel? _channel;
  bool _isConnected = false;

  TailscaleRelayClient({
    required this.relayUrl,
    required this.jwtToken,
    required this.targetIp,
    this.connectionTimeout = const Duration(seconds: 10),
  });

  /// Connect to the relay WebSocket endpoint
  Future<WebSocketChannel> connect() async {
    if (_isConnected && _channel != null) {
      return _channel!;
    }

    final uri = Uri.parse('$relayUrl/tailscale/ws')
        .replace(queryParameters: {
      'token': jwtToken,
      'targetIp': targetIp,
    });

    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready.timeout(connectionTimeout);

      _isConnected = true;
      print('✓ Connected to Tailscale Relay: $targetIp');
      return _channel!;
    } catch (e) {
      print('✗ Failed to connect to relay: $e');
      rethrow;
    }
  }

  /// Send a request to the target LLM provider
  Future<void> sendRequest(Map<String, dynamic> request) async {
    final channel = await connect();

    try {
      final payload = jsonEncode(request);
      channel.sink.add(payload);
      print('→ Sent request: ${request['model']}');
    } catch (e) {
      print('✗ Failed to send request: $e');
      rethrow;
    }
  }

  /// Stream responses from the LLM provider
  Stream<String> get responseStream {
    if (_channel == null) {
      throw StateError('Not connected. Call connect() first.');
    }

    return _channel!.stream.map((dynamic data) {
      if (data is String) {
        return data;
      }
      return utf8.decode(data as List<int>);
    });
  }

  /// Send request and stream responses in one call
  Stream<String> requestStream(Map<String, dynamic> request) async* {
    await sendRequest(request);
    yield* responseStream;
  }

  /// Close the WebSocket connection
  void disconnect() {
    if (_isConnected && _channel != null) {
      _channel!.sink.close();
      _isConnected = false;
      print('✓ Disconnected from relay');
    }
  }

  /// Get connection status
  bool get isConnected => _isConnected;

  /// Dispose of resources
  void dispose() {
    disconnect();
  }
}

/// Example usage widget
class TailscaleRelayExample extends StatefulWidget {
  @override
  _TailscaleRelayExampleState createState() => _TailscaleRelayExampleState();
}

class _TailscaleRelayExampleState extends State<TailscaleRelayExample> {
  final _client = TailscaleRelayClient(
    relayUrl: 'ws://localhost:3002',
    jwtToken: 'your-jwt-token',
    targetIp: '100.100.100.100',
  );

  final _messages = <String>[];
  bool _isLoading = false;

  Future<void> _sendRequest() async {
    setState(() => _isLoading = true);

    try {
      final request = {
        'model': 'llama2',
        'prompt': 'Hello from Flutter!',
        'stream': true,
      };

      await for (final response
          in _client.requestStream(request).take(20)) {
        setState(() {
          _messages.add(response);
        });
      }
    } catch (e) {
      setState(() {
        _messages.add('Error: $e');
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _sendRequest,
          child: Text(_isLoading ? 'Sending...' : 'Send Request'),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _messages.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(_messages[index]),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }
}

// Required import for Flutter
import 'package:flutter/material.dart';
