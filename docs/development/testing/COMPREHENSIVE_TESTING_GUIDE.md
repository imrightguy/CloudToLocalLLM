# Zoidbot Comprehensive Testing Guide

This guide covers all testing components in the Zoidbot project, including setup, execution, and integration with the CI/CD pipeline.

## 📁 Test Directory Structure

```
test/
├── COMPREHENSIVE_TESTING_GUIDE.md    # This guide
├── README.md                         # E2E specific documentation
├── flutter_test_config.dart          # Flutter test configuration
├── test_config.dart                  # Shared test utilities
├── api-backend/                      # Node.js API backend tests
│   ├── security/                     # Security-focused tests
│   │   ├── authentication-authorization.test.js
│   │   └── user-isolation.test.js
│   ├── admin-data-flush.test.js
│   ├── message-protocol.test.js
│   ├── tunnel-*.test.js              # Tunnel functionality tests
│   └── tunnel-system-integration.test.js
├── powershell/                       # PowerShell deployment tests
│   ├── CI-TestRunner.ps1             # CI-optimized test runner
│   ├── Run-Tests.ps1                 # Standard test runner
│   ├── TestConfig.ps1                # Test configuration
│   ├── Deploy-Zoidbot.Tests.ps1
│   ├── BuildEnvironmentUtilities.Tests.ps1
│   ├── Mocks/                        # Mock implementations
│   └── Integration/                  # Integration tests
└── e2e/                             # Playwright E2E tests
    ├── ci-health-check.spec.js       # CI health validation
    ├── auth-loop-analysis.spec.js    # Authentication testing
    ├── tunnel-*.spec.js              # Tunnel functionality E2E
    └── global-setup.js               # E2E test setup
```

## 🧪 Test Categories

### 1. Flutter/Dart Tests

**Location**: Root directory and `test/` (Flutter convention)
**Purpose**: Application logic, widget testing, and static analysis

```bash
# Run all Flutter tests
flutter test

# Run with coverage
flutter test --coverage

# Static analysis
flutter analyze --fatal-infos --fatal-warnings
```

**Key Features**:

- Widget testing for UI components
- Unit testing for business logic
- Integration testing for app flows
- Static analysis for code quality

### 2. Node.js/Jest Tests

**Location**: `test/api-backend/`
**Purpose**: API backend validation, security testing, and service integration

```bash
# Navigate to API backend
cd services/api-backend

# Run all tests
npm test

# Run specific categories
npm run test:security
npm run test:auth
npm run test:user-isolation
```

**Key Features**:

- API endpoint testing
- Security validation (JWT, authentication, authorization)
- User isolation and multi-tenancy testing
- Tunnel functionality validation
- Admin service testing

### 3. PowerShell Tests

**Location**: `test/powershell/`
**Purpose**: Deployment script validation and infrastructure testing

```bash
# Run all PowerShell tests
pwsh test/powershell/CI-TestRunner.ps1

# Run with coverage
pwsh test/powershell/CI-TestRunner.ps1 -CodeCoverage -ExportResults
```

**Key Features**:

- Deployment script validation
- Infrastructure testing with mocks
- Cross-platform compatibility testing
- Error handling and rollback testing

### 4. Playwright E2E Tests

**Location**: `test/e2e/`
**Purpose**: End-to-end user workflow validation

```bash
# Install browsers (first time)
npx playwright install --with-deps

# Run all E2E tests
npx playwright test

# Run specific test
npx playwright test test/e2e/ci-health-check.spec.js
```

**Key Features**:

- Authentication flow validation
- Cross-browser compatibility testing
- Performance baseline validation
- User journey testing
- Tunnel functionality E2E validation

## 🚀 Quick Start

### Prerequisites

```bash
# Check Flutter
flutter --version  # Should be 3.24.0+

# Check Node.js
node --version     # Should be 18+

# Check PowerShell
pwsh --version     # Should be 7+

# Check Playwright
npx playwright --version
```

### Run All Tests Locally

```bash
# Using integrated deployment script (recommended)
.\scripts\deploy\Deploy-WithTests.ps1 -DryRun

# Or run individual test suites
flutter test                                    # Flutter tests
npm test --prefix services/api-backend          # Node.js tests
pwsh test/powershell/CI-TestRunner.ps1         # PowerShell tests
npx playwright test                             # E2E tests
```

## 🔄 CI/CD Integration

### GitHub Actions Pipeline

The tests are automatically executed in the CI/CD pipeline defined in `.github/workflows/ci-cd.yml`:

1. **Parallel Test Execution**: All test suites run in parallel for faster feedback
2. **Quality Gates**: Tests must pass before deployment proceeds
3. **Comprehensive Reporting**: Results are collected and reported
4. **Artifact Collection**: Test results and coverage reports are preserved

### Test Execution Order

1. **Flutter Tests** - Application core validation
2. **Node.js Tests** - API backend validation
3. **PowerShell Tests** - Deployment script validation
4. **Playwright Tests** - E2E validation (depends on Flutter build)

### Quality Gates

- **Critical Failures**: Block deployment completely
- **Warning Failures**: Generate warnings but may allow deployment
- **Coverage Thresholds**: Enforce minimum code coverage requirements

## 📊 Test Configuration

### Flutter Test Configuration

**File**: `test/flutter_test_config.dart`

- Configures test environment for CI/CD
- Sets up mock services for headless testing
- Manages test timeouts and cleanup

### Node.js Test Configuration

**File**: `services/api-backend/jest.config.js`

- Jest configuration optimized for CI
- Coverage reporting and thresholds
- Test result formatting for CI integration

### PowerShell Test Configuration

**File**: `test/powershell/TestConfig.ps1`

- Mock behavior configuration
- Test data management
- Cross-platform compatibility settings

### Playwright Test Configuration

**File**: `playwright.config.js`

- Browser configuration for different environments
- CI-specific settings and timeouts
- Test result reporting and artifact collection

## 🛠️ Development Workflow

### Adding New Tests

1. **Choose the appropriate test category** based on what you're testing
2. **Follow existing patterns** and naming conventions
3. **Include both positive and negative test cases**
4. **Add proper documentation** and comments
5. **Update CI/CD pipeline** if needed

### Test Best Practices

1. **Write descriptive test names** that explain the scenario
2. **Use proper setup and teardown** for test isolation
3. **Mock external dependencies** for reliability
4. **Include edge cases** and error conditions
5. **Keep tests fast** to maintain CI/CD performance

### Running Tests During Development

```bash
# Quick validation during development
flutter test                    # Fast feedback on Flutter changes
npm test --prefix services/api-backend --watch  # Watch mode for API changes

# Full validation before commit
.\scripts\deploy\Deploy-WithTests.ps1 -DryRun

# Specific test debugging
npx playwright test --headed --debug  # Debug E2E tests visually
```

## 🔧 Troubleshooting

### Common Issues

#### Test Environment Setup

```bash
# Flutter issues
flutter clean && flutter pub get

# Node.js issues
rm -rf node_modules && npm install

# PowerShell issues
Install-Module -Name Pester -Force

# Playwright issues
npx playwright install --with-deps
```

#### CI/CD Pipeline Issues

1. Check GitHub Actions logs for specific errors
2. Verify environment variables are set correctly
3. Ensure all dependencies are properly installed
4. Review test isolation and cleanup procedures

### Getting Help

1. **Review this guide** and related documentation
2. **Check existing test examples** for patterns
3. **Run tests locally** to reproduce issues
4. **Review CI/CD logs** for detailed error information

## 📚 Related Documentation

- [Main Testing & CI/CD Guide](../docs/TESTING_AND_CICD_GUIDE.md)
- [PowerShell Testing Framework](powershell/README.md)
- [E2E Testing Documentation](README.md)
- [Development Workflow](../docs/DEVELOPMENT_WORKFLOW.md)

---

**Note**: This testing infrastructure ensures Zoidbot maintains high quality and reliability through comprehensive automated validation at every level of the application stack.

# LLM Testing Guide for Zoidbot

This guide provides comprehensive documentation for testing patterns, utilities, and best practices for the LLM integration components in Zoidbot.

## Testing Architecture

### Test Categories

1. **Unit Tests** (`test/services/`)
   - Provider Discovery Service tests
   - LangChain Integration Service tests
   - Tunnel LLM Request Handler tests
   - Individual component isolation testing

2. **Integration Tests** (`test/integration/`)
   - End-to-end tunnel communication tests
   - Provider failover scenarios
   - Cross-service interaction testing

3. **End-to-End Tests** (`test/e2e/`)
   - Complete user workflow testing
   - Real provider integration testing
   - Performance and load testing

## Testing Patterns

### Mock Provider Pattern

Use consistent mock providers across tests:

```dart
// Standard mock Ollama provider
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
```

### HTTP Client Mocking Pattern

Use the MockHttpClient pattern for consistent HTTP mocking:

```dart
class MockHttpClient extends http.BaseClient {
  final Map<String, http.Response> _responses = {};
  final Map<String, Exception> _exceptions = {};

  void setResponse(String url, http.Response response) {
    _responses[url] = response;
  }

  void setException(String url, Exception exception) {
    _exceptions[url] = exception;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    
    if (_exceptions.containsKey(url)) {
      throw _exceptions[url]!;
    }
    
    if (_responses.containsKey(url)) {
      final response = _responses[url]!;
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
      );
    }
    
    throw const SocketException('Connection refused');
  }
}
```

### Error Scenario Testing Pattern

Test error scenarios systematically:

```dart
group('Error Scenarios', () {
  test('should handle connection failure', () async {
    mockHttpClient.setException(
      'http://localhost:11434/api/version',
      const SocketException('Connection refused'),
    );

    final result = await service.detectProvider();
    expect(result, isNull);
  });

  test('should handle malformed response', () async {
    mockHttpClient.setResponse(
      'http://localhost:11434/api/version',
      http.Response('Invalid JSON', 200),
    );

    final result = await service.detectProvider();
    expect(result, isNull);
  });

  test('should handle timeout', () async {
    // Configure timeout scenario
    mockHttpClient.setResponse(
      'http://localhost:11434/api/version',
      http.Response('{"version": "0.1.17"}', 200),
    );

    // Test with very short timeout
    final result = await service.detectProvider(timeout: Duration(milliseconds: 1));
    expect(result, isNull);
  });
});
```

### Failover Testing Pattern

Test provider failover scenarios:

```dart
test('should failover to secondary provider', () async {
  // Primary provider fails
  mockProviderManager.setProviderError(
    'primary_provider',
    Exception('Primary provider failed'),
  );

  // Secondary provider succeeds
  mockProviderManager.setProviderResponse(
    'secondary_provider',
    'Success response from backup',
  );

  final result = await service.processWithFailover(
    ['primary_provider', 'secondary_provider'],
    request,
  );

  expect(result.providerId, equals('secondary_provider'));
  expect(result.body, contains('Success response from backup'));
});
```

## Test Naming Conventions

### Test File Naming

- Unit tests: `{service_name}_test.dart`
- Integration tests: `{feature_name}_integration_test.dart`
- End-to-end tests: `{workflow_name}_e2e_test.dart`

### Test Group Naming

- Feature groups: `group('Feature Name', () { ... })`
- Scenario groups: `group('Error Scenarios', () { ... })`
- Method groups: `group('methodName()', () { ... })`

### Test Case Naming

Use descriptive names that explain the scenario:

- `'should detect healthy Ollama instance'`
- `'should handle connection failure gracefully'`
- `'should failover to secondary provider when primary fails'`
- `'should timeout after specified duration'`

## Mock Data Standards

### Standard Provider IDs

- Ollama: `'ollama_11434'`
- LM Studio: `'lmstudio_1234'`
- OpenAI Compatible: `'openai_8080'`

### Standard Model Names

- Ollama: `['llama2:latest', 'codellama:latest', 'mistral:latest']`
- LM Studio: `['Meta-Llama-3-8B-Instruct', 'CodeLlama-7B-Instruct']`
- OpenAI Compatible: `['gpt-3.5-turbo', 'gpt-4']`

### Standard Response Times

- Fast response: `100ms`
- Normal response: `500ms`
- Slow response: `2000ms`
- Timeout threshold: `5000ms`

## Testing Utilities

### Test Helper Functions

```dart
// Create standard test request
TunnelRequestMessage createChatRequest({
  String? id,
  String? providerId,
  String? model,
  String? message,
  bool streaming = false,
}) {
  return TunnelRequestMessage(
    id: id ?? 'test_request_${DateTime.now().millisecondsSinceEpoch}',
    method: 'POST',
    path: '/api/chat',
    headers: {
      'Content-Type': 'application/json',
      if (providerId != null) 'X-Provider-Preference': providerId,
    },
    body: jsonEncode({
      'model': model ?? 'llama2:latest',
      'messages': [
        {'role': 'user', 'content': message ?? 'Test message'}
      ],
      'stream': streaming,
    }),
  );
}

// Verify response structure
void verifySuccessResponse(TunnelLLMResponse response, {
  required String requestId,
  String? providerId,
}) {
  expect(response.requestId, equals(requestId));
  expect(response.status, equals(200));
  expect(response.error, isNull);
  if (providerId != null) {
    expect(response.providerId, equals(providerId));
  }
}

// Verify error response
void verifyErrorResponse(TunnelLLMResponse response, {
  required String requestId,
  required int expectedStatus,
  required String errorType,
}) {
  expect(response.requestId, equals(requestId));
  expect(response.status, equals(expectedStatus));
  expect(response.error, isNotNull);
  expect(response.error!.type.toString(), contains(errorType));
}
```

## Performance Testing Guidelines

### Load Testing

- Test with 10-50 concurrent requests
- Measure response times under load
- Verify no memory leaks during extended testing

### Timeout Testing

- Test various timeout scenarios (1s, 5s, 30s)
- Verify proper cleanup on timeout
- Test timeout handling in streaming scenarios

### Resource Management Testing

- Verify proper disposal of resources
- Test connection pool management
- Monitor memory usage during tests

## Continuous Integration

### Test Execution Order

1. Unit tests (fastest)
2. Integration tests
3. End-to-end tests (slowest)

### Test Categories for CI

- **Smoke Tests**: Basic functionality verification
- **Regression Tests**: Prevent breaking changes
- **Performance Tests**: Ensure acceptable performance
- **Security Tests**: Validate security measures

### Test Environment Setup

```yaml
# Example CI configuration
test:
  stage: test
  script:
    - flutter test test/unit/
    - flutter test test/services/
    - flutter test test/integration/
    - flutter test test/e2e/ --timeout=300s
  coverage: '/lines......: \d+\.\d+%/'
```

## Debugging Test Failures

### Common Issues

1. **Async timing issues**: Use `await` properly, consider `pumpAndSettle()`
2. **Mock setup**: Verify mocks are configured before test execution
3. **Resource cleanup**: Ensure proper disposal in `tearDown()`
4. **State isolation**: Reset state between tests

### Debugging Tools

- Use `debugPrint()` for test debugging
- Enable verbose logging: `flutter test --verbose`
- Use `flutter test --coverage` for coverage analysis
- Profile tests: `flutter test --profile`

## Best Practices

1. **Test Independence**: Each test should be independent and not rely on other tests
2. **Clear Assertions**: Use descriptive assertion messages
3. **Mock Isolation**: Use mocks to isolate units under test
4. **Error Testing**: Test both success and failure scenarios
5. **Performance Awareness**: Keep tests fast and efficient
6. **Documentation**: Document complex test scenarios
7. **Maintenance**: Regularly update tests as code evolves

## Test Coverage Goals

- **Unit Tests**: >90% line coverage
- **Integration Tests**: >80% feature coverage
- **End-to-End Tests**: >70% user workflow coverage

## Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/provider_discovery_service_test.dart

# Run with coverage
flutter test --coverage

# Run integration tests only
flutter test test/integration/

# Run with specific timeout
flutter test --timeout=60s
```
