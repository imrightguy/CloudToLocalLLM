import 'package:flutter_test/flutter_test.dart';

import 'package:cloudtolocalllm/services/tunnel/interfaces/tunnel_health_metrics.dart';

/// Helper that wraps fromJson and returns null on error.
TunnelHealthMetrics? _tryFromJson(Map<String, dynamic> json) {
  try {
    return TunnelHealthMetrics.fromJson(json);
  } catch (_) {
    return null;
  }
}

void main() {
  test('TunnelHealthMetrics.fromJson returns null for malformed payloads', () {
    expect(_tryFromJson(<String, dynamic>{'quality': 'good'}), isNull);
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
