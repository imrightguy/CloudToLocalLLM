import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

enum GatewayConnectionState { disconnected, connecting, connected, error }

/// Service to manage the WebSocket connection to the OpenClaw Gateway.
/// Handles authentication, heartbeats, and message routing.
class OpenClawGatewayService extends ChangeNotifier {
  WebSocketChannel? _channel;
  GatewayConnectionState _state = GatewayConnectionState.disconnected;
  String? _error;
  
  // Configuration (should ideally come from settings)
  final String _url = "ws://100.112.240.71:18789"; // Tailscale IP
  final String _token = "d6453f5073999c971426923e3504b47a99d0198e481d41f5";
  
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  GatewayConnectionState get state => _state;
  String? get error => _error;
  bool get isConnected => _state == GatewayConnectionState.connected;

  void connect() {
    if (_state == GatewayConnectionState.connecting || _state == GatewayConnectionState.connected) return;

    _updateState(GatewayConnectionState.connecting);
    
    try {
      debugPrint('[Gateway] Connecting to $_url...');
      _channel = WebSocketChannel.connect(Uri.parse(_url));
      
      // Perform handshake immediately
      _sendHandshake();

      _channel!.stream.listen(
        (message) => _handleMessage(message),
        onDone: () => _handleDisconnect(),
        onError: (e) => _handleError(e),
      );
    } catch (e) {
      _handleError(e);
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _updateState(GatewayConnectionState.disconnected);
  }

  void _sendHandshake() {
    final requestId = const Uuid().v4();
    final handshake = {
      "type": "req",
      "id": requestId,
      "method": "connect",
      "params": {
        "minProtocol": 1,
        "maxProtocol": 1,
        "auth": { "token": _token },
        "client": {
          "id": "cloud-to-local-llm-app",
          "displayName": "Flutter Dashboard",
          "version": "10.1.187",
          "platform": kIsWeb ? "web" : "desktop",
          "instanceId": const Uuid().v4(),
        },
        "caps": ["agent", "send", "status"]
      }
    };
    
    _sendRaw(jsonEncode(handshake));
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      debugPrint('[Gateway] Received: ${data['type']}');

      if (data['type'] == 'res' && data['ok'] == true) {
        if (_state != GatewayConnectionState.connected) {
          debugPrint('[Gateway] Handshake successful. Connected.');
          _updateState(GatewayConnectionState.connected);
          _reconnectAttempts = 0;
        }
      } else if (data['type'] == 'event') {
        _processEvent(data['event'], data['payload']);
      }
    } catch (e) {
      debugPrint('[Gateway] Error decoding message: $e');
    }
  }

  void _processEvent(String event, dynamic payload) {
    // Handle specific events from OpenClaw (e.g., status updates, agent responses)
    debugPrint('[Gateway] Event: $event');
    notifyListeners();
  }

  void sendPrompt(String text) {
    if (!isConnected) return;

    final requestId = const Uuid().v4();
    final req = {
      "type": "req",
      "id": requestId,
      "method": "agent",
      "params": {
        "message": text,
      }
    };
    _sendRaw(jsonEncode(req));
  }

  void _sendRaw(String raw) {
    _channel?.sink.add(raw);
  }

  void _handleDisconnect() {
    debugPrint('[Gateway] Disconnected.');
    _updateState(GatewayConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _handleError(dynamic e) {
    debugPrint('[Gateway] Error: $e');
    _error = e.toString();
    _updateState(GatewayConnectionState.error);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_reconnectAttempts > 10) {
       debugPrint('[Gateway] Max reconnect attempts reached.');
       return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    debugPrint('[Gateway] Retrying in ${delay.inSeconds}s...');
    
    _reconnectTimer = Timer(delay, () => connect());
  }

  void _updateState(GatewayConnectionState newState) {
    _state = newState;
    notifyListeners();
  }
}
