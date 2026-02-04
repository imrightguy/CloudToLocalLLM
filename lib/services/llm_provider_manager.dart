/// LLM Provider Manager
///
/// Manages LLM provider registration, health monitoring, and failover capabilities.
/// Integrates with LangChain provider loading and automatic provider discovery.
///
/// Key Features:
/// - Automatic provider registration from discovery service
/// - Real-time health monitoring with periodic checks
/// - Provider performance metrics collection
/// - Intelligent failover and provider prioritization
/// - Provider enable/disable management
///
/// Usage:
/// ```dart
/// final manager = LLMProviderManager(
///   discoveryService: discoveryService,
///   langchainService: langchainService,
/// );
/// await manager.initialize();
/// final provider = await manager.getProviderWithFailover();
/// ```
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'provider_discovery_service.dart';
import 'langchain_integration_service.dart';
import 'llm_providers/base_llm_provider.dart';
import '../models/llm_communication_error.dart';

/// Provider health status
enum ProviderHealthStatus {
  healthy,
  degraded,
  unhealthy,
  unknown,
}

/// Provider performance metrics
///
/// Tracks performance statistics for LLM providers including response times,
/// success rates, and request counts. Used for health monitoring and
/// provider prioritization decisions.
class ProviderMetrics {
  final String providerId;
  final double averageResponseTime;
  final double successRate;
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final DateTime lastRequestTime;
  final DateTime lastSuccessTime;
  final DateTime lastFailureTime;
  final Map<String, dynamic> additionalMetrics;

  const ProviderMetrics({
    required this.providerId,
    required this.averageResponseTime,
    required this.successRate,
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.lastRequestTime,
    required this.lastSuccessTime,
    required this.lastFailureTime,
    required this.additionalMetrics,
  });

  /// Create empty metrics for a provider
  factory ProviderMetrics.empty(String providerId) {
    final now = DateTime.now();
    return ProviderMetrics(
      providerId: providerId,
      averageResponseTime: 0.0,
      successRate: 0.0,
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      lastRequestTime: now,
      lastSuccessTime: now,
      lastFailureTime: now,
      additionalMetrics: {},
    );
  }

  /// Create updated metrics with new request data
  ProviderMetrics withNewRequest({
    required bool success,
    required double responseTime,
    Map<String, dynamic>? additionalData,
  }) {
    final now = DateTime.now();
    final newTotalRequests = totalRequests + 1;
    final newSuccessfulRequests =
        success ? successfulRequests + 1 : successfulRequests;
    final newFailedRequests = success ? failedRequests : failedRequests + 1;

    // Calculate new average response time
    final newAverageResponseTime = totalRequests == 0
        ? responseTime
        : ((averageResponseTime * totalRequests) + responseTime) /
            newTotalRequests;

    // Calculate new success rate
    final newSuccessRate =
        newTotalRequests == 0 ? 0.0 : newSuccessfulRequests / newTotalRequests;

    return ProviderMetrics(
      providerId: providerId,
      averageResponseTime: newAverageResponseTime,
      successRate: newSuccessRate,
      totalRequests: newTotalRequests,
      successfulRequests: newSuccessfulRequests,
      failedRequests: newFailedRequests,
      lastRequestTime: now,
      lastSuccessTime: success ? now : lastSuccessTime,
      lastFailureTime: success ? lastFailureTime : now,
      additionalMetrics: {
        ...additionalMetrics,
        if (additionalData != null) ...additionalData,
      },
    );
  }

  /// Get health status based on metrics
  ProviderHealthStatus get healthStatus {
    if (totalRequests == 0) return ProviderHealthStatus.unknown;

    if (successRate >= 0.95 && averageResponseTime < 5000) {
      return ProviderHealthStatus.healthy;
    } else if (successRate >= 0.8 && averageResponseTime < 10000) {
      return ProviderHealthStatus.degraded;
    } else {
      return ProviderHealthStatus.unhealthy;
    }
  }
}

/// Registered provider information
class RegisteredProvider {
  final ProviderInfo info;
  final LangChainProviderWrapper? langchainWrapper;
  final BaseLLMProvider? providerInstance;
  final ProviderMetrics metrics;
  final ProviderHealthStatus healthStatus;
  final DateTime registeredAt;
  final DateTime lastHealthCheck;
  final bool isEnabled;
  final int priority;

  const RegisteredProvider({
    required this.info,
    this.langchainWrapper,
    this.providerInstance,
    required this.metrics,
    required this.healthStatus,
    required this.registeredAt,
    required this.lastHealthCheck,
    required this.isEnabled,
    required this.priority,
  });

  /// Create a copy with updated fields
  RegisteredProvider copyWith({
    ProviderInfo? info,
    LangChainProviderWrapper? langchainWrapper,
    BaseLLMProvider? providerInstance,
    ProviderMetrics? metrics,
    ProviderHealthStatus? healthStatus,
    DateTime? registeredAt,
    DateTime? lastHealthCheck,
    bool? isEnabled,
    int? priority,
  }) {
    return RegisteredProvider(
      info: info ?? this.info,
      langchainWrapper: langchainWrapper ?? this.langchainWrapper,
      providerInstance: providerInstance ?? this.providerInstance,
      metrics: metrics ?? this.metrics,
      healthStatus: healthStatus ?? this.healthStatus,
      registeredAt: registeredAt ?? this.registeredAt,
      lastHealthCheck: lastHealthCheck ?? this.lastHealthCheck,
      isEnabled: isEnabled ?? this.isEnabled,
      priority: priority ?? this.priority,
    );
  }

  /// Check if provider is available for use
  bool get isAvailable =>
      isEnabled &&
      info.status == ProviderStatus.available &&
      healthStatus != ProviderHealthStatus.unhealthy;
}

/// LLM Provider Manager
class LLMProviderManager extends ChangeNotifier {
  final ProviderDiscoveryService _discoveryService;
  final LangChainIntegrationService _langchainService;

  final Map<String, RegisteredProvider> _registeredProviders = {};
  final Map<String, Timer> _healthCheckTimers = {};

  Timer? _periodicHealthCheckTimer;
  bool _isInitialized = false;
  String? _preferredProviderId;
  String? _error;

  static const Duration _healthCheckInterval = Duration(seconds: 30);

  LLMProviderManager({
    required ProviderDiscoveryService discoveryService,
    required LangChainIntegrationService langchainService,
  })  : _discoveryService = discoveryService,
        _langchainService = langchainService {
    // Listen to discovery service changes
    _discoveryService.addListener(_onDiscoveryChanged);

    // Listen to LangChain service changes
    _langchainService.addListener(_onLangChainChanged);
  }

  /// Check if manager is initialized
  bool get isInitialized => _isInitialized;

  /// Get current error
  String? get error => _error;

  /// Get preferred provider ID
  String? get preferredProviderId => _preferredProviderId;

  /// Get all registered providers
  List<RegisteredProvider> get registeredProviders =>
      List.unmodifiable(_registeredProviders.values);

  /// Get available providers (enabled and healthy)
  List<RegisteredProvider> get availableProviders => _registeredProviders.values
      .where((provider) => provider.isAvailable)
      .toList()
    ..sort((a, b) => b.priority.compareTo(a.priority));

  /// Get healthy providers
  List<RegisteredProvider> get healthyProviders => _registeredProviders.values
      .where((provider) =>
          provider.isEnabled &&
          provider.healthStatus == ProviderHealthStatus.healthy)
      .toList()
    ..sort((a, b) => b.priority.compareTo(a.priority));

  /// Initialize the provider manager
  Future<void> initialize() async {
    try {
      debugPrint('Initializing LLM Provider Manager...');
      _error = null;

      // Ensure discovery service is running (skip on web platforms)
      if (!kIsWeb && !_discoveryService.isScanning) {
        debugPrint(
            ' [LLMProviderManager] Starting provider discovery (desktop platform)');
        await _discoveryService.scanForProviders();
      } else if (kIsWeb) {
        debugPrint(
            ' [LLMProviderManager] Skipping provider discovery on web platform');
        debugPrint(
            ' [LLMProviderManager] Web platform uses tunnel/bridge system for provider access');
      }

      // Ensure LangChain service is initialized
      if (!_langchainService.isInitialized) {
        await _langchainService.initializeProviders();
      }

      // Register discovered providers
      await _registerDiscoveredProviders();

      // Start health monitoring
      _startHealthMonitoring();

      _isInitialized = true;
      debugPrint(
          'LLM Provider Manager initialized with ${_registeredProviders.length} providers');
    } catch (error) {
      _error = 'Failed to initialize provider manager: $error';
      debugPrint(_error);
    }

    notifyListeners();
  }

  /// Register a provider manually
  Future<void> registerProvider(ProviderInfo providerInfo,
      {int priority = 0}) async {
    try {
      debugPrint('Registering provider: ${providerInfo.name}');

      // Get LangChain wrapper if available
      final langchainWrapper = _langchainService.getProvider(providerInfo.id);

      final registeredProvider = RegisteredProvider(
        info: providerInfo,
        langchainWrapper: langchainWrapper,
        metrics: ProviderMetrics.empty(providerInfo.id),
        healthStatus: ProviderHealthStatus.unknown,
        registeredAt: DateTime.now(),
        lastHealthCheck: DateTime.now(),
        isEnabled: true,
        priority: priority,
      );

      _registeredProviders[providerInfo.id] = registeredProvider;

      // Start health monitoring for this provider
      _startProviderHealthCheck(providerInfo.id);

      // Set as preferred if none is set
      _preferredProviderId ??= providerInfo.id;

      debugPrint('Provider registered successfully: ${providerInfo.name}');
      notifyListeners();
    } catch (error) {
      debugPrint('Failed to register provider ${providerInfo.name}: $error');
      throw LLMCommunicationError.fromException(
        error is Exception ? error : Exception(error.toString()),
        type: LLMCommunicationErrorType.providerConfigurationError,
        providerId: providerInfo.id,
      );
    }
  }

  /// Get preferred provider
  RegisteredProvider? getPreferredProvider() {
    if (_preferredProviderId == null) return null;
    return _registeredProviders[_preferredProviderId];
  }

  /// Set preferred provider
  void setPreferredProvider(String providerId) {
    if (_registeredProviders.containsKey(providerId)) {
      _preferredProviderId = providerId;
      debugPrint('Preferred provider set to: $providerId');
      notifyListeners();
    } else {
      debugPrint('Cannot set preferred provider - not registered: $providerId');
    }
  }

  /// Get available providers sorted by health and priority
  List<RegisteredProvider> getAvailableProviders() {
    return availableProviders;
  }

  /// Get provider by ID
  RegisteredProvider? getProvider(String providerId) {
    return _registeredProviders[providerId];
  }

  /// Test provider connection
  Future<bool> testProviderConnection(String providerId) async {
    final provider = _registeredProviders[providerId];
    if (provider == null) {
      debugPrint('Provider not found for connection test: $providerId');
      return false;
    }

    final stopwatch = Stopwatch()..start();
    bool success = false;

    try {
      debugPrint('Testing connection for provider: ${provider.info.name}');

      // Use LangChain service to test if available
      if (provider.langchainWrapper != null) {
        success = await _langchainService.testProvider(providerId);
      } else {
        // Fallback to discovery service validation
        success =
            await _discoveryService.validateProviderEndpoint(provider.info);
      }

      stopwatch.stop();
      final responseTime = stopwatch.elapsedMilliseconds.toDouble();

      // Update metrics
      await _updateProviderMetrics(providerId, success, responseTime);

      debugPrint(
          'Connection test for ${provider.info.name}: ${success ? 'SUCCESS' : 'FAILED'}');
      return success;
    } catch (error) {
      stopwatch.stop();
      final responseTime = stopwatch.elapsedMilliseconds.toDouble();

      await _updateProviderMetrics(providerId, false, responseTime);
      debugPrint('Connection test error for ${provider.info.name}: $error');
      return false;
    }
  }

  /// Reconnect a specific provider
  Future<bool> reconnectProvider(String providerId) async {
    final provider = _registeredProviders[providerId];
    if (provider == null) {
      debugPrint('Provider not found for reconnection: $providerId');
      return false;
    }

    try {
      debugPrint('Reconnecting provider: ${provider.info.name}');

      // First disconnect if provider instance is available
      if (provider.providerInstance != null) {
        await provider.providerInstance!.disconnect();
      }

      // Wait a moment before reconnecting
      await Future.delayed(const Duration(milliseconds: 500));

      // Attempt to reconnect
      if (provider.providerInstance != null) {
        await provider.providerInstance!.connect();
      }

      // Test the connection
      final isConnected = await testProviderConnection(providerId);

      if (isConnected) {
        // Update provider status
        _registeredProviders[providerId] = provider.copyWith(
          healthStatus: ProviderHealthStatus.healthy,
          lastHealthCheck: DateTime.now(),
        );

        debugPrint('Provider ${provider.info.name} reconnected successfully');
        notifyListeners();
        return true;
      } else {
        debugPrint('Provider ${provider.info.name} reconnection failed');
        return false;
      }
    } catch (error) {
      debugPrint('Error reconnecting provider ${provider.info.name}: $error');

      // Update provider status to unhealthy
      _registeredProviders[providerId] = provider.copyWith(
        healthStatus: ProviderHealthStatus.unhealthy,
        lastHealthCheck: DateTime.now(),
      );

      notifyListeners();
      return false;
    }
  }

  /// Get provider with automatic failover
  Future<RegisteredProvider?> getProviderWithFailover() async {
    // Try preferred provider first
    if (_preferredProviderId != null) {
      final preferred = _registeredProviders[_preferredProviderId];
      if (preferred != null && preferred.isAvailable) {
        final isHealthy = await testProviderConnection(_preferredProviderId!);
        if (isHealthy) {
          return preferred;
        }
      }
    }

    // Try other available providers in order of priority and health
    final availableProviders = getAvailableProviders();
    for (final provider in availableProviders) {
      if (provider.info.id == _preferredProviderId) continue; // Already tried

      final isHealthy = await testProviderConnection(provider.info.id);
      if (isHealthy) {
        debugPrint('Failover to provider: ${provider.info.name}');
        return provider;
      }
    }

    debugPrint('No healthy providers available for failover');
    return null;
  }

  /// Enable/disable a provider
  void setProviderEnabled(String providerId, bool enabled) {
    final provider = _registeredProviders[providerId];
    if (provider != null) {
      _registeredProviders[providerId] = provider.copyWith(isEnabled: enabled);
      debugPrint(
          'Provider ${provider.info.name} ${enabled ? 'enabled' : 'disabled'}');
      notifyListeners();
    }
  }

  /// Set provider priority
  void setProviderPriority(String providerId, int priority) {
    final provider = _registeredProviders[providerId];
    if (provider != null) {
      _registeredProviders[providerId] = provider.copyWith(priority: priority);
      debugPrint('Provider ${provider.info.name} priority set to: $priority');
      notifyListeners();
    }
  }

  /// Get provider health monitoring stream
  Stream<Map<String, ProviderHealthStatus>> monitorProviderHealth() async* {
    while (_isInitialized) {
      final healthMap = <String, ProviderHealthStatus>{};

      for (final provider in _registeredProviders.values) {
        healthMap[provider.info.id] = provider.healthStatus;
      }

      yield healthMap;
      await Future.delayed(_healthCheckInterval);
    }
  }

  /// Register all discovered providers
  Future<void> _registerDiscoveredProviders() async {
    final discoveredProviders = _discoveryService.getAvailableProviders();

    for (final providerInfo in discoveredProviders) {
      if (!_registeredProviders.containsKey(providerInfo.id)) {
        await registerProvider(providerInfo,
            priority: _getDefaultPriority(providerInfo.type));
      }
    }
  }

  /// Get default priority for provider type
  int _getDefaultPriority(ProviderType type) {
    switch (type) {
      case ProviderType.custom:
        return 100; // OpenClaw/Custom highest priority
      case ProviderType.ollama:
        return 80;
      case ProviderType.lmStudio:
        return 60;
      case ProviderType.openAICompatible:
        return 40;
    }
  }

  /// Start health monitoring for all providers
  void _startHealthMonitoring() {
    _periodicHealthCheckTimer?.cancel();
    _periodicHealthCheckTimer = Timer.periodic(_healthCheckInterval, (_) {
      _performHealthChecks();
    });

    // Start individual provider health checks
    for (final providerId in _registeredProviders.keys) {
      _startProviderHealthCheck(providerId);
    }

    debugPrint(
        'Started health monitoring for ${_registeredProviders.length} providers');
  }

  /// Start health check for specific provider
  void _startProviderHealthCheck(String providerId) {
    _healthCheckTimers[providerId]?.cancel();
    _healthCheckTimers[providerId] = Timer.periodic(_healthCheckInterval, (_) {
      _performProviderHealthCheck(providerId);
    });
  }

  /// Perform health checks for all providers
  Future<void> _performHealthChecks() async {
    for (final providerId in _registeredProviders.keys) {
      await _performProviderHealthCheck(providerId);
    }
  }

  /// Perform health check for specific provider
  Future<void> _performProviderHealthCheck(String providerId) async {
    final provider = _registeredProviders[providerId];
    if (provider == null || !provider.isEnabled) return;

    try {
      final isHealthy = await testProviderConnection(providerId);
      final newHealthStatus = isHealthy
          ? ProviderHealthStatus.healthy
          : ProviderHealthStatus.unhealthy;

      // Update provider with new health status
      _registeredProviders[providerId] = provider.copyWith(
        healthStatus: newHealthStatus,
        lastHealthCheck: DateTime.now(),
      );

      // Notify listeners if health status changed
      if (provider.healthStatus != newHealthStatus) {
        debugPrint(
            'Provider ${provider.info.name} health changed to: $newHealthStatus');
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Health check failed for ${provider.info.name}: $error');

      _registeredProviders[providerId] = provider.copyWith(
        healthStatus: ProviderHealthStatus.unhealthy,
        lastHealthCheck: DateTime.now(),
      );
    }
  }

  /// Update provider metrics
  Future<void> _updateProviderMetrics(
    String providerId,
    bool success,
    double responseTime,
  ) async {
    final provider = _registeredProviders[providerId];
    if (provider == null) return;

    final newMetrics = provider.metrics.withNewRequest(
      success: success,
      responseTime: responseTime,
    );

    _registeredProviders[providerId] = provider.copyWith(metrics: newMetrics);
  }

  /// Handle discovery service changes
  void _onDiscoveryChanged() {
    if (_isInitialized) {
      debugPrint('Provider discovery changed, updating registrations...');
      _registerDiscoveredProviders();
    }
  }

  /// Handle LangChain service changes
  void _onLangChainChanged() {
    if (_isInitialized) {
      debugPrint('LangChain service changed, updating provider wrappers...');
      _updateLangChainWrappers();
    }
  }

  /// Update LangChain wrappers for registered providers
  void _updateLangChainWrappers() {
    for (final entry in _registeredProviders.entries) {
      final providerId = entry.key;
      final provider = entry.value;

      final langchainWrapper = _langchainService.getProvider(providerId);
      if (langchainWrapper != provider.langchainWrapper) {
        _registeredProviders[providerId] = provider.copyWith(
          langchainWrapper: langchainWrapper,
        );
      }
    }
    notifyListeners();
  }

  /// Get provider statistics
  Map<String, dynamic> getProviderStats() {
    final stats = <String, dynamic>{
      'total_providers': _registeredProviders.length,
      'available_providers': availableProviders.length,
      'healthy_providers': healthyProviders.length,
      'preferred_provider': _preferredProviderId,
      'initialized': _isInitialized,
      'error': _error,
    };

    // Add per-provider stats
    final providerStats = <String, dynamic>{};
    for (final provider in _registeredProviders.values) {
      providerStats[provider.info.id] = {
        'name': provider.info.name,
        'type': provider.info.type.toString(),
        'health_status': provider.healthStatus.toString(),
        'is_enabled': provider.isEnabled,
        'priority': provider.priority,
        'success_rate': provider.metrics.successRate,
        'average_response_time': provider.metrics.averageResponseTime,
        'total_requests': provider.metrics.totalRequests,
      };
    }
    stats['provider_details'] = providerStats;

    return stats;
  }

  @override
  void dispose() {
    _discoveryService.removeListener(_onDiscoveryChanged);
    _langchainService.removeListener(_onLangChainChanged);

    _periodicHealthCheckTimer?.cancel();
    for (final timer in _healthCheckTimers.values) {
      timer.cancel();
    }
    _healthCheckTimers.clear();

    super.dispose();
  }
}
