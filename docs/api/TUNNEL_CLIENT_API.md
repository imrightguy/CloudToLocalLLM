# Tunnel Client API Documentation

## Overview

The Tunnel Client API provides a Dart interface for establishing and managing secure SSH-over-WebSocket tunnels from Flutter applications. This document describes all public classes, methods, and configuration options.

## TunnelService

The main service for managing tunnel connections. Extends `ChangeNotifier` for reactive state management.

### Class Definition

```dart
class TunnelService extends ChangeNotifier {
  // Connection Management
  Future<void> connect({
    required String serverUrl,
    required String authToken,
    TunnelConfig? config,
  });
  
  Future<void> disconnect({bool graceful = true});
  
  Future<void> reconnect();
  
  // Request Operations
  Future<TunnelResponse> forwardRequest(TunnelRequest request);
  
  // State Management
  TunnelConnectionState get connectionState;
  TunnelHealthMetrics get healthMetrics;
  
  // Configuration
  void updateConfig(TunnelConfig config);
  TunnelConfig get currentConfig;
  
  // Diagnostics
  Future<DiagnosticReport> runDiagnostics();
}
```

### Methods

#### connect()

Establishes a tunnel connection to the streaming proxy server.

**Signature:**
```dart
Future<void> connect({
  required String serverUrl,
  required String authToken,
  TunnelConfig? config,
})
```

**Parameters:**
- `serverUrl` (String, required): WebSocket URL of the streaming proxy (e.g., `wss://proxy.example.com`)
- `authToken` (String, required): JWT authentication token from Auth0
- `config` (TunnelConfig, optional): Custom configuration; uses default if not provided

**Returns:** Future that completes when connection is established

**Throws:**
- `TunnelError` with category `network` if connection fails
- `TunnelError` with category `authentication` if token is invalid
- `TunnelError` with category `configuration` if config is invalid

**Example:**
```dart
final tunnelService = TunnelService();

try {
  await tunnelService.connect(
    serverUrl: 'wss://proxy.cloudtolocalllm.online',
    authToken: authToken,
    config: TunnelConfig.stableNetwork(),
  );
  print('Connected to tunnel');
} on TunnelError catch (e) {
  print('Connection failed: ${e.userMessage}');
}
```

#### disconnect()

Closes the tunnel connection gracefully.

**Signature:**
```dart
Future<void> disconnect({bool graceful = true})
```

**Parameters:**
- `graceful` (bool, optional): If true, waits for pending requests to complete (timeout: 10 seconds)

**Returns:** Future that completes when disconnection is complete

**Example:**
```dart
await tunnelService.disconnect(graceful: true);
print('Disconnected from tunnel');
```

#### reconnect()

Manually triggers a reconnection attempt.

**Signature:**
```dart
Future<void> reconnect()
```

**Returns:** Future that completes when reconnection is attempted

**Example:**
```dart
await tunnelService.reconnect();
```

#### forwardRequest()

Sends a request through the tunnel to the local SSH server.

**Signature:**
```dart
Future<TunnelResponse> forwardRequest(TunnelRequest request)
```

**Parameters:**
- `request` (TunnelRequest, required): The request to forward

**Returns:** Future that completes with the response

**Throws:**
- `TunnelError` with category `network` if connection is lost
- `TunnelError` with category `server` if server returns error
- `TunnelError` with category `protocol` if protocol error occurs

**Example:**
```dart
final request = TunnelRequest(
  id: 'req-123',
  userId: 'user-456',
  priority: RequestPriority.high,
  timeout: Duration(seconds: 30),
  headers: {'Content-Type': 'application/json'},
  payload: utf8.encode('{"command": "ls"}'),
);

try {
  final response = await tunnelService.forwardRequest(request);
  print('Response: ${utf8.decode(response.payload)}');
} on TunnelError catch (e) {
  print('Request failed: ${e.userMessage}');
}
```

#### updateConfig()

Updates tunnel configuration dynamically.

**Signature:**
```dart
void updateConfig(TunnelConfig config)
```

**Parameters:**
- `config` (TunnelConfig, required): New configuration

**Example:**
```dart
tunnelService.updateConfig(TunnelConfig.unstableNetwork());
```

#### runDiagnostics()

Executes a comprehensive diagnostic test suite.

**Signature:**
```dart
Future<DiagnosticReport> runDiagnostics()
```

**Returns:** Future that completes with diagnostic report

**Example:**
```dart
final report = await tunnelService.runDiagnostics();
if (report.allTestsPassed) {
  print('All diagnostics passed');
} else {
  for (final test in report.tests.where((t) => !t.passed)) {
    print('Failed: ${test.name} - ${test.errorMessage}');
  }
}
```

### Properties

#### connectionState

Current connection state.

**Type:** `TunnelConnectionState` (enum)

**Values:**
- `disconnected`: Not connected
- `connecting`: Connection in progress
- `connected`: Connected and ready
- `reconnecting`: Attempting to reconnect
- `error`: Connection error

**Example:**
```dart
if (tunnelService.connectionState == TunnelConnectionState.connected) {
  print('Tunnel is ready');
}
```

#### healthMetrics

Current health metrics for the connection.

**Type:** `TunnelHealthMetrics`

**Properties:**
- `uptime` (Duration): Time connected
- `reconnectCount` (int): Number of reconnections
- `averageLatency` (double): Average request latency in ms
- `packetLoss` (double): Estimated packet loss percentage
- `quality` (ConnectionQuality): Overall connection quality
- `queuedRequests` (int): Number of queued requests
- `successfulRequests` (int): Number of successful requests
- `failedRequests` (int): Number of failed requests

**Example:**
```dart
final metrics = tunnelService.healthMetrics;
print('Uptime: ${metrics.uptime}');
print('Quality: ${metrics.quality}');
print('Latency: ${metrics.averageLatency}ms');
```

#### currentConfig

Current tunnel configuration.

**Type:** `TunnelConfig`

**Example:**
```dart
final config = tunnelService.currentConfig;
print('Max reconnect attempts: ${config.maxReconnectAttempts}');
```

## TunnelConfig

Configuration class for tunnel behavior.

### Class Definition

```dart
class TunnelConfig {
  final int maxReconnectAttempts;
  final Duration reconnectBaseDelay;
  final Duration requestTimeout;
  final int maxQueueSize;
  final bool enableCompression;
  final bool enableAutoReconnect;
  final LogLevel logLevel;
  
  // Predefined profiles
  static TunnelConfig stableNetwork();
  static TunnelConfig unstableNetwork();
  static TunnelConfig lowBandwidth();
}

enum LogLevel {
  error,
  warning,
  info,
  debug,
  trace,
}
```

### Predefined Profiles

#### stableNetwork()

Optimized for stable, high-speed networks.

**Configuration:**
- Max reconnect attempts: 5
- Reconnect base delay: 2 seconds
- Request timeout: 30 seconds
- Max queue size: 100
- Compression: enabled
- Auto-reconnect: enabled

**Use Case:** Office networks, wired connections

#### unstableNetwork()

Optimized for unstable, low-speed networks.

**Configuration:**
- Max reconnect attempts: 10
- Reconnect base delay: 5 seconds
- Request timeout: 60 seconds
- Max queue size: 200
- Compression: enabled
- Auto-reconnect: enabled

**Use Case:** Mobile networks, WiFi, satellite

#### lowBandwidth()

Optimized for low-bandwidth connections.

**Configuration:**
- Max reconnect attempts: 10
- Reconnect base delay: 5 seconds
- Request timeout: 60 seconds
- Max queue size: 50
- Compression: enabled (aggressive)
- Auto-reconnect: enabled

**Use Case:** Metered connections, satellite, rural areas

### Custom Configuration

```dart
final customConfig = TunnelConfig(
  maxReconnectAttempts: 8,
  reconnectBaseDelay: Duration(seconds: 3),
  requestTimeout: Duration(seconds: 45),
  maxQueueSize: 150,
  enableCompression: true,
  enableAutoReconnect: true,
  logLevel: LogLevel.debug,
);

await tunnelService.connect(
  serverUrl: 'wss://proxy.example.com',
  authToken: authToken,
  config: customConfig,
);
```

## TunnelRequest

Represents a request to be forwarded through the tunnel.

### Class Definition

```dart
class TunnelRequest {
  final String id;
  final String userId;
  final RequestPriority priority;
  final DateTime createdAt;
  final Duration timeout;
  final Map<String, String> headers;
  final Uint8List payload;
  final int retryCount;
  final String? correlationId;
  final Map<String, dynamic>? metadata;
}

enum RequestPriority {
  high,    // Interactive user requests
  normal,  // Batch operations
  low,     // Background tasks
}
```

### Creating Requests

```dart
final request = TunnelRequest(
  id: 'req-${DateTime.now().millisecondsSinceEpoch}',
  userId: currentUser.id,
  priority: RequestPriority.high,
  createdAt: DateTime.now(),
  timeout: Duration(seconds: 30),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  },
  payload: utf8.encode(jsonEncode({'command': 'ls -la'})),
  retryCount: 0,
  correlationId: 'corr-${DateTime.now().millisecondsSinceEpoch}',
);
```

## TunnelResponse

Represents a response from the tunnel.

### Class Definition

```dart
class TunnelResponse {
  final String requestId;
  final int statusCode;
  final Map<String, String> headers;
  final Uint8List payload;
  final Duration latency;
  final DateTime receivedAt;
}
```

### Accessing Response Data

```dart
final response = await tunnelService.forwardRequest(request);

print('Status: ${response.statusCode}');
print('Latency: ${response.latency.inMilliseconds}ms');
print('Body: ${utf8.decode(response.payload)}');

// Parse JSON response
final jsonData = jsonDecode(utf8.decode(response.payload));
```

## Error Handling

### TunnelError

Represents errors that occur during tunnel operations.

### Class Definition

```dart
class TunnelError {
  final String id;
  final TunnelErrorCategory category;
  final String code;
  final String message;
  final String userMessage;
  final String? suggestion;
  final DateTime timestamp;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? context;
  
  bool get isRetryable;
  bool get isUserActionable;
  String get documentationUrl;
}

enum TunnelErrorCategory {
  network,        // DNS, connection refused, timeout
  authentication, // Invalid token, expired token
  configuration,  // Invalid settings, missing config
  server,         // Server error, unavailable
  protocol,       // SSH error, WebSocket error
  unknown,        // Unexpected errors
}
```

### Error Codes

| Code | Category | Description | Recovery |
|------|----------|-------------|----------|
| TUNNEL_001 | network | Connection refused | Check network, firewall, server availability |
| TUNNEL_002 | authentication | Authentication failed | Verify JWT token, check Auth0 configuration |
| TUNNEL_003 | authentication | Token expired | Re-authenticate or refresh token |
| TUNNEL_004 | server | Server unavailable | Wait and retry, check server status |
| TUNNEL_005 | server | Rate limit exceeded | Reduce request rate, wait for reset |
| TUNNEL_006 | server | Queue full | Reduce request rate, increase queue size |
| TUNNEL_007 | protocol | Request timeout | Increase timeout, check server load |
| TUNNEL_008 | protocol | SSH error | Check SSH server, verify credentials |
| TUNNEL_009 | protocol | WebSocket error | Check WebSocket support, try alternative method |
| TUNNEL_010 | configuration | Configuration error | Validate settings, reset to defaults |

### Error Handling Examples

```dart
// Basic error handling
try {
  await tunnelService.connect(
    serverUrl: 'wss://proxy.example.com',
    authToken: authToken,
  );
} on TunnelError catch (e) {
  print('Error: ${e.userMessage}');
  if (e.suggestion != null) {
    print('Suggestion: ${e.suggestion}');
  }
}

// Category-specific handling
try {
  final response = await tunnelService.forwardRequest(request);
} on TunnelError catch (e) {
  switch (e.category) {
    case TunnelErrorCategory.network:
      print('Network issue: ${e.message}');
      // Implement retry logic
      break;
    case TunnelErrorCategory.authentication:
      print('Auth issue: ${e.message}');
      // Redirect to login
      break;
    case TunnelErrorCategory.server:
      print('Server issue: ${e.message}');
      // Show user-friendly message
      break;
    default:
      print('Unknown error: ${e.message}');
  }
}

// Retryable errors
try {
  final response = await tunnelService.forwardRequest(request);
} on TunnelError catch (e) {
  if (e.isRetryable) {
    // Implement exponential backoff retry
    await Future.delayed(Duration(seconds: 2));
    final response = await tunnelService.forwardRequest(request);
  }
}
```

## Diagnostics

### DiagnosticReport

Comprehensive diagnostic test results.

### Class Definition

```dart
class DiagnosticReport {
  final DateTime timestamp;
  final List<DiagnosticTest> tests;
  final DiagnosticSummary summary;
  
  bool get allTestsPassed => tests.every((t) => t.passed);
}

class DiagnosticTest {
  final String name;
  final String description;
  final bool passed;
  final Duration duration;
  final String? errorMessage;
  final Map<String, dynamic>? details;
}

class DiagnosticSummary {
  final int totalTests;
  final int passedTests;
  final int failedTests;
  final Duration totalDuration;
  final List<String> recommendations;
}
```

### Running Diagnostics

```dart
final report = await tunnelService.runDiagnostics();

print('Diagnostic Report');
print('================');
print('Timestamp: ${report.timestamp}');
print('Total Tests: ${report.summary.totalTests}');
print('Passed: ${report.summary.passedTests}');
print('Failed: ${report.summary.failedTests}');
print('Duration: ${report.summary.totalDuration.inSeconds}s');
print('');

for (final test in report.tests) {
  final status = test.passed ? '✓' : '✗';
  print('$status ${test.name} (${test.duration.inMilliseconds}ms)');
  if (!test.passed && test.errorMessage != null) {
    print('  Error: ${test.errorMessage}');
  }
}

if (report.summary.recommendations.isNotEmpty) {
  print('');
  print('Recommendations:');
  for (final rec in report.summary.recommendations) {
    print('- $rec');
  }
}
```

## State Management with Provider

### Using TunnelService with Provider

```dart
// In main.dart
ChangeNotifierProvider(
  create: (_) => TunnelService(),
  child: MyApp(),
)

// In widgets
class TunnelStatusWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tunnelService = context.watch<TunnelService>();
    
    return Column(
      children: [
        Text('Status: ${tunnelService.connectionState}'),
        Text('Latency: ${tunnelService.healthMetrics.averageLatency}ms'),
        Text('Quality: ${tunnelService.healthMetrics.quality}'),
      ],
    );
  }
}
```

## Common Use Cases

### Establishing a Tunnel Connection

```dart
final tunnelService = TunnelService();

try {
  await tunnelService.connect(
    serverUrl: 'wss://proxy.cloudtolocalllm.online',
    authToken: jwtToken,
    config: TunnelConfig.stableNetwork(),
  );
  print('Tunnel connected');
} on TunnelError catch (e) {
  print('Connection failed: ${e.userMessage}');
}
```

### Sending Requests Through Tunnel

```dart
final request = TunnelRequest(
  id: 'req-${DateTime.now().millisecondsSinceEpoch}',
  userId: userId,
  priority: RequestPriority.high,
  timeout: Duration(seconds: 30),
  headers: {'Content-Type': 'application/json'},
  payload: utf8.encode(jsonEncode({'query': 'SELECT * FROM users'})),
);

try {
  final response = await tunnelService.forwardRequest(request);
  final result = jsonDecode(utf8.decode(response.payload));
  print('Result: $result');
} on TunnelError catch (e) {
  print('Request failed: ${e.userMessage}');
}
```

### Handling Connection Loss

```dart
tunnelService.addListener(() {
  if (tunnelService.connectionState == TunnelConnectionState.reconnecting) {
    print('Connection lost, reconnecting...');
  } else if (tunnelService.connectionState == TunnelConnectionState.connected) {
    print('Connection restored');
  }
});
```

### Monitoring Connection Quality

```dart
tunnelService.addListener(() {
  final metrics = tunnelService.healthMetrics;
  
  switch (metrics.quality) {
    case ConnectionQuality.excellent:
      print('Connection quality: Excellent');
      break;
    case ConnectionQuality.good:
      print('Connection quality: Good');
      break;
    case ConnectionQuality.fair:
      print('Connection quality: Fair');
      break;
    case ConnectionQuality.poor:
      print('Connection quality: Poor - consider adjusting settings');
      break;
  }
});
```

### Graceful Shutdown

```dart
@override
void dispose() {
  tunnelService.disconnect(graceful: true);
  super.dispose();
}
```

## Best Practices

1. **Always handle errors**: Wrap tunnel operations in try-catch blocks
2. **Use appropriate priorities**: Mark interactive requests as high priority
3. **Monitor connection quality**: Check metrics regularly and adjust configuration
4. **Implement retry logic**: Use exponential backoff for retryable errors
5. **Clean up resources**: Call disconnect() in dispose() methods
6. **Use predefined profiles**: Start with stable/unstable/lowBandwidth profiles
7. **Run diagnostics**: Use runDiagnostics() to troubleshoot issues
8. **Log correlation IDs**: Include correlation IDs for request tracing
9. **Respect rate limits**: Implement client-side rate limiting
10. **Test error scenarios**: Test network failures, timeouts, and server errors
