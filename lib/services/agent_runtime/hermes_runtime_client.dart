import 'dart:async';

import 'package:cloudtolocalllm/models/agent_event.dart';
import 'package:cloudtolocalllm/models/streaming_message.dart';
import 'package:cloudtolocalllm/services/agent_runtime/agent_runtime_client.dart';
import 'package:cloudtolocalllm/services/hermes/hermes_streaming_service.dart';
import 'package:cloudtolocalllm/services/streaming_service.dart';

class HermesRuntimeClient implements AgentRuntimeClient {
  final String baseUrl;
  final String? apiKey;
  late final HermesStreamingService _streamingService;
  RuntimeConnectionState _connectionState = RuntimeConnectionState.disconnected;
  RuntimeCapabilityManifest _capabilityManifest =
      const RuntimeCapabilityManifest(
    chatStreaming: true,
    agentEvents: true,
    toolRequests: true,
    desktopActionRequests: true,
    voice: true,
  );

  HermesRuntimeClient({
    required this.baseUrl,
    this.apiKey,
  }) {
    _streamingService = HermesStreamingService(
      baseUrl: baseUrl,
      apiKey: apiKey,
    );
  }

  @override
  RuntimeIdentity get identity => RuntimeIdentity(
        kind: AgentRuntimeKind.hermes,
        id: 'hermes:$baseUrl',
        name: 'Hermes Agent',
        baseUrl: baseUrl,
      );

  @override
  RuntimeCapabilityManifest get capabilityManifest => _capabilityManifest;

  @override
  RuntimeConnectionState get connectionState => _connectionState;

  @override
  Stream<AgentEvent> get agentEventStream => _streamingService.agentEventStream;

  @override
  StreamingService get streamingService => _streamingService;

  @override
  Future<void> connect() async {
    _connectionState = RuntimeConnectionState.connecting;
    await _streamingService.establishConnection();
    _connectionState = _streamingService.connection.isActive
        ? RuntimeConnectionState.connected
        : RuntimeConnectionState.unhealthy;
    final models = await _streamingService.getAvailableModels();
    _capabilityManifest = RuntimeCapabilityManifest(
      chatStreaming: true,
      agentEvents: true,
      toolRequests: true,
      desktopActionRequests: true,
      voice: true,
      models: models,
    );
  }

  @override
  Future<void> disconnect() async {
    await _streamingService.closeConnection();
    _connectionState = RuntimeConnectionState.disconnected;
  }

  @override
  Future<RuntimeHealth> health() async {
    final healthy = await _streamingService.testConnection();
    _connectionState = healthy
        ? RuntimeConnectionState.connected
        : RuntimeConnectionState.unhealthy;
    return RuntimeHealth(
      state: _connectionState,
      message:
          healthy ? 'Hermes Agent is reachable' : 'Hermes Agent is unreachable',
    );
  }

  @override
  Future<List<String>> getAvailableModels() async {
    final models = await _streamingService.getAvailableModels();
    _capabilityManifest = RuntimeCapabilityManifest(
      chatStreaming: true,
      agentEvents: true,
      toolRequests: true,
      desktopActionRequests: true,
      voice: true,
      models: models,
    );
    return models;
  }

  @override
  Stream<StreamingMessage> streamChat({
    required String prompt,
    required String model,
    required String conversationId,
    List<Map<String, String>>? history,
  }) {
    return _streamingService.streamResponse(
      prompt: prompt,
      model: model,
      conversationId: conversationId,
      history: history,
    );
  }

  @override
  Future<String?> sendChatMessage({
    required String prompt,
    required String model,
    List<Map<String, String>>? history,
  }) async {
    final chunks = StringBuffer();
    final conversationId = DateTime.now().microsecondsSinceEpoch.toString();

    await for (final message in streamChat(
      prompt: prompt,
      model: model,
      conversationId: conversationId,
      history: history,
    )) {
      if (message.hasError) {
        throw StateError(message.error ?? 'Hermes stream failed');
      }
      if (message.isDataChunk) {
        chunks.write(message.chunk);
      }
    }

    final response = chunks.toString().trim();
    return response.isEmpty ? null : response;
  }
}
