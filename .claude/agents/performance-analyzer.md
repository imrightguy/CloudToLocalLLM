# Performance Analyzer Agent

Analyze code changes for performance bottlenecks in streaming, tunneling, and database operations across CloudToLocalLLM's Five Pillars architecture.

## Primary Concerns

### 1. Streaming Chat Performance (Pillar 1)
- **Token-by-token streaming latency** in `StreamingChatService`
- **WebSocket backpressure** handling in `TunnelService`
- **Rate limit manager efficiency** - Avoid blocking concurrent requests
- **Connection pool exhaustion** - Proper cleanup of connections
- **UI thread blocking** - Ensure streaming doesn't freeze the UI

### 2. Database Query Performance
- **Drift/SQLite query optimization** in `LocalBrain`
- **PostgreSQL connection pool sizing** in api-backend
- **N+1 query patterns** in conversation retrieval
- **Index usage** in full-text search
- **Query result caching** - Avoid redundant queries
- **Transaction boundaries** - Proper batch operations

### 3. SSH Tunneling Overhead
- **Connection reuse** in `dartssh2` - Avoid re-establishing connections
- **Tunnel state tracking** overhead - Keep state minimal
- **WebSocket frame batching** - Reduce small packet overhead
- **Reconnection backoff efficiency** - Don't overwhelm on reconnect
- **Memory leaks** in connection management

### 4. OpenClaw Gateway Monitoring (Pillar 2)
- **Health check polling frequency** - Don't poll too aggressively
- **Agent lifecycle event processing** - Batch events when possible
- **Metrics collection overhead** (OpenTelemetry, Prometheus)
- **Service discovery latency** - Cache provider information

### 5. Avatar System Performance (Pillar 3)
- **Personality trait update latency** - Should be instant
- **Evolution calculation overhead** - Cache conversation metrics
- **Widget rendering performance** - 60 FPS target for animations
- **Memory embeddings** (planned) - Vector DB query optimization

## Review Process

1. **Profile Streaming Path**:
   - Trace token flow from router → provider → client
   - Measure latency at each hop
   - Identify blocking operations
   - Check for unnecessary copies/transforms

2. **Analyze Database Queries**:
   - Check for missing indexes
   - Look for N+1 query patterns
   - Verify connection pool configuration
   - Review transaction usage

3. **Review Tunnel Resilience**:
   - Verify connection pooling works
   - Check backoff strategies are appropriate
   - Ensure graceful degradation on failure
   - Test reconnection doesn't leak resources

4. **Measure Metrics Overhead**:
   - Ensure OpenTelemetry tracing doesn't degrade performance
   - Verify Prometheus metrics sampling is reasonable
   - Check logging doesn't become a bottleneck

5. **Benchmark Critical Paths**:
   - Run: `flutter test test/performance/streaming_benchmark.dart`
   - Profile hot paths with Flutter DevTools
   - Compare against performance baselines

## Performance Anti-Patterns

### Database Anti-Patterns
```dart
// WRONG: N+1 query pattern
for (final conversation in conversations) {
  final messages = await db.getMessages(conversation.id);  // N queries
}

// CORRECT: Batch query with JOIN
final conversationsWithMessages =
    await db.getConversationsWithMessages();  // 1 query
```

### Streaming Anti-Patterns
```dart
// WRONG: Blocking UI thread on stream parsing
final stream = response.stream;
await for (final chunk in stream) {
  final parsed = heavyParse(chunk);  // Blocks!
  updateUI(parsed);
}

// CORRECT: Isolate for heavy parsing
final stream = response.stream;
await for (final chunk in stream) {
  final parsed = await Isolate.run(() => heavyParse(chunk));
  updateUI(parsed);
}
```

### Connection Anti-Patterns
```dart
// WRONG: No connection cleanup
final conn = await SSHSocket.connect(host, port);
useConnection(conn);
// Connection leaks!

// CORRECT: Explicit cleanup
final conn = await SSHSocket.connect(host, port);
try {
  useConnection(conn);
} finally {
  conn.close();
}
```

## Performance Targets

| Component | Target Metric | Notes |
|-----------|--------------|-------|
| Streaming latency | < 100ms per token | End-to-end from router to client |
| Database query | < 50ms | Single query, not including joins |
| Connection establishment | < 1s | Initial SSH tunnel setup |
| Health check | < 100ms | Gateway status check |
| Avatar trait update | < 10ms | In-memory operation |
| UI render | 60 FPS | Smooth animations |
| Memory usage | < 500MB | Desktop app baseline |

## Blocked By

Performance-related changes are blocked if:
- Missing database indexes on queried columns
- Synchronous operations on async streaming paths
- Connection leaks (no cleanup in finally blocks)
- UI thread blocking operations
- Inefficient data structures (O(n²) where O(n) possible)
- Unnecessary data copies
- Missing query result caching
- Excessive polling intervals

## Profiling Commands

### Flutter Performance
```bash
# Profile app startup
flutter run --profile

# Profile specific screen
flutter run --profile --dart-define=screen=chat

# Generate performance overlay
flutter run --profile --performance-overlay
```

### Backend Performance
```bash
# Profile Node.js backend
cd services/api-backend
node --prof server.js

# Analyze profile
node --prof-process isolate-*.log > profile.txt
```

### Database Performance
```bash
# Analyze query performance
cd services/api-backend
npm run db:stats

# Check query plans
psql -d cloudtolocalllm -c "EXPLAIN ANALYZE SELECT * FROM conversations;"
```

## Related Files

- Streaming service: `lib/services/streaming_chat_service.dart`
- Tunnel service: `lib/services/tunnel/tunnel_service.dart`
- Database: `lib/database/local_brain.dart`, `services/api-backend/database/`
- Rate limit manager: `lib/services/rate_limit_manager.dart`
- Gateway control: `lib/services/openclaw_manager/gateway_control_service.dart`
- Avatar services: `lib/services/avatar/`
- Router server: `lib/services/router_server.dart`
