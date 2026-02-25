# ADR 003: Monitoring Strategy

## Status

Accepted

## Context

Assessment of whether Grafana is required for CloudToLocalLLM operations.

## Decision

Adopt a hybrid monitoring approach:

1. **Sentry**: For error tracking and exception management.
2. **Prometheus (In-Cluster)**: For metrics collection and time-series data.
3. **Grafana Cloud (SaaS)**: For visualization and alerting.

## Consequences

- **Positive**: Maintains provider-agnostic portability (no Azure Monitor lock-in).
- **Positive**: Zero local storage overhead for metrics (SaaS handles retention).
- **Negative**: Requires Prometheus to be running in-cluster (~512MB RAM cost).
