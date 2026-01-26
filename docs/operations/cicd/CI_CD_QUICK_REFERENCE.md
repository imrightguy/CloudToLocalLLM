# CI/CD Quick Reference

## Azure VM Deployment ✓

The deployment pipeline is automated via GitHub Actions using Service Principal authentication.

### Pipeline: deployment.yml

1. **AI Analysis**: Determines which components changed.
2. **Build**: Build Docker images for changed components (API, Web, Proxy, Postgres).
3. **Registry**: Push images to GHCR (ghcr.io).
4. **Deploy**: SSH into Azure Swarm VM and update stack.

### Required Secrets

- `AZURE_CREDENTIALS`: Service Principal JSON.
- `CLOUDFLARE_TUNNEL_TOKEN`: For ingress.
- `JWT_SECRET`: API authentication.
- `POSTGRES_PASSWORD`: Database security.

### Quick Commands

```bash
# Trigger manual build
gh workflow run deployment.yml -f force_build=true

# View deployment logs
gh run list --workflow="deployment.yml" --limit 3
```
