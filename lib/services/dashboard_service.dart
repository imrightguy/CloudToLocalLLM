import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:zoidbot/models/agent.dart';
import 'package:zoidbot/models/agent_event.dart';
import 'package:zoidbot/services/auth_service.dart';
import 'package:zoidbot/di/locator.dart';
import 'package:zoidbot/config/app_config.dart';

class DashboardService {
  final String baseUrl = '${AppConfig.apiBaseUrl}/api/agent/dashboard';
  final AuthService _authService = serviceLocator.get<AuthService>();
  WebSocketChannel? _channel;

  Future<List<Agent>> getAgents() async {
    final token = await _authService.getAccessToken();
    final response = await http.get(
      Uri.parse('$baseUrl/agents'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List data = json.decode(response.body)['data'];
      return data.map((json) => Agent.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load agents');
    }
  }

  Future<List<AgentEvent>> getRecentEvents({int limit = 50}) async {
    final token = await _authService.getAccessToken();
    final response = await http.get(
      Uri.parse('$baseUrl/events?limit=$limit'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List data = json.decode(response.body)['data'];
      return data.map((json) => AgentEvent.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load events');
    }
  }

  /**
   * Connect to the real-time event stream via WebSocket
   */
  void connectWebSocket({
    required Function(Map<String, dynamic>) onData,
    required Function(dynamic) onError,
  }) async {
    final token = await _authService.getAccessToken();
    if (token == null) {
      onError('Authentication token missing');
      return;
    }

    // Determine WS URL based on AppConfig.apiBaseUrl
    String wsUrl;
    if (AppConfig.apiBaseUrl.startsWith('https://')) {
      wsUrl = AppConfig.apiBaseUrl.replaceFirst('https://', 'wss://');
    } else {
      wsUrl = AppConfig.apiBaseUrl.replaceFirst('http://', 'ws://');
    }

    // Add /dashboard path (matching server.js upgrade handler)
    wsUrl = '$wsUrl/dashboard';

    final uri = Uri.parse('$wsUrl?token=$token');
    print('[DashboardWS] Connecting to $uri');

    try {
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> decoded = json.decode(data);
            onData(decoded);
          } catch (e) {
            print('[DashboardWS] Error decoding message: $e');
          }
        },
        onError: (error) {
          print('[DashboardWS] Connection error: $error');
          onError(error);
        },
        onDone: () {
          print('[DashboardWS] Connection closed');
          _channel = null;
        },
      );
    } catch (e) {
      print('[DashboardWS] Connection attempt failed: $e');
      onError(e);
    }
  }

  /**
   * Disconnect from the WebSocket stream
   */
  void disconnectWebSocket() {
    _channel?.sink.close();
    _channel = null;
    print('[DashboardWS] Disconnected');
  }
}
