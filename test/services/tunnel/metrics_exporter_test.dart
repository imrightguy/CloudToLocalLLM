import 'package:flutter_test/flutter_test.dart';

import 'package:cloudtolocalllm/services/tunnel/metrics_collector.dart';
import 'package:cloudtolocalllm/services/tunnel/metrics_exporter.dart';

void main() {
  test('exportErrorAggregation returns zero rates for empty collector', () {
    final exporter = MetricsExporter(MetricsCollector());

    final aggregation = exporter.exportErrorAggregation();

    expect(aggregation['total_errors'], 0);
    expect(aggregation['error_rate'], 0.0);
    expect(aggregation['errors_by_type'], isA<Map<String, int>>());
    expect(aggregation['error_percentages'], isA<Map<String, double>>());
    expect(aggregation['error_percentages'], isEmpty);
    expect(aggregation['most_common_error'], isNull);
  });
}
