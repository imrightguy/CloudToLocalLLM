# Tunnel System Development Guide

> **Status**: Legacy/fallback development guide. Current product direction is Tailscale-first secure device mesh with per-user cloud connector containers. Use this guide only for maintaining existing tunnel components or planning migration. New connectivity work should start with [Secure Device Mesh](../architecture/SECURE_DEVICE_MESH.md).

## Prerequisites

Before starting tunnel system development, ensure you have the following installed:

### Required Tools

- **Node.js 18+**: For server development
  - Download: https://nodejs.org/
  - Verify: `node --version` (should be v18.0.0 or higher)

- **Flutter 3.8+**: For client development
  - Download: https://flutter.dev/docs/get-started/install
  - Verify: `flutter --version` (should be 3.8.0 or higher)
  - Verify Dart: `dart --version` (should be 3.9.0 or higher)

- **Git**: For version control
  - Download: https://git-scm.com/
  - Verify: `git --version`

- **SSH Server**: For local testing
  - **Windows**: Install OpenSSH Server

    ```powershell
    # Enable OpenSSH Server
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Start-Service sshd
    Set-Service -Name sshd -StartupType Automatic
    ```

  - **Linux**: Install OpenSSH

    ```bash
    sudo apt-get install openssh-server
    sudo systemctl start ssh
    sudo systemctl enable ssh
    ```

  - **macOS**: SSH is built-in

    ```bash
    sudo systemsetup -setremotelogin on
    ```

- **Docker**: For containerized testing (optional)
  - Download: https://www.docker.com/products/docker-desktop
  - Verify: `docker --version`

### Optional Tools

- **VS Code**: Recommended IDE
  - Download: https://code.visualstudio.com/
  - Extensions: Dart, Flutter, REST Client

- **Postman**: For API testing
  - Download: https://www.postman.com/downloads/

- **wscat**: For WebSocket testing
  - Install: `npm install -g wscat`

- **jq**: For JSON processing
  - Download: https://stedolan.github.io/jq/

## Project Setup

### 1. Clone Repository

```bash
git clone https://github.com/CloudToLocalLLM/CloudToLocalLLM.git
cd CloudToLocalLLM
```

### 2. Install Dependencies

#### Server Dependencies

```bash
# Navigate to streaming-proxy directory
cd services/streaming-proxy

# Install npm dependencies
npm install

# Verify installation
npm list
```

#### Client Dependencies

```bash
# Navigate to project root
cd ../..

# Get Flutter dependencies
flutter pub get

# Verify installation
flutter pub list
```

### 3. Configure Environment Variables

#### Server Configuration

Create `.env` file in `services/streaming-proxy/`:

```bash
# Server Configuration
NODE_ENV=development
PORT=3001
LOG_LEVEL=debug

# WebSocket Configuration
WS_PATH=/ws
WS_PING_INTERVAL=30000
WS_PONG_TIMEOUT=5000
WS_MAX_FRAME_SIZE=1048576

# SSH Configuration
SSH_KEEP_ALIVE_INTERVAL=60000
SSH_MAX_CHANNELS_PER_CONNECTION=10

# Rate Limiting
RATE_LIMIT_REQUESTS_PER_MINUTE=100
RATE_LIMIT_GLOBAL_REQUESTS_PER_MINUTE=10000

# Circuit Breaker
CIRCUIT_BREAKER_FAILURE_THRESHOLD=5
CIRCUIT_BREAKER_SUCCESS_THRESHOLD=2
CIRCUIT_BREAKER_TIMEOUT=60000

# Auth0 Configuration
JWT_ISSUER_DOMAIN=your-auth0-domain.auth0.com
JWT_AUDIENCE=https://api.cloudtolocalllm.online

# Monitoring
METRICS_ENABLED=true
TRACING_ENABLED=true
OTEL_EXPORTER_JAEGER_ENDPOINT=http://localhost:14268/api/traces
```

#### Client Configuration

Create `.env` file in project root:

```bash
# API Configuration
API_BASE_URL=http://localhost:3001
WS_URL=ws://localhost:3001

# Auth0 Configuration
JWT_ISSUER_DOMAIN=your-auth0-domain.auth0.com
JWT_CLIENT_ID=your-client-id
JWT_REDIRECT_URI=http://localhost:5000/callback

# SSH Configuration
SSH_HOST=localhost
SSH_PORT=22
SSH_USERNAME=your-username
```

### 4. Start Local SSH Server

#### Windows

```powershell
# Start SSH server
Start-Service sshd

# Verify it's running
Get-Service sshd

# Test connection
ssh localhost
```

#### Linux/macOS

```bash
# Start SSH server
sudo systemctl start ssh

# Verify it's running
sudo systemctl status ssh

# Test connection
ssh localhost
```

## Running the Application

### Server Development

#### Start Development Server

```bash
cd services/streaming-proxy

# Start with hot reload
npm run dev

# Expected output:
# [INFO] Streaming proxy server listening on port 3001
# [INFO] WebSocket endpoint: ws://localhost:3001/ws
# [INFO] Health check: http://localhost:3001/api/tunnel/health
```

#### Verify Server is Running

```bash
# Check health endpoint
curl http://localhost:3001/api/tunnel/health

# Expected response:
# {"status":"healthy","activeConnections":0,"version":"3.0.0"}
```

### Client Development

#### Start Flutter App (Desktop)

```bash
# Windows
flutter run -d windows

# Linux
flutter run -d linux

# Web
flutter run -d chrome
```

#### Verify Client is Running

- App should launch with tunnel connection UI
- Should show "Disconnected" status initially
- Should be able to connect to local server

## Testing

### Unit Tests

#### Server Unit Tests

```bash
cd services/streaming-proxy

# Run all tests
npm test

# Run specific test file
npm test -- src/websocket-handler.test.ts

# Run with coverage
npm test -- --coverage

# Watch mode
npm test -- --watch
```

#### Client Unit Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/tunnel_service_test.dart

# Run with coverage
flutter test --coverage

# Watch mode
flutter test --watch
```

### Integration Tests

#### Server Integration Tests

```bash
cd services/streaming-proxy

# Run integration tests
npm run test:integration

# Expected output:
# ✓ WebSocket connection establishment
# ✓ Request forwarding through tunnel
# ✓ Reconnection after network failure
# ✓ Rate limiting enforcement
# ✓ Circuit breaker activation
```

#### Client Integration Tests

```bash
# Run integration tests
flutter test test/integration/

# Expected output:
# ✓ Tunnel connection establishment
# ✓ Request forwarding
# ✓ Reconnection handling
# ✓ Error recovery
```

### Load Tests

```bash
cd services/streaming-proxy

# Run load tests
npm run test:load

# Expected output:
# Load test results:
# - Concurrent connections: 1000
# - Requests per second: 1000
# - Average latency: 45ms
# - Error rate: 0%
```

### Chaos Tests

```bash
cd services/streaming-proxy

# Run chaos tests
npm run test:chaos

# Expected output:
# Chaos test results:
# - Network failure recovery: PASS
# - Server crash recovery: PASS
# - Redis failure recovery: PASS
# - Connection pool exhaustion: PASS
```

## Debugging

### Server Debugging

#### VS Code Debugging

1. Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "launch",
      "name": "Launch Streaming Proxy",
      "program": "${workspaceFolder}/services/streaming-proxy/src/server.ts",
      "preLaunchTask": "npm: dev",
      "outFiles": ["${workspaceFolder}/services/streaming-proxy/dist/**/*.js"],
      "sourceMaps": true,
      "console": "integratedTerminal"
    }
  ]
}
```

1. Set breakpoints in VS Code
2. Press F5 to start debugging
3. Use Debug Console to inspect variables

#### Enable Debug Logging

```bash
# Set log level to debug
export LOG_LEVEL=debug

# Start server
npm run dev

# Look for [DEBUG] messages in output
```

#### Monitor Metrics

```bash
# In another terminal, watch metrics
watch -n 1 'curl -s http://localhost:3001/api/tunnel/metrics | grep tunnel_'
```

### Client Debugging

#### Flutter DevTools

```bash
# Start DevTools
flutter pub global activate devtools
devtools

# Run app with DevTools
flutter run --devtools-server-address localhost:9100
```

#### Enable Debug Logging

```dart
// In main.dart
final config = TunnelConfig(
  logLevel: LogLevel.debug,
  // ... other settings
);

await tunnelService.connect(
  serverUrl: 'ws://localhost:3001',
  authToken: authToken,
  config: config,
);
```

#### Monitor Connection

```dart
// Add listener to monitor connection state
tunnelService.addListener(() {
  print('Connection state: ${tunnelService.connectionState}');
  print('Metrics: ${tunnelService.healthMetrics}');
});
```

## Common Development Tasks

### Adding New Metrics

#### Server-Side

1. Define metric in `src/monitoring/prometheus-metrics.ts`:

```typescript
export const myNewMetric = new Counter({
  name: 'tunnel_my_new_metric_total',
  help: 'Description of my new metric',
  labelNames: ['category'],
});
```

1. Record metric in relevant component:

```typescript
myNewMetric.inc({ category: 'example' });
```

1. Verify metric appears in `/api/tunnel/metrics`

#### Client-Side

1. Add metric to `MetricsCollector`:

```dart
void recordMyMetric(String category) {
  _metrics['my_new_metric'] = category;
}
```

1. Export metric in `exportPrometheusFormat()`:

```dart
metrics['tunnel_my_new_metric'] = _metrics['my_new_metric'];
```

### Implementing New Error Types

#### Server-Side

1. Add error code to `src/errors/error-codes.ts`:

```typescript
export const TUNNEL_011 = 'TUNNEL_011';
```

1. Create error in component:

```typescript
throw new TunnelError(
  TUNNEL_011,
  'My error message',
  TunnelErrorCategory.PROTOCOL,
  'User-friendly message',
  'Suggestion for recovery'
);
```

#### Client-Side

1. Add error code to `lib/services/tunnel/error_codes.dart`:

```dart
static const String myNewError = 'TUNNEL_011';
```

1. Handle error in error handler:

```dart
case 'TUNNEL_011':
  return TunnelError(
    category: TunnelErrorCategory.protocol,
    code: 'TUNNEL_011',
    message: 'My error message',
    userMessage: 'User-friendly message',
    suggestion: 'Suggestion for recovery',
  );
```

### Testing Reconnection Scenarios

#### Simulate Network Failure

```bash
# On Linux/macOS
# Block traffic to server
sudo iptables -A OUTPUT -d localhost -p tcp --dport 3001 -j DROP

# Wait for reconnection
sleep 10

# Restore traffic
sudo iptables -D OUTPUT -d localhost -p tcp --dport 3001 -j DROP
```

#### Simulate Server Crash

```bash
# Kill server process
pkill -f "npm run dev"

# Wait for client to detect failure
sleep 5

# Restart server
npm run dev
```

#### Monitor Reconnection

```dart
// Watch reconnection attempts
tunnelService.addListener(() {
  if (tunnelService.connectionState == TunnelConnectionState.reconnecting) {
    print('Reconnecting...');
  }
});
```

### Testing Rate Limiting

```bash
# Send rapid requests to trigger rate limit
for i in {1..150}; do
  curl -H "Authorization: Bearer $TOKEN" \
    http://localhost:3001/api/tunnel/health &
done

# Should see 429 responses after 100 requests
```

### Testing Circuit Breaker

```bash
# Simulate SSH server failure
sudo systemctl stop ssh

# Send requests - should see circuit breaker open
for i in {1..10}; do
  curl -H "Authorization: Bearer $TOKEN" \
    http://localhost:3001/api/tunnel/health
done

# Restart SSH server
sudo systemctl start ssh

# Circuit breaker should recover after 60 seconds
```

## Code Organization

### Server Structure

```
services/streaming-proxy/src/
├── server.ts                 # Main entry point
├── websocket-handler.ts      # WebSocket connection handling
├── auth/
│   └── middleware.ts         # JWT validation
├── rate-limiter/
│   └── limiter.ts            # Rate limiting logic
├── connection-pool/
│   └── pool.ts               # SSH connection management
├── ssh/
│   └── tunnel-manager.ts     # SSH operations
├── circuit-breaker/
│   └── breaker.ts            # Circuit breaker pattern
├── monitoring/
│   ├── prometheus-metrics.ts # Prometheus metrics
│   ├── otel-setup.ts         # OpenTelemetry tracing
│   └── logger.ts             # Structured logging
└── errors/
    └── error-codes.ts        # Error definitions
```

### Client Structure

```
lib/services/tunnel/
├── tunnel_service.dart       # Main service
├── request_queue.dart        # Request queuing
├── metrics_collector.dart    # Metrics collection
├── websocket_client.dart     # WebSocket transport
├── error_handler.dart        # Error handling
├── config/
│   └── tunnel_config.dart    # Configuration
├── models/
│   ├── tunnel_request.dart   # Request model
│   ├── tunnel_response.dart  # Response model
│   └── tunnel_error.dart     # Error model
└── diagnostics/
    └── diagnostic_suite.dart # Diagnostic tests
```

## Best Practices

### Code Style

- **Server**: Follow TypeScript/Node.js conventions
  - Use `npm run lint` to check code style
  - Use `npm run format` to auto-format code

- **Client**: Follow Dart/Flutter conventions
  - Use `dart format .` to format code
  - Use `dart analyze` to check for issues

### Testing

- Write tests for new features
- Aim for 80%+ code coverage
- Test error scenarios
- Test edge cases

### Documentation

- Add JSDoc comments to TypeScript code
- Add dartdoc comments to Dart code
- Document complex algorithms
- Include code examples

### Performance

- Monitor metrics regularly
- Profile code for bottlenecks
- Optimize hot paths
- Test with realistic load

### Security

- Validate all inputs
- Use secure defaults
- Implement rate limiting
- Log security events

## Troubleshooting Development Issues

### Issue: "Cannot find module"

**Solution:**

```bash
# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install

# Or for Flutter
flutter pub get
```

### Issue: "Port already in use"

**Solution:**

```bash
# Find process using port 3001
lsof -i :3001

# Kill process
kill -9 <PID>

# Or use different port
PORT=3002 npm run dev
```

### Issue: "SSH connection refused"

**Solution:**

```bash
# Verify SSH server is running
sudo systemctl status ssh

# Start SSH server
sudo systemctl start ssh

# Test SSH connection
ssh localhost
```

### Issue: "Tests failing"

**Solution:**

```bash
# Run tests with verbose output
npm test -- --verbose

# Run specific test
npm test -- src/specific-test.test.ts

# Check test logs
cat test-results.log
```

## Resources

- **API Documentation**: `docs/API/TUNNEL_CLIENT_API.md`, `docs/API/TUNNEL_SERVER_API.md`
- **Architecture Documentation**: `docs/ARCHITECTURE/TUNNEL_SYSTEM.md`
- **Troubleshooting Guide**: `docs/OPERATIONS/TUNNEL_TROUBLESHOOTING.md`
- **GitHub Repository**: https://github.com/CloudToLocalLLM/CloudToLocalLLM
- **Issue Tracker**: https://github.com/CloudToLocalLLM/CloudToLocalLLM/issues

## Getting Help

- Check existing documentation
- Search GitHub issues
- Ask in community forum
- Contact development team

## Next Steps

1. Set up development environment
2. Run existing tests to verify setup
3. Make a small change and test it
4. Read architecture documentation
5. Start implementing features

Happy coding!
