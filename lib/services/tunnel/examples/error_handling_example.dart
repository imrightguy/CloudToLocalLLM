/// Error Handling and Diagnostics Usage Examples
/// Demonstrates how to use the error handling and diagnostic components
// ignore_for_file: avoid_print
library;

import 'dart:async';
import 'dart:io';
import '../error_categorization.dart';
import '../error_recovery_strategy.dart';
import '../diagnostics/diagnostics.dart';
import '../interfaces/tunnel_models.dart';
import '../reconnection_manager.dart';

/// Example 1: Error Categorization
void exampleErrorCategorization() {
  print('=== Example 1: Error Categorization ===\n');

  // Example 1a: Network error
  try {
    throw SocketException('Connection refused');
  } catch (e, stackTrace) {
    final error = ErrorCategorizationService.categorizeException(
      e as Exception,
      stackTrace: stackTrace,
      context: {'operation': 'connect', 'host': 'example.com'},
    );

    print('Category: ${error.category.name}');
    print('Code: ${error.code}');
    print('User Message: ${error.userMessage}');
    print('Suggestion: ${error.suggestion}');
    print('Is Retryable: ${error.isRetryable}');
    print('Documentation: ${error.documentationUrl}');
    print('');
  }

  // Example 1b: Timeout error
  try {
    throw TimeoutException('Operation timed out', const Duration(seconds: 30));
  } catch (e, stackTrace) {
    final error = ErrorCategorizationService.categorizeException(
      e as Exception,
      stackTrace: stackTrace,
    );

    print('Timeout Error:');
    print('  ${error.userMessage}');
    print('  ${error.suggestion}');
    print('');
  }

  // Example 1c: HTTP status code
  final httpError = ErrorCategorizationService.fromHttpStatus(
    429,
    message: 'Too many requests',
    context: {'endpoint': '/tunnel'},
  );

  print('HTTP 429 Error:');
  print('  ${httpError.userMessage}');
  print('  ${httpError.suggestion}');
  print('');
}

/// Example 2: Running Diagnostics
Future<void> exampleRunDiagnostics() async {
  print('=== Example 2: Running Diagnostics ===\n');

  final testSuite = DiagnosticTestSuite(
    serverHost: 'api.cloudtolocalllm.online',
    serverPort: 443,
    authToken: 'sample-token',
    testTimeout: const Duration(seconds: 30),
  );

  print('Running diagnostic tests...\n');

  // Run all tests
  final tests = await testSuite.runAllTests();

  // Display individual test results
  for (final test in tests) {
    final status = test.passed ? '✓ PASS' : '✗ FAIL';
    print('$status - ${test.name}');
    print('  Duration: ${test.duration.inMilliseconds}ms');

    if (!test.passed && test.errorMessage != null) {
      print('  Error: ${test.errorMessage}');
    }

    if (test.details != null && test.details!.isNotEmpty) {
      print('  Details:');
      test.details!.forEach((key, value) {
        print('    $key: $value');
      });
    }
    print('');
  }
}

/// Example 3: Generating Diagnostic Report
Future<void> exampleDiagnosticReport() async {
  print('=== Example 3: Diagnostic Report ===\n');

  final testSuite = DiagnosticTestSuite(
    serverHost: 'api.cloudtolocalllm.online',
    serverPort: 443,
    authToken: 'sample-token',
  );

  // Run tests
  final tests = await testSuite.runAllTests();

  // Generate report
  final report = DiagnosticReportGenerator.generateReport(tests);

  // Calculate health score
  final score = DiagnosticReportGenerator.calculateHealthScore(report);
  final status = DiagnosticReportGenerator.getHealthStatus(score);

  print('Health Score: $score/100 ($status)');
  print('Pass Rate: ${(report.summary.passRate * 100).toStringAsFixed(1)}%');
  print('');

  // Display recommendations
  print('Recommendations:');
  for (final recommendation in report.summary.recommendations) {
    print('  $recommendation');
  }
  print('');

  // Format as text
  print('--- Text Format ---');
  print(DiagnosticReportGenerator.formatReportAsText(report));

  // Format as JSON
  print('--- JSON Format ---');
  final json = DiagnosticReportGenerator.formatReportAsJson(report);
  print('Health Score: ${json['healthScore']}');
  print('Health Status: ${json['healthStatus']}');
  print('');
}

/// Example 4: Error Recovery
Future<void> exampleErrorRecovery() async {
  print('=== Example 4: Error Recovery ===\n');

  // Create mock functions for recovery
  Future<bool> testConnection() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return true; // Simulate successful connection test
  }

  Future<void> reconnect() async {
    await Future.delayed(const Duration(milliseconds: 200));
    print('  Reconnected successfully');
  }

  Future<void> flushQueue() async {
    await Future.delayed(const Duration(milliseconds: 100));
    print('  Flushed queued requests');
  }

  Future<void> refreshToken() async {
    await Future.delayed(const Duration(milliseconds: 150));
    print('  Refreshed authentication token');
  }

  // Create recovery strategy
  final reconnectionManager = ReconnectionManager(
    maxAttempts: 10,
    baseDelay: const Duration(seconds: 2),
    maxDelay: const Duration(seconds: 60),
  );

  final strategy = ErrorRecoveryStrategy(
    reconnectionManager: reconnectionManager,
    testConnection: testConnection,
    reconnect: reconnect,
    flushQueuedRequests: flushQueue,
    refreshAuthToken: refreshToken,
  );

  // Example 4a: Network error recovery
  print('Network Error Recovery:');
  final networkError = TunnelError.network(
    code: TunnelErrorCodes.connectionRefused,
    message: 'Connection refused',
  );

  final networkResult = await strategy.attemptRecovery(networkError);
  print('  Success: ${networkResult.success}');
  print('  Duration: ${networkResult.duration.inMilliseconds}ms');
  print('  Attempts: ${networkResult.attempts}');
  print('  Message: ${networkResult.message}');
  print('');

  // Example 4b: Authentication error recovery
  print('Authentication Error Recovery:');
  final authError = TunnelError.authentication(
    code: TunnelErrorCodes.tokenExpired,
    message: 'Token expired',
  );

  final authResult = await strategy.attemptRecovery(authError);
  print('  Success: ${authResult.success}');
  print('  Duration: ${authResult.duration.inMilliseconds}ms');
  print('  Attempts: ${authResult.attempts}');
  print('  Message: ${authResult.message}');
  print('');

  // Example 4c: Check if error is recoverable
  print('Error Recoverability:');
  final configError = TunnelError.configuration(
    code: TunnelErrorCodes.configurationError,
    message: 'Invalid configuration',
  );

  print(
      '  Network error recoverable: ${ErrorRecoveryStrategy.isRecoverable(networkError)}');
  print(
      '  Auth error recoverable: ${ErrorRecoveryStrategy.isRecoverable(authError)}');
  print(
      '  Config error recoverable: ${ErrorRecoveryStrategy.isRecoverable(configError)}');
  print('');

  // Example 4d: Get recovery strategy description
  print('Recovery Strategy Descriptions:');
  print(
      '  Network: ${ErrorRecoveryStrategy.getRecoveryStrategyDescription(networkError)}');
  print(
      '  Auth: ${ErrorRecoveryStrategy.getRecoveryStrategyDescription(authError)}');
  print(
      '  Config: ${ErrorRecoveryStrategy.getRecoveryStrategyDescription(configError)}');
  print('');
}

/// Example 5: Complete Error Handling Flow
Future<void> exampleCompleteFlow() async {
  print('=== Example 5: Complete Error Handling Flow ===\n');

  // Simulate an operation that might fail
  Future<void> riskyOperation() async {
    // Simulate random failure
    await Future.delayed(const Duration(milliseconds: 100));
    throw SocketException('Connection refused');
  }

  try {
    await riskyOperation();
  } catch (e, stackTrace) {
    // Step 1: Categorize the error
    final error = ErrorCategorizationService.categorizeException(
      e as Exception,
      stackTrace: stackTrace,
      context: {'operation': 'riskyOperation'},
    );

    print('Error Detected:');
    print('  Category: ${error.category.name}');
    print('  Code: ${error.code}');
    print('  Message: ${error.userMessage}');
    print('  Suggestion: ${error.suggestion}');
    print('');

    // Step 2: Check if recoverable
    if (ErrorRecoveryStrategy.isRecoverable(error)) {
      print('Error is recoverable. Attempting recovery...');
      print(
          'Strategy: ${ErrorRecoveryStrategy.getRecoveryStrategyDescription(error)}');
      print('');

      // Step 3: Attempt recovery (mock)
      final reconnectionManager = ReconnectionManager(
        maxAttempts: 3,
        baseDelay: const Duration(seconds: 1),
        maxDelay: const Duration(seconds: 30),
      );

      final strategy = ErrorRecoveryStrategy(
        reconnectionManager: reconnectionManager,
        testConnection: () async => true,
        reconnect: () async {
          print('  Reconnecting...');
        },
        flushQueuedRequests: () async {
          print('  Flushing queue...');
        },
      );

      final result = await strategy.attemptRecovery(error);

      if (result.success) {
        print('Recovery successful!');
        print('  Duration: ${result.duration.inMilliseconds}ms');
        print('  Attempts: ${result.attempts}');
      } else {
        print('Recovery failed: ${result.message}');
        print('  Running diagnostics...');

        // Step 4: Run diagnostics if recovery fails
        final testSuite = DiagnosticTestSuite(
          serverHost: 'api.cloudtolocalllm.online',
          serverPort: 443,
        );

        final tests = await testSuite.runAllTests();
        final report = DiagnosticReportGenerator.generateReport(tests);
        final score = DiagnosticReportGenerator.calculateHealthScore(report);

        print('  Health Score: $score/100');
        print('  Recommendations:');
        for (final rec in report.summary.recommendations) {
          print('    - $rec');
        }
      }
    } else {
      print('Error is not automatically recoverable.');
      print('User intervention required.');
    }
  }
}

/// Main function to run all examples
Future<void> main() async {
  print('╔════════════════════════════════════════════════════════════╗');
  print('║  Error Handling and Diagnostics Examples                  ║');
  print('╚════════════════════════════════════════════════════════════╝');
  print('');

  // Run examples
  exampleErrorCategorization();
  print('');

  await exampleRunDiagnostics();
  print('');

  await exampleDiagnosticReport();
  print('');

  await exampleErrorRecovery();
  print('');

  await exampleCompleteFlow();
  print('');

  print('╔════════════════════════════════════════════════════════════╗');
  print('║  All examples completed!                                   ║');
  print('╚════════════════════════════════════════════════════════════╝');
}
