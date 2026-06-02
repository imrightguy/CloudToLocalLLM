import 'dart:async';

import 'package:cloudtolocalllm/models/agent_event.dart';
import 'package:cloudtolocalllm/models/streaming_message.dart';
import 'package:cloudtolocalllm/services/agent_runtime/agent_runtime_client.dart';
import 'package:cloudtolocalllm/services/hermes/hermes_process_client.dart';
import 'package:cloudtolocalllm/services/streaming_service.dart';

/// An [AgentRuntimeClient] backed by [HermesProcessClient] instead of
/// the HTTP gateway. Uses child process stdin/stdout — survives gateway
/// restarts, just like the Hermes TUI.
class HermesProcessBackedRuntimeClient implements AgentRuntimeClient {
  final HermesProcessClient _processClient;
  final String _baseUrl;

  RuntimeConnectionState _connectionState = RuntimeConnectionState.disconnected;
  RuntimeCapabilityManifest _capabilityManifest =
      const RuntimeCapabilityManifest(
    chatStreaming: true,
    agentEvents: true,  // Now supports agent events via the process client
    toolRequests: false,
    desktopActionRequests: false,
    voice: false,
  );

  HermesProcessBackedRuntimeClient(
    this._processClient, {
    String baseUrl = 'process:hermes-agent',
  }) : _baseUrl = baseUrl;

  @override
  RuntimeIdentity get identity => RuntimeIdentity(
        kind: AgentRuntimeKind.hermes,
        id: 'hermes:$_baseUrl',
        name: 'Hermes Agent (process)',
        baseUrl: _baseUrl,
      );

  @override
  RuntimeCapabilityManifest get capabilityManifest => _capabilityManifest;

  @override
  RuntimeConnectionState get connectionState => _connectionState;

  @override
  Stream<AgentEvent> get agentEventStream => _processClient.agentEventStream;

  @override
  StreamingService? get streamingService => _processClient;

  @override
  Future<void> connect() async {
    _connectionState = RuntimeConnectionState.connecting;
    await _processClient.establishConnection();
    _connectionState = _processClient.connection.isActive
        ? RuntimeConnectionState.connected
        : RuntimeConnectionState.unhealthy;
    _capabilityManifest = RuntimeCapabilityManifest(
      chatStreaming: true,
      agentEvents: false,
      toolRequests: false,
      desktopActionRequests: false,
      voice: false,
      models: ['default'],
    );
  }

  @override
  Future<void> disconnect() async {
    await _processClient.closeConnection();
    _connectionState = RuntimeConnectionState.disconnected;
  }

  @override
  Future<RuntimeHealth> health() async {
    final healthy = await _processClient.testConnection();
    _connectionState = healthy
        ? RuntimeConnectionState.connected
        : RuntimeConnectionState.unhealthy;
    return RuntimeHealth(
      state: _connectionState,
      message: healthy
          ? 'Hermes agent process is available'
          : 'Hermes agent process is unavailable',
    );
  }

  @override
  Future<List<String>> getAvailableModels() async {
    return ['default'];
  }

  @override
  Stream<StreamingMessage> streamChat({
    required String prompt,
    required String model,
    required String conversationId,
    List<Map<String, String>>? history,
  }) {
    return _processClient.streamResponse(
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
        throw StateError(message.error ?? 'Hermes process stream failed');
      }
      if (message.isDataChunk) {
        chunks.write(message.chunk);
      }
    }

    final response = chunks.toString().trim();
    return response.isEmpty ? null : response;
  }
}
