# Monitoring Libraries Documentation and Best Practices

## Library Resolution

### Prometheus Client (prom-client)

**Library Name:** Prom Client  
**Context7 Library ID:** `/siimon/prom-client`  
**NPM Package:** `prom-client`  
**Trust Score:** 7.0/10  
**Code Snippets Available:** 38  
**Repository:** https://github.com/siimon/prom-client

### OpenTelemetry JavaScript

**Library Name:** OpenTelemetry JavaScript Client  
**Context7 Library ID:** `/open-telemetry/opentelemetry-js`  
**NPM Package:** `@opentelemetry/sdk-node`  
**Trust Score:** 9.3/10  
**Code Snippets Available:** 219  
**Repository:** https://github.com/open-telemetry/opentelemetry-js

---

## Prometheus Client (prom-client) Best Practices

### 1. Metric Types

#### Counter

- **Purpose:** Track cumulative values that only increase
- **Use Cases:** Request count, errors, total bytes sent
- **Reset:** Only resets on process restart
- **Example:** HTTP requests total, errors total

```typescript
const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'status_code']
});

httpRequestsTotal.inc({ method: 'GET', status_code: '200' });
httpRequestsTotal.inc({ method: 'POST', status_code: '201' }, 5); // Increment by 5
```

#### Gauge

- **Purpose:** Track values that can increase or decrease
- **Use Cases:** Active connections, queue size, memory usage
- **Reset:** Can be set to any value
- **Example:** Active connections, pending requests

```typescript
const activeConnections = new Gauge({
  name: 'active_connections',
  help: 'Number of active connections',
  labelNames: ['service']
});

activeConnections.set({ service: 'api' }, 42);
activeConnections.inc({ service: 'api' });      // Increment by 1
activeConnections.dec({ service: 'api' }, 3);   // Decrement by 3
```

#### Histogram

- **Purpose:** Track distribution of values (latency, size)
- **Use Cases:** Request duration, response size, processing time
- **Buckets:** Define ranges for distribution analysis
- **Example:** Request latency, response size

```typescript
const requestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
});

// Observe values
requestDuration.observe({ method: 'GET', route: '/api/users', status: '200' }, 0.123);

// Use startTimer for automatic duration measurement
const end = requestDuration.startTimer();
// ... perform operation ...
end({ method: 'GET', route: '/api/users', status: '200' });
```

#### Summary

- **Purpose:** Calculate percentiles (P50, P95, P99)
- **Use Cases:** Request latency percentiles, response time analysis
- **Percentiles:** Define which percentiles to calculate
- **Example:** Request latency percentiles

```typescript
const requestLatency = new Summary({
  name: 'http_request_latency_seconds',
  help: 'HTTP request latency in seconds',
  labelNames: ['service'],
  percentiles: [0.5, 0.9, 0.95, 0.99]
});

requestLatency.observe({ service: 'api' }, 0.15);
requestLatency.observe({ service: 'api' }, 0.23);
```

### 2. Bucket Configuration

#### Linear Buckets

- **Use:** Equal spacing between values
- **Example:** Response sizes (0, 100, 200, 300, ...)

```typescript
const responseSize = new Histogram({
  name: 'response_size_bytes',
  help: 'HTTP response size in bytes',
  buckets: linearBuckets(0, 100, 11)  // [0, 100, 200, ..., 1000]
});
```

#### Exponential Buckets

- **Use:** Exponential growth for wide ranges
- **Example:** Latencies (1ms, 2ms, 4ms, 8ms, ...)

```typescript
const requestDuration = new Histogram({
  name: 'request_duration_ms',
  help: 'Request duration in milliseconds',
  buckets: exponentialBuckets(1, 2, 9)  // [1, 2, 4, 8, 16, 32, 64, 128, 256]
});
```

### 3. Label Management

#### Best Practices

- **Minimize cardinality:** Avoid high-cardinality labels (user IDs, request IDs)
- **Initialize combinations:** Pre-initialize all expected label combinations with zero()
- **Consistent naming:** Use consistent label names across metrics
- **Avoid dynamic labels:** Don't use unbounded values as labels

```typescript
const httpRequests = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'status_code']
});

// Initialize all expected combinations
httpRequests.zero({ method: 'GET', status_code: '200' });
httpRequests.zero({ method: 'GET', status_code: '404' });
httpRequests.zero({ method: 'POST', status_code: '201' });
```

### 4. Metrics Endpoint

#### Prometheus Format

- **Content-Type:** `text/plain; version=0.0.4; charset=utf-8`
- **Endpoint:** `/metrics`
- **Format:** Prometheus exposition format

```typescript
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.status(500).end(err.message);
  }
});
```

### 5. Default Metrics

#### Collect Default Metrics

- **Node.js runtime metrics:** Memory, CPU, event loop
- **GC metrics:** Garbage collection duration and frequency
- **Process metrics:** Uptime, file descriptors

```typescript
const { collectDefaultMetrics } = require('prom-client');

// Enable with default configuration
collectDefaultMetrics();

// Enable with custom configuration
collectDefaultMetrics({
  prefix: 'myapp_',
  gcDurationBuckets: [0.001, 0.01, 0.1, 1, 2, 5],
  labels: {
    app: 'my-application',
    environment: 'production'
  }
});
```

### 6. Custom Registry

#### Multiple Registries

- **Use:** Separate metrics for different components
- **Merge:** Combine multiple registries

```typescript
const customRegistry = new Registry();

const counter = new Counter({
  name: 'custom_counter',
  help: 'Custom counter',
  registers: [customRegistry]  // Register to custom registry only
});

// Merge registries
const merged = Registry.merge([customRegistry, register]);
```

### 7. Cluster Aggregation

#### Aggregate Worker Metrics

- **Master process:** Aggregates metrics from workers
- **Workers:** Collect metrics normally
- **Aggregation methods:** sum, first, min, max, average, omit

```typescript
const { AggregatorRegistry } = require('prom-client');

if (cluster.isPrimary) {
  const aggregatorRegistry = new AggregatorRegistry();
  
  app.get('/metrics', async (req, res) => {
    const metrics = await aggregatorRegistry.clusterMetrics();
    res.set('Content-Type', aggregatorRegistry.contentType);
    res.send(metrics);
  });
}
```

### 8. Pushgateway Integration

#### Push Metrics

- **Use:** Batch jobs, short-lived processes
- **Methods:** pushAdd (append), push (replace), delete

```typescript
const gateway = new Pushgateway('http://pushgateway:9091');

// Push metrics
await gateway.pushAdd({
  jobName: 'batch-job',
  groupings: { instance: 'server-1' }
});

// Delete metrics
await gateway.delete({
  jobName: 'batch-job'
});
```

---

## OpenTelemetry Best Practices

### 1. Tracing Setup

#### Node.js SDK Initialization

- **Auto-instrumentation:** Automatically instrument common modules
- **Exporters:** Send traces to Jaeger, Zipkin, or OTLP Collector
- **Span processors:** SimpleSpanProcessor (immediate), BatchSpanProcessor (batched)

```typescript
const opentelemetry = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { ConsoleSpanExporter } = require('@opentelemetry/sdk-trace-base');

const sdk = new opentelemetry.NodeSDK({
  traceExporter: new ConsoleSpanExporter(),
  instrumentations: [getNodeAutoInstrumentations()]
});

sdk.start();

process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => console.log('SDK shut down successfully'))
    .finally(() => process.exit(0));
});
```

### 2. Metrics Collection

#### Meter Provider Setup

- **Instruments:** Counter, UpDownCounter, Histogram, Gauge
- **Exporters:** Prometheus, OTLP, Jaeger
- **Views:** Customize metric behavior

```typescript
const { MeterProvider, PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
const { PrometheusExporter } = require('@opentelemetry/exporter-prometheus');

const prometheusExporter = new PrometheusExporter();

const meterProvider = new MeterProvider({
  readers: [prometheusExporter]
});

const meter = meterProvider.getMeter('my-service', '1.0.0');
```

### 3. Instrumentation

#### HTTP Instrumentation

- **Automatic:** Captures HTTP requests/responses
- **Attributes:** Method, status code, URL, latency
- **Custom hooks:** Add custom attributes to spans

```typescript
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');
const { registerInstrumentations } = require('@opentelemetry/instrumentation');

registerInstrumentations({
  instrumentations: [
    new HttpInstrumentation({
      requestHook: (span, request) => {
        span.setAttribute('custom.attribute', 'value');
      }
    })
  ]
});
```

### 4. Context Propagation

#### W3C Trace Context

- **Standard:** W3C Trace Context for distributed tracing
- **Headers:** traceparent, tracestate
- **Baggage:** Additional context data

```typescript
const { W3CTraceContextPropagator } = require('@opentelemetry/core');
const api = require('@opentelemetry/api');

api.propagation.setGlobalPropagator(new W3CTraceContextPropagator());
```

### 5. Span Attributes

#### Best Practices

- **Semantic conventions:** Use standard attribute names
- **Cardinality:** Avoid high-cardinality attributes
- **Consistency:** Use consistent naming across spans

```typescript
const { ATTR_HTTP_REQUEST_METHOD, ATTR_HTTP_RESPONSE_STATUS_CODE } = require('@opentelemetry/semantic-conventions');

span.setAttribute(ATTR_HTTP_REQUEST_METHOD, 'GET');
span.setAttribute(ATTR_HTTP_RESPONSE_STATUS_CODE, 200);
```

---

## Implementation Guidelines for CloudToLocalLLM

### Prometheus Metrics

**File:** `services/streaming-proxy/src/metrics/server-metrics-collector.ts`

Implement the following metrics:

1. **Connection Metrics**
   - `tunnel_connections_total` (Counter) - Total connections established
   - `tunnel_active_connections` (Gauge) - Currently active connections
   - `tunnel_connection_duration_seconds` (Histogram) - Connection duration

2. **Request Metrics**
   - `tunnel_requests_total` (Counter) - Total requests forwarded
   - `tunnel_request_duration_seconds` (Histogram) - Request latency
   - `tunnel_request_size_bytes` (Histogram) - Request size
   - `tunnel_response_size_bytes` (Histogram) - Response size

3. **Error Metrics**
   - `tunnel_errors_total` (Counter) - Total errors by type
   - `tunnel_error_rate` (Gauge) - Error rate percentage

4. **Queue Metrics**
   - `tunnel_queue_size` (Gauge) - Current queue size
   - `tunnel_queue_max_size` (Gauge) - Maximum queue size
   - `tunnel_queue_drops_total` (Counter) - Dropped requests

5. **SSH Metrics**
   - `tunnel_ssh_connections_total` (Counter) - SSH connections
   - `tunnel_ssh_keep_alive_failures_total` (Counter) - Keep-alive failures
   - `tunnel_ssh_channel_count` (Gauge) - Active SSH channels

### OpenTelemetry Tracing

**File:** `services/streaming-proxy/src/tracing/tracer.ts`

Implement tracing for:

1. **Connection Lifecycle**
   - Span: `tunnel.connection.establish`
   - Span: `tunnel.connection.close`

2. **Request Processing**
   - Span: `tunnel.request.forward`
   - Span: `tunnel.request.queue`
   - Span: `tunnel.request.execute`

3. **Error Handling**
   - Span: `tunnel.error.handle`
   - Attributes: error type, category, recovery action

---

## Code Comments Template

Add these comments to monitoring code:

```typescript
/**
 * Prometheus Metrics Collection
 * 
 * Collects metrics for tunnel monitoring with best practices:
 * - Uses appropriate metric types (Counter, Gauge, Histogram, Summary)
 * - Minimizes label cardinality to prevent cardinality explosion
 * - Pre-initializes all expected label combinations with zero()
 * - Implements proper bucket configuration for histograms
 * - Exposes metrics at /metrics endpoint in Prometheus format
 * 
 * Reference: prom-client library documentation
 * Library ID: /siimon/prom-client
 * Trust Score: 7.0/10
 * 
 * Metrics Exposed:
 * - tunnel_connections_total: Total connections established
 * - tunnel_active_connections: Currently active connections
 * - tunnel_request_duration_seconds: Request latency distribution
 * - tunnel_errors_total: Total errors by category
 * - tunnel_queue_size: Current request queue size
 * 
 * Requirements:
 * - 3.1: Collect connection metrics
 * - 3.2: Collect request metrics
 * - 3.3: Collect error metrics
 * - 3.4: Collect queue metrics
 * - 3.5: Collect SSH metrics
 * - 11.1: Expose Prometheus metrics endpoint
 */
```

---

## References

### Prometheus Client

- **Repository:** https://github.com/siimon/prom-client
- **NPM:** https://www.npmjs.com/package/prom-client
- **Documentation:** https://github.com/siimon/prom-client/blob/master/README.md
- **Context7 ID:** `/siimon/prom-client`

### OpenTelemetry

- **Repository:** https://github.com/open-telemetry/opentelemetry-js
- **NPM:** https://www.npmjs.com/package/@opentelemetry/sdk-node
- **Documentation:** https://opentelemetry.io/docs/instrumentation/js/
- **Context7 ID:** `/open-telemetry/opentelemetry-js`

### Standards

- **Prometheus:** https://prometheus.io/docs/instrumenting/exposition_formats/
- **OpenTelemetry:** https://opentelemetry.io/docs/
- **Semantic Conventions:** https://opentelemetry.io/docs/reference/specification/protocol/exporter/

---

## Related Requirements

This documentation addresses the following requirements:

- **Requirement 11.1:** Expose Prometheus metrics endpoint
- **Requirement 11.6:** Implement OpenTelemetry tracing
- **Requirement 12.3:** Library documentation and best practices
- **Requirement 3.1-3.5:** Metrics collection
- **Requirement 3.8:** Slow request detection
- **Requirement 3.10:** Metrics retention and aggregation

---

## Document Metadata

- **Created:** 2024
- **Last Updated:** 2024
- **Task:** 19.3 - Resolve and document monitoring libraries
- **Libraries:** prom-client, OpenTelemetry
- **Trust Scores:** 7.0/10, 9.3/10
- **Code Snippets:** 38 + 219 = 257 total
