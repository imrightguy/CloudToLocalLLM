import 'dart:convert';
import 'dart:io';

import 'package:cloudtolocalllm/database/drift_local_brain.dart' as brain;
import 'package:cloudtolocalllm/services/providers/base_provider.dart'
    as provider;
import 'package:cloudtolocalllm/services/rate_limit_manager.dart';
import 'package:cloudtolocalllm/services/router_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
  });

  group('RouterServer local security defaults', () {
    RouterServer? server;

    tearDown(() async {
      await server?.stop();
      server = null;
    });

    test('can be constructed with default port', () async {
      server = _buildRouter(port: 0);
      expect(server, isNotNull);
    });

    // Tests 1 & 2: re-enabled — auth middleware now implemented (#422).
    test('rejects privileged local requests when no local token is available',
        () async {
      final baseUrl = await _startRouter(serverRef: (value) => server = value);

      final response = await http.post(
        baseUrl.replace(path: '/v1/chat/completions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'glm-4-flash',
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
        }),
      );

      expect(response.statusCode, HttpStatus.forbidden);
    });

    test('rejects privileged local requests without the configured local token',
        () async {
      final baseUrl = await _startRouter(serverRef: (value) => server = value);

      final response = await http.post(
        baseUrl.replace(path: '/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer wrong-token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'glm-4-flash',
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
        }),
      );

      expect(response.statusCode, HttpStatus.unauthorized);
    });

    test('allows privileged local requests with the configured bearer token',
        () async {
      final baseUrl = await _startRouter(serverRef: (value) => server = value);

      final response = await http.post(
        baseUrl.replace(path: '/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer router-secret',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'glm-4-flash',
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
        }),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(jsonDecode(response.body), containsPair('model', 'glm-4-flash'));
    });

    test('keeps health and model listing available locally without a token',
        () async {
      final baseUrl = await _startRouter(serverRef: (value) => server = value);

      final health = await http.get(baseUrl.replace(path: '/health'));
      final models = await http.get(baseUrl.replace(path: '/v1/models'));

      expect(health.statusCode, HttpStatus.ok);
      expect(health.body, 'OK');
      expect(models.statusCode, HttpStatus.ok);
      expect(jsonDecode(models.body), containsPair('object', 'list'));
    });
  });
}

RouterServer _buildRouter({
  required int port,
}) {
  return RouterServer(
    port: port,
    rateLimitManager: _TestRateLimitManager(),
    providers: {'zhipu': _EchoProvider()},
    authSecret: 'router-secret',
  );
}

Future<Uri> _startRouter({
  required void Function(RouterServer server) serverRef,
}) async {
  final port = await _availableLoopbackPort();
  final server = _buildRouter(port: port);
  serverRef(server);
  await server.start();
  return Uri.parse('http://127.0.0.1:$port');
}

Future<int> _availableLoopbackPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

class _TestRateLimitManager implements RateLimitManager {
  @override
  brain.LocalBrain get db => throw UnimplementedError();

  @override
  Future<void> endRequest(String modelId) async {}

  @override
  Future<String> getAvailableModel(String requestedModelId) async {
    return requestedModelId;
  }

  @override
  Future<bool> isAvailable(String modelId) async => true;

  @override
  Future<void> startRequest(String modelId) async {}

  @override
  Future<void> syncFromHeader(String modelId, int remaining) async {}

  @override
  Stream<List<brain.ModelCapacityData>> watchCapacities() =>
      const Stream.empty();
}

class _EchoProvider implements provider.LlmProvider {
  @override
  String get baseUrl => 'http://127.0.0.1:0';

  @override
  String get name => 'test-echo';

  @override
  Future<provider.CompletionResponse> complete(
    provider.CompletionRequest request,
  ) async {
    return provider.CompletionResponse(
      id: 'chatcmpl-test',
      object: 'chat.completion',
      created: 0,
      model: request.model,
      choices: [
        provider.Choice(
          index: 0,
          message: provider.Message(role: 'assistant', content: 'hello'),
          finishReason: 'stop',
        ),
      ],
    );
  }

  @override
  Stream<provider.StreamEvent> streamCompletion(
    provider.CompletionRequest request,
  ) {
    return Stream.value(provider.StreamEvent(data: '{"done":true}'));
  }
}
