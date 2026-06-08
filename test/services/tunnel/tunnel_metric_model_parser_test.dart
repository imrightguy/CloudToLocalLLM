import 'package:flutter_test/flutter_test.dart';

import 'package:cloudtolocalllm/services/tunnel/interfaces/tunnel_models.dart';

void main() {
  test('ServerMetrics.fromJson accepts valid payloads', () {
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
  });

  test('UserMetrics.fromJson accepts valid payloads', () {
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
