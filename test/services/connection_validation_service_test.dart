import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/models/validation_result.dart';
import 'package:cloudtolocalllm/models/validation_test.dart';

void main() {
  group('ConnectionValidationService', () {
    // Note: Full service tests would require mocking AuthService and HTTP client
    // For now, we'll focus on testing the models and basic functionality
  });

  group('ValidationResult', () {
    test('should create successful result', () {
      final result = ValidationResult.success(
        'All tests passed',
        duration: 1500,
      );

      expect(result.isSuccess, true);
      expect(result.message, 'All tests passed');
      expect(result.duration, 1500);
      expect(result.tests, isEmpty);
    });

    test('should create failed result', () {
      final result = ValidationResult.failure(
        'Some tests failed',
        duration: 2000,
      );

      expect(result.isSuccess, false);
      expect(result.message, 'Some tests failed');
      expect(result.duration, 2000);
    });

    test('should calculate success rate correctly', () {
      final tests = [
        ValidationTest.success('Test 1', 'Passed'),
        ValidationTest.failure('Test 2', 'Failed'),
        ValidationTest.success('Test 3', 'Passed'),
        ValidationTest.failure('Test 4', 'Failed'),
      ];

      final result = ValidationResult.success('Mixed results', tests: tests);

      expect(result.successRate, 0.5);
      expect(result.successfulTestCount, 2);
      expect(result.failedTestCount, 2);
    });

    test('should filter tests by success/failure', () {
      final tests = [
        ValidationTest.success('Test 1', 'Passed'),
        ValidationTest.failure('Test 2', 'Failed'),
        ValidationTest.success('Test 3', 'Passed'),
      ];

      final result = ValidationResult.success('Mixed results', tests: tests);

      expect(result.successfulTests.length, 2);
      expect(result.failedTests.length, 1);
      expect(result.successfulTests.first.name, 'Test 1');
      expect(result.failedTests.first.name, 'Test 2');
    });

    test('should find specific tests', () {
      final tests = [
        ValidationTest.success('Desktop Communication', 'Passed'),
        ValidationTest.failure('LLM Connectivity', 'Failed'),
      ];

      final result = ValidationResult.success('Mixed results', tests: tests);

      expect(result.hasTestPassed('Desktop Communication'), true);
      expect(result.hasTestPassed('LLM Connectivity'), false);
      expect(result.hasTestPassed('Non-existent Test'), false);

      final desktopTest = result.getTest('Desktop Communication');
      expect(desktopTest, isNotNull);
      expect(desktopTest!.isSuccess, true);
    });

    test('should group tests by category', () {
      final tests = [
        ValidationTest.success('Test 1', 'Passed', category: 'network'),
        ValidationTest.success('Test 2', 'Passed', category: 'network'),
        ValidationTest.failure('Test 3', 'Failed', category: 'auth'),
      ];

      final result = ValidationResult.success('Mixed results', tests: tests);

      final networkTests = result.getTestsByCategory('network');
      final authTests = result.getTestsByCategory('auth');

      expect(networkTests.length, 2);
      expect(authTests.length, 1);
      expect(authTests.first.isSuccess, false);
    });

    test('should convert to/from JSON', () {
      final tests = [
        ValidationTest.success('Test 1', 'Passed', duration: 100),
        ValidationTest.failure('Test 2', 'Failed', duration: 200),
      ];

      final original = ValidationResult.success(
        'Test results',
        tests: tests,
        duration: 1000,
        metadata: {'userId': 'test-123'},
      );

      final json = original.toJson();
      final restored = ValidationResult.fromJson(json);

      expect(restored.isSuccess, original.isSuccess);
      expect(restored.message, original.message);
      expect(restored.duration, original.duration);
      expect(restored.tests.length, original.tests.length);
      expect(restored.metadata, original.metadata);
    });
  });

  group('ValidationTest', () {
    test('should create successful test', () {
      final test = ValidationTest.success(
        'Network Test',
        'Connection successful',
        duration: 150,
        category: 'network',
      );

      expect(test.name, 'Network Test');
      expect(test.isSuccess, true);
      expect(test.message, 'Connection successful');
      expect(test.duration, 150);
      expect(test.category, 'network');
      expect(test.status, 'PASSED');
    });

    test('should create failed test', () {
      final test = ValidationTest.failure(
        'Auth Test',
        'Authentication failed',
        error: 'Invalid token',
        duration: 200,
        category: 'auth',
      );

      expect(test.name, 'Auth Test');
      expect(test.isSuccess, false);
      expect(test.message, 'Authentication failed');
      expect(test.error, 'Invalid token');
      expect(test.duration, 200);
      expect(test.category, 'auth');
      expect(test.status, 'FAILED');
    });

    test('should format duration correctly', () {
      final fastTest = ValidationTest.success('Fast', 'Done', duration: 500);
      final slowTest = ValidationTest.success('Slow', 'Done', duration: 2500);
      final noTimeTest = ValidationTest.success('No Time', 'Done');

      expect(fastTest.durationString, '500ms');
      expect(slowTest.durationString, '2.5s');
      expect(noTimeTest.durationString, 'N/A');
    });

    test('should detect details and errors', () {
      final detailedTest = ValidationTest.success(
        'Detailed Test',
        'Success',
        details: {'responseTime': 100, 'status': 'ok'},
      );

      final errorTest = ValidationTest.failure(
        'Error Test',
        'Failed',
        error: 'Connection timeout',
      );

      final simpleTest = ValidationTest.success('Simple', 'Done');

      expect(detailedTest.hasDetails, true);
      expect(detailedTest.hasError, false);

      expect(errorTest.hasDetails, false);
      expect(errorTest.hasError, true);

      expect(simpleTest.hasDetails, false);
      expect(simpleTest.hasError, false);
    });

    test('should convert to/from JSON', () {
      final original = ValidationTest.failure(
        'Test Name',
        'Test failed',
        error: 'Network error',
        duration: 300,
        category: 'network',
        details: {'code': 500, 'url': 'http://example.com'},
      );

      final json = original.toJson();
      final restored = ValidationTest.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.isSuccess, original.isSuccess);
      expect(restored.message, original.message);
      expect(restored.error, original.error);
      expect(restored.duration, original.duration);
      expect(restored.category, original.category);
      expect(restored.details, original.details);
    });

    test('should create formatted result', () {
      final test = ValidationTest.failure(
        'Network Test',
        'Connection failed',
        error: 'Timeout',
        duration: 5000,
        category: 'network',
        details: {'url': 'http://api.example.com', 'timeout': 5000},
      );

      final formatted = test.formattedResult;

      expect(formatted, contains('Test: Network Test'));
      expect(formatted, contains('Status: FAILED'));
      expect(formatted, contains('Message: Connection failed'));
      expect(formatted, contains('Duration: 5.0s'));
      expect(formatted, contains('Category: network'));
      expect(formatted, contains('Error: Timeout'));
      expect(formatted, contains('Details:'));
      expect(formatted, contains('url: http://api.example.com'));
    });

    test('should compare tests by name', () {
      final testA = ValidationTest.success('A Test', 'Done');
      final testB = ValidationTest.success('B Test', 'Done');
      final testC = ValidationTest.success('A Test', 'Also done');

      expect(testA.compareTo(testB), lessThan(0));
      expect(testB.compareTo(testA), greaterThan(0));
      expect(testA.compareTo(testC), 0);
    });
  });
}
