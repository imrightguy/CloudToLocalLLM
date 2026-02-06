/// Ollama Service (Stub)
///
/// Stub service providing compatibility methods for Ollama functionality.
/// Extends ChangeNotifier to work with Provider.of() pattern.
/// All methods return safe defaults or no-ops to prevent runtime errors.
///
/// This stub exists because Ollama integration was removed from the application.
/// LLM management is now strictly managed by OpenClaw.
library;

import 'package:flutter/foundation.dart';

/// Stub Ollama model class
class OllamaModel {
  final String name;
  final String? size;

  const OllamaModel({
    required this.name,
    this.size,
  });
}

/// Stub Ollama service - provides compatibility with existing code
/// Extends ChangeNotifier to work with Provider pattern
class OllamaService extends ChangeNotifier {
  /// Singleton instance (for GetIt registration)
  static OllamaService? _instance;
  static OllamaService get instance {
    _instance ??= OllamaService._internal();
    return _instance!;
  }

  OllamaService._internal();

  /// Check if Ollama is available
  static bool get isAvailable => false;

  /// Get Ollama status
  static Map<String, dynamic> getStatus() {
    return {
      'available': false,
      'service': 'Ollama integration removed from application',
      'note': 'This stub provides compatibility with existing OllamaService references',
      'migration': 'LLM management is now strictly managed by OpenClaw',
    };
  }

  /// Check if Ollama is connected (stub)
  static bool get isConnected => false;

  /// Get last error message (stub)
  static String? get error => null;

  /// List available models (stub - returns empty)
  static List<OllamaModel> get models => [];

  /// Pull a model (stub - no-op)
  static Future<void> pullModel(String model) async {
    debugPrint('[OllamaService] Model pull requested: $model (no-op in stub)');
  }

  /// Generate chat completion (stub - returns empty response)
  static Future<List<String>> generate(String prompt, String model) async {
    debugPrint('[OllamaService] Chat completion requested (stub, empty response)');
    return ['Ollama integration removed from application'];
  }

  /// Get service version
  static Map<String, dynamic> getVersion() {
    return {
      'version': 'stub',
      'message': 'Ollama integration removed, stub provides compatibility',
      'migration': 'LLM management is now strictly managed by OpenClaw',
    };
  }

  /// Check if service is loading (stub)
  static bool get isLoading => false;

  /// Get last connection error (stub)
  static String? get lastError => null;

  /// Test connection (stub - no-op)
  static Future<void> testConnection() async {
    debugPrint('[OllamaService] Connection test requested (no-op in stub)');
  }

  /// Delete a model (stub - no-op)
  static Future<void> deleteModel(String model) async {
    debugPrint('[OllamaService] Model deletion requested: $model (no-op in stub)');
  }
}
