# CloudToLocalLLM Docker Deployment Guide

> **Status**: Historical Docker Swarm runbook for the older streaming-proxy stack. Current deployment direction is described in [docs/deployment/DEPLOYMENT_OVERVIEW.md](docs/deployment/DEPLOYMENT_OVERVIEW.md): agent-runtime-first, Tailscale-first, optional per-user cloud connector, and optional hosted agent runtime. Use this file only when maintaining the older Swarm deployment path.

## Prerequisites

- Docker Swarm initialized (already running on LXC container)
- Domain names configured (or use IP addresses)
- Auth0 application configured (for JWT authentication)

## LXC Container Details

- **IP Address**: 208.110.72.52
- **SSH Access**: `ssh root@208.110.72.50 "pct enter 201"`
- **Resources**: 4 cores, 16GB RAM, 100GB disk

## Quick Start

### 1. Configure Environment Variables

```bash
# SSH into the container
ssh root@208.110.72.50 "pct exec 201 -- bash"

# Copy and edit the environment file
cd /opt/cloudtolocalllm
cp .env.example .env
nano .env  # Edit with your values
```

Required environment variables:
- `AUTH0_DOMAIN` - Your Auth0 domain
- `AUTH0_AUDIENCE` - Your API identifier
- `JWT_SECRET` - Strong random string for JWT signing
- `REDIS_PASSWORD` - Strong random string for Redis
- `LETSENCRYPT_EMAIL` - Email for SSL certificates
- `SENTRY_DSN` - Optional: Sentry error tracking DSN
- `GRAFANA_ADMIN_PASSWORD` - Grafana admin password

### 2. Build Service Images

From your local machine (in the project root):

```bash
# Build API Backend image
docker build -t cloudtolocalllm/api-backend:latest ./services/api-backend

# Build Streaming Proxy image
docker build -t cloudtolocalllm/streaming-proxy:latest ./services/streaming-proxy

# Save images to tar files
docker save cloudtolocalllm/api-backend:latest | gzip > api-backend.tar.gz
docker save cloudtolocalllm/streaming-proxy:latest | gzip > streaming-proxy.tar.gz

# Copy to container
scp api-backend.tar.gz root@208.110.72.52:/tmp/
scp streaming-proxy.tar.gz root@208.110.72.52:/tmp/
```

Then in the container:

```bash
# Load images
docker load < /tmp/api-backend.tar.gz
docker load < /tmp/streaming-proxy.tar.gz
```

### 3. Deploy Stack

```bash
cd /opt/cloudtolocalllm
docker stack deploy -c docker-compose.prod.yml cloudtolocalllm
```

### 4. Verify Deployment

```bash
# Check services
docker service ls

# Check service logs
docker service logs -f cloudtolocalllm_api-backend
docker service logs -f cloudtolocalllm_streaming-proxy

# Check health
curl http://localhost:8080/health
curl http://localhost:3001/health
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| API Backend | 8080 | REST API with Auth0 JWT |
| Streaming Proxy | 3001 | Legacy/fallback WebSocket proxy service |
| Redis | 6379 | Rate limiting cache |
| Traefik | 80, 443 | Reverse proxy with SSL |
| Prometheus | 9090 | Metrics collection |
| Grafana | 3000 | Metrics visualization |

## Scaling

```bash
# Scale API backend
docker service scale cloudtolocalllm_api-backend=3

# Scale streaming proxy
docker service scale cloudtolocalllm_streaming-proxy=2
```

## Updating

```bash
# Build new images
docker build -t cloudtolocalllm/api-backend:v1.0.1 ./services/api-backend

# Update stack with new image
docker service update --image cloudtolocalllm/api-backend:v1.0.1 cloudtolocalllm_api-backend
```

## Monitoring

- **Grafana**: http://208.110.72.52:3000 (or via Traefik domain)
- **Prometheus**: http://208.110.72.52:9090
- **Traefik Dashboard**: http://208.110.72.52:8080

## Troubleshooting

### View logs for all services
```bash
docker service logs cloudtolocalllm_api-backend --tail 100
```

### Restart a service
```bash
docker service update --force cloudtolocalllm_api-backend
```

### Remove the stack
```bash
docker stack rm cloudtolocalllm
```

### Check resource usage
```bash
docker stats
```

## Production Checklist

- [ ] Configure SSL/TLS certificates (Let's Encrypt via Traefik)
- [ ] Set up monitoring alerts (Prometheus/Grafana)
- [ ] Configure backup strategy for volumes
- [ ] Review security settings (firewall, auth)
- [ ] Test failover and recovery procedures
- [ ] Set up log aggregation (Winston -> Sentry/ELK)
