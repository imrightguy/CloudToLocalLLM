import 'package:flutter_test/flutter_test.dart';

import 'package:cloudtolocalllm/services/tunnel/metrics_collector.dart';
import 'package:cloudtolocalllm/services/tunnel/metrics_exporter.dart';

void main() {
  test('recordRequest counts failed errors once and exports them correctly', () {
    final collector = MetricsCollector();
    collector.recordRequest(
      latency: const Duration(milliseconds: 42),
      success: false,
      errorType: 'network',
    );

    final metrics = collector.getMetrics();
    expect(metrics.totalRequests, 1);
    expect(metrics.failedRequests, 1);
    expect(metrics.errorCounts['network'], 1);

    final exporter = MetricsExporter(collector);
    final aggregation = exporter.exportErrorAggregation();

    expect(aggregation['total_errors'], 1);
    expect(aggregation['error_rate'], 1.0);
    expect(aggregation['error_percentages'], containsPair('network', 100.0));
    expect(aggregation['most_common_error'], 'network');
  });
}
