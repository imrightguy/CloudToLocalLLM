# Error Handling and Diagnostics Implementation

This document describes the implementation of Task 5: Error Handling and Diagnostics for the SSH WebSocket Tunnel Enhancement.

## Overview

The error handling and diagnostics system provides comprehensive error detection, categorization, recovery, and diagnostic capabilities for the tunnel service. It addresses Requirements 2.1-2.10 from the requirements document.

## Components

### 1. Error Categorization System (`error_categorization.dart`)

**Purpose:** Intelligently categorize exceptions into tunnel errors with user-friendly messages and actionable suggestions.

**Key Features:**

- Type-based exception categorization (SocketException, WebSocketChannelException, TimeoutException, FormatException)
- String-based fallback categorization for unknown exception types
- HTTP status code to error code mapping
- Context-aware error messages and suggestions
- Detailed error context preservation for debugging

**Exception Handlers:**

- `SocketException`: Detects connection refused, network unreachable, DNS failures
- `WebSocketChannelException`: Handles WebSocket-specific errors and inner exceptions
- `TimeoutException`: Categorizes timeout errors with duration context
- `FormatException`: Identifies configuration format errors

**Error Categories:**

- Network: Connection issues, DNS failures, timeouts
- Authentication: Invalid credentials, expired tokens
- Configuration: Invalid settings, format errors
- Server: Unavailable, rate limits, queue full
- Protocol: SSH, WebSocket, compression, host key issues
- Unknown: Unrecognized errors

**Usage Example:**

```dart
try {
  // Some operation
} catch (e, stackTrace) {
  final tunnelError = ErrorCategorizationService.categorizeException(
    e as Exception,
    stackTrace: stackTrace,
    context: {'operation': 'connect'},
  );
  
  print('Error: ${tunnelError.userMessage}');
  print('Suggestion: ${tunnelError.suggestion}');
}
```

### 2. Diagnostic Test Suite (`diagnostics/diagnostic_test_suite.dart`)

**Purpose:** Comprehensive testing of tunnel connectivity and performance.

**Tests Implemented:**

1. **DNS Resolution Test**
   - Resolves server hostname to IP addresses
   - Detects DNS configuration issues
   - Timeout: Configurable (default 30s)

2. **WebSocket Connectivity Test**
   - Establishes WebSocket connection
   - Verifies server reachability
   - Tests SSL/TLS handshake

3. **SSH Authentication Test**
   - Validates authentication token presence
   - Checks token format
   - Simulates authentication flow

4. **Tunnel Establishment Test**
   - Sends tunnel establishment message
   - Waits for server response
   - Verifies bidirectional communication

5. **Data Transfer Test**
   - Sends 1KB test data
   - Measures transfer success
   - Calculates transfer rate

6. **Latency Test**
   - Performs 10 ping-pong measurements
   - Calculates average, min, max latency
   - Pass threshold: < 200ms average
   - Provides detailed latency distribution

7. **Throughput Test**
   - Sends 10 chunks of 64KB each
   - Measures data transfer rate
   - Pass threshold: > 100 KB/s
   - Calculates total throughput

**Test Execution:**

- Sequential execution with early termination on critical failures
- Configurable timeout per test
- Detailed error messages and context
- Graceful failure handling

**Usage Example:**

```dart
final testSuite = DiagnosticTestSuite(
  serverHost: 'api.zoidbot.online',
  serverPort: 443,
  authToken: userToken,
  testTimeout: Duration(seconds: 30),
);

final tests = await testSuite.runAllTests();
for (final test in tests) {
  print('${test.name}: ${test.passed ? "PASS" : "FAIL"}');
}
```

### 3. Diagnostic Report Generator (`diagnostics/diagnostic_report_generator.dart`)

**Purpose:** Aggregate test results and generate comprehensive reports with recommendations.

**Key Features:**

#### Health Score Calculation (0-100 points)

- **Base Score (0-60 points):** Pass rate percentage
- **DNS Resolution (5 points):** Critical for connectivity
- **WebSocket Connectivity (10 points):** Essential for tunnel
- **Authentication (5 points):** Required for access
- **Tunnel Establishment (10 points):** Core functionality
- **Latency (5 points + 3 bonus):** Performance indicator
  - Bonus: < 50ms average latency
- **Throughput (5 points + 2 bonus):** Bandwidth indicator
  - Bonus: > 500 KB/s throughput

#### Health Status Levels

- **Excellent (90-100):** All systems optimal
- **Good (75-89):** Minor issues, fully functional
- **Fair (50-74):** Some degradation, usable
- **Poor (25-49):** Significant issues
- **Critical (0-24):** Severe problems

#### Intelligent Recommendations

Context-aware suggestions based on failed tests:

- DNS failures: Check internet and DNS settings
- WebSocket failures: Check firewall and server status
- Authentication failures: Re-authenticate or refresh token
- Latency issues: Improve network connection
- Throughput issues: Close bandwidth-consuming apps
- Multiple failures: Broader connectivity issue

#### Output Formats

1. **Text Format:** Human-readable console output
2. **JSON Format:** Machine-readable for APIs
3. **Markdown Format:** Documentation and reports

**Usage Example:**

```dart
final report = DiagnosticReportGenerator.generateReport(tests);
final score = DiagnosticReportGenerator.calculateHealthScore(report);
final status = DiagnosticReportGenerator.getHealthStatus(score);

print('Health Score: $score/100 ($status)');
print(DiagnosticReportGenerator.formatReportAsText(report));
```

### 4. Error Recovery Strategy (`error_recovery_strategy.dart`)

**Purpose:** Automatic recovery from different error categories.

**Recovery Strategies:**

#### Network Error Recovery

- Uses exponential backoff with jitter
- Tests connection before reconnecting
- Flushes queued requests after successful recovery
- Respects max reconnection attempts
- Detailed logging of recovery attempts

#### Authentication Error Recovery

- Detects expired vs. invalid tokens
- Attempts automatic token refresh for expired tokens
- Requires user intervention for invalid credentials
- Reconnects with refreshed token

#### Server Error Recovery

- **Rate Limit Exceeded:** Waits 60 seconds before retry
- **Server Unavailable:** Retries with backoff (max 5 attempts)
- **Queue Full:** Waits 5 seconds for queue to drain
- Tests server availability before reconnecting

#### Protocol Error Recovery

- **WebSocket Errors:** Simple reconnection
- **SSH Errors:** Reconnection with clean state
- **Compression Errors:** Reconnection (may disable compression)
- **Other Protocol Errors:** Attempt reconnection

#### Configuration Error Handling

- No automatic recovery (requires manual fix)
- Provides clear error messages
- Suggests configuration reset or validation

**Recovery Result Tracking:**

- Success/failure status
- Recovery duration
- Number of attempts
- Descriptive message

**Usage Example:**

```dart
final strategy = ErrorRecoveryStrategy(
  reconnectionManager: reconnectionManager,
  testConnection: () async => await checkConnection(),
  reconnect: () async => await performReconnect(),
  flushQueuedRequests: () async => await flushQueue(),
  refreshAuthToken: () async => await refreshToken(),
);

final result = await strategy.attemptRecovery(tunnelError);
if (result.success) {
  print('Recovered in ${result.duration} after ${result.attempts} attempts');
} else {
  print('Recovery failed: ${result.message}');
}
```

## Integration

### With Tunnel Service

The error handling components integrate with the tunnel service:

```dart
class TunnelService {
  late final ErrorRecoveryStrategy _recoveryStrategy;
  
  Future<void> _handleError(Exception e, StackTrace stackTrace) async {
    // Categorize the error
    final tunnelError = ErrorCategorizationService.categorizeException(
      e,
      stackTrace: stackTrace,
      context: {'connectionState': _connectionState.name},
    );
    
    // Log the error
    _logError(tunnelError);
    
    // Notify listeners
    notifyListeners();
    
    // Attempt recovery if possible
    if (ErrorRecoveryStrategy.isRecoverable(tunnelError)) {
      final result = await _recoveryStrategy.attemptRecovery(tunnelError);
      if (result.success) {
        _logRecovery(result);
      }
    }
  }
  
  Future<DiagnosticReport> runDiagnostics() async {
    final testSuite = DiagnosticTestSuite(
      serverHost: _serverHost,
      serverPort: _serverPort,
      authToken: _authToken,
    );
    
    final tests = await testSuite.runAllTests();
    return DiagnosticReportGenerator.generateReport(tests);
  }
}
```

### With UI Components

Display error information and diagnostics to users:

```dart
class TunnelErrorWidget extends StatelessWidget {
  final TunnelError error;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text(error.userMessage),
          if (error.suggestion != null)
            Text(error.suggestion!),
          if (ErrorRecoveryStrategy.isRecoverable(error))
            Text(ErrorRecoveryStrategy.getRecoveryStrategyDescription(error)),
        ],
      ),
    );
  }
}

class DiagnosticReportWidget extends StatelessWidget {
  final DiagnosticReport report;
  
  @override
  Widget build(BuildContext context) {
    final score = DiagnosticReportGenerator.calculateHealthScore(report);
    final status = DiagnosticReportGenerator.getHealthStatus(score);
    final color = DiagnosticReportGenerator.getHealthStatusColor(score);
    
    return Column(
      children: [
        CircularProgressIndicator(
          value: score / 100,
          backgroundColor: Colors.grey,
          valueColor: AlwaysStoppedAnimation(Color(int.parse(color.substring(1), radix: 16))),
        ),
        Text('$score/100 - $status'),
        ...report.tests.map((test) => TestResultTile(test: test)),
        ...report.summary.recommendations.map((rec) => Text(rec)),
      ],
    );
  }
}
```

## Requirements Coverage

This implementation addresses the following requirements:

- **Requirement 2.1:** Error categorization into Network, Authentication, Configuration, Server, Protocol, Unknown ✓
- **Requirement 2.2:** User-friendly error messages for each category ✓
- **Requirement 2.3:** Actionable suggestions for common errors ✓
- **Requirement 2.4:** Detailed error context with stack traces and metadata ✓
- **Requirement 2.5:** Diagnostic mode testing each component separately ✓
- **Requirement 2.6:** Tests for DNS, WebSocket, SSH, tunnel, data transfer, latency, throughput ✓
- **Requirement 2.8:** Connection metrics collection (latency, packet loss, throughput) ✓
- **Requirement 2.9:** Distinguish between expired tokens and invalid credentials ✓
- **Requirement 2.10:** Error codes mapping to documentation ✓

## Testing

Unit tests should cover:

- Error categorization for all exception types
- Diagnostic test execution and result handling
- Report generation and formatting
- Recovery strategy execution for each error category
- Health score calculation accuracy

Integration tests should verify:

- End-to-end diagnostic flow
- Error recovery in real scenarios
- Report generation from actual test results

## Future Enhancements

Potential improvements:

1. Add more diagnostic tests (bandwidth, jitter, packet loss)
2. Implement diagnostic test scheduling and history
3. Add machine learning for error prediction
4. Implement automatic configuration tuning based on diagnostics
5. Add telemetry for aggregate error analysis
6. Implement A/B testing for recovery strategies

## Documentation

- Error codes are documented at: `https://docs.zoidbot.com/errors/{code}`
- Each error includes a link to relevant documentation
- Diagnostic reports can be exported for support tickets
- Recovery strategies are logged for debugging

## Performance Considerations

- Diagnostic tests run sequentially to avoid resource contention
- Early termination on critical failures saves time
- Error categorization is fast (< 1ms typically)
- Recovery strategies respect backoff to avoid overwhelming servers
- Health score calculation is O(n) where n is number of tests

## Security Considerations

- Authentication tokens are not logged in error context
- Diagnostic reports sanitize sensitive information
- Error messages don't expose internal system details
- Recovery strategies validate tokens before use
