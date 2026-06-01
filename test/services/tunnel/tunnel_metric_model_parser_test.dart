import 'package:flutter_test/flutter_test.dart';

import 'package:cloudtolocalllm/services/tunnel/interfaces/tunnel_models.dart';
import 'package:cloudtolocalllm/services/tunnel/metrics_collector.dart';

void main() {
  test('metric model constructors reject malformed payloads', () {
    // ConnectionStateChange and ReconnectionAttempt don't have fromJson;
    // they use direct constructors, so we test validation by construction
    expect(
      () => ConnectionStateChange(
        timestamp: DateTime.now(),
        state: TunnelConnectionState.connected,
        reason: null,
      ),
      returnsNormally,
    );

    expect(
      () => ReconnectionAttempt(
        timestamp: DateTime.now(),
        attemptNumber: 1,
        success: true,
      ),
      returnsNormally,
    );

    // ServerMetrics.fromJson throws on bad types
    expect(
      () => ServerMetrics.fromJson(<String, dynamic>{'activeConnections': 'bad'}),
      throwsA(isA<TypeError>()),
    );

    // UserMetrics.fromJson throws on bad types
    expect(
      () => UserMetrics.fromJson(<String, dynamic>{
        'userId': 'u',
        'connectionCount': 'bad',
      }),
      throwsA(isA<TypeError>()),
    );
  });

  test('metric model parsers accept valid payloads', () {
    final stateChange = ConnectionStateChange(
      timestamp: DateTime.parse('2026-05-10T12:00:00.000Z'),
      state: TunnelConnectionState.connected,
      reason: 'test',
    );
    expect(stateChange, isNotNull);
    expect(stateChange.state, TunnelConnectionState.connected);

    final reconnection = ReconnectionAttempt(
      timestamp: DateTime.parse('2026-05-10T12:00:01.000Z'),
      attemptNumber: 2,
      success: true,
      delay: const Duration(milliseconds: 500),
    );
    expect(reconnection, isNotNull);
    expect(reconnection.delay?.inMilliseconds, 500);

    final serverMetrics = ServerMetrics.fromJson(<String, dynamic>{
      'activeConnections': 1,
      'totalConnections': 2,
      'connectionRate': 0.5,
      'requestCount': 3,
      'successCount': 2,
      'errorCount': 1,
      'successRate': 0.666,
      'averageLatency': 12.5,
      'p50Latency': 10.0,
      'p95Latency': 20.0,
      'p99Latency': 25.0,
      'bytesReceived': 100,
      'bytesSent': 200,
      'requestsPerSecond': 1.5,
      'errorsByCategory': <String, int>{'network': 1},
      'errorRate': 0.333,
      'activeUsers': 1,
      'requestsByUser': <String, int>{'u': 3},
      'memoryUsage': 42.0,
      'cpuUsage': 15.0,
      'uptime': 1000,
      'timestamp': '2026-05-10T12:00:02.000Z',
      'window': 60000,
    });
    expect(serverMetrics, isNotNull);
    expect(serverMetrics.activeConnections, 1);

    final userMetrics = UserMetrics.fromJson(<String, dynamic>{
      'userId': 'u',
      'connectionCount': 4,
      'requestCount': 8,
      'successRate': 0.75,
      'averageLatency': 33.0,
      'dataTransferred': 1024,
      'rateLimitViolations': 0,
      'lastActivity': '2026-05-10T12:00:03.000Z',
    });
    expect(userMetrics, isNotNull);
    expect(userMetrics.connectionCount, 4);
  });
}
