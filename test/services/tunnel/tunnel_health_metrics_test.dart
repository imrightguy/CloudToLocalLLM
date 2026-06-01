import 'package:flutter_test/flutter_test.dart';

import 'package:cloudtolocalllm/services/tunnel/interfaces/tunnel_health_metrics.dart';

void main() {
  test('TunnelHealthMetrics.fromJson throws for malformed payloads', () {
    expect(
      () => TunnelHealthMetrics.fromJson(<String, dynamic>{'quality': 'good'}),
      throwsA(isA<TypeError>()),
    );
  });

  test('TunnelHealthMetrics.fromJson accepts valid payloads', () {
    final metrics = TunnelHealthMetrics.fromJson(<String, dynamic>{
      'uptime': 1000,
      'reconnectCount': 2,
      'averageLatency': 42.5,
      'packetLoss': 0.01,
      'quality': 'good',
      'queuedRequests': 4,
      'successfulRequests': 10,
      'failedRequests': 1,
    });

    expect(metrics, isNotNull);
    expect(metrics.quality, ConnectionQuality.good);
    expect(metrics.successRate, closeTo(10 / 11, 1e-9));
  });
}
