/// Provider Configuration Models for CloudToLocalLLM
///
/// This file contains comprehensive configuration models for different LLM provider types,
/// including validation, persistence, and type-specific settings management.
library;

/// Provider type enumeration
enum ProviderType {
  openclaw,
  hermes,
  ollama,
  lmStudio,
  openAICompatible,
  custom,
}

/// High-level role for a discovered or configured backend endpoint.
enum ProviderRole {
  agentRuntime,
  supportModelProvider,
}

extension ProviderTypeRole on ProviderType {
  bool get isAgentRuntime {
    return switch (this) {
      ProviderType.openclaw ||
      ProviderType.hermes ||
      ProviderType.custom =>
        true,
      ProviderType.ollama ||
      ProviderType.lmStudio ||
      ProviderType.openAICompatible =>
        false,
    };
  }

  bool get isSupportModelProvider => !isAgentRuntime;

  ProviderRole get defaultRole => isAgentRuntime
      ? ProviderRole.agentRuntime
      : ProviderRole.supportModelProvider;
}

/// Provider information discovered on the network
class ProviderInfo {
  final String id;
  final String name;
  final ProviderType type;

  // URL as a complete string (e.g., "http://localhost:18789")
  final String url;

  // Backward compatibility: separate baseUrl and port
  String get baseUrl {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      return uri.hasScheme ? '${uri.scheme}://${uri.host}' : url;
    }
    return url.split(':')[0]; // Fallback
  }

  int get port {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasPort) {
      return uri.port;
    }
    // Try to extract port from URL
    final parts = url.split(':');
    if (parts.length > 1) {
      return int.tryParse(parts.last) ?? 80;
    }
    return 80; // Default
  }

  // Additional metadata for wizard
  final bool isLocal;
  final bool isAvailable;
  final String? version;
  final List<String> availableModels;
  final ProviderRole? role;

  const ProviderInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    this.isLocal = true,
    this.isAvailable = false,
    this.version,
    this.availableModels = const [],
    this.role,
  });

  ProviderRole get effectiveRole => role ?? type.defaultRole;
  bool get canServeAsAgentRuntime => effectiveRole == ProviderRole.agentRuntime;
  bool get canServeAsSupportModelProvider =>
      effectiveRole == ProviderRole.supportModelProvider;

  /// Create from URL with auto-generated ID
  factory ProviderInfo.fromUrl({
    required String name,
    required ProviderType type,
    required String url,
    bool isLocal = true,
    bool isAvailable = false,
    String? version,
    ProviderRole? role,
  }) {
    final id = '${type.name}_${name.toLowerCase().replaceAll(' ', '_')}';
    return ProviderInfo(
      id: id,
      name: name,
      type: type,
      url: url,
      isLocal: isLocal,
      isAvailable: isAvailable,
      version: version,
      role: role,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'url': url,
        'baseUrl': baseUrl, // For backward compatibility
        'port': port, // For backward compatibility
        'isLocal': isLocal,
        'isAvailable': isAvailable,
        'version': version,
        'availableModels': availableModels,
        'role': effectiveRole.name,
      };

  factory ProviderInfo.fromJson(Map<String, dynamic> json) {
    // Handle both old format (baseUrl/port) and new format (url)
    final String url;
    if (json.containsKey('url')) {
      url = json['url'] as String;
    } else if (json.containsKey('baseUrl') && json.containsKey('port')) {
      final baseUrl = json['baseUrl'] as String;
      final port = json['port'] as int;
      url = '$baseUrl:$port';
    } else {
      url = 'http://localhost:80'; // Fallback
    }

    return ProviderInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ProviderType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ProviderType.custom,
      ),
      url: url,
      isLocal: json['isLocal'] as bool? ?? true,
      isAvailable: json['isAvailable'] as bool? ?? false,
      version: json['version'] as String?,
      availableModels: (json['availableModels'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      role: ProviderRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => ProviderType.values
            .firstWhere(
              (e) => e.name == json['type'],
              orElse: () => ProviderType.custom,
            )
            .defaultRole,
      ),
    );
  }

  /// Create a copy with updated values
  ProviderInfo copyWith({
    String? id,
    String? name,
    ProviderType? type,
    String? url,
    bool? isLocal,
    bool? isAvailable,
    String? version,
    List<String>? availableModels,
    ProviderRole? role,
  }) {
    return ProviderInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      url: url ?? this.url,
      isLocal: isLocal ?? this.isLocal,
      isAvailable: isAvailable ?? this.isAvailable,
      version: version ?? this.version,
      availableModels: availableModels ?? this.availableModels,
      role: role ?? this.role,
    );
  }
}

/// Base provider configuration interface
abstract class ProviderConfiguration {
  String get providerId;
  String get providerType;
  String get baseUrl;
  Duration get timeout;
  Map<String, dynamic> get customSettings;

  /// Validate the configuration
  bool isValid();

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson();

  /// Create a copy with updated values
  ProviderConfiguration copyWith(Map<String, dynamic> updates);
}

/// Ollama provider configuration
class OllamaProviderConfiguration implements ProviderConfiguration {
  @override
  final String providerId;

  @override
  final String baseUrl;

  @override
  final Duration timeout;

  final int port;
  final bool enableStreaming;
  final bool enableEmbeddings;
  final int maxConcurrentRequests;
  final Duration keepAliveTimeout;
  final Map<String, String>? customHeaders;

  @override
  final Map<String, dynamic> customSettings;

  const OllamaProviderConfiguration({
    required this.providerId,
    required this.baseUrl,
    required this.port,
    this.timeout = const Duration(seconds: 60),
    this.enableStreaming = true,
    this.enableEmbeddings = true,
    this.maxConcurrentRequests = 5,
    this.keepAliveTimeout = const Duration(minutes: 5),
    this.customHeaders,
    this.customSettings = const {},
  });

  @override
  String get providerType => 'ollama';

  @override
  bool isValid() {
    try {
      // Validate URL format
      final uri = Uri.parse(baseUrl);
      if (!uri.hasScheme || !uri.hasAuthority) return false;

      // Validate port range
      if (port < 1 || port > 65535) return false;

      // Validate timeout
      if (timeout.inMilliseconds < 1000) return false;

      // Validate concurrent requests
      if (maxConcurrentRequests < 1 || maxConcurrentRequests > 50) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'providerId': providerId,
        'providerType': providerType,
        'baseUrl': baseUrl,
        'port': port,
        'timeout': timeout.inMilliseconds,
        'enableStreaming': enableStreaming,
        'enableEmbeddings': enableEmbeddings,
        'maxConcurrentRequests': maxConcurrentRequests,
        'keepAliveTimeout': keepAliveTimeout.inMilliseconds,
        'customHeaders': customHeaders,
        'customSettings': customSettings,
      };

  factory OllamaProviderConfiguration.fromJson(Map<String, dynamic> json) {
    return OllamaProviderConfiguration(
      providerId: json['providerId'] as String,
      baseUrl: json['baseUrl'] as String,
      port: json['port'] as int,
      timeout: Duration(milliseconds: json['timeout'] as int? ?? 60000),
      enableStreaming: json['enableStreaming'] as bool? ?? true,
      enableEmbeddings: json['enableEmbeddings'] as bool? ?? true,
      maxConcurrentRequests: json['maxConcurrentRequests'] as int? ?? 5,
      keepAliveTimeout:
          Duration(milliseconds: json['keepAliveTimeout'] as int? ?? 300000),
      customHeaders: json['customHeaders'] != null
          ? Map<String, String>.from(json['customHeaders'] as Map)
          : null,
      customSettings: json['customSettings'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  OllamaProviderConfiguration copyWith(Map<String, dynamic> updates) {
    return OllamaProviderConfiguration(
      providerId: updates['providerId'] as String? ?? providerId,
      baseUrl: updates['baseUrl'] as String? ?? baseUrl,
      port: updates['port'] as int? ?? port,
      timeout: updates['timeout'] != null
          ? Duration(milliseconds: updates['timeout'] as int)
          : timeout,
      enableStreaming: updates['enableStreaming'] as bool? ?? enableStreaming,
      enableEmbeddings:
          updates['enableEmbeddings'] as bool? ?? enableEmbeddings,
      maxConcurrentRequests:
          updates['maxConcurrentRequests'] as int? ?? maxConcurrentRequests,
      keepAliveTimeout: updates['keepAliveTimeout'] != null
          ? Duration(milliseconds: updates['keepAliveTimeout'] as int)
          : keepAliveTimeout,
      customHeaders: updates['customHeaders'] != null
          ? Map<String, String>.from(updates['customHeaders'] as Map)
          : customHeaders,
      customSettings:
          updates['customSettings'] as Map<String, dynamic>? ?? customSettings,
    );
  }
}

/// LM Studio provider configuration
class LMStudioProviderConfiguration implements ProviderConfiguration {
  @override
  final String providerId;

  @override
  final String baseUrl;

  @override
  final Duration timeout;

  final int port;
  final bool enableStreaming;
  final int maxTokens;
  final double temperature;
  final double topP;
  final int maxConcurrentRequests;
  final Map<String, String>? customHeaders;

  @override
  final Map<String, dynamic> customSettings;

  const LMStudioProviderConfiguration({
    required this.providerId,
    required this.baseUrl,
    required this.port,
    this.timeout = const Duration(seconds: 120),
    this.enableStreaming = true,
    this.maxTokens = 2048,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.maxConcurrentRequests = 3,
    this.customHeaders,
    this.customSettings = const {},
  });

  @override
  String get providerType => 'lmstudio';

  @override
  bool isValid() {
    try {
      // Validate URL format
      final uri = Uri.parse(baseUrl);
      if (!uri.hasScheme || !uri.hasAuthority) return false;

      // Validate port range
      if (port < 1 || port > 65535) return false;

      // Validate timeout
      if (timeout.inMilliseconds < 1000) return false;

      // Validate model parameters
      if (maxTokens < 1 || maxTokens > 32768) return false;
      if (temperature < 0.0 || temperature > 2.0) return false;
      if (topP < 0.0 || topP > 1.0) return false;
      if (maxConcurrentRequests < 1 || maxConcurrentRequests > 10) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'providerId': providerId,
        'providerType': providerType,
        'baseUrl': baseUrl,
        'port': port,
        'timeout': timeout.inMilliseconds,
        'enableStreaming': enableStreaming,
        'maxTokens': maxTokens,
        'temperature': temperature,
        'topP': topP,
        'maxConcurrentRequests': maxConcurrentRequests,
        'customHeaders': customHeaders,
        'customSettings': customSettings,
      };

  factory LMStudioProviderConfiguration.fromJson(Map<String, dynamic> json) {
    return LMStudioProviderConfiguration(
      providerId: json['providerId'] as String,
      baseUrl: json['baseUrl'] as String,
      port: json['port'] as int,
      timeout: Duration(milliseconds: json['timeout'] as int? ?? 120000),
      enableStreaming: json['enableStreaming'] as bool? ?? true,
      maxTokens: json['maxTokens'] as int? ?? 2048,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      topP: (json['topP'] as num?)?.toDouble() ?? 0.9,
      maxConcurrentRequests: json['maxConcurrentRequests'] as int? ?? 3,
      customHeaders: json['customHeaders'] != null
          ? Map<String, String>.from(json['customHeaders'] as Map)
          : null,
      customSettings: json['customSettings'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  LMStudioProviderConfiguration copyWith(Map<String, dynamic> updates) {
    return LMStudioProviderConfiguration(
      providerId: updates['providerId'] as String? ?? providerId,
      baseUrl: updates['baseUrl'] as String? ?? baseUrl,
      port: updates['port'] as int? ?? port,
      timeout: updates['timeout'] != null
          ? Duration(milliseconds: updates['timeout'] as int)
          : timeout,
      enableStreaming: updates['enableStreaming'] as bool? ?? enableStreaming,
      maxTokens: updates['maxTokens'] as int? ?? maxTokens,
      temperature: (updates['temperature'] as num?)?.toDouble() ?? temperature,
      topP: (updates['topP'] as num?)?.toDouble() ?? topP,
      maxConcurrentRequests:
          updates['maxConcurrentRequests'] as int? ?? maxConcurrentRequests,
      customHeaders: updates['customHeaders'] != null
          ? Map<String, String>.from(updates['customHeaders'] as Map)
          : customHeaders,
      customSettings:
          updates['customSettings'] as Map<String, dynamic>? ?? customSettings,
    );
  }
}

/// OpenAI Compatible provider configuration
class OpenAICompatibleProviderConfiguration implements ProviderConfiguration {
  @override
  final String providerId;

  @override
  final String baseUrl;

  @override
  final Duration timeout;

  final int port;
  final String? apiKey;
  final String apiVersion;
  final bool requiresAuth;
  final bool enableStreaming;
  final int maxTokens;
  final double temperature;
  final int maxConcurrentRequests;
  final Map<String, String>? customHeaders;

  @override
  final Map<String, dynamic> customSettings;

  const OpenAICompatibleProviderConfiguration({
    required this.providerId,
    required this.baseUrl,
    required this.port,
    this.apiKey,
    this.timeout = const Duration(seconds: 90),
    this.apiVersion = 'v1',
    this.requiresAuth = false,
    this.enableStreaming = true,
    this.maxTokens = 4096,
    this.temperature = 0.7,
    this.maxConcurrentRequests = 5,
    this.customHeaders,
    this.customSettings = const {},
  });

  @override
  String get providerType => 'openai_compatible';

  @override
  bool isValid() {
    try {
      // Validate URL format
      final uri = Uri.parse(baseUrl);
      if (!uri.hasScheme || !uri.hasAuthority) return false;

      // Validate port range
      if (port < 1 || port > 65535) return false;

      // Validate timeout
      if (timeout.inMilliseconds < 1000) return false;

      // Validate auth requirements
      if (requiresAuth && (apiKey == null || apiKey!.isEmpty)) return false;

      // Validate model parameters
      if (maxTokens < 1 || maxTokens > 32768) return false;
      if (temperature < 0.0 || temperature > 2.0) return false;
      if (maxConcurrentRequests < 1 || maxConcurrentRequests > 20) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'providerId': providerId,
        'providerType': providerType,
        'baseUrl': baseUrl,
        'port': port,
        'apiKey': apiKey,
        'timeout': timeout.inMilliseconds,
        'apiVersion': apiVersion,
        'requiresAuth': requiresAuth,
        'enableStreaming': enableStreaming,
        'maxTokens': maxTokens,
        'temperature': temperature,
        'maxConcurrentRequests': maxConcurrentRequests,
        'customHeaders': customHeaders,
        'customSettings': customSettings,
      };

  factory OpenAICompatibleProviderConfiguration.fromJson(
      Map<String, dynamic> json) {
    return OpenAICompatibleProviderConfiguration(
      providerId: json['providerId'] as String,
      baseUrl: json['baseUrl'] as String,
      port: json['port'] as int,
      apiKey: json['apiKey'] as String?,
      timeout: Duration(milliseconds: json['timeout'] as int? ?? 90000),
      apiVersion: json['apiVersion'] as String? ?? 'v1',
      requiresAuth: json['requiresAuth'] as bool? ?? false,
      enableStreaming: json['enableStreaming'] as bool? ?? true,
      maxTokens: json['maxTokens'] as int? ?? 4096,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxConcurrentRequests: json['maxConcurrentRequests'] as int? ?? 5,
      customHeaders: json['customHeaders'] != null
          ? Map<String, String>.from(json['customHeaders'] as Map)
          : null,
      customSettings: json['customSettings'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  OpenAICompatibleProviderConfiguration copyWith(Map<String, dynamic> updates) {
    return OpenAICompatibleProviderConfiguration(
      providerId: updates['providerId'] as String? ?? providerId,
      baseUrl: updates['baseUrl'] as String? ?? baseUrl,
      port: updates['port'] as int? ?? port,
      apiKey: updates['apiKey'] as String? ?? apiKey,
      timeout: updates['timeout'] != null
          ? Duration(milliseconds: updates['timeout'] as int)
          : timeout,
      apiVersion: updates['apiVersion'] as String? ?? apiVersion,
      requiresAuth: updates['requiresAuth'] as bool? ?? requiresAuth,
      enableStreaming: updates['enableStreaming'] as bool? ?? enableStreaming,
      maxTokens: updates['maxTokens'] as int? ?? maxTokens,
      temperature: (updates['temperature'] as num?)?.toDouble() ?? temperature,
      maxConcurrentRequests:
          updates['maxConcurrentRequests'] as int? ?? maxConcurrentRequests,
      customHeaders: updates['customHeaders'] != null
          ? Map<String, String>.from(updates['customHeaders'] as Map)
          : customHeaders,
      customSettings:
          updates['customSettings'] as Map<String, dynamic>? ?? customSettings,
    );
  }
}

/// Hermes Agent provider configuration
class HermesProviderConfiguration implements ProviderConfiguration {
  @override
  final String providerId;

  @override
  final String baseUrl;

  @override
  final Duration timeout;

  final bool enableStreaming;

  @override
  final Map<String, dynamic> customSettings;

  const HermesProviderConfiguration({
    required this.providerId,
    required this.baseUrl,
    this.timeout = const Duration(seconds: 60),
    this.enableStreaming = true,
    this.customSettings = const {},
  });

  @override
  String get providerType => 'hermes';

  @override
  bool isValid() {
    try {
      final uri = Uri.parse(baseUrl);
      if (!uri.hasScheme || !uri.hasAuthority) return false;

      if (timeout.inMilliseconds < 1000) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'providerId': providerId,
        'providerType': providerType,
        'baseUrl': baseUrl,
        'timeout': timeout.inMilliseconds,
        'enableStreaming': enableStreaming,
        'customSettings': customSettings,
      };

  factory HermesProviderConfiguration.fromJson(Map<String, dynamic> json) {
    return HermesProviderConfiguration(
      providerId: json['providerId'] as String,
      baseUrl: json['baseUrl'] as String,
      timeout: Duration(milliseconds: json['timeout'] as int? ?? 60000),
      enableStreaming: json['enableStreaming'] as bool? ?? true,
      customSettings: json['customSettings'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  HermesProviderConfiguration copyWith(Map<String, dynamic> updates) {
    return HermesProviderConfiguration(
      providerId: updates['providerId'] as String? ?? providerId,
      baseUrl: updates['baseUrl'] as String? ?? baseUrl,
      timeout: updates['timeout'] != null
          ? Duration(milliseconds: updates['timeout'] as int)
          : timeout,
      enableStreaming: updates['enableStreaming'] as bool? ?? enableStreaming,
      customSettings:
          updates['customSettings'] as Map<String, dynamic>? ?? customSettings,
    );
  }
}

/// Provider configuration validation result
class ConfigurationValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ConfigurationValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  factory ConfigurationValidationResult.valid() {
    return const ConfigurationValidationResult(isValid: true);
  }

  factory ConfigurationValidationResult.invalid(List<String> errors,
      [List<String> warnings = const []]) {
    return ConfigurationValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings,
    );
  }
}

/// Factory for creating provider configurations
class ProviderConfigurationFactory {
  static ProviderConfiguration? fromJson(Map<String, dynamic> json) {
    final providerType = json['providerType'] as String?;

    switch (providerType) {
      case 'hermes':
        return HermesProviderConfiguration.fromJson(json);
      case 'ollama':
        return OllamaProviderConfiguration.fromJson(json);
      case 'lmstudio':
        return LMStudioProviderConfiguration.fromJson(json);
      case 'openai_compatible':
        return OpenAICompatibleProviderConfiguration.fromJson(json);
      default:
        return null;
    }
  }

  static ProviderConfiguration createDefault(
      String providerType, String providerId, String baseUrl, int port) {
    switch (providerType) {
      case 'hermes':
        return HermesProviderConfiguration(
          providerId: providerId,
          baseUrl: baseUrl,
        );
      case 'ollama':
        return OllamaProviderConfiguration(
          providerId: providerId,
          baseUrl: baseUrl,
          port: port,
        );
      case 'lmstudio':
        return LMStudioProviderConfiguration(
          providerId: providerId,
          baseUrl: baseUrl,
          port: port,
        );
      case 'openai_compatible':
        return OpenAICompatibleProviderConfiguration(
          providerId: providerId,
          baseUrl: baseUrl,
          port: port,
        );
      default:
        throw ArgumentError('Unknown provider type: $providerType');
    }
  }

  /// Validate a provider configuration with detailed feedback
  static ConfigurationValidationResult validateConfiguration(
      ProviderConfiguration config) {
    final errors = <String>[];
    final warnings = <String>[];

    // Basic validation
    if (!config.isValid()) {
      errors.add('Configuration failed basic validation');
    }

    // URL validation
    try {
      final uri = Uri.parse(config.baseUrl);
      if (!uri.hasScheme) {
        errors.add('Base URL must include a scheme (http:// or https://)');
      }
      if (!uri.hasAuthority) {
        errors.add('Base URL must include a host');
      }
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        errors.add('Base URL scheme must be http or https');
      }
    } catch (e) {
      errors.add('Invalid base URL format: ${e.toString()}');
    }

    // Provider-specific validation
    switch (config.providerType) {
      case 'hermes':
        final hermesConfig = config as HermesProviderConfiguration;
        final uri = Uri.parse(hermesConfig.baseUrl);
        if (uri.port != 8642) {
          warnings.add('Non-standard Hermes port detected. Default is 8642.');
        }
        break;

      case 'ollama':
        final ollamaConfig = config as OllamaProviderConfiguration;
        if (ollamaConfig.port != 11434) {
          warnings.add('Non-standard Ollama port detected. Default is 11434.');
        }
        if (ollamaConfig.maxConcurrentRequests > 10) {
          warnings.add('High concurrent request limit may impact performance');
        }
        break;

      case 'lmstudio':
        final lmStudioConfig = config as LMStudioProviderConfiguration;
        if (lmStudioConfig.port != 1234) {
          warnings
              .add('Non-standard LM Studio port detected. Default is 1234.');
        }
        if (lmStudioConfig.temperature > 1.5) {
          warnings.add(
              'High temperature setting may produce unpredictable results');
        }
        break;

      case 'openai_compatible':
        final openaiConfig = config as OpenAICompatibleProviderConfiguration;
        if (openaiConfig.requiresAuth &&
            (openaiConfig.apiKey == null || openaiConfig.apiKey!.isEmpty)) {
          errors.add('API key is required when authentication is enabled');
        }
        if (openaiConfig.maxTokens > 8192) {
          warnings.add('Very high token limit may cause performance issues');
        }
        break;
    }

    return ConfigurationValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}
