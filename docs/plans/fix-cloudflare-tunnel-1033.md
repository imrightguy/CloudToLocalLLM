# Fix Cloudflare Tunnel Error 1033 Plan

## Context
Cloudflare Tunnel Error 1033 at https://app.cloudtolocalllm.online indicates tunnel connection issues. Namespace: `cloudtolocalllm`. Deployment: `cloudflared`. Tunnel ID: `62da6c19-947b-4bf6-acad-100a73de4e0d`.

## Mermaid Workflow
```mermaid
graph TD
    A[Error 1033 Detected] --> B[kubectl get pods -n cloudtolocalllm | grep cloudflared]
    B --> C{Pods Running?}
    C -->|No| D[Logs: kubectl logs deployment/cloudflared -n cloudtolocalllm<br/>Restart: kubectl rollout restart deployment/cloudflared -n cloudtolocalllm]
    C -->|Yes| E[Set GH Secrets: export CLOUDFLARE_API_KEY=$(gh secret get CLOUDFLARE_API_KEY)<br/>etc.]
    E --> F[Diagnostic: bash scripts/cloudflare-tunnel-diagnostic.sh]
    F --> G{DNS/CNAME Issue?}
    G -->|Yes| H[bash scripts/cloudflare-dns-repair.sh]
    G -->|No| I[Verify ConfigMap cloudflared-config]
    I --> J[Purge Cache: bash scripts/cloudflare-cache-purge.sh]
    J --> K[Manual: CF Zero Trust Dashboard]
    K --> L[Test: curl -I https://app.cloudtolocalllm.online/]
    L --> M{Resolved?}
    M -->|No| N[gh workflow run Build Pipeline -f promote=true]
    M -->|Yes| O[Done]
```

## Actionable Todo List
- [x] Verify Kubernetes cluster status: `kubectl get nodes`; `kubectl get pods -n cloudtolocalllm | grep cloudflared`; `kubectl get deployments,daemonsets -n cloudtolocalllm | grep cloudflare`
- [ ] Inspect cloudflared pod logs: `kubectl logs -n cloudtolocalllm deployment/cloudflared --tail=100 -f`
- [ ] List k8s resources: `kubectl get configmaps,secrets -n cloudtolocalllm | grep -E 'cloudflare| tunnel'`; `kubectl get ingress -n cloudtolocalllm`
- [ ] Check secrets: `kubectl get secret tunnel-credentials cloudflare-api-token cloudflare-cache-secrets -n cloudtolocalllm -o yaml`
- [ ] Retrieve/set GH secrets locally: `gh secret list`; `export CLOUDFLARE_API_KEY=$(gh secret get CLOUDFLARE_API_KEY)`; `export CLOUDFLARE_TUNNEL_TOKEN=$(gh secret get CLOUDFLARE_TUNNEL_TOKEN)`
- [ ] Run diagnostic: `cd scripts && bash cloudflare-tunnel-diagnostic.sh`
- [ ] Repair DNS/CNAME if needed: `bash scripts/cloudflare-dns-repair.sh`
- [ ] Verify ConfigMap: `kubectl get configmap cloudflared-config -n cloudtolocalllm -o yaml`; tunnel ID 62da6c19-947b-4bf6-acad-100a73de4e0d
- [ ] Restart cloudflared: `kubectl rollout restart deployment/cloudflared -n cloudtolocalllm`
- [ ] Purge cache: `bash scripts/cloudflare-cache-purge.sh`
- [ ] Manual verify: Cloudflare Zero Trust dashboard tunnel status
- [ ] Test: `curl -I https://app.cloudtolocalllm.online/`; browser reload
- [ ] If needed: `gh workflow run \"🚀 Build Pipeline\" --ref main -f promote=true`
- [ ] Confirm fix, close browser session if open

## References
- [SOP](docs/plans/cloudflared_error_1033_sop.md)
- [k8s manifests](k8s/apps/local/ingress-cloudflared/)
- [Scripts](scripts/cloudflare-*.sh)