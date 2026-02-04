import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloudtolocalllm/models/agent.dart';
import 'package:cloudtolocalllm/models/agent_event.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/di/locator.dart';

class DashboardService {
  final String baseUrl = 'https://api.cloudtolocalllm.com/api/agent/dashboard';
  final AuthService _authService = serviceLocator.get<AuthService>();

  Future<List<Agent>> getAgents() async {
    final token = await _authService.getToken();
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
    final token = await _authService.getToken();
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

  // WebSocket implementation placeholder
  void connectWebSocket({
    required Function(Map<String, dynamic>) onData,
    required Function(dynamic) onError,
  }) {
    // To be implemented with web_socket_channel
  }
}
