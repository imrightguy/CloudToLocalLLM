import 'package:flutter_test/flutter_test.dart';

import 'package:cloudtolocalllm/services/tunnel/interfaces/tunnel_models.dart';

void main() {
  test('TunnelError.fromJson returns error for valid payloads', () {
    final error = TunnelError.fromJson(<String, dynamic>{
      'id': 'err-1',
      'category': 'network',
      'code': 'TUNNEL_001',
      'message': 'network issue',
      'userMessage': 'network issue',
      'timestamp': '2026-05-10T12:00:00.000Z',
      'context': <String, dynamic>{'host': 'example.invalid'},
    });
    expect(error, isNotNull);
    expect(error.code, 'TUNNEL_001');
  });

  test('TunnelMetrics.fromJson returns metrics for valid payloads', () {
    final metrics = TunnelMetrics.fromJson(<String, dynamic>{
      'totalRequests': 2,
      'successfulRequests': 1,
      'failedRequests': 1,
      'successRate': 0.5,
      'averageLatency': 10,
      'p95Latency': 20,
      'p99Latency': 25,
      'reconnectionCount': 3,
      'totalUptime': 1000,
      'errorCounts': <String, int>{'network': 1},
    });
    expect(metrics, isNotNull);
    expect(metrics.totalRequests, 2);
    expect(metrics.errorCounts['network'], 1);
  });

  test('fromJson throws on malformed payloads', () {
    expect(
      () => TunnelError.fromJson(<String, dynamic>{'code': 'ERR'}),
      throwsA(isA<TypeError>()),
    );
  });
}
