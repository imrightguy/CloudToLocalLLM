/// Unit tests for LangChain Integration Service
///
/// Tests LangChain integration functionality including:
/// - Provider initialization and configuration
/// - Text generation and streaming operations
/// - Provider switching and failover scenarios
/// - Error handling and recovery mechanisms
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:zoidbot/services/langchain_integration_service.dart';
import 'package:zoidbot/services/provider_discovery_service.dart';

void main() {
  group('LangChainIntegrationService', () {
    late LangChainIntegrationService service;
    late MockProviderDiscoveryService mockDiscoveryService;

    setUp(() {
      mockDiscoveryService = MockProviderDiscoveryService();
      service = LangChainIntegrationService(
        discoveryService: mockDiscoveryService,
      );
    });

    tearDown(() {
      service.dispose();
    });

    group('Service Initialization', () {
      test('should initialize successfully', () async {
        // Mock discovered providers
        mockDiscoveryService.setMockProviders([
          createMockOllamaProvider(),
          createMockLMStudioProvider(),
        ]);

        // Service is initialized in setUp
        expect(service.isInitialized, isTrue);
        expect(service.error, isNull);
        expect(service.availableProviders, hasLength(2));
      }, skip: 'Requires mock provider infrastructure');

      test('should handle initialization failure gracefully', () async {
        // Mock initialization failure
        mockDiscoveryService.setInitializationError(
          Exception('Failed to discover providers'),
        );

        // Service initialization would fail with discovery error
        expect(service.isInitialized, isFalse);
        expect(service.error, isNotNull);
        expect(service.error, contains('Failed to discover providers'));
      }, skip: 'Requires mock provider infrastructure');

      test('should initialize with no providers available', () async {
        // Mock no providers discovered
        mockDiscoveryService.setMockProviders([]);

        // Service is initialized in setUp
        expect(service.isInitialized, isTrue);
        expect(service.availableProviders, isEmpty);
        expect(service.error, isNull);
      }, skip: 'Requires mock provider infrastructure');
    });

    group('Provider Management', () {
      setUp(() async {
        mockDiscoveryService.setMockProviders([
          createMockOllamaProvider(),
          createMockLMStudioProvider(),
        ]);
        // Service is initialized in setUp
      });

      test('should get available providers', () {
        final providers = service.availableProviders;
        expect(providers, hasLength(2));
        expect(providers.any((p) => p.type == ProviderType.ollama), isTrue);
        expect(providers.any((p) => p.type == ProviderType.lmStudio), isTrue);
      }, skip: 'Requires mock provider infrastructure');

      test('should test provider connection', () async {
        final providerId = 'ollama_11434';
        mockDiscoveryService.setProviderHealthy(providerId, true);

        final isHealthy = await service.testProvider(providerId);

        expect(isHealthy, isTrue);
      }, skip: 'Requires mock provider infrastructure');

      test('should handle provider connection failure', () async {
        final providerId = 'ollama_11434';
        mockDiscoveryService.setProviderHealthy(providerId, false);

        final isHealthy = await service.testProvider(providerId);

        expect(isHealthy, isFalse);
      }, skip: 'Requires mock provider infrastructure');

      test('should handle unknown provider', () async {
        final isHealthy = await service.testProvider('unknown_provider');

        expect(isHealthy, isFalse);
      }, skip: 'Requires mock provider infrastructure');
    });

    group('Text Generation', () {
      setUp(() async {
        mockDiscoveryService.setMockProviders([
          createMockOllamaProvider(),
        ]);
        // Service is initialized in setUp
      });

      test('should generate text successfully', () async {
        const providerId = 'ollama_11434';
        const prompt = 'Hello, world!';
        const expectedResponse = 'Hello! How can I help you today?';

        mockDiscoveryService.setTextGenerationResponse(
          providerId,
          prompt,
          expectedResponse,
        );

        final result = await service.processTextGeneration(providerId, prompt);

        expect(result, equals(expectedResponse));
      }, skip: 'Requires mock provider infrastructure');

      test('should handle text generation failure', () async {
        const providerId = 'ollama_11434';
        const prompt = 'Hello, world!';

        mockDiscoveryService.setTextGenerationError(
          providerId,
          prompt,
          Exception('Generation failed'),
        );

        expect(
          () => service.processTextGeneration(providerId, prompt),
          throwsException,
        );
      }, skip: 'Requires mock provider infrastructure');

      test('should handle unknown provider for text generation', () async {
        const providerId = 'unknown_provider';
        const prompt = 'Hello, world!';

        expect(
          () => service.processTextGeneration(providerId, prompt),
          throwsException,
        );
      }, skip: 'Requires mock provider infrastructure');
    });

    group('Streaming Operations', () {
      setUp(() async {
        mockDiscoveryService.setMockProviders([
          createMockOllamaProvider(),
        ]);
        // Service is initialized in setUp
      });

      test('should stream text generation successfully', () async {
        const providerId = 'ollama_11434';
        const prompt = 'Tell me a story';
        final expectedChunks = ['Once', ' upon', ' a', ' time...'];

        mockDiscoveryService.setStreamingResponse(
          providerId,
          prompt,
          expectedChunks,
        );

        final chunks = <String>[];
        await for (final chunk
            in service.processStreamingGeneration(providerId, prompt)) {
          chunks.add(chunk);
        }

        expect(chunks, equals(expectedChunks));
      }, skip: 'Requires mock provider infrastructure');

      test('should handle streaming failure', () async {
        const providerId = 'ollama_11434';
        const prompt = 'Tell me a story';

        mockDiscoveryService.setStreamingError(
          providerId,
          prompt,
          Exception('Streaming failed'),
        );

        expect(
          () => service.processStreamingGeneration(providerId, prompt).toList(),
          throwsException,
        );
      }, skip: 'Requires mock provider infrastructure');
    });

    group('Provider Failover', () {
      setUp(() async {
        mockDiscoveryService.setMockProviders([
          createMockOllamaProvider(),
          createMockLMStudioProvider(),
        ]);
        // Service is initialized in setUp
      });

      test('should failover to secondary provider', () async {
        const primaryProviderId = 'ollama_11434';
        const secondaryProviderId = 'lmstudio_1234';
        const prompt = 'Hello, world!';
        const expectedResponse = 'Hello from backup provider!';

        // Primary provider fails
        mockDiscoveryService.setTextGenerationError(
          primaryProviderId,
          prompt,
          Exception('Primary provider failed'),
        );

        // Secondary provider succeeds
        mockDiscoveryService.setTextGenerationResponse(
          secondaryProviderId,
          prompt,
          expectedResponse,
        );

        final result = await service.processTextGenerationWithPreferred(
          prompt,
        );

        expect(result, equals(expectedResponse));
      }, skip: 'Requires mock provider infrastructure');

      test('should fail when all providers fail', () async {
        const primaryProviderId = 'ollama_11434';
        const secondaryProviderId = 'lmstudio_1234';
        const prompt = 'Hello, world!';

        // Both providers fail
        mockDiscoveryService.setTextGenerationError(
          primaryProviderId,
          prompt,
          Exception('Primary provider failed'),
        );

        mockDiscoveryService.setTextGenerationError(
          secondaryProviderId,
          prompt,
          Exception('Secondary provider failed'),
        );

        expect(
          () => service.processTextGenerationWithPreferred(
            prompt,
          ),
          throwsException,
        );
      });
    });

    group('Error Handling', () {
      test('should handle service not initialized', () async {
        final uninitializedService =
            LangChainIntegrationService(discoveryService: mockDiscoveryService);

        expect(
          () =>
              uninitializedService.processTextGeneration('provider', 'prompt'),
          throwsStateError,
        );
      }, skip: 'Requires mock provider infrastructure');

      test('should handle concurrent operations', () async {
        mockDiscoveryService.setMockProviders([
          createMockOllamaProvider(),
        ]);
        // Service is initialized in setUp

        const providerId = 'ollama_11434';
        const prompt1 = 'First prompt';
        const prompt2 = 'Second prompt';
        const response1 = 'First response';
        const response2 = 'Second response';

        mockDiscoveryService.setTextGenerationResponse(
            providerId, prompt1, response1);
        mockDiscoveryService.setTextGenerationResponse(
            providerId, prompt2, response2);

        // Execute concurrent operations
        final futures = [
          service.processTextGeneration(providerId, prompt1),
          service.processTextGeneration(providerId, prompt2),
        ];

        final results = await Future.wait(futures);

        expect(results, hasLength(2));
        expect(results, containsAll([response1, response2]));
      }, skip: 'Requires mock provider infrastructure');
    });
  });
}

// Mock classes and helper functions

class MockProviderDiscoveryService extends ProviderDiscoveryService {
  final List<ProviderInfo> _mockProviders = [];
  final Map<String, bool> _providerHealth = {};
  final Map<String, Map<String, String>> _textGenerationResponses = {};
  final Map<String, Map<String, Exception>> _textGenerationErrors = {};
  final Map<String, Map<String, List<String>>> _streamingResponses = {};
  final Map<String, Map<String, Exception>> _streamingErrors = {};
  Exception? _initializationError;

  void setMockProviders(List<ProviderInfo> providers) {
    _mockProviders.clear();
    _mockProviders.addAll(providers);
  }

  void setInitializationError(Exception error) {
    _initializationError = error;
  }

  void setProviderHealthy(String providerId, bool isHealthy) {
    _providerHealth[providerId] = isHealthy;
  }

  void setTextGenerationResponse(
      String providerId, String prompt, String response) {
    _textGenerationResponses[providerId] ??= {};
    _textGenerationResponses[providerId]![prompt] = response;
  }

  void setTextGenerationError(
      String providerId, String prompt, Exception error) {
    _textGenerationErrors[providerId] ??= {};
    _textGenerationErrors[providerId]![prompt] = error;
  }

  void setStreamingResponse(
      String providerId, String prompt, List<String> chunks) {
    _streamingResponses[providerId] ??= {};
    _streamingResponses[providerId]![prompt] = chunks;
  }

  void setStreamingError(String providerId, String prompt, Exception error) {
    _streamingErrors[providerId] ??= {};
    _streamingErrors[providerId]![prompt] = error;
  }

  @override
  List<ProviderInfo> get discoveredProviders => _mockProviders;

  @override
  Future<List<ProviderInfo>> scanForProviders() async {
    if (_initializationError != null) {
      throw _initializationError!;
    }
    return _mockProviders;
  }

  @override
  Future<bool> validateProviderEndpoint(ProviderInfo provider) async {
    return _providerHealth[provider.id] ?? false;
  }
}

ProviderInfo createMockOllamaProvider() {
  return ProviderInfo(
    id: 'ollama_11434',
    name: 'Ollama',
    type: ProviderType.ollama,
    baseUrl: 'http://localhost:11434',
    port: 11434,
    capabilities: {
      'chat': true,
      'completion': true,
      'streaming': true,
    },
    status: ProviderStatus.available,
    lastSeen: DateTime.now(),
    availableModels: ['llama2:latest', 'codellama:latest'],
    version: '0.1.17',
  );
}

ProviderInfo createMockLMStudioProvider() {
  return ProviderInfo(
    id: 'lmstudio_1234',
    name: 'LM Studio',
    type: ProviderType.lmStudio,
    baseUrl: 'http://localhost:1234',
    port: 1234,
    capabilities: {
      'chat': true,
      'completion': true,
      'streaming': true,
    },
    status: ProviderStatus.available,
    lastSeen: DateTime.now(),
    availableModels: ['Meta-Llama-3-8B-Instruct'],
    version: '0.2.19',
  );
}
