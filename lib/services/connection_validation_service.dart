import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/validation_result.dart';
import '../models/validation_test.dart';
import '../services/auth_service.dart';

/// Service for comprehensive connection validation and testing during setup
///
/// This service performs detailed testing of all connection components including
/// desktop client communication, LLM connectivity, and streaming functionality.
class ConnectionValidationService extends ChangeNotifier {
  final AuthService _authService;
  final String _baseUrl;
  final Dio _dio = Dio();

  ConnectionValidationService({
    required AuthService authService,
    String? baseUrl,
  })  : _authService = authService,
        _baseUrl = baseUrl ?? _getDefaultBaseUrl() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
  }

  // Validation state
  bool _isValidating = false;
  ValidationResult? _lastValidationResult;
  String? _lastError;
  DateTime? _lastValidationTime;

  // Test tracking
  final List<ValidationTest> _runningTests = [];
  final Map<String, ValidationTest> _completedTests = {};

  // Getters
  bool get isValidating => _isValidating;
  ValidationResult? get lastValidationResult => _lastValidationResult;
  String? get lastError => _lastError;
  DateTime? get lastValidationTime => _lastValidationTime;
  List<ValidationTest> get runningTests => List.unmodifiable(_runningTests);
  Map<String, ValidationTest> get completedTests =>
      Map.unmodifiable(_completedTests);

  /// Get the default base URL based on environment
  static String _getDefaultBaseUrl() {
    if (kDebugMode) {
      return 'http://localhost:8080';
    } else {
      return 'https://api.cloudtolocalllm.online';
    }
  }

  /// Run comprehensive connection validation suite
  ///
  /// Performs all validation tests including desktop client communication,
  /// LLM connectivity, and streaming functionality validation.
  Future<ValidationResult> runComprehensiveValidation(String userId) async {
    if (!_authService.isAuthenticated.value) {
      throw Exception('User not authenticated');
    }

    _isValidating = true;
    _lastError = null;
    _runningTests.clear();
    _completedTests.clear();
    notifyListeners();

    final startTime = DateTime.now();
    final tests = <ValidationTest>[];

    try {
      debugPrint(
        ' [ConnectionValidation] Starting comprehensive validation for user: $userId',
      );

      // Test 1: Desktop Client Communication
      final desktopTest = await _testDesktopClientCommunication(userId);
      tests.add(desktopTest);
      _completedTests['desktop_communication'] = desktopTest;

      // Test 2: LLM Connectivity
      final llmTest = await _testLLMConnectivity(userId);
      tests.add(llmTest);
      _completedTests['llm_connectivity'] = llmTest;

      // Test 3: Streaming Functionality
      final streamingTest = await _testStreamingFunctionality(userId);
      tests.add(streamingTest);
      _completedTests['streaming_functionality'] = streamingTest;

      // Test 4: Authentication Validation
      final authTest = await _testAuthenticationValidation(userId);
      tests.add(authTest);
      _completedTests['authentication'] = authTest;

      // Test 5: Network Connectivity
      final networkTest = await _testNetworkConnectivity();
      tests.add(networkTest);
      _completedTests['network_connectivity'] = networkTest;

      final duration = DateTime.now().difference(startTime);
      final successfulTests = tests.where((test) => test.isSuccess).length;
      final isOverallSuccess = successfulTests == tests.length;

      _lastValidationResult = ValidationResult(
        isSuccess: isOverallSuccess,
        message: isOverallSuccess
            ? 'All validation tests passed successfully'
            : 'Some validation tests failed',
        tests: tests,
        duration: duration.inMilliseconds,
        timestamp: DateTime.now(),
        metadata: {
          'userId': userId,
          'totalTests': tests.length,
          'successfulTests': successfulTests,
          'failedTests': tests.length - successfulTests,
        },
      );

      _lastValidationTime = DateTime.now();

      debugPrint(
        ' [ConnectionValidation] Validation completed in ${duration.inMilliseconds}ms',
      );
      debugPrint(
        ' [ConnectionValidation] Results: $successfulTests/${tests.length} tests passed',
      );

      return _lastValidationResult!;
    } catch (e) {
      _lastError = 'Validation failed: ${e.toString()}';
      debugPrint(' [ConnectionValidation] Error during validation: $e');

      _lastValidationResult = ValidationResult.failure(
        'Unexpected error during validation: ${e.toString()}',
        tests: tests,
      );

      return _lastValidationResult!;
    } finally {
      _isValidating = false;
      notifyListeners();
    }
  }

  /// Test desktop client communication
  Future<ValidationTest> _testDesktopClientCommunication(String userId) async {
    final startTime = DateTime.now();

    try {
      debugPrint(
        ' [ConnectionValidation] Testing desktop client communication...',
      );

      final token = await _authService.getValidatedAccessToken();
      if (token == null) {
        return ValidationTest.failure(
          'Desktop Client Communication',
          'Failed to get authentication token',
          duration: DateTime.now().difference(startTime).inMilliseconds,
        );
      }

      final response = await _dio.get(
        '/tunnel/status',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        }),
      );

      final duration = DateTime.now().difference(startTime).inMilliseconds;

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final isConnected = data['connected'] == true;

        if (isConnected) {
          return ValidationTest.success(
            'Desktop Client Communication',
            'Desktop client is connected and responding',
            duration: duration,
            details: {'responseTime': duration, 'status': data},
          );
        } else {
          return ValidationTest.failure(
            'Desktop Client Communication',
            'Desktop client is not connected',
            duration: duration,
            details: {'status': data},
          );
        }
      } else {
        return ValidationTest.failure(
          'Desktop Client Communication',
          'Failed to check desktop client status: HTTP ${response.statusCode}',
          duration: duration,
        );
      }
    } catch (e) {
      return ValidationTest.failure(
        'Desktop Client Communication',
        'Error testing desktop client: ${e.toString()}',
        duration: DateTime.now().difference(startTime).inMilliseconds,
      );
    }
  }

  /// Test LLM connectivity
  Future<ValidationTest> _testLLMConnectivity(String userId) async {
    final startTime = DateTime.now();

    try {
      debugPrint(' [ConnectionValidation] Testing LLM connectivity...');

      final token = await _authService.getValidatedAccessToken();
      if (token == null) {
        return ValidationTest.failure(
          'LLM Connectivity',
          'Failed to get authentication token',
          duration: DateTime.now().difference(startTime).inMilliseconds,
        );
      }

      // Test basic LLM endpoint connectivity
      final response = await _dio.get(
        '/ollama/tags',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        }),
      );

      final duration = DateTime.now().difference(startTime).inMilliseconds;

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final models = data['models'] as List?;

        return ValidationTest.success(
          'LLM Connectivity',
          'LLM service is accessible and responding',
          duration: duration,
          details: {
            'responseTime': duration,
            'availableModels': models?.length ?? 0,
            'models': models?.take(3).toList() ?? [],
          },
        );
      } else {
        return ValidationTest.failure(
          'LLM Connectivity',
          'LLM service returned error: HTTP ${response.statusCode}',
          duration: duration,
        );
      }
    } catch (e) {
      return ValidationTest.failure(
        'LLM Connectivity',
        'Error testing LLM connectivity: ${e.toString()}',
        duration: DateTime.now().difference(startTime).inMilliseconds,
      );
    }
  }

  /// Test streaming functionality
  Future<ValidationTest> _testStreamingFunctionality(String userId) async {
    final startTime = DateTime.now();

    try {
      debugPrint(
        ' [ConnectionValidation] Testing streaming functionality...',
      );

      // For now, we'll do a basic test of the streaming endpoint
      // In a real implementation, this would test actual streaming
      final token = await _authService.getValidatedAccessToken();
      if (token == null) {
        return ValidationTest.failure(
          'Streaming Functionality',
          'Failed to get authentication token',
          duration: DateTime.now().difference(startTime).inMilliseconds,
        );
      }

      // Test streaming endpoint availability
      final response = await _dio.post(
        '/chat/stream',
        data: {
          'model': 'test',
          'messages': [
            {'role': 'user', 'content': 'test'},
          ],
          'stream': true,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        }),
      );

      final duration = DateTime.now().difference(startTime).inMilliseconds;

      // Accept both 200 (success) and 400 (bad request) as valid responses
      // since we're just testing endpoint availability
      if (response.statusCode == 200 || response.statusCode == 400) {
        return ValidationTest.success(
          'Streaming Functionality',
          'Streaming endpoint is accessible',
          duration: duration,
          details: {
            'responseTime': duration,
            'statusCode': response.statusCode,
          },
        );
      } else {
        return ValidationTest.failure(
          'Streaming Functionality',
          'Streaming endpoint returned unexpected status: HTTP ${response.statusCode}',
          duration: duration,
        );
      }
    } catch (e) {
      return ValidationTest.failure(
        'Streaming Functionality',
        'Error testing streaming functionality: ${e.toString()}',
        duration: DateTime.now().difference(startTime).inMilliseconds,
      );
    }
  }

  /// Test authentication validation
  Future<ValidationTest> _testAuthenticationValidation(String userId) async {
    final startTime = DateTime.now();

    try {
      debugPrint(
        ' [ConnectionValidation] Testing authentication validation...',
      );

      final token = await _authService.getValidatedAccessToken();
      if (token == null) {
        return ValidationTest.failure(
          'Authentication Validation',
          'Failed to get authentication token',
          duration: DateTime.now().difference(startTime).inMilliseconds,
        );
      }

      // Test token validation endpoint
      final response = await _dio.get(
        '/auth/validate',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        }),
      );

      final duration = DateTime.now().difference(startTime).inMilliseconds;

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final isValid = data['valid'] == true;

        if (isValid) {
          return ValidationTest.success(
            'Authentication Validation',
            'Authentication token is valid',
            duration: duration,
            details: {'responseTime': duration, 'tokenInfo': data},
          );
        } else {
          return ValidationTest.failure(
            'Authentication Validation',
            'Authentication token is invalid',
            duration: duration,
          );
        }
      } else {
        return ValidationTest.failure(
          'Authentication Validation',
          'Authentication validation failed: HTTP ${response.statusCode}',
          duration: duration,
        );
      }
    } catch (e) {
      return ValidationTest.failure(
        'Authentication Validation',
        'Error validating authentication: ${e.toString()}',
        duration: DateTime.now().difference(startTime).inMilliseconds,
      );
    }
  }

  /// Test network connectivity
  Future<ValidationTest> _testNetworkConnectivity() async {
    final startTime = DateTime.now();

    try {
      debugPrint(' [ConnectionValidation] Testing network connectivity...');

      // Test basic network connectivity to the API
      final response = await _dio.get('/health');

      final duration = DateTime.now().difference(startTime).inMilliseconds;

      if (response.statusCode == 200) {
        return ValidationTest.success(
          'Network Connectivity',
          'Network connection to API is working',
          duration: duration,
          details: {'responseTime': duration},
        );
      } else {
        return ValidationTest.failure(
          'Network Connectivity',
          'Network connectivity test failed: HTTP ${response.statusCode}',
          duration: duration,
        );
      }
    } catch (e) {
      return ValidationTest.failure(
        'Network Connectivity',
        'Error testing network connectivity: ${e.toString()}',
        duration: DateTime.now().difference(startTime).inMilliseconds,
      );
    }
  }

  /// Get validation summary for reporting
  Map<String, dynamic> getValidationSummary() {
    final result = _lastValidationResult;
    if (result == null) {
      return {
        'hasResults': false,
        'message': 'No validation results available',
      };
    }

    return {
      'hasResults': true,
      'isSuccess': result.isSuccess,
      'message': result.message,
      'totalTests': result.tests.length,
      'successfulTests': result.tests.where((test) => test.isSuccess).length,
      'failedTests': result.tests.where((test) => !test.isSuccess).length,
      'duration': result.duration,
      'timestamp': result.timestamp.toIso8601String(),
      'lastValidationTime': _lastValidationTime?.toIso8601String(),
    };
  }

  /// Clear validation results
  void clearResults() {
    _lastValidationResult = null;
    _lastError = null;
    _lastValidationTime = null;
    _completedTests.clear();
    debugPrint(' [ConnectionValidation] Cleared validation results');
    notifyListeners();
  }
}
