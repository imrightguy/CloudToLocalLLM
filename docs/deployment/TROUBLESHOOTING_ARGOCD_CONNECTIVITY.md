# Troubleshooting ArgoCD Connectivity (502 Bad Gateway)

This guide provides steps to diagnose and resolve 502 Bad Gateway errors when accessing ArgoCD via the Cloudflare Tunnel (`https://argocd.cloudtolocalllm.online/`).

## 1. Verify Internal Connectivity

Ensure the ArgoCD server is accessible within the cluster.

```bash
# Check if argocd-server pod is running
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# Verify the service is correct
kubectl get svc argocd-server -n argocd

# Test connectivity from a pod in the CloudToLocalLLM namespace
kubectl run curl-test --image=curlimages/curl -n CloudToLocalLLM -it --rm -- \
  curl -v http://argocd-server.argocd.svc.cluster.local:80/healthz
```

## 2. Common Causes & Fixes

### A. Protocol Mismatch (HTTP vs HTTPS)

`cloudflared` logs showing `tls: first record does not look like a TLS handshake` indicates that `cloudflared` is trying to use HTTPS to talk to an HTTP backend.

**Fix:**
Ensure the `cloudflared-config` uses the correct protocol and port. ArgoCD server with the `--insecure` flag listens on port 8080 (Service port 80).

```yaml
- hostname: argocd.cloudtolocalllm.online
  service: http://argocd-server.argocd.svc.cluster.local:80
```

### B. TLS Verification Issues

If ArgoCD is using a self-signed certificate internally, `cloudflared` might fail to verify it.

**Fix:**
Add `noTLSVerify: true` to the ingress rule.

```yaml
- hostname: argocd.cloudtolocalllm.online
  service: https://argocd-server.argocd.svc.cluster.local:443
  originRequest:
    noTLSVerify: true
```

### C. Host Header Mismatch

ArgoCD might reject requests if the `Host` header doesn't match its expected internal or external domain.

**Fix:**
Explicitly set the `httpHostHeader` in the tunnel config.

```yaml
- hostname: argocd.cloudtolocalllm.online
  service: http://argocd-server.argocd.svc.cluster.local:80
  originRequest:
    httpHostHeader: argocd.cloudtolocalllm.online
```

## 3. Deployment Stability

To ensure `cloudflared` always picks up the latest configuration:

- The deployment uses `checksum/config` annotation to trigger rolling restarts on ConfigMap updates.
- Image version is pinned to a stable release (e.g., `2024.12.2`).
- Replicas are set to `2` for high availability.

## 4. Monitoring Domain Health

Domain health is tracked via Prometheus Blackbox Exporter.
Check the Grafana dashboard or Prometheus targets to see the status of `https://argocd.cloudtolocalllm.online/`.
Alerts will be triggered if the domain is down for more than 1 minute.
