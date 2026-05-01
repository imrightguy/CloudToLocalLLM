# Tunnel Metrics Collection Implementation

> **Status**: Legacy/fallback tunnel metrics notes for the older SSH WebSocket tunnel stack. Current connectivity work should prefer the Tailscale secure device mesh.

## Overview

This document describes the implementation of client-side metrics collection for the SSH WebSocket tunnel system. The implementation provides comprehensive performance tracking, real-time quality calculation, and multiple export formats.

## Components Implemented

### 1. MetricsCollector (`metrics_collector.dart`)

**Purpose**: Core metrics collection and aggregation engine

**Key Features**:

- Records request metrics (latency, success/failure, error types)
- Tracks connection state changes
- Records reconnection attempts
- Maintains metric history with configurable size limits (10,000 data points)
- Calculates aggregate metrics (average, P95, P99 latency)
- Provides time-window filtering for metrics
- Automatic connection quality updates

**Main Methods**:

```dart
// Record metrics
void recordRequest({required Duration latency, required bool success, String? errorType})
void recordConnection({required TunnelConnectionState state, String? reason})
void recordReconnection({required int attemptNumber, required bool success, Duration? delay})

// Retrieve metrics
TunnelMetrics getMetrics({Duration? window})
ConnectionQuality get currentQuality

// Export
Map<String, dynamic> exportPrometheusFormat()
Map<String, dynamic> exportJson()
```

**Data Structures**:

- `MetricDataPoint`: Individual request measurement
- `ConnectionStateChange`: Connection lifecycle event
- `ReconnectionAttempt`: Reconnection tracking

### 2. ConnectionQualityCalculator (`connection_quality_calculator.dart`)

**Purpose**: Real-time connection quality calculation and monitoring

**Key Features**:

- Calculates quality based on latency and packet loss
- Real-time quality updates every 5 seconds
- Stream-based quality change notifications
- Quality score calculation (0-100)
- Quality thresholds:
  - Excellent: < 50ms latency, < 1% packet loss
  - Good: < 100ms latency, < 3% packet loss
  - Fair: < 200ms latency, < 5% packet loss
  - Poor: > 200ms latency or > 5% packet loss

**Main Methods**:

```dart
// Add measurements
void addMeasurement({required double latency, required bool success})

// Get quality
ConnectionQuality get currentQuality
Stream<ConnectionQuality> get qualityStream
ConnectionQuality calculateQuality()

// Quality details
String getQualityText()
String getQualityColor()
int getQualityScore()
Map<String, dynamic> getQualityMetrics()
```

**Quality Scoring**:

- Latency component: 0-50 points
- Packet loss component: 0-50 points
- Total score: 0-100 points

### 3. MetricsExporter (`metrics_exporter.dart`)

**Purpose**: Export metrics in multiple formats for monitoring and analysis

**Supported Formats**:

1. **Prometheus**: Standard Prometheus text format with HELP and TYPE annotations
2. **JSON**: Structured JSON with nested metrics and metadata
3. **CSV**: Simple CSV format for spreadsheet analysis

**Key Features**:

- Prometheus-compatible metric names and labels
- Percentile metrics (P95, P99)
- Error aggregation by type
- Summary statistics
- Health status calculation

**Main Methods**:

```dart
// Export in different formats
String export({MetricsExportFormat format, Duration? window})
String exportPrometheus({Duration? window})
String exportJson({Duration? window, bool pretty})
String exportCsv({Duration? window})

// Specialized exports
Map<String, dynamic> exportPercentiles({Duration? window})
Map<String, dynamic> exportErrorAggregation({Duration? window})
Map<String, dynamic> exportSummary({Duration? window})
```

**Prometheus Metrics**:

- `tunnel_requests_total`: Total request count
- `tunnel_requests_success_total`: Successful requests
- `tunnel_requests_failed_total`: Failed requests
- `tunnel_request_success_rate`: Success rate (0-1)
- `tunnel_request_latency_avg_ms`: Average latency
- `tunnel_request_latency_p95_ms`: P95 latency
- `tunnel_request_latency_p99_ms`: P99 latency
- `tunnel_reconnection_count`: Reconnection count
- `tunnel_uptime_seconds`: Connection uptime
- `tunnel_errors_total{error_type}`: Errors by type
- `tunnel_connection_quality`: Quality indicator (0-3)

### 4. TunnelPerformanceDashboard (`tunnel_performance_dashboard.dart`)

**Purpose**: Full-screen performance dashboard UI

**Features**:

- Connection quality indicator with visual feedback
- Request metrics (total, success, failed, success rate)
- Latency metrics (average, P95, P99)
- Connection statistics (uptime, reconnections, packet loss)
- Queue status display
- Auto-refresh every 5 seconds
- Manual refresh button

**UI Components**:

- Quality indicator card with progress bar
- Request metrics card with success rate bar
- Latency metrics card with percentiles
- Connection stats card
- Queue status card

### 5. TunnelMetricsWidget (`tunnel_metrics_widget.dart`)

**Purpose**: Compact inline metrics widget

**Features**:

- Compact view: Single-line badge with key metrics
- Detailed view: Card with expanded metrics
- Real-time updates
- Quality badge component
- Configurable display mode

**Usage Examples**:

```dart
// Compact inline display
TunnelMetricsWidget(
  metricsCollector: collector,
  showDetails: false,
)

// Detailed card display
TunnelMetricsWidget(
  metricsCollector: collector,
  showDetails: true,
)

// Quality badge only
ConnectionQualityBadge(
  quality: ConnectionQuality.excellent,
  showLabel: true,
)
```

## Integration Guide

### Basic Setup

```dart
// Create metrics collector
final metricsCollector = MetricsCollector();

// Create quality calculator (optional)
final qualityCalculator = ConnectionQualityCalculator();

// Create exporter
final exporter = MetricsExporter(metricsCollector);
```

### Recording Metrics

```dart
// Record a successful request
metricsCollector.recordRequest(
  latency: Duration(milliseconds: 45),
  success: true,
);

// Record a failed request
metricsCollector.recordRequest(
  latency: Duration(milliseconds: 200),
  success: false,
  errorType: TunnelErrorCodes.requestTimeout,
);

// Record connection state change
metricsCollector.recordConnection(
  state: TunnelConnectionState.connected,
  reason: 'Initial connection',
);

// Record reconnection attempt
metricsCollector.recordReconnection(
  attemptNumber: 1,
  success: true,
  delay: Duration(seconds: 2),
);

// Add quality measurement
qualityCalculator.addMeasurement(
  latency: 45.0,
  success: true,
);
```

### Retrieving Metrics

```dart
// Get all-time metrics
final metrics = metricsCollector.getMetrics();

// Get metrics for last 5 minutes
final recentMetrics = metricsCollector.getMetrics(
  window: Duration(minutes: 5),
);

// Get current quality
final quality = metricsCollector.currentQuality;

// Listen to quality changes
qualityCalculator.qualityStream.listen((quality) {
  print('Quality changed to: ${quality.name}');
});
```

### Exporting Metrics

```dart
// Export as Prometheus
final prometheusText = exporter.exportPrometheus();

// Export as JSON
final jsonText = exporter.exportJson(pretty: true);

// Export as CSV
final csvText = exporter.exportCsv();

// Export percentiles
final percentiles = exporter.exportPercentiles();

// Export error aggregation
final errors = exporter.exportErrorAggregation();

// Export summary
final summary = exporter.exportSummary();
```

### UI Integration

```dart
// Full dashboard
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => TunnelPerformanceDashboard(
      metricsCollector: metricsCollector,
      qualityCalculator: qualityCalculator,
    ),
  ),
);

// Inline compact widget
TunnelMetricsWidget(
  metricsCollector: metricsCollector,
  qualityCalculator: qualityCalculator,
  showDetails: false,
)

// Quality badge
ConnectionQualityBadge(
  quality: metricsCollector.currentQuality,
  showLabel: true,
)
```

## Requirements Coverage

### Requirement 3.3: Track client-side metrics

✅ Implemented via `MetricsCollector` class

- Records connection uptime, reconnection count, request queue size
- Maintains metric history with size limits
- Calculates aggregate metrics

### Requirement 3.5: Connection quality indicator

✅ Implemented via `ConnectionQualityCalculator` class

- Calculates quality based on latency and packet loss
- Defines quality thresholds (excellent/good/fair/poor)
- Updates quality in real-time
- Exposes quality indicator to UI

### Requirement 3.8: Track and log slow requests

✅ Implemented via `MetricsCollector` class

- Tracks request duration for all requests
- Calculates percentile metrics (P95, P99)
- Can identify slow requests via percentile analysis

### Requirement 3.9: Performance dashboard

✅ Implemented via `TunnelPerformanceDashboard` and `TunnelMetricsWidget`

- Displays real-time connection metrics
- Shows connection quality indicator
- Displays request success rate
- Shows latency graph (via percentile display)
- Displays queue status

### Requirement 3.4: Prometheus format export

✅ Implemented via `MetricsExporter` class

- Exports metrics in Prometheus text format
- Includes HELP and TYPE annotations
- Supports metric labels for dimensions

## Performance Considerations

### Memory Management

- Maximum history size: 10,000 data points per metric type
- Automatic cleanup of old data points
- Efficient queue-based storage (O(1) add/remove)

### CPU Usage

- Periodic quality updates: Every 5 seconds
- Percentile calculation: O(n log n) on demand
- Metric aggregation: O(n) on demand

### UI Updates

- Auto-refresh interval: 5 seconds
- Stream-based quality updates (no polling)
- Efficient state management with setState

## Testing Recommendations

### Unit Tests

```dart
test('MetricsCollector records requests correctly', () {
  final collector = MetricsCollector();
  collector.recordRequest(latency: Duration(milliseconds: 50), success: true);
  
  final metrics = collector.getMetrics();
  expect(metrics.totalRequests, 1);
  expect(metrics.successfulRequests, 1);
});

test('ConnectionQualityCalculator calculates quality correctly', () {
  final calculator = ConnectionQualityCalculator();
  calculator.addMeasurement(latency: 30.0, success: true);
  
  expect(calculator.currentQuality, ConnectionQuality.excellent);
});
```

### Integration Tests

- Test metrics collection during tunnel operations
- Verify quality updates based on network conditions
- Test export formats for correctness
- Verify UI updates with real metrics

## Future Enhancements

1. **Histogram Support**: Add histogram metrics for better percentile accuracy
2. **Custom Metrics**: Allow user-defined metrics
3. **Metric Persistence**: Save metrics to disk for historical analysis
4. **Advanced Visualizations**: Add charts and graphs to dashboard
5. **Alerting**: Add threshold-based alerts for metrics
6. **Metric Sampling**: Add sampling for high-volume scenarios
7. **Metric Aggregation**: Add time-based aggregation (hourly, daily)

## Related Files

- `lib/services/tunnel/interfaces/tunnel_models.dart` - Data models
- `lib/services/tunnel/interfaces/tunnel_health_metrics.dart` - Health metrics
- `lib/services/tunnel/metrics_collector.dart` - Core collector
- `lib/services/tunnel/connection_quality_calculator.dart` - Quality calculator
- `lib/services/tunnel/metrics_exporter.dart` - Export functionality
- `lib/widgets/tunnel_performance_dashboard.dart` - Full dashboard UI
- `lib/widgets/tunnel_metrics_widget.dart` - Compact widget UI

## References

- Requirements: `.kiro/specs/ssh-websocket-tunnel-enhancement/requirements.md`
- Design: `.kiro/specs/ssh-websocket-tunnel-enhancement/design.md`
- Tasks: `.kiro/specs/ssh-websocket-tunnel-enhancement/tasks.md`
