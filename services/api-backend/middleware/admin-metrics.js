/**
 * Admin Center Prometheus Metrics
 *
 * Collects metrics for Admin Center API endpoints including:
 * - API request count and response times
 * - Payment success/failure rates
 * - Refund processing times
 * - Database query performance
 * - Stripe API interaction metrics
 *
 * Requirements: Task 31.2, Requirement 12
 */

import {
  Counter,
  Histogram,
  Gauge,
  Registry,
  collectDefaultMetrics,
} from 'prom-client';

/**
 * Admin Center metrics registry
 */
export const adminMetricsRegistry = new Registry();

// Collect default Node.js metrics
collectDefaultMetrics({ register: adminMetricsRegistry, prefix: 'admin_' });

/**
 * Counter: Total API requests
 * Labels: method (GET, POST, PATCH, DELETE), endpoint, status_code
 */
export const adminApiRequestsTotal = new Counter({
  name: 'admin_api_requests_total',
  help: 'Total number of Admin API requests',
  labelNames: ['method', 'endpoint', 'status_code'],
  registers: [adminMetricsRegistry],
});

/**
 * Histogram: API response time in milliseconds
 * Labels: method, endpoint
 * Buckets: 10, 50, 100, 200, 500, 1000, 2000, 5000 ms
 */
export const adminApiResponseTimeMs = new Histogram({
  name: 'admin_api_response_time_ms',
  help: 'Admin API response time in milliseconds',
  labelNames: ['method', 'endpoint'],
  buckets: [10, 50, 100, 200, 500, 1000, 2000, 5000],
  registers: [adminMetricsRegistry],
});

/**
 * Counter: Payment processing attempts
 * Labels: status (success, failed), payment_method (card, paypal)
 */
export const adminPaymentAttemptsTotal = new Counter({
  name: 'admin_payment_attempts_total',
  help: 'Total payment processing attempts',
  labelNames: ['status', 'payment_method'],
  registers: [adminMetricsRegistry],
});

/**
 * Gauge: Payment success rate (0-1)
 */
export const adminPaymentSuccessRate = new Gauge({
  name: 'admin_payment_success_rate',
  help: 'Payment success rate (0-1)',
  registers: [adminMetricsRegistry],
});

/**
 * Gauge: Payment failure rate (0-1)
 */
export const adminPaymentFailureRate = new Gauge({
  name: 'admin_payment_failure_rate',
  help: 'Payment failure rate (0-1)',
  registers: [adminMetricsRegistry],
});

/**
 * Counter: Refund processing attempts
 * Labels: status (success, failed), reason
 */
export const adminRefundAttemptsTotal = new Counter({
  name: 'admin_refund_attempts_total',
  help: 'Total refund processing attempts',
  labelNames: ['status', 'reason'],
  registers: [adminMetricsRegistry],
});

/**
 * Histogram: Refund processing time in milliseconds
 * Buckets: 100, 500, 1000, 2000, 5000, 10000 ms
 */
export const adminRefundProcessingTimeMs = new Histogram({
  name: 'admin_refund_processing_time_ms',
  help: 'Refund processing time in milliseconds',
  buckets: [100, 500, 1000, 2000, 5000, 10000],
  registers: [adminMetricsRegistry],
});

/**
 * Counter: Subscription operations
 * Labels: operation (create, update, cancel), status (success, failed)
 */
export const adminSubscriptionOperationsTotal = new Counter({
  name: 'admin_subscription_operations_total',
  help: 'Total subscription operations',
  labelNames: ['operation', 'status'],
  registers: [adminMetricsRegistry],
});

/**
 * Counter: Database queries
 * Labels: operation (select, insert, update, delete), table
 */
export const adminDatabaseQueriesTotal = new Counter({
  name: 'admin_database_queries_total',
  help: 'Total database queries',
  labelNames: ['operation', 'table'],
  registers: [adminMetricsRegistry],
});

/**
 * Histogram: Database query execution time in milliseconds
 * Labels: operation, table
 * Buckets: 1, 5, 10, 50, 100, 500, 1000 ms
 */
export const adminDatabaseQueryTimeMs = new Histogram({
  name: 'admin_database_query_time_ms',
  help: 'Database query execution time in milliseconds',
  labelNames: ['operation', 'table'],
  buckets: [1, 5, 10, 50, 100, 500, 1000],
  registers: [adminMetricsRegistry],
});

/**
 * Counter: Stripe API calls
 * Labels: operation (payment, refund, subscription), status (success, failed)
 */
export const adminStripeApiCallsTotal = new Counter({
  name: 'admin_stripe_api_calls_total',
  help: 'Total Stripe API calls',
  labelNames: ['operation', 'status'],
  registers: [adminMetricsRegistry],
});

/**
 * Histogram: Stripe API response time in milliseconds
 * Labels: operation
 * Buckets: 100, 500, 1000, 2000, 5000, 10000 ms
 */
export const adminStripeApiResponseTimeMs = new Histogram({
  name: 'admin_stripe_api_response_time_ms',
  help: 'Stripe API response time in milliseconds',
  labelNames: ['operation'],
  buckets: [100, 500, 1000, 2000, 5000, 10000],
  registers: [adminMetricsRegistry],
});

/**
 * Counter: Stripe API errors
 * Labels: error_type (network, auth, rate_limit, server)
 */
export const adminStripeApiErrorsTotal = new Counter({
  name: 'admin_stripe_api_errors_total',
  help: 'Total Stripe API errors',
  labelNames: ['error_type'],
  registers: [adminMetricsRegistry],
});

/**
 * Counter: Admin actions
 * Labels: action (user_suspend, user_reactivate, subscription_change, refund_process), admin_role
 */
export const adminActionsTotal = new Counter({
  name: 'admin_actions_total',
  help: 'Total admin actions performed',
  labelNames: ['action', 'admin_role'],
  registers: [adminMetricsRegistry],
});

/**
 * Gauge: Active admin sessions
 */
export const adminActiveSessionsGauge = new Gauge({
  name: 'admin_active_sessions',
  help: 'Number of active admin sessions',
  registers: [adminMetricsRegistry],
});

/**
 * Counter: Authentication attempts
 * Labels: result (success, failed), reason (invalid_token, expired_token, no_admin_role)
 */
export const adminAuthAttemptsTotal = new Counter({
  name: 'admin_auth_attempts_total',
  help: 'Total admin authentication attempts',
  labelNames: ['result', 'reason'],
  registers: [adminMetricsRegistry],
});

/**
 * Counter: API errors
 * Labels: error_type (validation, database, stripe, server), status_code
 */
export const adminApiErrorsTotal = new Counter({
  name: 'admin_api_errors_total',
  help: 'Total Admin API errors',
  labelNames: ['error_type', 'status_code'],
  registers: [adminMetricsRegistry],
});

/**
 * Gauge: Error rate (0-1)
 */
export const adminErrorRate = new Gauge({
  name: 'admin_error_rate',
  help: 'Admin API error rate (0-1)',
  registers: [adminMetricsRegistry],
});

/**
 * Histogram: Slow API requests (>2 seconds)
 */
export const adminSlowRequestsTotal = new Counter({
  name: 'admin_slow_requests_total',
  help: 'Total slow API requests (>2 seconds)',
  labelNames: ['method', 'endpoint'],
  registers: [adminMetricsRegistry],
});

/**
 * Gauge: Database connection pool size
 */
export const adminDbPoolSize = new Gauge({
  name: 'admin_db_pool_size',
  help: 'Database connection pool size',
  registers: [adminMetricsRegistry],
});

/**
 * Gauge: Database connection pool idle connections
 */
export const adminDbPoolIdleConnections = new Gauge({
  name: 'admin_db_pool_idle_connections',
  help: 'Number of idle database connections',
  registers: [adminMetricsRegistry],
});

/**
 * Gauge: Database connection pool waiting requests
 */
export const adminDbPoolWaitingRequests = new Gauge({
  name: 'admin_db_pool_waiting_requests',
  help: 'Number of requests waiting for database connection',
  registers: [adminMetricsRegistry],
});

/**
 * Export metrics in Prometheus text format
 */
export async function exportAdminMetricsAsText() {
  return adminMetricsRegistry.metrics();
}

/**
 * Get admin metrics registry
 */
export function getAdminMetricsRegistry() {
  return adminMetricsRegistry;
}

/**
 * Initialize all metrics with zero values
 */
export function initializeAdminMetrics() {
  // Initialize payment metrics
  const paymentStatuses = ['success', 'failed'];
  const paymentMethods = ['card', 'paypal'];
  for (const status of paymentStatuses) {
    for (const method of paymentMethods) {
      adminPaymentAttemptsTotal.labels(status, method).inc(0);
    }
  }

  // Initialize refund metrics
  const refundReasons = [
    'customer_request',
    'billing_error',
    'service_issue',
    'duplicate',
    'fraudulent',
    'other',
  ];
  for (const status of paymentStatuses) {
    for (const reason of refundReasons) {
      adminRefundAttemptsTotal.labels(status, reason).inc(0);
    }
  }

  // Initialize subscription metrics
  const subscriptionOps = ['create', 'update', 'cancel'];
  for (const op of subscriptionOps) {
    for (const status of paymentStatuses) {
      adminSubscriptionOperationsTotal.labels(op, status).inc(0);
    }
  }

  // Initialize Stripe API metrics
  const stripeOps = ['payment', 'refund', 'subscription'];
  for (const op of stripeOps) {
    for (const status of paymentStatuses) {
      adminStripeApiCallsTotal.labels(op, status).inc(0);
    }
  }

  // Initialize Stripe error types
  const stripeErrorTypes = ['network', 'auth', 'rate_limit', 'server'];
  for (const errorType of stripeErrorTypes) {
    adminStripeApiErrorsTotal.labels(errorType).inc(0);
  }

  // Initialize auth attempts
  adminAuthAttemptsTotal.labels('success', '').inc(0);
  adminAuthAttemptsTotal.labels('failed', 'invalid_token').inc(0);
  adminAuthAttemptsTotal.labels('failed', 'expired_token').inc(0);
  adminAuthAttemptsTotal.labels('failed', 'no_admin_role').inc(0);

  // Initialize error metrics
  const errorTypes = ['validation', 'database', 'stripe', 'server'];
  const statusCodes = ['400', '401', '403', '404', '500', '503'];
  for (const errorType of errorTypes) {
    for (const statusCode of statusCodes) {
      adminApiErrorsTotal.labels(errorType, statusCode).inc(0);
    }
  }

  // Initialize gauges
  adminPaymentSuccessRate.set(0);
  adminPaymentFailureRate.set(0);
  adminErrorRate.set(0);
  adminActiveSessionsGauge.set(0);
  adminDbPoolSize.set(0);
  adminDbPoolIdleConnections.set(0);
  adminDbPoolWaitingRequests.set(0);
}

/**
 * Middleware to track API request metrics
 */
export function adminMetricsMiddleware(req, res, next) {
  const start = Date.now();
  const endpoint = req.route?.path || req.path;
  const method = req.method;

  // Track response
  res.on('finish', () => {
    const duration = Date.now() - start;
    const statusCode = res.statusCode.toString();

    // Increment request counter
    adminApiRequestsTotal.labels(method, endpoint, statusCode).inc();

    // Record response time
    adminApiResponseTimeMs.labels(method, endpoint).observe(duration);

    // Track slow requests (>2 seconds)
    if (duration > 2000) {
      adminSlowRequestsTotal.labels(method, endpoint).inc();
    }

    // Track errors
    if (statusCode.startsWith('4') || statusCode.startsWith('5')) {
      const errorType = statusCode.startsWith('4') ? 'validation' : 'server';
      adminApiErrorsTotal.labels(errorType, statusCode).inc();
    }
  });

  next();
}

/**
 * Update payment success/failure rates
 */
export function updatePaymentRates(successCount, failureCount) {
  const total = successCount + failureCount;
  if (total > 0) {
    adminPaymentSuccessRate.set(successCount / total);
    adminPaymentFailureRate.set(failureCount / total);
  }
}

/**
 * Update error rate
 */
export function updateErrorRate(errorCount, totalCount) {
  if (totalCount > 0) {
    adminErrorRate.set(errorCount / totalCount);
  }
}

/**
 * Track database query
 */
export function trackDatabaseQuery(operation, table, durationMs) {
  adminDatabaseQueriesTotal.labels(operation, table).inc();
  adminDatabaseQueryTimeMs.labels(operation, table).observe(durationMs);
}

/**
 * Track Stripe API call
 */
export function trackStripeApiCall(operation, status, durationMs) {
  adminStripeApiCallsTotal.labels(operation, status).inc();
  adminStripeApiResponseTimeMs.labels(operation).observe(durationMs);
}

/**
 * Track Stripe API error
 */
export function trackStripeApiError(errorType) {
  adminStripeApiErrorsTotal.labels(errorType).inc();
}

/**
 * Track admin action
 */
export function trackAdminAction(action, adminRole) {
  adminActionsTotal.labels(action, adminRole).inc();
}

/**
 * Track authentication attempt
 */
export function trackAuthAttempt(result, reason = '') {
  adminAuthAttemptsTotal.labels(result, reason).inc();
}

/**
 * Update database pool metrics
 */
export function updateDbPoolMetrics(
  poolSize,
  idleConnections,
  waitingRequests,
) {
  adminDbPoolSize.set(poolSize);
  adminDbPoolIdleConnections.set(idleConnections);
  adminDbPoolWaitingRequests.set(waitingRequests);
}
