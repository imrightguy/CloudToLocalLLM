# Error Handling & Diagnostics Quick Reference

## Quick Start

### 1. Categorize an Error

```dart
import 'package:cloudtolocalllm/services/tunnel/error_handling.dart';

try {
  // Your operation
} catch (e, stackTrace) {
  final error = ErrorCategorizationService.categorizeException(
    e as Exception,
    stackTrace: stackTrace,
    context: {'operation': 'connect'},
  );
  
  // Use the error
  print(error.userMessage);      // User-friendly message
  print(error.suggestion);        // Actionable suggestion
  print(error.isRetryable);       // Can we retry?
  print(error.documentationUrl);  // Help link
}
```

### 2. Run Diagnostics

```dart
import 'package:cloudtolocalllm/services/tunnel/error_handling.dart';

final testSuite = DiagnosticTestSuite(
  serverHost: 'api.cloudtolocalllm.online',
  serverPort: 443,
  authToken: userToken,
);

// Run all tests
final tests = await testSuite.runAllTests();

// Generate report
final report = DiagnosticReportGenerator.generateReport(tests);

// Get health score
final score = DiagnosticReportGenerator.calculateHealthScore(report);
final status = DiagnosticReportGenerator.getHealthStatus(score);

print('Health: $score/100 ($status)');
```

### 3. Attempt Error Recovery

```dart
import 'package:cloudtolocalllm/services/tunnel/error_handling.dart';

final strategy = ErrorRecoveryStrategy(
  reconnectionManager: reconnectionManager,
  testConnection: () async => await checkConnection(),
  reconnect: () async => await performReconnect(),
  flushQueuedRequests: () async => await flushQueue(),
  refreshAuthToken: () async => await refreshToken(), // Optional
);

final result = await strategy.attemptRecovery(tunnelError);

if (result.success) {
  print('Recovered in ${result.duration}');
} else {
  print('Failed: ${result.message}');
}
```

## Error Categories

| Category | Description | Examples |
|----------|-------------|----------|
| `network` | Connection issues | Connection refused, DNS failure, timeout |
| `authentication` | Auth problems | Invalid credentials, expired token |
| `configuration` | Config errors | Invalid settings, format errors |
| `server` | Server issues | Unavailable, rate limit, queue full |
| `protocol` | Protocol errors | SSH error, WebSocket error, compression |
| `unknown` | Unrecognized | Unexpected errors |

## Error Codes

### Network Errors

- `TUNNEL_001` - Connection refused
- `TUNNEL_007` - Request timeout
- `TUNNEL_011` - DNS resolution failed
- `TUNNEL_012` - Network unreachable

### Authentication Errors

- `TUNNEL_002` - Authentication failed
- `TUNNEL_003` - Token expired
- `TUNNEL_013` - Invalid credentials

### Server Errors

- `TUNNEL_004` - Server unavailable
- `TUNNEL_005` - Rate limit exceeded
- `TUNNEL_006` - Queue full

### Protocol Errors

- `TUNNEL_008` - SSH error
- `TUNNEL_009` - WebSocket error
- `TUNNEL_015` - Compression error
- `TUNNEL_016` - Protocol version mismatch
- `TUNNEL_017` - Host key verification failed
- `TUNNEL_018` - Channel limit exceeded

### Configuration Errors

- `TUNNEL_010` - Configuration error

### Unknown Errors

- `TUNNEL_999` - Unknown error

## Diagnostic Tests

| Test | Description | Pass Criteria |
|------|-------------|---------------|
| DNS Resolution | Resolve hostname | Addresses found |
| WebSocket Connectivity | Connect to server | Connection established |
| SSH Authentication | Validate token | Token valid |
| Tunnel Establishment | Establish tunnel | Bidirectional communication |
| Data Transfer | Transfer 1KB | Data sent and received |
| Latency | 10 ping-pongs | Average < 200ms |
| Throughput | Transfer 640KB | Rate > 100 KB/s |

## Health Score

| Score | Status | Color | Meaning |
|-------|--------|-------|---------|
| 90-100 | Excellent | Green | All systems optimal |
| 75-89 | Good | Light Green | Minor issues, fully functional |
| 50-74 | Fair | Amber | Some degradation, usable |
| 25-49 | Poor | Orange | Significant issues |
| 0-24 | Critical | Red | Severe problems |

## Recovery Strategies

| Error Type | Strategy | Details |
|------------|----------|---------|
| Network | Exponential backoff | Retry with increasing delays |
| Token expired | Token refresh | Automatic token refresh |
| Rate limit | Wait | Wait 60s before retry |
| Server unavailable | Retry | Max 5 attempts with backoff |
| Queue full | Wait | Wait 5s for queue to drain |
| Protocol | Reconnect | Simple reconnection |
| Configuration | Manual | Requires user intervention |

## Common Patterns

### Pattern 1: Try-Catch with Recovery

```dart
try {
  await operation();
} catch (e, stackTrace) {
  final error = ErrorCategorizationService.categorizeException(
    e as Exception,
    stackTrace: stackTrace,
  );
  
  if (ErrorRecoveryStrategy.isRecoverable(error)) {
    final result = await strategy.attemptRecovery(error);
    if (!result.success) {
      // Show error to user
      showError(error);
    }
  } else {
    // User intervention required
    showError(error);
  }
}
```

### Pattern 2: Diagnostics on Failure

```dart
try {
  await connect();
} catch (e) {
  // Run diagnostics to identify issue
  final testSuite = DiagnosticTestSuite(
    serverHost: serverHost,
    serverPort: serverPort,
    authToken: authToken,
  );
  
  final tests = await testSuite.runAllTests();
  final report = DiagnosticReportGenerator.generateReport(tests);
  
  // Show report to user
  showDiagnosticReport(report);
}
```

### Pattern 3: HTTP Error Handling

```dart
final response = await http.get(url);

if (response.statusCode != 200) {
  final error = ErrorCategorizationService.fromHttpStatus(
    response.statusCode,
    message: response.body,
  );
  
  throw error;
}
```

## Output Formats

### Text Format

```dart
final text = DiagnosticReportGenerator.formatReportAsText(report);
print(text);
```

### JSON Format

```dart
final json = DiagnosticReportGenerator.formatReportAsJson(report);
// Use for APIs or storage
```

### Markdown Format

```dart
final markdown = DiagnosticReportGenerator.formatReportAsMarkdown(report);
// Use for documentation or reports
```

## Best Practices

### ✅ DO

- Always provide context when categorizing errors
- Run diagnostics when connection issues persist
- Use recovery strategies for retryable errors
- Log error details for debugging
- Show user-friendly messages to users
- Include suggestions with error messages

### ❌ DON'T

- Don't log authentication tokens in error context
- Don't expose internal system details in error messages
- Don't retry non-retryable errors
- Don't block UI during recovery attempts
- Don't ignore error categories
- Don't skip diagnostic tests on critical failures

## Integration with UI

### Error Display Widget

```dart
class ErrorWidget extends StatelessWidget {
  final TunnelError error;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Icon(Icons.error, color: Colors.red),
          Text(error.userMessage),
          if (error.suggestion != null)
            Text(error.suggestion!),
          if (ErrorRecoveryStrategy.isRecoverable(error))
            ElevatedButton(
              onPressed: () => attemptRecovery(error),
              child: Text('Retry'),
            ),
        ],
      ),
    );
  }
}
```

### Diagnostic Report Widget

```dart
class DiagnosticWidget extends StatelessWidget {
  final DiagnosticReport report;
  
  @override
  Widget build(BuildContext context) {
    final score = DiagnosticReportGenerator.calculateHealthScore(report);
    final status = DiagnosticReportGenerator.getHealthStatus(score);
    
    return Column(
      children: [
        CircularProgressIndicator(value: score / 100),
        Text('$score/100 - $status'),
        ...report.tests.map((test) => TestTile(test: test)),
        ...report.summary.recommendations.map((rec) => Text(rec)),
      ],
    );
  }
}
```

## Performance Tips

1. **Error Categorization**: < 1ms, no optimization needed
2. **Diagnostic Tests**: Run in background, show progress
3. **Recovery**: Use timeouts to prevent hanging
4. **Report Generation**: Cache results for repeated access

## Troubleshooting

### Issue: Diagnostics timeout

**Solution:** Increase `testTimeout` parameter

### Issue: Recovery fails repeatedly

**Solution:** Check if error is actually recoverable

### Issue: Health score always low

**Solution:** Review failed tests and fix underlying issues

### Issue: No recommendations generated

**Solution:** Ensure tests are actually running and failing

## Additional Resources

- Full documentation: `ERROR_HANDLING_IMPLEMENTATION.md`
- Usage examples: `examples/error_handling_example.dart`
- Task summary: `TASK_5_SUMMARY.md`
- Error codes: `https://docs.cloudtolocalllm.com/errors/{code}`
