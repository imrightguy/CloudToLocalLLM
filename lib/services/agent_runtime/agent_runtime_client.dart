import 'package:cloudtolocalllm/models/agent_event.dart';
import 'package:cloudtolocalllm/models/streaming_message.dart';
import 'package:cloudtolocalllm/services/streaming_service.dart';

enum AgentRuntimeKind {
  hermes,
  openclaw,
  custom,
  hosted,
}

enum RuntimeConnectionState {
  disconnected,
  connecting,
  connected,
  unhealthy,
}

class RuntimeIdentity {
  final AgentRuntimeKind kind;
  final String id;
  final String name;
  final String baseUrl;
  final String? deviceId;

  const RuntimeIdentity({
    required this.kind,
    required this.id,
    required this.name,
    required this.baseUrl,
    this.deviceId,
  });
}

class RuntimeHealth {
  final RuntimeConnectionState state;
  final String? message;

  const RuntimeHealth({
    required this.state,
    this.message,
  });

  bool get isHealthy => state == RuntimeConnectionState.connected;
}

class RuntimeCapabilityManifest {
  final bool chatStreaming;
  final bool agentEvents;
  final bool toolRequests;
  final bool desktopActionRequests;
  final bool voice;
  final List<String> models;

  const RuntimeCapabilityManifest({
    required this.chatStreaming,
    required this.agentEvents,
    required this.toolRequests,
    required this.desktopActionRequests,
    required this.voice,
    this.models = const [],
  });
}

abstract class AgentRuntimeClient {
  RuntimeIdentity get identity;
  RuntimeCapabilityManifest get capabilityManifest;
  RuntimeConnectionState get connectionState;
  Stream<AgentEvent> get agentEventStream;
  StreamingService? get streamingService;

  Future<void> connect();
  Future<void> disconnect();
  Future<RuntimeHealth> health();
  Future<List<String>> getAvailableModels();

  Stream<StreamingMessage> streamChat({
    required String prompt,
    required String model,
    required String conversationId,
    List<Map<String, String>>? history,
  });

  Future<String?> sendChatMessage({
    required String prompt,
    required String model,
    List<Map<String, String>>? history,
  });
}
